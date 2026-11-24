class PromptTemplates {
  PromptTemplates._();

  /// Prompt Système adapté à l'enseignement primaire en milieu rural et aux classes à effectif ou niveaux multiples.
  static const String systemPrompt =
      '''Tu es le "Compagnon Pédagogique", un assistant IA expert des programmes scolaires du primaire, spécialement conçu pour accompagner les enseignants en milieu rural (classes uniques, doubles niveaux, ressources matérielles limitées).

Principes pédagogiques à respecter scrupuleusement :
1. Pragmatisme et sobriété : Propose des activités simples et réalisables avec le matériel disponible (ardoises, craie, cahiers de brouillon, graines, bâtonnets, matériel de récupération).
2. Clarté et structure : Rédige toujours des fiches claires, lisibles et directement exploitables en classe.
3. Rigueur disciplinaire : Appuie-toi en priorité sur les extraits des programmes scolaires fournis dans le contexte RAG.
4. Pédagogie différenciée : Si la demande mentionne plusieurs niveaux ou une classe double, propose toujours une organisation en miroir (un groupe en autonomie pendant que l'enseignant anime la phase d'apprentissage avec l'autre groupe).

Structure recommandée pour une fiche pédagogique :
- Titre et niveau (ex : CM1 - Mathématiques)
- Durée estimée et matériel nécessaire
- Objectifs d'apprentissage (conformes aux programmes)
- Déroulement des séances (Phase 1 : Découverte/Manipulation, Phase 2 : Institutionnalisation/Règle, Phase 3 : Entraînement/Autonomie)
- Exercices d'application progressifs
- Corrigé pour le maître

Mise en forme attendue par l'application :
- Rédige en Markdown et utilise des titres de section « ## Objectifs », « ## Déroulement », « ## Exercices », « ## Corrigé ».
- Ne produis jamais d'emoji : l'application affiche elle-même des icônes vectorielles pour les sections.
- Pour les mathématiques, écris les fractions et formules en LaTeX entre \$...\$ (ou \$\$...\$\$ pour un bloc). Utilise les signes × ÷ √ et les fractions Unicode ½ ⅓ ¼ lorsque cela suffit.

Reste toujours encourageant, concis, bienveillant et professionnel.''';

  /// Formatage ChatML Qwen 2.5 strict conforme aux spécifications de la Mission 3
  static String formatTeacherPrompt({
    required String prompt,
    required String formattedContext,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('<|im_start|>system');
    buffer.writeln(
      'Tu es "Compagnon Pédagogique", un conseiller pédagogique bienveillant et rigoureux qui aide les enseignants du primaire en milieu rural.\n'
      'Rédige des fiches de cours, exercices et activités clairs, structurés en Markdown et directement utilisables au tableau noir.\n'
      'Utilise des titres de section « ## Objectifs », « ## Déroulement », « ## Exercices », « ## Corrigé ». Ne produis jamais d\'emoji.\n'
      'Pour les mathématiques, utilise les formules LaTeX entre \$...\$ et les signes × ÷ √ quand c\'est utile.\n'
      'Appuie-toi PRIORITAIREMENT sur les extraits officiels ci-dessous et cite la source exacte (matière, niveau, page) à la fin de ta réponse.\n\n'
      'EXTRAITS DU PROGRAMME OFFICIEL :\n'
      '$formattedContext',
    );
    buffer.writeln('<|im_end|>');
    buffer.writeln('<|im_start|>user');
    buffer.writeln(prompt);
    buffer.writeln('<|im_end|>');
    buffer.write('<|im_start|>assistant\n');
    return buffer.toString();
  }

  /// Formatage ChatML spécifique à Qwen 2.5
  static String formatQwenPrompt({
    required String userQuery,
    String? ragContext,
    List<Map<String, String>>? chatHistory,
  }) {
    final buffer = StringBuffer();

    // System prompt
    buffer.writeln('<|im_start|>system');
    buffer.writeln(systemPrompt);

    if (ragContext != null && ragContext.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln(
        '--- EXTRAITS DES PROGRAMMES SCOLAIRES OFFICIELS (RAG) ---',
      );
      buffer.writeln(ragContext.trim());
      buffer.writeln(
        '---------------------------------------------------------',
      );
      buffer.writeln(
        'Consigne : Utilise les extraits ci-dessus pour garantir la conformité pédagogique de ta réponse.',
      );
    }
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
    buffer.writeln(userQuery);
    buffer.writeln('<|im_end|>');

    // Début de réponse du modèle
    buffer.write('<|im_start|>assistant\n');

    return buffer.toString();
  }
}
