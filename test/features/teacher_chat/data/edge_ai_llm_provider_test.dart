import 'dart:io';

import 'package:compagnon_pedagogique/core/constants/app_constants.dart';
import 'package:compagnon_pedagogique/core/constants/prompt_templates.dart';
import 'package:compagnon_pedagogique/core/errors/failures.dart';
import 'package:compagnon_pedagogique/core/utils/emoji_sanitizer.dart';
import 'package:compagnon_pedagogique/features/model_manager/data/model_manager_repository.dart';
import 'package:compagnon_pedagogique/features/model_manager/domain/model_status.dart';
import 'package:compagnon_pedagogique/features/rag_engine/data/rag_context_formatter.dart';
import 'package:compagnon_pedagogique/features/rag_engine/domain/document_chunk.dart';
import 'package:compagnon_pedagogique/features/rag_engine/domain/rag_repository.dart';
import 'package:compagnon_pedagogique/features/teacher_chat/data/edge_ai_llm_provider.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

class MockRagRepository implements RagRepository {
  List<DocumentChunk> mockResults = [];
  String lastSearchedQuery = '';
  int lastLimit = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> initializeDatabase() async {}

  @override
  Future<List<DocumentChunk>> searchRelevantChunks(
    String query, {
    int limit = 3,
  }) async {
    lastSearchedQuery = query;
    lastLimit = limit;
    return mockResults;
  }

  @override
  String formatChunksForPrompt(List<DocumentChunk> chunks) {
    const formatter = RagContextFormatter();
    return formatter.format(chunks);
  }

  @override
  Future<void> dispose() async {}
}

class MockModelManagerRepository implements ModelManagerRepository {
  String returnedPath = '/non/existent/model.gguf';

  @override
  Future<bool> areAllModelsReady() async => false;

  @override
  Future<Directory> getModelsDirectory() async => Directory('/tmp');

  @override
  Future<String> getModelPath(String fileName) async => returnedPath;

  @override
  TaskEither<Failure, Map<String, ModelFileStatus>> checkModelsStatus() =>
      TaskEither.right({});

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
  Future<void> pauseDownload() async {}

  @override
  TaskEither<Failure, String?> importModelFromFilePicker({
    required Function(double progress) onCopyProgress,
  }) =>
      TaskEither.right(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PromptTemplates Qwen 2.5 Strict Tests', () {
    test('formatTeacherPrompt should strictly produce Qwen 2.5 ChatML format',
        () {
      const prompt = 'Fiche sur les fractions CM1';
      const context =
          '[SOURCE : Mathématiques | CM1 | Page 42]\nLes fractions simples.';

      final formatted = PromptTemplates.formatTeacherPrompt(
        prompt: prompt,
        formattedContext: context,
      );

      // Verify ChatML delimiters
      expect(formatted, contains('<|im_start|>system'));
      expect(formatted, contains('<|im_end|>'));
      expect(formatted, contains('<|im_start|>user'));
      expect(formatted, contains('<|im_start|>assistant'));

      // Verify specific educational instructions for rural primary schools
      expect(formatted, contains('Compagnon Pédagogique'));
      expect(formatted, contains('primaire en milieu rural'));
      expect(formatted, contains('EXTRAITS DU PROGRAMME OFFICIEL :'));
      expect(formatted, contains(context));
      expect(formatted, contains(prompt));

      // Verify tag order
      final systemIdx = formatted.indexOf('<|im_start|>system');
      final userIdx = formatted.indexOf('<|im_start|>user');
      final assistantIdx = formatted.indexOf('<|im_start|>assistant');

      expect(systemIdx < userIdx, isTrue);
      expect(userIdx < assistantIdx, isTrue);
    });

    test('le prompt demande une mise en page Markdown sans emoji', () {
      expect(containsEmoji(PromptTemplates.systemPrompt), isFalse);

      final formatted = PromptTemplates.formatTeacherPrompt(
        prompt: 'Fiche fractions',
        formattedContext: '',
      );
      expect(containsEmoji(formatted), isFalse);
      expect(formatted, contains('## Objectifs'));
      expect(formatted, contains('LaTeX'));
    });
  });

  group('EdgeAiLlmProvider Tests', () {
    late MockRagRepository mockRagRepo;
    late MockModelManagerRepository mockModelRepo;
    late EdgeAiLlmProvider provider;

    setUp(() {
      mockRagRepo = MockRagRepository();
      mockModelRepo = MockModelManagerRepository();
      provider = EdgeAiLlmProvider(
        ragRepository: mockRagRepo,
        ragContextFormatter: const RagContextFormatter(),
        modelRepository: mockModelRepo,
      );
    });

    tearDown(() {
      provider.dispose();
    });

    test('initial state should have empty history and empty sources', () {
      expect(provider.history, isEmpty);
      expect(provider.lastRetrievedSources, isEmpty);
    });

    test('history setter should update history and notify listeners', () {
      bool notified = false;
      provider.addListener(() => notified = true);

      final message = ChatMessage.user('Test query', const []);
      provider.history = [message];

      expect(provider.history.length, 1);
      expect(provider.history.first.text, 'Test query');
      expect(notified, isTrue);
    });

    test('generateStream queries RAG with limit 3 and emits sources via stream',
        () async {
      final sampleChunks = [
        const DocumentChunk(
          id: 1,
          niveau: 'CM1',
          matiere: 'Mathématiques',
          page: 12,
          content: 'Nombres et opérations',
        ),
      ];
      mockRagRepo.mockResults = sampleChunks;

      List<DocumentChunk>? emittedSources;
      final sub = provider.sourcesStream.listen((sources) {
        emittedSources = sources;
      });

      final output = await provider
          .generateStream('Comment enseigner les nombres ?')
          .toList();

      expect(mockRagRepo.lastSearchedQuery, 'Comment enseigner les nombres ?');
      expect(mockRagRepo.lastLimit, 3);
      expect(provider.lastRetrievedSources, equals(sampleChunks));
      expect(emittedSources, equals(sampleChunks));

      // With no model installed, a clear error message in French is returned
      expect(output.join(), contains('modèle'));
      expect(output.join(), contains(AppConstants.llmModelFileName));

      await sub.cancel();
    });

    test('sendMessageStream populates history with user and LLM message',
        () async {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      final stream = provider.sendMessageStream('Créer un exercice');
      final chunks = await stream.toList();

      expect(chunks.isNotEmpty, isTrue);
      expect(provider.history.length, 2);
      expect(provider.history.first.origin.isUser, isTrue);
      expect(provider.history.first.text, 'Créer un exercice');
      expect(provider.history.last.origin.isLlm, isTrue);
      expect(provider.history.last.text, equals(chunks.join()));
      expect(notifyCount, greaterThanOrEqualTo(1));
    });

    test('supports custom fallback streamer for testing or offline simulations',
        () async {
      final customProvider = EdgeAiLlmProvider(
        ragRepository: mockRagRepo,
        modelRepository: mockModelRepo,
        fallbackStreamer: (prompt, formattedPrompt, sources) async* {
          yield 'Token1 ';
          yield 'Token2 ';
          yield 'Fini.';
        },
      );

      final result = await customProvider.generateStream('Ma demande').toList();
      expect(result, ['Token1 ', 'Token2 ', 'Fini.']);

      customProvider.dispose();
    });

    group('Cadrage en une question à la fois', () {
      late String? fallbackPrompt;
      late EdgeAiLlmProvider guidedProvider;

      setUp(() {
        fallbackPrompt = null;
        guidedProvider = EdgeAiLlmProvider(
          ragRepository: mockRagRepo,
          modelRepository: mockModelRepo,
          fallbackStreamer: (prompt, formattedPrompt, sources) async* {
            fallbackPrompt = prompt;
            yield 'FICHE GENEREE';
          },
        );
      });

      tearDown(() => guidedProvider.dispose());

      test('une demande vague déclenche une seule question, sans inférence',
          () async {
        final questions = await guidedProvider
            .sendMessageStream('Préparer une fiche de cours')
            .toList();

        expect(questions, hasLength(1));
        expect(questions.single, contains('classe'));
        expect(guidedProvider.isAwaitingClarification, isTrue);
        expect(mockRagRepo.lastSearchedQuery, isEmpty);
      });

      test('classe puis matière sont demandées avant la génération', () async {
        await guidedProvider
            .sendMessageStream('Préparer une fiche de cours')
            .toList();
        final subjectQuestion =
            await guidedProvider.sendMessageStream('CM1').toList();

        expect(subjectQuestion.single, contains('matière'));
        expect(guidedProvider.isAwaitingClarification, isTrue);

        final answer =
            await guidedProvider.sendMessageStream('Mathématiques').toList();
        expect(answer.join(), contains('FICHE GENEREE'));
        expect(guidedProvider.isAwaitingClarification, isFalse);
        expect(fallbackPrompt, contains('Préparer une fiche de cours'));
        expect(fallbackPrompt, contains('Classe : CM1'));
        expect(fallbackPrompt, contains('Matière : Mathématiques'));
        expect(mockRagRepo.lastSearchedQuery, 'Préparer une fiche de cours');
      });

      test('une demande déjà précise est générée sans question', () async {
        const request = 'Fiche sur les fractions CM1 mathématiques';

        final answer = await guidedProvider.sendMessageStream(request).toList();

        expect(answer.join(), contains('FICHE GENEREE'));
        expect(guidedProvider.isAwaitingClarification, isFalse);
        expect(guidedProvider.gatheredInfo, isEmpty);
      });

      test('propose les puces interactives adaptées selon la question',
          () async {
        expect(guidedProvider.currentClarificationSuggestions, isEmpty);

        await guidedProvider.sendMessageStream('Fiche pédagogique').toList();
        expect(guidedProvider.isAwaitingClarification, isTrue);
        expect(guidedProvider.pendingQuestionLabel, 'Classe');
        expect(guidedProvider.currentClarificationSuggestions, contains('CP'));
        expect(guidedProvider.currentClarificationSuggestions, contains('CM2'));
        expect(guidedProvider.currentClarificationSuggestions,
            contains('Double niveau'));

        await guidedProvider.sendMessageStream('CE2').toList();
        expect(guidedProvider.pendingQuestionLabel, 'Matière');
        expect(guidedProvider.currentClarificationSuggestions,
            contains('Mathématiques'));
        expect(guidedProvider.currentClarificationSuggestions,
            contains('Français'));
      });
    });

    group('Phase 1 - Machine d\'état & Discrimination', () {
      test('transitionne correctement à travers les GenerationPhase', () async {
        final phases = <GenerationPhase>[];
        final sub = provider.phaseStream.listen(phases.add);

        expect(provider.currentPhase, GenerationPhase.idle);

        final customProvider = EdgeAiLlmProvider(
          ragRepository: mockRagRepo,
          modelRepository: mockModelRepo,
          fallbackStreamer: (p, fp, s) async* {
            yield 'Tok1';
          },
        );

        final pPhases = <GenerationPhase>[];
        customProvider.phaseStream.listen(pPhases.add);

        await customProvider
            .generateStream('Fiche fractions CM1 maths')
            .toList();
        await Future<void>.delayed(Duration.zero);

        expect(customProvider.currentPhase, GenerationPhase.completed);
        expect(pPhases, contains(GenerationPhase.retrievingCurriculum));
        expect(pPhases, contains(GenerationPhase.loadingModel));
        expect(pPhases, contains(GenerationPhase.streamingTokens));
        expect(pPhases, contains(GenerationPhase.completed));

        await sub.cancel();
        customProvider.dispose();
      });

      test('isClarificationQuestion identifie fidèlement les questions posées',
          () {
        expect(
            provider.isClarificationQuestion(
                'Pour quelle classe prépares-tu cette fiche ?'),
            isTrue);
        expect(provider.isClarificationQuestion('Quelle matière ?'), isTrue);
        expect(
            provider.isClarificationQuestion(
                'Quelle durée prévois-tu pour la séance ?'),
            isTrue);
        expect(
            provider.isClarificationQuestion('## Objectifs\nVoici la fiche.'),
            isFalse);
        expect(
            provider.isClarificationQuestion(
                '## Exercices\nCombien de billes a Pierre ?'),
            isFalse);
        expect(provider.isClarificationQuestion(''), isFalse);
      });

      test(
          'reconnaît "Double niveau" comme une classe valide sans réinterroger',
          () async {
        final guidedProvider = EdgeAiLlmProvider(
          ragRepository: mockRagRepo,
          modelRepository: mockModelRepo,
          fallbackStreamer: (p, fp, s) async* {
            yield 'FICHE DOUBLE NIVEAU GENEREE';
          },
        );

        // 1. Demande vague déclenchant la question de classe
        final q1 = await guidedProvider
            .sendMessageStream('Préparer une fiche')
            .toList();
        expect(q1.single, contains('classe'));

        // 2. Répondre "Double niveau"
        final q2 =
            await guidedProvider.sendMessageStream('Double niveau').toList();
        // Doit passer à la question suivante (matière) et NON reposer la question de classe !
        expect(q2.single, contains('matière'));
        expect(guidedProvider.pendingQuestionLabel, 'Matière');

        guidedProvider.dispose();
      });

      test(
          'isActivelyGeneratingFor discrimine les messages en cours de génération',
          () async {
        final customProvider = EdgeAiLlmProvider(
          ragRepository: mockRagRepo,
          modelRepository: mockModelRepo,
          fallbackStreamer: (p, fp, s) async* {
            yield 'Contenu partiel';
          },
        );

        expect(
            customProvider.isActivelyGeneratingFor('Contenu partiel'), isFalse);

        await customProvider
            .sendMessageStream('Fiche fractions CM1 maths')
            .toList();

        // Une fois terminé, la génération n'est plus active
        expect(
            customProvider.isActivelyGeneratingFor('Contenu partiel'), isFalse);
        customProvider.dispose();
      });
    });
  });
}
