import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:translator/translator.dart';

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class ChatProvider with ChangeNotifier {
  final List<ChatMessage> _messages = [];
  String _responseMessage = '';
  bool _isLoading = false;
  final GoogleTranslator _translator = GoogleTranslator();
  bool _useHuggingFace = false; // Flag to switch between APIs

  List<ChatMessage> get messages => _messages;
  String get responseMessage => _responseMessage;
  bool get isLoading => _isLoading;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> sendMessage(String prompt) async {
    _messages.add(ChatMessage(text: prompt, isUser: true));
    _setLoading(true);

    try {
      await generateMessage(prompt);
    } catch (e) {
      print('Error in sendMessage during generateMessage call: $e');
      // If OpenRouter fails, try HuggingFace
      if (!_useHuggingFace) {
        print('Switching to HuggingFace API...');
        _useHuggingFace = true;
        try {
          await generateMessage(prompt);
          _useHuggingFace = false; // Reset for next message
          return;
        } catch (e2) {
          print('HuggingFace API also failed: $e2');
        }
      }
      _messages.add(
          ChatMessage(text: 'Error generating response: $e', isUser: false));
    } finally {
      _setLoading(false);
      _useHuggingFace = false; // Reset for next message
    }
  }

  String _formatResponseText(String rawText) {
    // Your existing formatting logic remains the same...
    List<String> lines = rawText.split('\n');
    List<String> formattedLines = lines.map((line) {
      String trimmedLine = line.trimLeft();
      if (trimmedLine.startsWith('///')) {
        String content = trimmedLine.substring(3);
        return '.${content.startsWith(' ') ? content : ' $content'}'
            .trimRight();
      } else {
        return line;
      }
    }).toList();
    String intermediateText = formattedLines.join('\n');
    String textWithoutBoxed = intermediateText.replaceAll(r'\boxed', '');
    String textWithoutBraces =
        textWithoutBoxed.replaceAll('{', '').replaceAll('}', '');
    return textWithoutBraces;
  }

  Future<void> generateMessage(String prompt) async {
    if (_useHuggingFace) {
      await _generateWithHuggingFace(prompt);
    } else {
      await _generateWithOpenRouter(prompt);
    }
  }

  Future<void> _generateWithHuggingFace(String prompt) async {
    final huggingFaceKey = dotenv.env['HUGGINGFACE_API_KEY'];

    if (huggingFaceKey == null || huggingFaceKey.isEmpty) {
      print('Error: HUGGINGFACE_API_KEY not found in .env file.');
      throw Exception('HuggingFace API Key missing');
    }

    final url = Uri.parse(
        'https://api-inference.huggingface.co/models/mistralai/Mixtral-8x7B-Instruct-v0.1');
    final headers = {
      'Authorization': 'Bearer $huggingFaceKey',
      'Content-Type': 'application/json',
    };

    final systemPrompt =
        """Tu es un assistant IA spécialisé dans l'enseignement du français. Instructions IMPORTANTES:
1. Tu DOIS répondre UNIQUEMENT en français
2. N'utilise JAMAIS l'anglais, même pour des clarifications
3. Si l'utilisateur pose une question en anglais, traduis-la mentalement et réponds en français
4. Adapte ton niveau de français à celui de l'utilisateur
5. Corrige poliment les erreurs de français de l'utilisateur
6. Encourage l'apprentissage avec un ton positif et bienveillant""";

    final body = jsonEncode({
      "inputs": "$systemPrompt\n\nUser: $prompt\n\nAssistant:",
      "parameters": {
        "max_new_tokens": 1000,
        "temperature": 0.7,
        "top_p": 0.95,
        "return_full_text": false
      }
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData is List && responseData.isNotEmpty) {
          final generatedText =
              responseData[0]['generated_text']?.toString().trim();
          if (generatedText != null && generatedText.isNotEmpty) {
            _messages.add(ChatMessage(text: generatedText, isUser: false));
            return;
          }
        }
        throw Exception('Unexpected response format from HuggingFace');
      } else {
        throw Exception('HuggingFace API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calling HuggingFace API: $e');
      rethrow;
    }
  }

  Future<void> _generateWithOpenRouter(String prompt) async {
    final apiKey = dotenv.env['OPENROUTER_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      print('Error: OPENROUTER_API_KEY not found in .env file.');
      _messages.add(ChatMessage(
          text: 'Error: API Key configuration missing.', isUser: false));
      return;
    }

    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'HTTP-Referer': 'https://pronounce-it-right.com',
    };

    // Enhanced system prompt to strictly enforce French responses
    final systemPrompt =
        """Tu es un assistant IA spécialisé dans l'enseignement du français. Instructions IMPORTANTES:
1. Tu DOIS répondre UNIQUEMENT en français
2. N'utilise JAMAIS l'anglais, même pour des clarifications
3. Si l'utilisateur pose une question en anglais, traduis-la mentalement et réponds en français
4. Adapte ton niveau de français à celui de l'utilisateur
5. Corrige poliment les erreurs de français de l'utilisateur
6. Encourage l'apprentissage avec un ton positif et bienveillant""";

    // Prepare user message with language instruction
    final userPrompt = """Je vais te poser une question. Souviens-toi:
- Réponds UNIQUEMENT en français
- Si ma question est en anglais, comprends-la mais réponds en français
- Aide-moi à améliorer mon français

Ma question est: $prompt""";

    final apiMessages = [
      {
        "role": "system",
        "content": systemPrompt,
      },
      {
        "role": "user",
        "content": userPrompt,
      }
    ];

    final body = jsonEncode({
      "model": "deepseek/deepseek-r1-zero:free",
      "messages": apiMessages,
      "temperature": 0.7, // Add some creativity while keeping responses focused
      "max_tokens": 1000, // Ensure we get complete responses
      "response_format": {"type": "text"}, // Ensure we get plain text responses
    });

    print('Sending API Request:');
    print(' URL: $url');
    // Avoid printing the full header with the key in production logs
    // print(' Headers: $headers');
    print(' Body: $body');

    try {
      final response = await http.post(url, headers: headers, body: body);

      print('Response status: ${response.statusCode}');
      // Only print body on success or non-sensitive errors in production
      print('Raw Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final messageContent =
            responseData['choices']?[0]?['message']?['content'];

        if (messageContent != null) {
          final rawMessage = messageContent.toString();
          print('Raw Generated Message:\n$rawMessage');
          final formattedMessage = _formatResponseText(rawMessage);
          print('Formatted Message:\n$formattedMessage');
          // Don't update _responseMessage here, just add to the list
          _messages.add(ChatMessage(text: formattedMessage, isUser: false));
        } else {
          print('Error: Could not find message content in response.');
          _messages.add(ChatMessage(
              text:
                  'Error: Received an unexpected response format from the API.',
              isUser: false));
        }
      } else {
        String errorMessage = 'API Error';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error']?['message']?.toString() ??
              errorData.toString();
        } catch (_) {
          // Use response body directly if JSON parsing fails
          errorMessage = response.body.length > 200
              ? '${response.body.substring(0, 200)}...'
              : response.body;
        }
        print('Error: ${response.statusCode} - $errorMessage');
        _messages.add(ChatMessage(
            text: 'Error (${response.statusCode}): $errorMessage',
            isUser: false));
      }
    } catch (e) {
      print('Error calling API in generateMessage: $e');
      _messages.add(
          ChatMessage(text: 'Network or processing error: $e', isUser: false));
    }
    // notifyListeners() is handled by _setLoading(false) in the finally block of sendMessage
  }

  Future<String> translateToEnglish(String text) async {
    print('TranslateToEnglish: Starting translation for text: "$text"');
    final apiKey = dotenv.env['OPENROUTER_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      print('TranslateToEnglish: Error - API Key missing');
      throw Exception('API Key configuration missing.');
    }

    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    print('TranslateToEnglish: Using API endpoint: $url');

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'HTTP-Referer': 'https://pronounce-it-right.com',
    };

    final systemPrompt = """You are a French to English translator. 
1. Translate the given French text to English accurately
2. ONLY provide the English translation, no additional text
3. Maintain the original tone and meaning""";

    final userPrompt = """Translate this French text to English: "$text\"""";
    print(
        'TranslateToEnglish: Prepared prompts - System and User prompts ready');

    final apiMessages = [
      {
        "role": "system",
        "content": systemPrompt,
      },
      {
        "role": "user",
        "content": userPrompt,
      }
    ];

    final body = jsonEncode({
      "model": "deepseek/deepseek-r1-zero:free",
      "messages": apiMessages,
      "temperature": 0.3,
      "max_tokens": 500,
      "response_format": {"type": "text"},
    });

    print('TranslateToEnglish: Sending API request...');
    try {
      final response = await http.post(url, headers: headers, body: body);
      print(
          'TranslateToEnglish: Received response with status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('TranslateToEnglish: Successfully parsed response JSON');

        final translation = responseData['choices']?[0]?['message']?['content'];
        if (translation != null) {
          final trimmedTranslation = translation.toString().trim();
          print(
              'TranslateToEnglish: Raw translation result: "$trimmedTranslation"');

          // Validate translation is not empty
          if (trimmedTranslation.isEmpty) {
            print('TranslateToEnglish: Error - Received empty translation');
            throw Exception('Received empty translation. Please try again.');
          }

          print(
              'TranslateToEnglish: Successfully translated. Result: "$trimmedTranslation"');
          return trimmedTranslation;
        } else {
          print(
              'TranslateToEnglish: Error - No translation content in response');
          throw Exception('Translation response format unexpected');
        }
      } else {
        print(
            'TranslateToEnglish: Error - API returned ${response.statusCode}');
        print('TranslateToEnglish: Error response body: ${response.body}');
        throw Exception('Translation failed: ${response.statusCode}');
      }
    } catch (e) {
      print('TranslateToEnglish: Critical error during translation: $e');
      throw Exception('Translation error: $e');
    }
  }

  Future<String> translate(
      String text, String fromLanguage, String toLanguage) async {
    print('Translate: Starting translation from $fromLanguage to $toLanguage');

    // Map language names to ISO codes
    final Map<String, String> languageCodes = {
      'Detect Language': 'auto',
      'English': 'en',
      'French': 'fr',
      'Spanish': 'es',
      'German': 'de',
      'Italian': 'it',
      'Portuguese': 'pt',
      'Russian': 'ru',
      'Chinese': 'zh-cn',
      'Japanese': 'ja',
      'Korean': 'ko',
      'Arabic': 'ar',
      'Hindi': 'hi'
    };

    try {
      final sourceCode = languageCodes[fromLanguage] ?? 'auto';
      final targetCode = languageCodes[toLanguage] ?? 'en';

      final translation = await _translator.translate(
        text,
        from: sourceCode,
        to: targetCode,
      );

      if (translation.text.isEmpty) {
        throw Exception('Received empty translation. Please try again.');
      }

      print('Translate: Successfully translated using Google Translate');
      return translation.text;
    } catch (e) {
      print('Translate: Error during translation: $e');
      throw Exception('Translation error: $e');
    }
  }
}
