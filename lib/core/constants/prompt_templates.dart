class PromptTemplates {
  PromptTemplates._();

  /// Prompt système concis et structuré, calibré pour un petit modèle local
  /// (Qwen 2.5 1.5B) au service des enseignants du primaire en milieu rural.
  static const String systemPrompt =
      '''Tu es "Compagnon Pédagogique", un conseiller pédagogique rigoureux qui aide les enseignants du primaire en milieu rural (classes uniques, doubles niveaux, matériel simple : tableau noir, craie, ardoise, cahiers, graines ou bâtonnets).

Règles strictes :
- Réponds toujours en français clair, correct et directement utilisable en classe.
- Rédige en Markdown avec les sections « ## Objectifs », « ## Déroulement », « ## Exercices », « ## Corrigé ».
- N'utilise jamais d'emoji.
- Pour les mathématiques, écris les formules en LaTeX entre \$...\$ et utilise × ÷ √ si utile.
- Si la demande mentionne un double niveau ou deux classes, propose une organisation en miroir (un groupe en autonomie, l'autre avec l'enseignant).
- Reste concret, concis et fidèle au niveau demandé.''';

  /// Plafond de caractères pour les extraits RAG injectés dans l'instruction
  /// système afin de préserver la fenêtre de contexte (2048 tokens) et laisser
  /// suffisamment d'espace à la réponse (~1024 tokens) sur Qwen 2.5 1.5B.
  static const int maxRagContextChars = 2000;

  static final RegExp _chatMlTagPattern = RegExp(r'<\|im_(?:start|end)\|>\s*');

  static String _stripChatMlTokens(String input) =>
      input.replaceAll(_chatMlTagPattern, '').trim();

  static String _truncateContext(String context, int maxChars) {
    if (maxChars <= 0 || context.length <= maxChars) {
      return context;
    }
    final slice = context.substring(0, maxChars);
    final lastSpace = slice.lastIndexOf(RegExp(r'\s'));
    final cutoff = lastSpace > (maxChars ~/ 2) ? lastSpace : maxChars;
    return '${slice.substring(0, cutoff).trimRight()}…';
  }

  /// Construit l'instruction système brute (sans balises ChatML) à transmettre
  /// à `InferenceModel.openSession(systemInstruction: ...)`.
  ///
  /// Le moteur `flutter_edge_ai` / `llamadart` applique lui-même le template
  /// de chat natif du fichier GGUF : aucune balise `<|im_start|>` ne doit
  /// être ajoutée manuellement ici.
  static String buildSystemInstruction({
    String formattedContext = '',
    int maxContextChars = maxRagContextChars,
  }) {
    final sanitizedContext = _stripChatMlTokens(formattedContext);
    if (sanitizedContext.isEmpty) {
      return systemPrompt;
    }

    final boundedContext = _truncateContext(sanitizedContext, maxContextChars);

    final buffer = StringBuffer(systemPrompt);
    buffer.writeln();
    buffer.writeln();
    buffer.writeln(
      'Appuie-toi PRIORITAIREMENT sur les extraits officiels ci-dessous, sans inventer de référence, et cite la source exacte (matière, niveau, page) en fin de réponse.',
    );
    buffer.writeln();
    buffer.writeln('EXTRAITS DU PROGRAMME OFFICIEL :');
    buffer.write(boundedContext);
    return buffer.toString();
  }

  /// Nettoie la demande utilisateur (sans balises ChatML) pour l'envoyer via
  /// `Message.text(text: ..., isUser: true)`.
  static String buildUserPrompt(String prompt) => _stripChatMlTokens(prompt);

  /// Formatage ChatML Qwen 2.5 brut (réservé aux moteurs sans template natif).
  ///
  /// Ne pas passer le résultat à `flutter_edge_ai` (`openSession` /
  /// `addQueryChunk`), qui applique déjà le template de chat du GGUF.
  static String formatTeacherPrompt({
    required String prompt,
    required String formattedContext,
  }) {
    final systemInstruction = buildSystemInstruction(
      formattedContext: formattedContext,
    );
    final userPrompt = buildUserPrompt(prompt);

    final buffer = StringBuffer();
    buffer.writeln('<|im_start|>system');
    buffer.writeln(systemInstruction);
    buffer.writeln('<|im_end|>');
    buffer.writeln('<|im_start|>user');
    buffer.writeln(userPrompt);
    buffer.writeln('<|im_end|>');
    buffer.write('<|im_start|>assistant\n');
    return buffer.toString();
  }

  /// Formatage ChatML complet avec historique (réservé aux moteurs sans
  /// template natif).
  static String formatQwenPrompt({
    required String userQuery,
    String? ragContext,
    List<Map<String, String>>? chatHistory,
  }) {
    final buffer = StringBuffer();

    // System prompt
    buffer.writeln('<|im_start|>system');
    buffer.writeln(
      buildSystemInstruction(formattedContext: ragContext ?? ''),
    );
    buffer.writeln('<|im_end|>');

    // Historique éventuel
    if (chatHistory != null) {
      for (final turn in chatHistory) {
        final role = turn['role'] ?? 'user';
        final content = turn['content'] ?? '';
        buffer.writeln('<|im_start|>$role');
        buffer.writeln(content);
        buffer.writeln('<|im_end|>');
      }
    }

    // Question utilisateur actuelle
    buffer.writeln('<|im_start|>user');
    buffer.writeln(buildUserPrompt(userQuery));
    buffer.writeln('<|im_end|>');

    // Début de réponse du modèle
    buffer.write('<|im_start|>assistant\n');

    return buffer.toString();
  }
}
