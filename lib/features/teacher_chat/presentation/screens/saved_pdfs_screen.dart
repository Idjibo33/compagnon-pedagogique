import 'dart:io';

import 'package:compagnon_pedagogique/core/theme/app_theme.dart';
import 'package:compagnon_pedagogique/core/utils/pdf_exporter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

enum PdfDateFilter { all, today, thisWeek }

class SavedPdfsScreen extends StatefulWidget {
  final List<File>? initialFiles;
  final Future<List<File>> Function()? pdfLoader;
  final Future<void> Function(File file)? pdfOpener;

  const SavedPdfsScreen({
    super.key,
    this.initialFiles,
    this.pdfLoader,
    this.pdfOpener,
  });

  @override
  State<SavedPdfsScreen> createState() => _SavedPdfsScreenState();
}

class _SavedPdfsScreenState extends State<SavedPdfsScreen> {
  late List<File> _pdfFiles;
  late bool _isLoading;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  PdfDateFilter _selectedFilter = PdfDateFilter.all;

  @override
  void initState() {
    super.initState();
    _pdfFiles = widget.initialFiles ?? [];
    _isLoading = widget.initialFiles == null;
    if (_isLoading) {
      _loadPdfs();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPdfs() async {
    setState(() => _isLoading = true);
    final files = await (widget.pdfLoader ?? PdfExporter.listSavedPdfs)();
    if (mounted) {
      setState(() {
        _pdfFiles = files;
        _isLoading = false;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  String _formatFileDate(DateTime date) {
    return DateFormat('dd/MM/yyyy à HH:mm').format(date);
  }

  String _getReadableTitle(File file) {
    final rawName = p.basenameWithoutExtension(file.path);
    final readableName = rawName
        .replaceAll(RegExp(r'^fiche_'), '')
        .replaceAll(RegExp(r'_\d{8}_\d{6}$'), '')
        .replaceAll('_', ' ')
        .trim();

    return readableName.isEmpty
        ? 'Fiche Pédagogique'
        : readableName[0].toUpperCase() + readableName.substring(1);
  }

  List<File> get _filteredPdfFiles {
    return _pdfFiles.where((file) {
      // 1. Filtre par recherche textuelle
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final rawName = p.basename(file.path).toLowerCase();
        final readableTitle = _getReadableTitle(file).toLowerCase();
        if (!rawName.contains(query) && !readableTitle.contains(query)) {
          return false;
        }
      }

      // 2. Filtre par date
      if (_selectedFilter != PdfDateFilter.all) {
        try {
          final modTime = file.lastModifiedSync();
          final now = DateTime.now();
          if (_selectedFilter == PdfDateFilter.today) {
            final isToday = modTime.year == now.year &&
                modTime.month == now.month &&
                modTime.day == now.day;
            if (!isToday) return false;
          } else if (_selectedFilter == PdfDateFilter.thisWeek) {
            final difference = now.difference(modTime);
            if (difference.inDays > 7 || difference.isNegative) return false;
          }
        } catch (_) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _openPdf(File file) async {
    try {
      if (widget.pdfOpener != null) {
        await widget.pdfOpener!(file);
        return;
      }
      final result = await PdfExporter.openPdf(file);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Impossible d\'ouvrir le fichier : ${result.message}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ouverture : $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _deletePdf(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer la fiche ?'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${p.basename(file.path)}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await PdfExporter.deletePdf(file);
      _loadPdfs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPdfFiles;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        title: const Text(
          'Fiches PDF Sauvegardées',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            onPressed: _loadPdfs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pdfFiles.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryRoyalBlueLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 40,
                            color: AppTheme.primaryRoyalBlue,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Aucune fiche PDF enregistrée',
                          style: TextStyle(
                            color: AppTheme.textDarkSlate,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Lorsque l\'assistant génère un cours ou exercice, cliquez sur le bouton "Exporter en PDF" pour retrouver vos fiches prêtes à imprimer ici.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textMutedSlate,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Barre de recherche et filtres
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() => _searchQuery = val);
                            },
                            decoration: InputDecoration(
                              hintText: 'Rechercher une fiche pédagogique...',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textMutedSlate,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: AppTheme.primaryRoyalBlue,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded,
                                          size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: const Color(0xFFF1F5F9),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('Toutes'),
                                  selected:
                                      _selectedFilter == PdfDateFilter.all,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() =>
                                          _selectedFilter = PdfDateFilter.all);
                                    }
                                  },
                                  selectedColor: AppTheme.primaryRoyalBlue,
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedFilter == PdfDateFilter.all
                                        ? Colors.white
                                        : AppTheme.textDarkSlate,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Aujourd\'hui'),
                                  selected:
                                      _selectedFilter == PdfDateFilter.today,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() => _selectedFilter =
                                          PdfDateFilter.today);
                                    }
                                  },
                                  selectedColor: AppTheme.primaryRoyalBlue,
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        _selectedFilter == PdfDateFilter.today
                                            ? Colors.white
                                            : AppTheme.textDarkSlate,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Cette semaine'),
                                  selected:
                                      _selectedFilter == PdfDateFilter.thisWeek,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() => _selectedFilter =
                                          PdfDateFilter.thisWeek);
                                    }
                                  },
                                  selectedColor: AppTheme.primaryRoyalBlue,
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedFilter ==
                                            PdfDateFilter.thisWeek
                                        ? Colors.white
                                        : AppTheme.textDarkSlate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Liste des fiches ou état vide de recherche
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.search_off_rounded,
                                      size: 48,
                                      color: AppTheme.textMutedSlate,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Aucune fiche trouvée',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textDarkSlate,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Modifiez vos termes de recherche ou réinitialisez les filtres.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMutedSlate,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton.icon(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                          _selectedFilter = PdfDateFilter.all;
                                        });
                                      },
                                      icon: const Icon(Icons.refresh_rounded,
                                          size: 16),
                                      label: const Text(
                                          'Réinitialiser les filtres'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final file = filtered[index];
                                DateTime modifiedDate = DateTime.now();
                                int fileSize = 0;
                                try {
                                  final stat = file.statSync();
                                  modifiedDate = stat.modified;
                                  fileSize = stat.size;
                                } catch (_) {}

                                final displayTitle = _getReadableTitle(file);

                                return InkWell(
                                  onTap: () => _openPdf(file),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFFFF),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFE8F1FD),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Icon(
                                                  Icons.picture_as_pdf_rounded,
                                                  color: Color(0xFF1A6FEE),
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      displayTitle,
                                                      style: const TextStyle(
                                                        color:
                                                            Color(0xFF0F172A),
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          _formatFileDate(
                                                              modifiedDate),
                                                          style:
                                                              const TextStyle(
                                                            color: Color(
                                                                0xFF64748B),
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        const Text(
                                                          '•',
                                                          style: TextStyle(
                                                            color: Color(
                                                                0xFF64748B),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Text(
                                                          _formatFileSize(
                                                              fileSize),
                                                          style:
                                                              const TextStyle(
                                                            color: Color(
                                                                0xFF64748B),
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Divider(
                                            height: 24,
                                            color: Color(0xFFE2E8F0),
                                          ),
                                          // Actions rapides : Ouvrir (open_filex) + Partager + Supprimer + Imprimer
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                tooltip:
                                                    'Partager (Bluetooth, Xender)',
                                                icon: const Icon(
                                                  Icons.share_outlined,
                                                  size: 20,
                                                ),
                                                color: const Color(0xFF64748B),
                                                onPressed: () =>
                                                    PdfExporter.sharePdf(file),
                                              ),
                                              IconButton(
                                                tooltip: 'Supprimer',
                                                icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 20,
                                                ),
                                                color: AppTheme.errorRed,
                                                onPressed: () =>
                                                    _deletePdf(file),
                                              ),
                                              const SizedBox(width: 4),
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      AppTheme.primaryRoyalBlue,
                                                  side: const BorderSide(
                                                    color: AppTheme
                                                        .primaryRoyalBlue,
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                ),
                                                onPressed: () => _openPdf(file),
                                                icon: const Icon(
                                                  Icons.visibility_outlined,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  'Ouvrir',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFF1A6FEE),
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    PdfExporter.printPdf(file),
                                                icon: const Icon(
                                                  Icons.print_rounded,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  'Ouvrir / Imprimer',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
