class Word {
  final String id;
  final String french;
  final String english;
  final String category;
  final String difficulty;
  final String? phoneticHint; // Optional phonetic hint for pronunciation

  Word({
    required this.id,
    required this.french,
    required this.english,
    required this.category,
    required this.difficulty,
    this.phoneticHint, // Making it optional with default value of null
  });
}
