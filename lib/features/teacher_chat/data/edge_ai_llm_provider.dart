import 'dart:async';
import 'dart:io';

import 'package:compagnon_pedagogique/core/constants/app_constants.dart';
import 'package:compagnon_pedagogique/core/constants/prompt_templates.dart';
import 'package:compagnon_pedagogique/features/model_manager/data/model_manager_repository.dart';
import 'package:compagnon_pedagogique/features/rag_engine/data/rag_context_formatter.dart';
import 'package:compagnon_pedagogique/features/rag_engine/domain/document_chunk.dart';
import 'package:compagnon_pedagogique/features/rag_engine/domain/rag_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_llama/flutter_edge_ai_llama.dart';

/// Phases du cycle de génération réactive pour le moteur Edge AI
enum GenerationPhase {
  idle,
  clarifying,
  retrievingCurriculum,
  loadingModel,
  streamingTokens,
  completed,
  error,
}

typedef EdgeAiFallbackStreamer = Stream<String> Function(
  String prompt,
  String formattedPrompt,
  List<DocumentChunk> sources,
);

/// Pont IA reliant le moteur Edge AI local (flutter_edge_ai_llama + RagRepository)
/// au composant LlmChatView de flutter_ai_toolkit.
class EdgeAiLlmProvider extends LlmProvider with ChangeNotifier {
  final RagRepository _ragRepository;
  final RagContextFormatter _ragContextFormatter;
  final ModelManagerRepository _modelRepository;
  final EdgeAiFallbackStreamer? _fallbackStreamer;
  final List<ChatMessage> _history;

  InferenceModel? _inferenceModel;
  Completer<InferenceModel?>? _modelInitCompleter;

  // Machine d'état réactive
  GenerationPhase _currentPhase = GenerationPhase.idle;
  GenerationPhase get currentPhase => _currentPhase;

  final _phaseStreamController = StreamController<GenerationPhase>.broadcast();
  Stream<GenerationPhase> get phaseStream => _phaseStreamController.stream;

  // Questions de clarification enregistrées
  final Set<String> _clarificationQuestions = <String>{};

  // Dernières sources RAG retrouvées
  List<DocumentChunk> _lastRetrievedSources = [];
  List<DocumentChunk> get lastRetrievedSources => _lastRetrievedSources;

  /// Cadrage en une question à la fois. Il est piloté par l'application plutôt
  /// que par le modèle local : avec 1,5 milliard de paramètres, une consigne
  /// « pose une question » dans le prompt n'est pas assez fiable hors ligne.
  bool _awaitingClarification = false;
  String _pendingRequest = '';
  String _pendingQuestionLabel = '';
  final List<String> _gatheredInfo = <String>[];
  int _clarificationRounds = 0;

  /// Nombre maximal de questions posées avant de lancer la génération.
  static const int maxClarificationRounds = 3;

  bool get isAwaitingClarification => _awaitingClarification;
  String get pendingQuestionLabel => _pendingQuestionLabel;
  List<String> get gatheredInfo => List<String>.unmodifiable(_gatheredInfo);

  /// Suggestions interactives (Zéro Clavier) selon l'étape de cadrage
  List<String> get currentClarificationSuggestions {
    if (!_awaitingClarification) return const [];
    switch (_pendingQuestionLabel.toLowerCase()) {
      case 'classe':
        return const ['CP', 'CE1', 'CE2', 'CM1', 'CM2', 'Double niveau'];
      case 'matière':
      case 'matiere':
        return const [
          'Mathématiques',
          'Français',
          'Sciences',
          'Histoire-Géo',
          'EPS',
        ];
      case 'durée':
      case 'duree':
        return const ['30 min', '45 min', '60 min'];
      default:
        return const ['CP', 'CE1', 'CE2', 'CM1', 'CM2', 'Double niveau'];
    }
  }

  static final RegExp _gradePattern = RegExp(
    r'\b(CP|CE1|CE2|CM1|CM2|6e|6ème|double[- ]niveau|multi[- ]niveau|cours double|classe double)\b',
    caseSensitive: false,
  );
  static final RegExp _subjectPattern = RegExp(
    r'\b(math(?:s|ématiques?)?|fran[cç]ais|lecture|sciences?|histoire|g[ée]ographie|anglais|EPS)\b',
    caseSensitive: false,
  );
  static final RegExp _durationPattern = RegExp(
    r'\b\d+\s*(min|minutes?|h|heures?)\b',
    caseSensitive: false,
  );
  static final RegExp _needsDurationPattern = RegExp(
    r'\b(s[ée]ance|planning|progression|dur[ée]e)\b',
    caseSensitive: false,
  );

  // StreamController pour notifier les sources RAG actives à l'UI
  final _sourcesStreamController =
      StreamController<List<DocumentChunk>>.broadcast();
  Stream<List<DocumentChunk>> get sourcesStream =>
      _sourcesStreamController.stream;

  EdgeAiLlmProvider({
    required RagRepository ragRepository,
    RagContextFormatter? ragContextFormatter,
    required ModelManagerRepository modelRepository,
    EdgeAiFallbackStreamer? fallbackStreamer,
    Iterable<ChatMessage>? history,
  })  : _ragRepository = ragRepository,
        _ragContextFormatter =
            ragContextFormatter ?? const RagContextFormatter(),
        _modelRepository = modelRepository,
        _fallbackStreamer = fallbackStreamer,
        _history =
            history != null ? List<ChatMessage>.from(history) : <ChatMessage>[];

  void _setPhase(GenerationPhase phase) {
    _currentPhase = phase;
    _phaseStreamController.add(phase);
    notifyListeners();
  }

  /// Détermine si la réponse indiquée est activement en cours de génération
  bool isActivelyGeneratingFor(String response) {
    if (_currentPhase == GenerationPhase.idle ||
        _currentPhase == GenerationPhase.completed ||
        _currentPhase == GenerationPhase.error) {
      return false;
    }
    if (_history.isNotEmpty && _history.last.origin.isLlm) {
      final currentText = _history.last.text ?? '';
      return response == currentText;
    }
    return false;
  }

  /// Détermine si la réponse correspond à une question de cadrage
  bool isClarificationQuestion(String response) {
    final trimmed = response.trim();
    if (trimmed.isEmpty) return false;
    if (_clarificationQuestions.contains(trimmed)) return true;
    if (trimmed.contains('classe prépares-tu') ||
        trimmed.contains('Quelle matière') ||
        trimmed.contains('Quelle durée')) {
      return true;
    }
    // Si la réponse contient des balises d'en-tête Markdown (# ou ##), ce n'est PAS une question de cadrage
    if (RegExp(r'(^|\n)#+\s').hasMatch(trimmed)) {
      return false;
    }
    return trimmed.endsWith('?') && trimmed.length < 150;
  }

  @override
  Iterable<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> history) {
    _history.clear();
    _history.addAll(history);
    notifyListeners();
  }

  /// Charge paresseusement le modèle local qwen2.5-1.5b-instruct-q4_k_m.gguf
  /// en singleton pour préserver la mémoire vive (RAM).
  Future<InferenceModel?> getOrLoadInferenceModel() async {
    if (_inferenceModel != null) return _inferenceModel;
    if (_modelInitCompleter != null) return _modelInitCompleter!.future;

    final completer = Completer<InferenceModel?>();
    _modelInitCompleter = completer;

    try {
      final llmPath =
          await _modelRepository.getModelPath(AppConstants.llmModelFileName);
      final llmFile = File(llmPath);

      if (!await llmFile.exists() ||
          await llmFile.length() < (AppConstants.llmModelExpectedSize * 0.5)) {
        completer.complete(null);
        return null;
      }

      FlutterEdgeAi.initialize(
        inferenceEngines: const [LlamaEngineProvider()],
      );

      final builder = FlutterEdgeAi.installModel(
        modelType: ModelType.qwen,
        fileType: ModelFileType.gguf,
      );
      builder.fromFile(llmPath);
      await builder.install();

      _inferenceModel = await FlutterEdgeAi.getActiveModel();
      completer.complete(_inferenceModel);
      return _inferenceModel;
    } catch (e) {
      debugPrint('[EdgeAiLlmProvider] Erreur chargement modèle LLM: $e');
      completer.complete(null);
      return null;
    } finally {
      _modelInitCompleter = null;
    }
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    try {
      HapticFeedback.lightImpact().catchError((_) {});
    } catch (_) {}

    final userMessage = ChatMessage.user(prompt, attachments);
    final llmMessage = ChatMessage.llm();
    _history.addAll([userMessage, llmMessage]);

    // Une seule question à la fois : on ne lance pas le modèle tant que le
    // niveau, la matière et éventuellement la durée ne sont pas connus.
    final question = _nextClarificationQuestion(prompt);
    if (question != null) {
      _clarificationQuestions.add(question.trim());
      _setPhase(GenerationPhase.clarifying);
      llmMessage.append(question);
      yield question;
      _setPhase(GenerationPhase.completed);
      _setPhase(GenerationPhase.idle);
      notifyListeners();
      return;
    }

    final clarifiedPrompt = _buildClarifiedPrompt();
    final originalRequest = _pendingRequest;
    final responseStream = generateStream(
      clarifiedPrompt,
      attachments: attachments,
      ragQuery: originalRequest,
    );
    yield* responseStream.map((chunk) {
      llmMessage.append(chunk);
      notifyListeners();
      return chunk;
    });

    notifyListeners();
  }

  /// Renvoie la prochaine question de cadrage, ou null si l'agent peut répondre.
  String? _nextClarificationQuestion(String incomingPrompt) {
    if (_awaitingClarification) {
      _gatheredInfo.add('$_pendingQuestionLabel : ${incomingPrompt.trim()}');
      _awaitingClarification = false;
      _pendingQuestionLabel = '';
    } else {
      // Nouvelle demande : on repart d'un cadrage vierge.
      _pendingRequest = incomingPrompt.trim();
      _gatheredInfo.clear();
      _clarificationRounds = 0;
    }

    final known = '$_pendingRequest ${_gatheredInfo.join(' ')}';
    final missing = _missingInfo(known);
    if (missing == null || _clarificationRounds >= maxClarificationRounds) {
      return null;
    }

    _clarificationRounds++;
    _awaitingClarification = true;
    switch (missing) {
      case 'classe':
        _pendingQuestionLabel = 'Classe';
        return 'Pour quelle classe prépares-tu cette fiche ?';
      case 'matière':
        _pendingQuestionLabel = 'Matière';
        return 'Quelle matière ?';
      default:
        _pendingQuestionLabel = 'Durée';
        return 'Quelle durée prévois-tu pour la séance ?';
    }
  }

  /// Informations manquantes dans la demande, dans leur ordre de priorité.
  String? _missingInfo(String known) {
    if (!_gradePattern.hasMatch(known)) return 'classe';
    if (!_subjectPattern.hasMatch(known)) return 'matière';
    if (_needsDurationPattern.hasMatch(known) &&
        !_durationPattern.hasMatch(known)) {
      return 'durée';
    }
    return null;
  }

  /// Demande initiale complétée des réponses données aux questions.
  String _buildClarifiedPrompt() {
    final buffer = StringBuffer(_pendingRequest);
    if (_gatheredInfo.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Informations confirmées par l\'enseignant :');
      for (final info in _gatheredInfo) {
        buffer.writeln('- $info');
      }
    }
    return buffer.toString();
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],

    /// Requête utilisée pour la recherche RAG. Par défaut la demande elle-même.
    String? ragQuery,
  }) async* {
    try {
      // 1. Recherche RAG des passages officiels pertinents (limit: 3)
      _setPhase(GenerationPhase.retrievingCurriculum);
      _lastRetrievedSources = await _ragRepository
          .searchRelevantChunks(ragQuery ?? prompt, limit: 3);
      _sourcesStreamController.add(_lastRetrievedSources);

      // 2. Formatage du contexte officiel
      final formattedContext =
          _ragContextFormatter.format(_lastRetrievedSources);

      // 3. Construction du prompt Qwen 2.5 avec les balises strictes
      final formattedPrompt = PromptTemplates.formatTeacherPrompt(
        prompt: prompt,
        formattedContext: formattedContext,
      );

      // 4. Inférence et diffusion streaming des tokens
      if (_fallbackStreamer != null) {
        _setPhase(GenerationPhase.loadingModel);
        _setPhase(GenerationPhase.streamingTokens);
        bool isFirst = true;
        await for (final chunk in _fallbackStreamer(
          prompt,
          formattedPrompt,
          _lastRetrievedSources,
        )) {
          if (isFirst) {
            isFirst = false;
            HapticFeedback.selectionClick().catchError((_) {});
          }
          yield chunk;
        }
        _setPhase(GenerationPhase.completed);
        HapticFeedback.mediumImpact().catchError((_) {});
        return;
      }

      _setPhase(GenerationPhase.loadingModel);
      final model = await getOrLoadInferenceModel();
      if (model == null) {
        _setPhase(GenerationPhase.error);
        // Message d'erreur clair en français si le modèle n'est pas encore prêt/chargé
        yield 'Le modèle d\'intelligence artificielle locale (${AppConstants.llmModelFileName}) '
            'n\'est pas encore téléchargé ou installé sur votre appareil.\n\n'
            'Veuillez vous rendre dans l\'écran des paramètres (icône en haut à droite) '
            'pour lancer le téléchargement ou importer les fichiers .gguf depuis une carte SD ou Xender.';
        return;
      }

      try {
        final session = await model.openSession();
        try {
          await session.addQueryChunk(Message.text(text: formattedPrompt));
          _setPhase(GenerationPhase.streamingTokens);
          bool isFirst = true;
          await for (final chunk in session.getResponseAsync()) {
            if (isFirst) {
              isFirst = false;
              HapticFeedback.selectionClick().catchError((_) {});
            }
            yield chunk;
          }
          _setPhase(GenerationPhase.completed);
          HapticFeedback.mediumImpact().catchError((_) {});
        } finally {
          await session.close();
        }
      } catch (e) {
        debugPrint('[EdgeAiLlmProvider] Erreur lors de l\'inférence: $e');
        _setPhase(GenerationPhase.error);
        yield 'Erreur lors de la génération avec le modèle local : $e';
      }
    } catch (e) {
      debugPrint('[EdgeAiLlmProvider] Erreur générale: $e');
      _setPhase(GenerationPhase.error);
      yield 'Erreur : $e';
    }
  }

  @override
  void dispose() {
    _sourcesStreamController.close();
    _phaseStreamController.close();
    _inferenceModel?.close();
    _inferenceModel = null;
    super.dispose();
  }
}
