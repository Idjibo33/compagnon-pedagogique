import 'dart:io';

import 'package:compagnon_pedagogique/core/constants/app_constants.dart';
import 'package:compagnon_pedagogique/core/theme/app_theme.dart';
import 'package:compagnon_pedagogique/core/errors/failures.dart';
import 'package:compagnon_pedagogique/features/model_manager/data/model_manager_repository.dart';
import 'package:compagnon_pedagogique/features/model_manager/domain/model_status.dart';
import 'package:fpdart/fpdart.dart';
import 'package:compagnon_pedagogique/features/rag_engine/domain/document_chunk.dart';
import 'package:compagnon_pedagogique/features/rag_engine/domain/rag_repository.dart';
import 'package:compagnon_pedagogique/features/teacher_chat/data/edge_ai_llm_provider.dart';
import 'package:compagnon_pedagogique/features/teacher_chat/presentation/screens/teacher_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
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

class FakeRagRepo implements RagRepository {
  List<DocumentChunk> chunks = [];

  @override
  Future<void> initialize() async {}
  @override
  Future<void> initializeDatabase() async {}
  @override
  Future<List<DocumentChunk>> searchRelevantChunks(String query,
          {int limit = 3}) async =>
      chunks;
  @override
  String formatChunksForPrompt(List<DocumentChunk> chunks) => '';
  @override
  Future<void> dispose() async {}
}

class FakeModelRepo implements ModelManagerRepository {
  @override
  Future<bool> areAllModelsReady() async => true;
  @override
  Future<Directory> getModelsDirectory() async => Directory('/tmp');
  @override
  Future<String> getModelPath(String fileName) async => '/tmp/$fileName';
  @override
  TaskEither<Failure, Map<String, ModelFileStatus>> checkModelsStatus() =>
      TaskEither.right({});
  @override
  Future<void> pauseDownload() async {}
  @override
  TaskEither<Failure, String?> importModelFromFilePicker(
          {required Function(double progress) onCopyProgress}) =>
      TaskEither.right(null);
  @override
  TaskEither<Failure, Unit> startDownload({
    required Function(String fileName, double progress, int bytes) onProgress,
    required Function(
      String fileName,
      Either<Failure, ModelDownloadState> status,
    ) onStatus,
  }) =>
      TaskEither.right(unit);
  @override
  Future<int?> getAvailableDiskSpace() async => 2000000000;
  @override
  Future<bool> hasEnoughDiskSpace({int requiredBytes = 1610612736}) async =>
      true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    GoogleFonts.roboto();
    GoogleFonts.robotoMono();
    await GoogleFonts.pendingFonts();
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('chat_widget_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('TeacherChatScreen Widget Tests', () {
    testWidgets('renders AppBar with title and 100% Hors Ligne badge',
        (tester) async {
      final fakeProvider = EdgeAiLlmProvider(
        ragRepository: FakeRagRepo(),
        modelRepository: FakeModelRepo(),
        fallbackStreamer: (p, fp, s) async* {
          yield 'Test response';
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TeacherChatScreen(provider: fakeProvider),
        ),
      );

      await tester.pump();

      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('100% Hors Ligne'), findsOneWidget);
      expect(find.byType(LlmChatView), findsOneWidget);

      // Verify header action buttons exist
      expect(find.byTooltip('Fiches PDF enregistrées'), findsOneWidget);
      expect(find.byTooltip('Paramètres & Modèles'), findsOneWidget);
      expect(find.byTooltip('Mode Plein Soleil (WCAG AAA)'), findsOneWidget);
    });

    testWidgets(
        'bascule le Mode Plein Soleil avec contraste élevé au clic sur l\'icône',
        (tester) async {
      final fakeProvider = EdgeAiLlmProvider(
        ragRepository: FakeRagRepo(),
        modelRepository: FakeModelRepo(),
        fallbackStreamer: (p, fp, s) async* {
          yield 'Test response';
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TeacherChatScreen(provider: fakeProvider),
        ),
      );

      await tester.pump();

      // Clic pour activer le mode plein soleil
      await tester.tap(find.byTooltip('Mode Plein Soleil (WCAG AAA)'));
      await tester.pump();

      expect(find.byTooltip('Désactiver le Mode Plein Soleil'), findsOneWidget);

      // Clic pour désactiver
      await tester.tap(find.byTooltip('Désactiver le Mode Plein Soleil'));
      await tester.pump();

      expect(find.byTooltip('Mode Plein Soleil (WCAG AAA)'), findsOneWidget);
    });

    testWidgets(
        'affiche la pastille sources dans l\'AppBar et ouvre la modale au tap',
        (tester) async {
      final fakeRag = FakeRagRepo();
      fakeRag.chunks = const [
        DocumentChunk(
          id: 1,
          niveau: 'CM1',
          matiere: 'Mathématiques',
          page: 12,
          content: 'Nombres et opérations',
        ),
      ];
      final fakeProvider = EdgeAiLlmProvider(
        ragRepository: fakeRag,
        modelRepository: FakeModelRepo(),
        fallbackStreamer: (p, fp, s) async* {
          yield 'Test response';
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TeacherChatScreen(provider: fakeProvider),
        ),
      );

      await tester.pump();

      // Émettre une recherche RAG
      await fakeProvider.generateStream('Fiche calcul CM1').first;
      await tester.pump();

      // La pastille sources doit être présente dans l'AppBar
      expect(find.text('1 source'), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);

      // Clic sur la pastille pour ouvrir la feuille modale
      await tester.tap(find.text('1 source'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Vérifier le contenu de la feuille modale
      expect(find.text('Extraits des programmes officiels'), findsOneWidget);
      expect(find.text('Nombres et opérations'), findsOneWidget);
      expect(find.text('Mathématiques • CM1'), findsOneWidget);
      expect(find.text('Page 12'), findsOneWidget);
    });

    testWidgets(
        'affiche les puces interactives de cadrage (ActionChip) en attente de clarification',
        (tester) async {
      final fakeProvider = EdgeAiLlmProvider(
        ragRepository: FakeRagRepo(),
        modelRepository: FakeModelRepo(),
        fallbackStreamer: (p, fp, s) async* {
          yield 'Fiche générée';
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TeacherChatScreen(provider: fakeProvider),
        ),
      );

      await tester.pump();

      // Déclencher une question de cadrage
      await fakeProvider.sendMessageStream('Préparer une fiche').first;
      await tester.pump();

      // Puces de niveau de classe doivent s'afficher au-dessus de la saisie
      expect(find.byType(ActionChip), findsWidgets);
      expect(find.text('CP'), findsOneWidget);
      expect(find.text('CM1'), findsOneWidget);
      expect(find.text('Double niveau'), findsOneWidget);

      // Clic sur CM1 pour injecter directement sans clavier
      await tester.tap(find.text('CM1'));
      await tester.pump();
    });
  });
}
