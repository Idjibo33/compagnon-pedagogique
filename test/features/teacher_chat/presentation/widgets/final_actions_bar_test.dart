import 'package:compagnon_pedagogique/features/teacher_chat/presentation/widgets/final_actions_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'affiche les deux boutons pilules Exporter en PDF et Copier le texte',
      (tester) async {
    bool exportCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinalActionsBar(
            content: 'Contenu de la fiche pédagogique',
            onExportPdf: () => exportCalled = true,
          ),
        ),
      ),
    );

    // Faire avancer l'animation de 200ms
    await tester.pumpAndSettle();

    expect(find.text('Exporter en PDF'), findsOneWidget);
    expect(find.text('Copier le texte'), findsOneWidget);

    // Clic sur Exporter en PDF
    await tester.tap(find.text('Exporter en PDF'));
    expect(exportCalled, isTrue);

    // Clic sur Copier le texte
    await tester.tap(find.text('Copier le texte'));
    await tester.pump();

    // Doit afficher temporairement "Copié !" avec coche verte
    expect(find.text('Copié !'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    // Après 2 secondes, revient à "Copier le texte"
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Copier le texte'), findsOneWidget);
  });

  testWidgets(
      'en mode plein soleil (highContrast), la bordure du bouton Copier est noire et nette',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinalActionsBar(
            content: 'Contenu contraste',
            onExportPdf: () {},
            highContrast: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final buttons =
        tester.widgetList<ElevatedButton>(find.byType(ElevatedButton));
    final copyButton = buttons.last;
    final side = copyButton.style?.side?.resolve({});
    expect(side?.color, Colors.black);
  });
}
