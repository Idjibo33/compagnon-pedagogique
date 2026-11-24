/// Utilitaires pour garantir l'absence d'emoji dans l'interface.
///
/// Le modèle local reçoit la consigne de ne jamais en produire, mais on garde
/// un filet de sécurité côté application.

bool _isEmojiRune(int rune) =>
    (rune >= 0x1F300 && rune <= 0x1FAFF) ||
    (rune >= 0x2600 && rune <= 0x27BF) ||
    rune == 0xFE0F ||
    rune == 0x200D;

bool containsEmoji(String text) => text.runes.any(_isEmojiRune);

String stripEmojis(String text) =>
    String.fromCharCodes(text.runes.where((rune) => !_isEmojiRune(rune)));
