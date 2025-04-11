import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/chat_provider.dart';
import '../services/audio_services.dart'; // Fixed import path

class ChatAiScreen extends StatefulWidget {
  const ChatAiScreen({super.key});

  @override
  State<ChatAiScreen> createState() => _ChatAiScreenState();
}

class _ChatAiScreenState extends State<ChatAiScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController =
      ScrollController(); // For auto-scrolling
  final AudioService _audioService =
      AudioService(); // Add AudioService instance

  @override
  void initState() {
    super.initState();
    _audioService.initializeAudio(context); // Initialize audio service
    // Optional: Add a listener to scroll down when the keyboard appears or messages change
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose(); // Dispose the scroll controller
    _audioService.dispose(); // Dispose audio service
    super.dispose();
  }

  void _scrollToBottom() {
    // Scrolls to the bottom of the list
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    if (_controller.text.trim().isNotEmpty) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final textToSend = _controller.text.trim();
      _controller.clear(); // Clear input field immediately

      // Call the provider's method to send the message
      chatProvider.sendMessage(textToSend).then((_) {
        // Scroll down after the message and potential response are added
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }).catchError((error) {
        // Handle potential errors during sending if needed (e.g., show a snackbar)
        print("Error sending message from UI: $error");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $error')),
        );
      });
      // Scroll down immediately after sending user message
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Use Consumer or context.watch to listen to ChatProvider changes
    final chatProvider = context.watch<ChatProvider>();

    // Scroll down when new messages are added by the provider
    if (chatProvider.messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      // AppBar is handled by HomeScreen
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController, // Attach scroll controller
              padding: const EdgeInsets.all(16.0),
              // Use messages from the provider
              itemCount: chatProvider.messages.length,
              itemBuilder: (context, index) {
                final message = chatProvider.messages[index];
                // Pass isUserMessage directly
                return _buildMessageBubble(
                    message, message.isUser, theme, colorScheme);
              },
            ),
          ),
          // Show a loading indicator below the messages if loading
          if (chatProvider.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(), // Or CircularProgressIndicator
            ),
          _buildInputArea(theme, colorScheme, chatProvider.isLoading),
        ],
      ),
    );
  }

  // Updated to accept isUser directly
  Widget _buildMessageBubble(ChatMessage message, bool isUser, ThemeData theme,
      ColorScheme colorScheme) {
    final alignment =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor =
        isUser ? colorScheme.primaryContainer : colorScheme.secondaryContainer;
    final textColor = isUser
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSecondaryContainer;
    final borderRadius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
            topRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
            topLeft: Radius.circular(4),
          );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end, // Align icons better
            children: [
              if (!isUser) ...[
                Padding(
                  padding: const EdgeInsets.only(
                      right: 8.0, bottom: 2.0), // Adjust padding
                  child: Icon(Icons.smart_toy_outlined,
                      size: 20, color: colorScheme.secondary),
                ),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: borderRadius,
                  ),
                  child: SelectableText(
                    message.text,
                    style:
                        theme.textTheme.bodyLarge?.copyWith(color: textColor),
                    onSelectionChanged: (selection, cause) {
                      if (selection.baseOffset != selection.extentOffset) {
                        String selectedText = message.text.substring(
                            selection.baseOffset, selection.extentOffset);
                        if (selectedText.isNotEmpty) {
                          showDialog<String>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Select an action'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Selected text:'),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      margin: const EdgeInsets.only(top: 8),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(selectedText),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _handleTTS(selectedText);
                                    },
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.volume_up, size: 20),
                                        SizedBox(width: 8),
                                        Text('Play TTS'),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      //   Navigator.of(context).pop();
                                      _handleTranslation(selectedText, context);
                                    },
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.translate, size: 20),
                                        SizedBox(width: 8),
                                        Text('Translate'),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
              if (isUser) ...[
                Padding(
                  padding: const EdgeInsets.only(
                      right: 8.0, bottom: 2.0), // Adjust padding
                  child: Icon(Icons.smart_toy_outlined,
                      size: 20, color: colorScheme.primary),
                ),
              ],
              if (isUser) ...[
                Padding(
                  padding: const EdgeInsets.only(
                      left: 8.0, bottom: 2.0), // Adjust padding
                  child: Icon(Icons.person_outline,
                      size: 20, color: colorScheme.primary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Updated to disable input/button when loading
  Widget _buildInputArea(
      ThemeData theme, ColorScheme colorScheme, bool isLoading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0)
          .copyWith(
              bottom: MediaQuery.of(context).padding.bottom +
                  8.0 // Adjust for safe area
              ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !isLoading, // Disable text field when loading
              decoration: InputDecoration(
                hintText:
                    isLoading ? 'AI is thinking...' : 'Ask the AI anything...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.inputDecorationTheme.fillColor ??
                    colorScheme.surfaceVariant.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 10.0),
              ),
              onSubmitted: isLoading ? null : (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8.0),
          IconButton(
            icon: Icon(Icons.send,
                color: isLoading ? theme.disabledColor : colorScheme.primary),
            onPressed:
                isLoading ? null : _sendMessage, // Disable button when loading
            style: IconButton.styleFrom(
              backgroundColor: isLoading
                  ? theme.disabledColor.withOpacity(0.12)
                  : colorScheme.primaryContainer,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  // Add method to handle TTS
  Future<void> _handleTTS(String text) async {
    try {
      await _audioService.playReferenceAudio(text, () {
        // Optional: Add any callback after TTS completes
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing TTS: $e')),
      );
    }
  }

  Future<void> _handleTranslation(String text, BuildContext context) async {
    print('ChatAI: Starting translation handling for text: "$text"');
    bool isRetrying = false;

    Future<void> attemptTranslation() async {
      try {
        print('ChatAI: Getting ChatProvider instance...');
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);

        print('ChatAI: Calling translateToEnglish...');
        final translation = await chatProvider.translateToEnglish(text);
        print('ChatAI: Translation received: "$translation"');

        if (!context.mounted) {
          print(
              'ChatAI: Context is no longer mounted, cancelling dialog display');
          return;
        }

        print('ChatAI: Showing translation dialog...');
        showDialog(
          context: context,
          builder: (BuildContext context) {
            print('ChatAI: Building translation dialog UI');
            return AlertDialog(
              title: const Text('Translation'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('French:',
                      style: Theme.of(context).textTheme.titleSmall),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(text),
                  ),
                  Text('English:',
                      style: Theme.of(context).textTheme.titleSmall),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(translation),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => _handleTTS(text),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.volume_up, size: 20),
                      SizedBox(width: 8),
                      Text('Play French TTS'),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
        print('ChatAI: Translation dialog displayed successfully');
      } catch (e) {
        print('ChatAI: Error during translation handling: $e');
        if (!context.mounted) {
          print(
              'ChatAI: Context is no longer mounted, cannot show error message');
          return;
        }

        if (e.toString().contains('empty translation') && !isRetrying) {
          isRetrying = true;
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Translation Failed'),
                content: const Text(
                    'Received an empty translation. Would you like to try again?'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      attemptTranslation(); // Retry translation
                    },
                    child: const Text('Retry'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          );
        } else {
          print('ChatAI: Showing error snackbar');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Translation error: $e')),
          );
        }
      }
    }

    // Start initial translation attempt
    await attemptTranslation();
  }
}
