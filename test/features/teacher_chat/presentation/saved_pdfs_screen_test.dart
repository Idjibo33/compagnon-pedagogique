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
      expect(find.text('Ouvrir / Imprimer'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);

      tempDir.deleteSync(recursive: true);
    });
  });
}
