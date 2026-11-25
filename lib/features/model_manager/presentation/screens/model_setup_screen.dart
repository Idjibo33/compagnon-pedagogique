import 'package:compagnon_pedagogique/core/constants/app_constants.dart';
import 'package:compagnon_pedagogique/core/theme/app_theme.dart';
import 'package:compagnon_pedagogique/core/utils/disk_space_checker.dart';
import 'package:compagnon_pedagogique/features/model_manager/domain/model_status.dart';
import 'package:compagnon_pedagogique/features/model_manager/presentation/cubit/model_manager_cubit.dart';
import 'package:compagnon_pedagogique/features/model_manager/presentation/cubit/model_manager_state.dart';
import 'package:compagnon_pedagogique/features/teacher_chat/presentation/screens/teacher_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ModelSetupScreen extends StatefulWidget {
  const ModelSetupScreen({super.key});

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen> {
  bool _isStorageAlertShowing = false;

  @override
  void initState() {
    super.initState();
    context.read<ModelManagerCubit>().checkStatus();
  }

  void _showInsufficientStorageDialog(
    BuildContext context,
    int? availableBytes,
  ) {
    if (_isStorageAlertShowing) return;
    _isStorageAlertShowing = true;

    final availableStr = availableBytes != null
        ? SystemDiskSpaceChecker.formatBytes(availableBytes)
        : 'Inconnu';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.disc_full_rounded, color: AppTheme.errorRed, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Espace Disque Insuffisant',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Le fonctionnement du Compagnon Pédagogique hors-ligne nécessite au moins 1.5 Go d\'espace libre pour installer les modèles d\'intelligence artificielle.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppTheme.textDarkSlate,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Espace disponible :',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMutedSlate,
                        ),
                      ),
                      Text(
                        availableStr,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.errorRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Espace minimal requis :',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMutedSlate,
                        ),
                      ),
                      Text(
                        '1.50 Go',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryRoyalBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Veuillez libérer de l\'espace sur votre stockage interne (suppression de photos, vidéos ou applications inutilisées) puis réessayez.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMutedSlate,
                height: 1.3,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRoyalBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _isStorageAlertShowing = false;
              context.read<ModelManagerCubit>().dismissDiskSpaceAlert();
            },
            child: const Text('Compris'),
          ),
        ],
      ),
    ).then((_) {
      _isStorageAlertShowing = false;
      context.read<ModelManagerCubit>().dismissDiskSpaceAlert();
    });
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 Mo';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1000) {
      final gb = mb / 1024;
      return '${gb.toStringAsFixed(2)} Go';
    }
    return '${mb.toStringAsFixed(0)} Mo';
  }

  void _navigateToChat() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const TeacherChatScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: Navigator.of(context).canPop()
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: const Text(
                'Gestion des Modèles',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDarkSlate,
                ),
              ),
              leading: IconButton(
                icon:
                    const Icon(Icons.arrow_back, color: AppTheme.textDarkSlate),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: SafeArea(
        child: BlocConsumer<ModelManagerCubit, ModelManagerState>(
          listener: (context, state) {
            if (state.isDiskSpaceInsufficient) {
              _showInsufficientStorageDialog(
                context,
                state.availableDiskSpaceBytes,
              );
            }
            if (state.errorMessage != null && !state.isDiskSpaceInsufficient) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: AppTheme.errorRed,
                ),
              );
            }
            if (state.infoMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.infoMessage!),
                  backgroundColor: AppTheme.statusOfflineGreen,
                ),
              );
            }
          },
          builder: (context, state) {
            final overallProgress = state.overallProgress;
            final isReady = state.areAllModelsReady;
            final isDownloading = state.isDownloadingAny;
            final isImporting = state.isImporting;

            return Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // En-tête avec Logo et Badge Hors-Ligne
                    Center(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppTheme.cardSurface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: AppTheme.dividerColor, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryRoyalBlue
                                  .withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          AppConstants.logoAssetPath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.school_rounded,
                            size: 48,
                            color: AppTheme.primaryRoyalBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Titre & Sous-titre
                    const Text(
                      AppConstants.appName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textDarkSlate,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Assistant IA pédagogique 100 % autonome et hors ligne pour le primaire.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textMutedSlate,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Carte d'état des modèles IA
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isReady
                                          ? Icons.check_circle_rounded
                                          : Icons.memory_rounded,
                                      color: isReady
                                          ? AppTheme.statusOfflineGreen
                                          : AppTheme.primaryRoyalBlue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isReady
                                          ? 'Modèles prêts pour utilisation'
                                          : 'Installation des modèles IA',
                                      style: const TextStyle(
                                        color: AppTheme.textDarkSlate,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isReady
                                        ? AppTheme.statusOfflineGreenLight
                                        : AppTheme.primaryRoyalBlueLight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isReady
                                        ? 'Actif'
                                        : '${(overallProgress * 100).toStringAsFixed(0)} %',
                                    style: TextStyle(
                                      color: isReady
                                          ? AppTheme.statusOfflineGreen
                                          : AppTheme.primaryRoyalBlue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Barre de progression globale
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: isReady ? 1.0 : overallProgress,
                                minHeight: 10,
                                backgroundColor: AppTheme.scaffoldBackground,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isReady
                                      ? AppTheme.statusOfflineGreen
                                      : AppTheme.primaryRoyalBlue,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Détail des volumes
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isImporting
                                      ? 'Copie locale en cours...'
                                      : (isDownloading
                                          ? 'Téléchargement avec reprise...'
                                          : (isReady
                                              ? 'Stockage local validé'
                                              : 'Volume total requis : ~1.23 Go')),
                                  style: const TextStyle(
                                    color: AppTheme.textMutedSlate,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${_formatBytes(state.totalCurrentBytes)} / ${_formatBytes(state.totalExpectedBytes)}',
                                  style: const TextStyle(
                                    color: AppTheme.textDarkSlate,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(
                                height: 28, color: AppTheme.dividerColor),

                            // Modèle 1 : LLM
                            _buildModelRow(
                              title: 'LLM : Qwen 2.5 1.5B (Génération)',
                              sizeText: '~1.1 Go',
                              status: state
                                  .modelsStatus[AppConstants.llmModelFileName],
                            ),
                            const SizedBox(height: 12),

                            // Modèle 2 : Embedding
                            _buildModelRow(
                              title: 'Vecteurs : Multilingual E5 (RAG 384d)',
                              sizeText: '~130 Mo',
                              status: state.modelsStatus[
                                  AppConstants.embeddingModelFileName],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bouton Principal "Continuer" ou "Télécharger les modèles"
                    ElevatedButton(
                      onPressed: isImporting
                          ? null
                          : (isReady
                              ? _navigateToChat
                              : () {
                                  if (isDownloading) {
                                    context
                                        .read<ModelManagerCubit>()
                                        .pauseDownload();
                                  } else {
                                    context
                                        .read<ModelManagerCubit>()
                                        .startDownload();
                                  }
                                }),
                      child: Text(
                        isReady
                            ? 'Continuer vers le Compagnon'
                            : (isDownloading
                                ? 'Mettre en pause'
                                : 'Télécharger les modèles (~1.23 Go)'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Bouton Secondaire "Importer depuis Xender / Carte SD"
                    OutlinedButton.icon(
                      onPressed: isImporting
                          ? null
                          : () => context
                              .read<ModelManagerCubit>()
                              .importLocalFile(),
                      icon: isImporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.folder_open_rounded, size: 20),
                      label: Text(
                        isImporting
                            ? 'Importation (${(state.importProgress * 100).toStringAsFixed(0)} %)...'
                            : 'Importer depuis Xender / Carte SD',
                      ),
                    ),

                    if (!isReady) ...[
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: _navigateToChat,
                        child: const Text(
                          'Accéder directement (Mode Démo / Test)',
                          style: TextStyle(
                            color: AppTheme.textMutedSlate,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    // Note d'information pour milieu rural
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.dividerColor),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppTheme.primaryRoyalBlue,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Astuce zone rurale : demandez à un collègue ayant déjà l\'application de vous transférer les fichiers .gguf via Xender pour économiser vos données internet.',
                              style: TextStyle(
                                color: AppTheme.textMutedSlate,
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModelRow({
    required String title,
    required String sizeText,
    required ModelFileStatus? status,
  }) {
    final isReady = status?.isReady ?? false;
    final isDownloading = status?.state == ModelDownloadState.downloading;
    final isError = status?.state == ModelDownloadState.error;

    return Row(
      children: [
        Icon(
          isReady
              ? Icons.check_circle_rounded
              : (isError
                  ? Icons.error_outline_rounded
                  : (isDownloading
                      ? Icons.downloading_rounded
                      : Icons.radio_button_unchecked_rounded)),
          size: 18,
          color: isReady
              ? AppTheme.statusOfflineGreen
              : (isError
                  ? AppTheme.errorRed
                  : (isDownloading
                      ? AppTheme.primaryRoyalBlue
                      : AppTheme.textMutedSlate)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textDarkSlate,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                isError && status?.errorMessage != null
                    ? status!.errorMessage!
                    : sizeText,
                maxLines: 2,
                style: TextStyle(
                  color: isError ? AppTheme.errorRed : AppTheme.textMutedSlate,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Text(
          isReady
              ? 'Prêt'
              : (isError
                  ? 'Erreur'
                  : (isDownloading
                      ? '${((status?.progress ?? 0) * 100).toStringAsFixed(0)} %'
                      : 'En attente')),
          style: TextStyle(
            color: isReady
                ? AppTheme.statusOfflineGreen
                : (isError
                    ? AppTheme.errorRed
                    : (isDownloading
                        ? AppTheme.primaryRoyalBlue
                        : AppTheme.textMutedSlate)),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
