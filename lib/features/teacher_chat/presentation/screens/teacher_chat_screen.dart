import 'dart:async';

import 'package:compagnon_pedagogique/core/constants/app_constants.dart';
import 'package:compagnon_pedagogique/core/di/injection_container.dart';
import 'package:compagnon_pedagogique/core/theme/app_theme.dart';
import 'package:compagnon_pedagogique/core/utils/emoji_sanitizer.dart';
import 'package:compagnon_pedagogique/core/utils/pdf_exporter.dart';
import 'package:compagnon_pedagogique/features/model_manager/presentation/screens/model_setup_screen.dart';
import 'package:compagnon_pedagogique/features/rag_engine/domain/document_chunk.dart';
import 'package:compagnon_pedagogique/features/teacher_chat/data/edge_ai_llm_provider.dart';
import 'package:compagnon_pedagogique/features/teacher_chat/presentation/screens/saved_pdfs_screen.dart';
import 'package:compagnon_pedagogique/features/teacher_chat/presentation/widgets/final_actions_bar.dart';
import 'package:compagnon_pedagogique/features/teacher_chat/presentation/widgets/generation_state_indicator.dart';
import 'package:compagnon_pedagogique/features/teacher_chat/presentation/widgets/markdown_answer_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:open_filex/open_filex.dart';

class TeacherChatScreen extends StatefulWidget {
  final EdgeAiLlmProvider? provider;

  const TeacherChatScreen({super.key, this.provider});

  @override
  State<TeacherChatScreen> createState() => _TeacherChatScreenState();
}

class _TeacherChatScreenState extends State<TeacherChatScreen> {
  late final EdgeAiLlmProvider _provider;
  StreamSubscription<List<DocumentChunk>>? _sourcesSubscription;
  List<DocumentChunk> _activeSources = [];
  bool _isPleinSoleil = false;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider ?? sl<EdgeAiLlmProvider>();
    _provider.addListener(_onProviderUpdate);
    _sourcesSubscription = _provider.sourcesStream.listen((sources) {
      if (mounted) {
        setState(() {
          _activeSources = sources;
        });
      }
    });
  }

  void _onProviderUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderUpdate);
    _sourcesSubscription?.cancel();
    super.dispose();
  }

  void _togglePleinSoleil() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    setState(() {
      _isPleinSoleil = !_isPleinSoleil;
    });
  }

  void _handleClarificationChip(String suggestion) {
    if (_provider.currentPhase == GenerationPhase.streamingTokens ||
        _provider.currentPhase == GenerationPhase.loadingModel ||
        _provider.currentPhase == GenerationPhase.retrievingCurriculum) {
      return;
    }
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    final stream = _provider.sendMessageStream(suggestion);
    stream.listen(null, onError: (e) {
      debugPrint('[TeacherChatScreen] Erreur flux clarification: $e');
    });
  }

  void _showSourcesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isPleinSoleil ? Colors.white : AppTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                // Poignée de glissement
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // En-tête de la feuille
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_stories_rounded,
                        color: AppTheme.primaryRoyalBlue,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Extraits des programmes officiels',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDarkSlate,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.dividerColor),

                // Liste des sources RAG
                Expanded(
                  child: _activeSources.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucun extrait pour cette requête.',
                            style: TextStyle(color: AppTheme.textMutedSlate),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _activeSources.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, index) {
                            final chunk = _activeSources[index];
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _isPleinSoleil
                                    ? Colors.white
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _isPleinSoleil
                                      ? Colors.black
                                      : const Color(0xFFE2E8F0),
                                  width: _isPleinSoleil ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryRoyalBlueLight,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${chunk.matiere} • ${chunk.niveau}',
                                          style: const TextStyle(
                                            color: AppTheme.primaryRoyalBlue,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Page ${chunk.page}',
                                        style: const TextStyle(
                                          color: AppTheme.textMutedSlate,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    chunk.content,
                                    style: TextStyle(
                                      color: _isPleinSoleil
                                          ? Colors.black
                                          : AppTheme.textDarkSlate,
                                      fontSize: 13,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportMessageToPdf(String messageContent) async {
    try {
      // Aucun emoji ne doit atteindre le PDF, même si le modèle en produit un.
      final safeContent = stripEmojis(messageContent);

      // Déterminer un titre propre à partir du premier en-tête ou de la première ligne
      final lines = safeContent.split('\n');
      final firstHeading = lines.firstWhere(
        (line) => line.trim().isNotEmpty,
        orElse: () => 'Fiche Pédagogique',
      );
      final sanitizedTitle = firstHeading
          .replaceAll(RegExp(r'^#+\s*'), '')
          .replaceAll(RegExp(r'[\*\_]'), '')
          .trim();

      final pdfFile = await PdfExporter.generatePedagogicalPdf(
        title: sanitizedTitle,
        content: safeContent,
      );

      // Validation tactile à la confirmation d'export PDF
      try {
        unawaited(HapticFeedback.mediumImpact());
      } catch (_) {}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.cardSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.dividerColor),
          ),
          duration: const Duration(seconds: 5),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppTheme.statusOfflineGreenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppTheme.statusOfflineGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fiche PDF enregistrée',
                      style: TextStyle(
                        color: AppTheme.textDarkSlate,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Disponible dans fiches_pdf/',
                      style: TextStyle(
                        color: AppTheme.textMutedSlate,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  PdfExporter.printPdf(pdfFile);
                },
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text(
                  'Imprimer',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              IconButton(
                tooltip: 'Ouvrir',
                icon: const Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: AppTheme.primaryRoyalBlue,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  OpenFilex.open(pdfFile.path);
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            'Erreur lors de l\'export PDF : $e',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  Widget _buildClarificationChipsBar() {
    final suggestions = _provider.currentClarificationSuggestions;
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isPleinSoleil
            ? Colors.white
            : const Color(0xFFF7F9FC).withAlpha(245),
        border: Border(
          top: BorderSide(
            color: _isPleinSoleil ? Colors.black : const Color(0xFFE2E8F0),
            width: 1,
          ),
          bottom: BorderSide(
            color: _isPleinSoleil ? Colors.black : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final suggestion in suggestions) ...[
              ActionChip(
                backgroundColor:
                    _isPleinSoleil ? Colors.white : const Color(0xFFFFFFFF),
                elevation: 0,
                side: BorderSide(
                  color:
                      _isPleinSoleil ? Colors.black : const Color(0xFFBFDBFE),
                  width: _isPleinSoleil ? 1.5 : 1.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                label: Text(
                  suggestion,
                  style: TextStyle(
                    color:
                        _isPleinSoleil ? Colors.black : const Color(0xFF1A6FEE),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                onPressed: () => _handleClarificationChip(suggestion),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isPleinSoleil ? Colors.white : const Color(0xFFF7F9FC);
    final borderColor = _isPleinSoleil ? Colors.black : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(66),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: borderColor,
                width: _isPleinSoleil ? 1.5 : 1.0,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Logo compact ~32px
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      AppConstants.logoAssetPath,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRoyalBlueLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: AppTheme.primaryRoyalBlue,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Titre & badge "● 100% Hors Ligne"
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConstants.appName,
                          style: TextStyle(
                            color: _isPleinSoleil
                                ? Colors.black
                                : const Color(0xFF0F172A),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.statusOfflineGreenLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Color(0xFF16A34A),
                                      shape: BoxShape.circle,
                                    ),
                                    child: SizedBox(width: 6, height: 6),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '100% Hors Ligne',
                                    style: TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Pastille compacte Sources RAG dans l'AppBar (sans layout shift)
                  if (_activeSources.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => _showSourcesModal(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _isPleinSoleil
                              ? Colors.white
                              : const Color(0xFFE8F1FD),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isPleinSoleil
                                ? Colors.black
                                : const Color(0xFFBFDBFE),
                            width: _isPleinSoleil ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_stories_rounded,
                              size: 14,
                              color: _isPleinSoleil
                                  ? const Color(0xFF0D47A1)
                                  : const Color(0xFF1A6FEE),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _activeSources.length > 1
                                  ? '${_activeSources.length} sources'
                                  : '1 source',
                              style: TextStyle(
                                color: _isPleinSoleil
                                    ? const Color(0xFF0D47A1)
                                    : const Color(0xFF1A6FEE),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Commutateur Mode Plein Soleil (WCAG AAA)
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _isPleinSoleil ? Colors.black : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isPleinSoleil
                            ? Colors.black
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: _isPleinSoleil
                          ? 'Désactiver le Mode Plein Soleil'
                          : 'Mode Plein Soleil (WCAG AAA)',
                      icon: Icon(
                        _isPleinSoleil
                            ? Icons.wb_sunny_rounded
                            : Icons.wb_sunny_outlined,
                        size: 19,
                        color: _isPleinSoleil
                            ? const Color(0xFFFDE047)
                            : const Color(0xFF0F172A),
                      ),
                      onPressed: _togglePleinSoleil,
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Icône dossier/PDF -> SavedPdfsScreen
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isPleinSoleil
                            ? Colors.black
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Fiches PDF enregistrées',
                      icon: const Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 19,
                        color: Color(0xFF0F172A),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SavedPdfsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Icône paramètres/stockage -> ModelSetupScreen
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isPleinSoleil
                            ? Colors.black
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Paramètres & Modèles',
                      icon: const Icon(
                        Icons.tune_rounded,
                        size: 19,
                        color: Color(0xFF0F172A),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ModelSetupScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Interface de Chat LLM fluide
          LlmChatView(
            provider: _provider,
            welcomeMessage:
                'Bonjour Maître. Décrivez le cours ou l\'exercice dont vous avez besoin.',
            suggestions: const [
              'Préparer une fiche de cours',
              'Créer des exercices corrigés',
              'Idée d\'activité pour classe double',
            ],
            style: LlmChatViewStyle(
              backgroundColor: bgColor,
              userMessageStyle: UserMessageStyle(
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
                decoration: BoxDecoration(
                  color:
                      _isPleinSoleil ? Colors.black : const Color(0xFF1A6FEE),
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                ),
              ),
              llmMessageStyle: LlmMessageStyle(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: borderColor,
                    width: _isPleinSoleil ? 1.5 : 1.0,
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                ),
              ),
            ),
            responseBuilder: (BuildContext context, String response) {
              final isActivelyGenerating =
                  _provider.isActivelyGeneratingFor(response);
              final isClarification =
                  _provider.isClarificationQuestion(response);
              final isError = _provider.currentPhase == GenerationPhase.error ||
                  response.startsWith('Le modèle d\'intelligence') ||
                  response.startsWith('Erreur');

              // Pendant la latence TTFT (réponse encore vide), afficher l'indicateur d'état
              if (response.trim().isEmpty) {
                return GenerationStateIndicator(
                  phase: _provider.currentPhase,
                  highContrast: _isPleinSoleil,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownAnswerView(
                    content: response,
                    isStreaming: isActivelyGenerating,
                    highContrast: _isPleinSoleil,
                  ),
                  // Afficher la barre d'outils animée à la fin de la génération (hors clarification et erreur)
                  if (!isClarification &&
                      !isActivelyGenerating &&
                      !isError) ...[
                    const SizedBox(height: 12),
                    FinalActionsBar(
                      content: response,
                      onExportPdf: () => _exportMessageToPdf(response),
                      highContrast: _isPleinSoleil,
                    ),
                  ],
                ],
              );
            },
          ),

          // Puces de cadrage pédagogique interactives (Zéro Clavier) au-dessus de la saisie
          if (_provider.isAwaitingClarification &&
              _provider.currentClarificationSuggestions.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 74,
              child: _buildClarificationChipsBar(),
            ),
        ],
      ),
    );
  }
}
