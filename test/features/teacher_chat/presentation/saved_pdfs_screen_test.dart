import 'dart:io';

import 'package:compagnon_pedagogique/core/theme/app_theme.dart';
import 'package:compagnon_pedagogique/features/teacher_chat/presentation/screens/saved_pdfs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SavedPdfsScreen Isolated Tests', () {
    testWidgets('renders empty state correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SavedPdfsScreen(initialFiles: []),
        ),
      );

      await tester.pump();

      expect(find.text('Fiches PDF Sauvegardées'), findsOneWidget);
      expect(find.text('Aucune fiche PDF enregistrée'), findsOneWidget);
    });

    testWidgets('renders card list when files are provided', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('pdf_card_test_');
      final dummyFile =
          File('${tempDir.path}/fiche_Fractions_CM1_20261117_120000.pdf');
      dummyFile.writeAsStringSync('pdf content');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SavedPdfsScreen(initialFiles: [dummyFile]),
        ),
      );

      await tester.pump();

      expect(find.text('Fiches PDF Sauvegardées'), findsOneWidget);
      expect(find.text('Ouvrir'), findsOneWidget);
      expect(find.text('Ouvrir / Imprimer'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);

      tempDir.deleteSync(recursive: true);
    });

    testWidgets('recherche textuelle filtre les cartes affichées',
        (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('pdf_search_test_');
      final mathFile = File('${tempDir.path}/fiche_mathematiques_cm1.pdf');
      mathFile.writeAsStringSync('math');
      final grammFile = File('${tempDir.path}/fiche_grammaire_ce2.pdf');
      grammFile.writeAsStringSync('grammaire');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SavedPdfsScreen(initialFiles: [mathFile, grammFile]),
        ),
      );

      await tester.pump();

      expect(find.textContaining('Mathematiques'), findsOneWidget);
      expect(find.textContaining('Grammaire'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'math');
      await tester.pump();

      expect(find.textContaining('Mathematiques'), findsOneWidget);
      expect(find.textContaining('Grammaire'), findsNothing);

      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump();

      expect(find.textContaining('Mathematiques'), findsOneWidget);
      expect(find.textContaining('Grammaire'), findsOneWidget);

      tempDir.deleteSync(recursive: true);
    });

    testWidgets('bouton Ouvrir déclenche le callback pdfOpener',
        (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('pdf_open_test_');
      final file = File('${tempDir.path}/fiche_sciences_cm2.pdf');
      file.writeAsStringSync('sciences');

      File? opened;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SavedPdfsScreen(
            initialFiles: [file],
            pdfOpener: (f) async {
              opened = f;
            },
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Ouvrir'), findsOneWidget);
      await tester.tap(find.text('Ouvrir'));
      await tester.pump();

      expect(opened, isNotNull);
      expect(opened!.path, equals(file.path));

      tempDir.deleteSync(recursive: true);
    });

    testWidgets('affiche état vide de recherche avec bouton réinitialiser',
        (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('pdf_empty_search_');
      final file = File('${tempDir.path}/fiche_histoire_cm1.pdf');
      file.writeAsStringSync('histoire');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SavedPdfsScreen(initialFiles: [file]),
        ),
      );

      await tester.pump();

      await tester.enterText(find.byType(TextField), 'introuvable_xyz');
      await tester.pump();

      expect(find.text('Aucune fiche trouvée'), findsOneWidget);
      expect(find.text('Réinitialiser les filtres'), findsOneWidget);

      await tester.tap(find.text('Réinitialiser les filtres'));
      await tester.pump();

      expect(find.text('Aucune fiche trouvée'), findsNothing);
      expect(find.textContaining('Histoire'), findsOneWidget);

      tempDir.deleteSync(recursive: true);
    });
  });
}
