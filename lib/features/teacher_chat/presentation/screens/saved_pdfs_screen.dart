import 'dart:io';

import 'package:compagnon_pedagogique/core/theme/app_theme.dart';
import 'package:compagnon_pedagogique/core/utils/pdf_exporter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

class SavedPdfsScreen extends StatefulWidget {
  final List<File>? initialFiles;
  final Future<List<File>> Function()? pdfLoader;

  const SavedPdfsScreen({
    super.key,
    this.initialFiles,
    this.pdfLoader,
  });

  @override
  State<SavedPdfsScreen> createState() => _SavedPdfsScreenState();
}

class _SavedPdfsScreenState extends State<SavedPdfsScreen> {
  late List<File> _pdfFiles;
  late bool _isLoading;

  @override
  void initState() {
    super.initState();
    _pdfFiles = widget.initialFiles ?? [];
    _isLoading = widget.initialFiles == null;
    if (_isLoading) {
      _loadPdfs();
    }
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
      if (await file.exists()) {
        await file.delete();
      }
      _loadPdfs();
    }
  }

  @override
  Widget build(BuildContext context) {
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
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  itemCount: _pdfFiles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final file = _pdfFiles[index];
                    DateTime modifiedDate = DateTime.now();
                    int fileSize = 0;
                    try {
                      final stat = file.statSync();
                      modifiedDate = stat.modified;
                      fileSize = stat.size;
                    } catch (_) {}

                    final rawName = p.basenameWithoutExtension(file.path);
                    final readableName = rawName
                        .replaceAll(RegExp(r'^fiche_'), '')
                        .replaceAll(RegExp(r'_\d{8}_\d{6}$'), '')
                        .replaceAll('_', ' ')
                        .trim();

                    final displayTitle = readableName.isEmpty
                        ? 'Fiche Pédagogique'
                        : readableName[0].toUpperCase() +
                            readableName.substring(1);

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F1FD),
                                    borderRadius: BorderRadius.circular(12),
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
                                          color: Color(0xFF0F172A),
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            _formatFileDate(modifiedDate),
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            '•',
                                            style: TextStyle(
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatFileSize(fileSize),
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
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
                            // Actions rapides : Ouvrir/Imprimer & Supprimer (+ Partager)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  tooltip: 'Partager (Bluetooth, Xender)',
                                  icon: const Icon(
                                    Icons.share_outlined,
                                    size: 20,
                                  ),
                                  color: const Color(0xFF64748B),
                                  onPressed: () => PdfExporter.sharePdf(file),
                                ),
                                IconButton(
                                  tooltip: 'Supprimer',
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 20,
                                  ),
                                  color: AppTheme.errorRed,
                                  onPressed: () => _deletePdf(file),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A6FEE),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => PdfExporter.printPdf(file),
                                  icon: const Icon(
                                    Icons.print_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Ouvrir / Imprimer',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
