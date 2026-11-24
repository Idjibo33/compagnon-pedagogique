import 'package:compagnon_pedagogique/core/utils/emoji_sanitizer.dart';
import 'package:compagnon_pedagogique/features/teacher_chat/presentation/widgets/markdown_answer_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const markdown = '''
# Fiche de cours — Fractions simples
CM1 · Mathématiques

## Objectifs
- Nommer ½, ⅓ et ¼
- Calculer 12 ÷ 3

## Exercices
Écris 3 × 4 et \$\\sqrt{16}\$.

## Corrigé
Chaque élève reçoit 4 graines.
''';

  testWidgets('affiche les titres avec des icônes et sans balises brutes',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MarkdownAnswerView(content: markdown)),
      ),
    );

    expect(find.text('Fiche de cours — Fractions simples'), findsOneWidget);
    expect(find.text('Objectifs'), findsOneWidget);
    expect(find.text('Exercices'), findsOneWidget);
    expect(find.text('Corrigé'), findsOneWidget);
    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    expect(find.byIcon(Icons.edit_note_outlined), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.textContaining('##'), findsNothing);
  });

  testWidgets('rend les fractions et les formules LaTeX', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MarkdownAnswerView(content: markdown)),
      ),
    );

    final text = _renderedText(tester);
    expect(text, contains('½, ⅓ et ¼'));
    expect(text, contains('12 ÷ 3'));
    expect(find.byWidgetPredicate((widget) => widget is Math), findsOneWidget);
  });

  testWidgets('ne produit aucun emoji dans le rendu', (tester) async {
    const withEmoji = '''
# Fiche 🎯
## Objectifs ✅
Une puce 📌
''';
    expect(containsEmoji(withEmoji), isTrue);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MarkdownAnswerView(content: withEmoji)),
      ),
    );

    expect(containsEmoji(_renderedText(tester)), isFalse);
  });

  testWidgets('affiche le curseur respiratoire ▋ uniquement en mode streaming',
      (tester) async {
    // Mode non-streaming (défaut)
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
            body:
                MarkdownAnswerView(content: 'Texte final', isStreaming: false)),
      ),
    );
    expect(find.text('▋'), findsNothing);

    // Mode streaming
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
            body: MarkdownAnswerView(
                content: 'Texte en cours...', isStreaming: true)),
      ),
    );
    expect(find.text('▋'), findsOneWidget);
  });

  testWidgets('isole et gère les balises LaTeX incomplètes en mode streaming',
      (tester) async {
    const incompleteLatex = 'Calcul en cours : \$\\frac{1}{2';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownAnswerView(
            content: incompleteLatex,
            isStreaming: true,
          ),
        ),
      ),
    );

    expect(find.text('▋'), findsOneWidget);
    // Vérifier que le rendu ne lance aucune exception
    expect(tester.takeException(), isNull);
  });

  testWidgets('prend en compte le mode plein soleil (highContrast)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownAnswerView(
            content: 'Texte contraste élevé',
            highContrast: true,
          ),
        ),
      ),
    );

    expect(find.text('Texte contraste élevé'), findsOneWidget);
  });

  testWidgets(
      'ne duplique pas le titre principal quand il n\'y a pas de sous-sections ##',
      (tester) async {
    const textWithoutSections = '''
# Fiche d'introduction
Voici un contenu direct sans sections numérotées.
''';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownAnswerView(content: textWithoutSections),
        ),
      ),
    );

    // Le titre doit apparaître exactement une seule fois
    expect(find.text("Fiche d'introduction"), findsOneWidget);
    expect(find.textContaining('Voici un contenu direct'), findsOneWidget);
  });

  testWidgets(
      'isole les blocs de code triples backticks incomplets en mode streaming',
      (tester) async {
    const streamingCode = 'Exemple de code :\n```python\nprint("Bonjour';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownAnswerView(
            content: streamingCode,
            isStreaming: true,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('▋'), findsOneWidget);
  });
}

/// Texte effectivement affiché, y compris les spans du rendu Markdown.
String _renderedText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final widget in tester.allWidgets) {
    if (widget is Text) {
      buffer.writeln(widget.data ?? '');
    } else if (widget is RichText) {
      buffer.writeln(widget.text.toPlainText());
    } else if (widget is SelectableText) {
      buffer.writeln(widget.textSpan?.toPlainText() ?? '');
    }
  }
  return buffer.toString();
}
