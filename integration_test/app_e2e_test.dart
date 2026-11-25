import 'dart:io';

import 'package:compagnon_pedagogique/core/constants/app_constants.dart';
import 'package:compagnon_pedagogique/core/di/injection_container.dart' as di;
import 'package:compagnon_pedagogique/core/di/injection_container.dart';
import 'package:compagnon_pedagogique/features/model_manager/data/model_manager_repository.dart';
import 'package:compagnon_pedagogique/features/model_manager/presentation/cubit/model_manager_cubit.dart';
import 'package:compagnon_pedagogique/features/model_manager/presentation/screens/model_setup_screen.dart';
import 'package:compagnon_pedagogique/features/rag_engine/data/local_rag_repository_impl.dart';
import 'package:compagnon_pedagogique/features/rag_engine/data/rag_context_formatter.dart';
import 'package:compagnon_pedagogique/features/rag_engine/domain/document_chunk.dart';
import 'package:compagnon_pedagogique/features/rag_engine/domain/rag_repository.dart';
import 'package:compagnon_pedagogique/features/teacher_chat/data/edge_ai_llm_provider.dart';
import 'package:compagnon_pedagogique/features/teacher_chat/presentation/screens/saved_pdfs_screen.dart';
import 'package:compagnon_pedagogique/features/teacher_chat/presentation/screens/teacher_chat_screen.dart';
import 'package:compagnon_pedagogique/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
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

/// Référentiel RAG de test pour le parcours E2E
/// Délègue au vrai LocalRagRepositoryImpl si la base SQLite est active,
/// ou injecte l'extrait officiel du programme scolaire de test.
class E2eTestRagRepository implements RagRepository {
  final LocalRagRepositoryImpl _realRepo;
  final List<DocumentChunk> _curriculumChunks;

  E2eTestRagRepository({
    required LocalRagRepositoryImpl realRepo,
    List<DocumentChunk>? curriculumChunks,
  })  : _realRepo = realRepo,
        _curriculumChunks = curriculumChunks ??
            const [
              DocumentChunk(
                id: 1,
                niveau: 'CM1',
                matiere: 'Mathématiques',
                page: 42,
                content:
                    'Fractions simples : nommer, utiliser, représenter des fractions simples. Partage équitable et repérage au tableau noir.',
              ),
            ];

  @override
  Future<void> initialize() async {
    try {
      await _realRepo.initialize();
    } catch (_) {}
  }

  @override
  Future<void> initializeDatabase() async {
    try {
      await _realRepo.initializeDatabase();
    } catch (_) {}
  }

  @override
  Future<List<DocumentChunk>> searchRelevantChunks(
    String query, {
    int limit = 3,
  }) async {
    try {
      final realResults =
          await _realRepo.searchRelevantChunks(query, limit: limit);
      if (realResults.isNotEmpty) {
        return realResults;
      }
    } catch (_) {}

    final lower = query.toLowerCase();
    if (lower.contains('fraction') ||
        lower.contains('math') ||
        lower.contains('cours') ||
        lower.contains('cm1') ||
        lower.contains('fiche')) {
      return _curriculumChunks.take(limit).toList();
    }
    return _curriculumChunks;
  }

  @override
  String formatChunksForPrompt(List<DocumentChunk> chunks) =>
      _realRepo.formatChunksForPrompt(chunks);

  @override
  Future<void> dispose() async {
    await _realRepo.dispose();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempTestDir;

  setUpAll(() async {
    // Pré-chargement des polices locales pour garantir un fonctionnement 100% hors ligne
    GoogleFonts.roboto();
    GoogleFonts.robotoMono();
    await GoogleFonts.pendingFonts();
  });

  setUp(() {
    tempTestDir = Directory.systemTemp.createTempSync('compagnon_e2e_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempTestDir.path);
  });

  tearDown(() {
    if (tempTestDir.existsSync()) {
      tempTestDir.deleteSync(recursive: true);
    }
  });

  group('Suite de Tests d\'Intégration End-to-End (Compagnon Pédagogique)', () {
    testWidgets(
      'Scénario 1 (Premier lancement & Routage) : Sans modèles GGUF, affiche ModelSetupScreen avec import local',
      (WidgetTester tester) async {
        await di.resetDependencies();

        final modelsDir = Directory(
          p.join(tempTestDir.path, AppConstants.modelsDirectoryName),
        )..createSync(recursive: true);

        final testModelRepo = ModelManagerRepositoryImpl(
          customModelsDirectory: modelsDir,
          minLlmBytes: 50,
          minEmbBytes: 50,
        );

        sl.registerSingleton<ModelManagerRepository>(testModelRepo);
        sl.registerFactory<ModelManagerCubit>(
          () => ModelManagerCubit(repository: sl<ModelManagerRepository>()),
        );
        sl.registerLazySingleton<RagContextFormatter>(
          () => const RagContextFormatter(),
        );
        sl.registerLazySingleton<RagRepository>(
          () => LocalRagRepositoryImpl(formatter: sl<RagContextFormatter>()),
        );
        sl.registerLazySingleton<EdgeAiLlmProvider>(
          () => EdgeAiLlmProvider(
            ragRepository: sl<RagRepository>(),
            ragContextFormatter: sl<RagContextFormatter>(),
            modelRepository: sl<ModelManagerRepository>(),
          ),
        );

        final isReady = await testModelRepo.areAllModelsReady();
        expect(isReady, isFalse);

        // Lancement de l'application
        await tester.pumpWidget(
          const CompagnonPedagogiqueApp(initialModelsReady: false),
        );
        await tester.pumpAndSettle();

        // 1. Vérification que ModelSetupScreen est affiché
        expect(find.byType(ModelSetupScreen), findsOneWidget);
        expect(find.byType(TeacherChatScreen), findsNothing);

        // 2. Vérification de la présence du bouton d'importation locale Xender / Carte SD
        expect(
          find.text('Importer depuis Xender / Carte SD'),
          findsOneWidget,
        );

        // 3. Vérification des libellés de préparation et de volume requis
        expect(
          find.text('Télécharger les modèles (~1.23 Go)'),
          findsOneWidget,
        );
        expect(
          find.text('Compagnon Pédagogique'),
          findsOneWidget,
        );
        expect(
          find.text('Volume total requis : ~1.23 Go'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Scénario 2 (Installation & Bascule automatique) : Présence des 2 GGUF transitionne vers TeacherChatScreen avec badge 100% Hors Ligne',
      (WidgetTester tester) async {
        await di.resetDependencies();

        final modelsDir = Directory(
          p.join(tempTestDir.path, AppConstants.modelsDirectoryName),
        )..createSync(recursive: true);

        // Création des 2 fichiers .gguf requis
        final llmFile =
            File(p.join(modelsDir.path, AppConstants.llmModelFileName));
        llmFile.writeAsStringSync(
          'GGUF_TEST_LLM_QWEN_2_5_MODEL_VALIDATION_STRING_LONGER_THAN_FIFTY_BYTES',
        );

        final embFile =
            File(p.join(modelsDir.path, AppConstants.embeddingModelFileName));
        embFile.writeAsStringSync(
          'GGUF_TEST_EMBEDDING_MULTILINGUAL_E5_MODEL_VALIDATION_STRING_LONGER_THAN_FIFTY',
        );

        final testModelRepo = ModelManagerRepositoryImpl(
          customModelsDirectory: modelsDir,
          minLlmBytes: 50,
          minEmbBytes: 50,
        );

        sl.registerSingleton<ModelManagerRepository>(testModelRepo);
        sl.registerFactory<ModelManagerCubit>(
          () => ModelManagerCubit(repository: sl<ModelManagerRepository>()),
        );
        sl.registerLazySingleton<RagContextFormatter>(
          () => const RagContextFormatter(),
        );
        sl.registerLazySingleton<RagRepository>(
          () => LocalRagRepositoryImpl(formatter: sl<RagContextFormatter>()),
        );
        sl.registerLazySingleton<EdgeAiLlmProvider>(
          () => EdgeAiLlmProvider(
            ragRepository: sl<RagRepository>(),
            ragContextFormatter: sl<RagContextFormatter>(),
            modelRepository: sl<ModelManagerRepository>(),
          ),
        );

        final isReady = await testModelRepo.areAllModelsReady();
        expect(isReady, isTrue);

        // Démarrage de l'application avec les modèles prêts
        await tester.pumpWidget(
          CompagnonPedagogiqueApp(initialModelsReady: isReady),
        );
        await tester.pumpAndSettle();

        // 1. Vérification que l'écran bascule bien sur TeacherChatScreen
        expect(find.byType(TeacherChatScreen), findsOneWidget);
        expect(find.byType(ModelSetupScreen), findsNothing);

        // 2. Vérification du badge vert "100% Hors Ligne"
        expect(find.text('100% Hors Ligne'), findsOneWidget);

        // 3. Vérification du message d'accueil et des suggestions 1-tap
        expect(
          find.text(
            'Bonjour Maître. Décrivez le cours ou l\'exercice dont vous avez besoin.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Préparer une fiche de cours'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Scénario 3 (Flux complet Question -> RAG -> Export PDF -> Historique) : Génération, RAG officiel, export PDF et historique',
      (WidgetTester tester) async {
        await di.resetDependencies();

        final modelsDir = Directory(
          p.join(tempTestDir.path, AppConstants.modelsDirectoryName),
        )..createSync(recursive: true);

        // Créer les modèles pour marquer l'état prêt
        final llmFile =
            File(p.join(modelsDir.path, AppConstants.llmModelFileName));
        llmFile.writeAsStringSync(
            'LLM_GGUF_TEST_DATA_PADDING_LONGER_THAN_50_BYTES');

        final embFile =
            File(p.join(modelsDir.path, AppConstants.embeddingModelFileName));
        embFile.writeAsStringSync(
            'EMB_GGUF_TEST_DATA_PADDING_LONGER_THAN_50_BYTES');

        final testModelRepo = ModelManagerRepositoryImpl(
          customModelsDirectory: modelsDir,
          minLlmBytes: 50,
          minEmbBytes: 50,
        );

        final localRagImpl = LocalRagRepositoryImpl(
          formatter: const RagContextFormatter(),
        );

        final e2eRagRepo = E2eTestRagRepository(
          realRepo: localRagImpl,
          curriculumChunks: const [
            DocumentChunk(
              id: 1,
              niveau: 'CM1',
              matiere: 'Mathématiques',
              page: 42,
              content:
                  'Fractions simples : nommer, utiliser, représenter des fractions simples. Partage équitable et repérage.',
            ),
          ],
        );

        // Fournisseur IA avec stream de réponse pédagogique structuré
        final e2eLlmProvider = EdgeAiLlmProvider(
          ragRepository: e2eRagRepo,
          ragContextFormatter: const RagContextFormatter(),
          modelRepository: testModelRepo,
          fallbackStreamer: (prompt, formattedPrompt, sources) async* {
            yield '# Fiche Pédagogique : Les Fractions au CM1\n\n';
            yield '## 1. Objectifs de la séance\n';
            yield '- Comprendre la notion de partage équitable.\n';
            yield '- Représenter des fractions simples (1/2, 1/4) au tableau.\n\n';
            yield '## 2. Activité au Tableau Noir\n';
            yield 'Tracer une bande de 4 carreaux et hachurer 1 carreau (1/4).\n\n';
            yield '## 3. Exercices d\'application\n';
            yield '1. Partager un gâteau de 8 parts entre 4 élèves.\n';
            yield '2. Écrire la fraction correspondante.\n\n';
            yield 'Source officielle : Mathématiques CM1, p. 42.';
          },
        );

        sl.registerSingleton<ModelManagerRepository>(testModelRepo);
        sl.registerFactory<ModelManagerCubit>(
          () => ModelManagerCubit(repository: sl<ModelManagerRepository>()),
        );
        sl.registerLazySingleton<RagContextFormatter>(
          () => const RagContextFormatter(),
        );
        sl.registerLazySingleton<RagRepository>(() => e2eRagRepo);
        sl.registerLazySingleton<EdgeAiLlmProvider>(() => e2eLlmProvider);

        // 1. Démarrer l'application avec TeacherChatScreen
        await tester.pumpWidget(
          CompagnonPedagogiqueApp(
            initialModelsReady: true,
            customLlmProvider: e2eLlmProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TeacherChatScreen), findsOneWidget);

        // 2. Déclencher une demande via la suggestion 1-tap "Préparer une fiche de cours"
        final suggestionFinder = find.text('Préparer une fiche de cours');
        expect(suggestionFinder, findsOneWidget);
        await tester.tap(suggestionFinder);
        await tester.pumpAndSettle();

        // 2b. Parcours de cadrage sans clavier via les puces interactives (Phase 1)
        final cm1Chip = find.widgetWithText(ActionChip, 'CM1');
        expect(cm1Chip, findsOneWidget);
        await tester.tap(cm1Chip);
        await tester.pumpAndSettle();

        final mathsChip = find.widgetWithText(ActionChip, 'Mathématiques');
        expect(mathsChip, findsOneWidget);
        await tester.tap(mathsChip);

        // Pomper les frames pour laisser le RAG s'exécuter et le stream se propager
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // 3. Vérifier que la recherche RAG a remonté la pastille de source(s) officielle(s) dans l'AppBar
        expect(
          find.textContaining('source'),
          findsOneWidget,
        );

        // 4. Vérifier que le contenu généré est affiché à l'écran
        expect(
          find.textContaining('Fiche Pédagogique : Les Fractions au CM1'),
          findsOneWidget,
        );

        // 5. Vérifier la présence du bouton pilule "Exporter en PDF" (FinalActionsBar)
        final exportPdfButton =
            find.widgetWithText(ElevatedButton, 'Exporter en PDF');
        expect(exportPdfButton, findsOneWidget);

        // 6. Cliquer sur "Exporter en PDF"
        await tester.tap(exportPdfButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        // 7. Vérifier que la génération PDF a bien réussi et que le fichier est sauvegardé
        final pdfDir = Directory(
          p.join(tempTestDir.path, AppConstants.pdfsDirectoryName),
        );
        expect(pdfDir.existsSync(), isTrue);
        final generatedPdfs = pdfDir.listSync().whereType<File>().toList();
        expect(generatedPdfs.isNotEmpty, isTrue);

        // Vérifier également la présence de la confirmation SnackBar si encore affichée
        final snackBarFinder = find.text('Fiche PDF enregistrée');
        if (snackBarFinder.evaluate().isNotEmpty) {
          expect(snackBarFinder, findsOneWidget);
        }

        await tester.pumpAndSettle();

        // 8. Naviguer vers SavedPdfsScreen via l'icône de l'AppBar
        final pdfListIcon = find.byTooltip('Fiches PDF enregistrées');
        expect(pdfListIcon, findsOneWidget);
        await tester.tap(pdfListIcon);
        await tester.pumpAndSettle();

        // 9. Vérifier que SavedPdfsScreen est ouvert et que le fichier PDF y apparaît
        expect(find.byType(SavedPdfsScreen), findsOneWidget);
        expect(find.text('Fiches PDF Sauvegardées'), findsOneWidget);
        expect(find.byIcon(Icons.picture_as_pdf_rounded), findsWidgets);
        expect(find.byType(ListView), findsOneWidget);
      },
    );
  });
}
