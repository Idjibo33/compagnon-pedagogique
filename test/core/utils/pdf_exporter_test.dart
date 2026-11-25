import 'dart:io';

import 'package:compagnon_pedagogique/core/constants/app_constants.dart';
import 'package:compagnon_pedagogique/core/utils/pdf_exporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String appDocDir;

  FakePathProviderPlatform(this.appDocDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => appDocDir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FakePathProviderPlatform fakePlatform;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pdf_exporter_test_');
    fakePlatform = FakePathProviderPlatform(tempDir.path);
    PathProviderPlatform.instance = fakePlatform;
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PdfExporter Tests', () {
    test(
        'getPdfStorageDirectory should point to fiches_pdf and create directory',
        () async {
      final dir = await PdfExporter.getPdfStorageDirectory();

      expect(dir.existsSync(), isTrue);
      expect(p.basename(dir.path), equals(AppConstants.pdfsDirectoryName));
      expect(p.basename(dir.path), equals('fiches_pdf'));
    });

    test(
        'generatePedagogicalPdf should produce a non-empty .pdf file with proper headers',
        () async {
      const title = 'Fractions CM1';
      const content = '''# Les Fractions Simples
### 🎯 Objectifs
- Découvrir les demis et les quarts.
- Partager équitablement des objets.

- Exercice 1 : Colorie 1/2 du gâteau.
- Exercice 2 : Écris la fraction correspondante.

Corrigé : Vérifier le partage égal.''';

      final file = await PdfExporter.generatePedagogicalPdf(
        title: title,
        content: content,
        teacherQuery: 'Fiche fractions niveau CM1',
      );

      expect(file.existsSync(), isTrue);
      expect(file.path.endsWith('.pdf'), isTrue);
      expect(file.lengthSync(), greaterThan(1000));
    });

    test(
        'generatePedagogicalPdf handles empty or special characters in title gracefully',
        () async {
      final file = await PdfExporter.generatePedagogicalPdf(
        title: '///???@@@###',
        content: 'Contenu minimaliste pour test',
      );

      expect(file.existsSync(), isTrue);
      expect(file.path.endsWith('.pdf'), isTrue);
      expect(file.lengthSync(), greaterThan(500));
    });

    test(
        'listSavedPdfs should return all generated PDFs ordered from newest to oldest',
        () async {
      final dir = await PdfExporter.getPdfStorageDirectory();

      // Create two distinct files with delayed timestamps
      final file1 = File(p.join(dir.path, 'fiche_test_1.pdf'));
      await file1.writeAsString('pdf content 1');
      await Future.delayed(const Duration(milliseconds: 50));

      final file2 = File(p.join(dir.path, 'fiche_test_2.pdf'));
      await file2.writeAsString('pdf content 2');

      // Also create a non-pdf file to ensure filtering
      final txtFile = File(p.join(dir.path, 'notes.txt'));
      await txtFile.writeAsString('ignored text');

      final list = await PdfExporter.listSavedPdfs();

      expect(list.length, 2);
      expect(list.first.path, file2.path);
      expect(list.last.path, file1.path);
    });

    test('listSavedPdfs returns empty list when directory has no PDF files',
        () async {
      final list = await PdfExporter.listSavedPdfs();
      expect(list, isEmpty);
    });

    test('getPublicDocumentsDirectory and public copy mirror pedagogical PDF',
        () async {
      final publicDir = await PdfExporter.getPublicDocumentsDirectory();
      expect(publicDir, isNotNull);
      expect(await publicDir!.exists(), isTrue);
      expect(publicDir.path, contains(AppConstants.publicPdfDirectoryName));

      final file = await PdfExporter.generatePedagogicalPdf(
        title: 'Sciences CM1',
        content: '# Les Énergies Renouvelables\n- Le solaire\n- L\'éolien',
      );

      final publicFile = File(p.join(publicDir.path, p.basename(file.path)));
      expect(publicFile.existsSync(), isTrue);
      expect(publicFile.lengthSync(), equals(file.lengthSync()));

      // Test de suppression synchrone miroir
      await PdfExporter.deletePdf(file);
      expect(file.existsSync(), isFalse);
      expect(publicFile.existsSync(), isFalse);
    });

    test('generatePedagogicalPdf strip les emojis et ne plante pas', () async {
      final file = await PdfExporter.generatePedagogicalPdf(
        title: '🎯 Géographie CE2 🌍',
        content: '# Les Continents 🗺️\n- L\'Afrique 🦁\n- L\'Europe 🏰',
        teacherQuery: 'Fiche sur les continents 🧭',
      );

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(500));
    });
  });
}
