import 'dart:io';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_constants.dart';
import 'emoji_sanitizer.dart';

class PdfExporter {
  PdfExporter._();

  /// Répertoire local interne où sont stockées les fiches PDF
  static Future<Directory> getPdfStorageDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final pdfDir =
        Directory(p.join(appDocDir.path, AppConstants.pdfsDirectoryName));
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return pdfDir;
  }

  /// Répertoire public pour l'exportation des fiches PDF (accessible via USB sur PC sans root).
  /// Sur Android : Documents/CompagnonPedagogique/
  /// Sur desktop/test : Documents/CompagnonPedagogique/
  static Future<Directory?> getPublicDocumentsDirectory() async {
    if (Platform.isAndroid) {
      // 1. Dossier public standard /storage/emulated/0/Documents/CompagnonPedagogique
      final primary = Directory(
        p.join('/storage/emulated/0/Documents',
            AppConstants.publicPdfDirectoryName),
      );
      try {
        if (!await primary.exists()) {
          await primary.create(recursive: true);
        }
        return primary;
      } catch (_) {
        // Fallback vers le stockage externe de l'application
        try {
          final extDirs = await getExternalStorageDirectories(
            type: StorageDirectory.documents,
          );
          if (extDirs != null && extDirs.isNotEmpty) {
            final appExtDoc = Directory(
              p.join(extDirs.first.path, AppConstants.publicPdfDirectoryName),
            );
            if (!await appExtDoc.exists()) {
              await appExtDoc.create(recursive: true);
            }
            return appExtDoc;
          }
        } catch (_) {}
      }
    } else {
      // Linux, macOS, Windows ou environnement de test
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        final publicDoc = Directory(
          p.join(
            appDocDir.path,
            'Documents',
            AppConstants.publicPdfDirectoryName,
          ),
        );
        if (!await publicDoc.exists()) {
          await publicDoc.create(recursive: true);
        }
        return publicDoc;
      } catch (_) {}
    }
    return null;
  }

  /// Génère une fiche pédagogique PDF stylisée à partir d'un prompt et d'une réponse de l'IA
  static Future<File> generatePedagogicalPdf({
    required String title,
    required String content,
    String? teacherQuery,
  }) async {
    final pdf = pw.Document();
    final currentDate = DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now());

    // Assainissement des emojis pour compatibilité stricte polices PDF (Helvetica)
    final cleanTitle = stripEmojis(title);
    final cleanContent = stripEmojis(content);
    final cleanQuery = teacherQuery != null ? stripEmojis(teacherQuery) : null;

    // Découpage propre du contenu en paragraphes
    final paragraphs = cleanContent.split('\n');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.blue800, width: 1.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 10,
                      height: 10,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.green700,
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Text(
                      'Compagnon Pédagogique (Hors Ligne)',
                      style: const pw.TextStyle(
                        color: PdfColors.blue900,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  'Généré le $currentDate',
                  style: const pw.TextStyle(
                    color: PdfColors.grey700,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Fiche Pédagogique Conforme aux Programmes Officiels',
                  style: const pw.TextStyle(
                    color: PdfColors.grey600,
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} sur ${context.pagesCount}',
                  style: const pw.TextStyle(
                    color: PdfColors.grey700,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 10),
            // Titre principal
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.blue200, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    cleanTitle.isEmpty ? 'Fiche Pédagogique' : cleanTitle,
                    style: const pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  if (cleanQuery != null && cleanQuery.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Demande de l\'enseignant : "$cleanQuery"',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Contenu de la fiche
            ...paragraphs.map((line) {
              final trimmed = line.trim();
              if (trimmed.isEmpty) {
                return pw.SizedBox(height: 6);
              }

              // Détection des en-têtes markdown (###, ##, #)
              if (trimmed.startsWith('#')) {
                final headerText = trimmed.replaceAll(RegExp(r'^#+\s*'), '');
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
                  child: pw.Text(
                    headerText,
                    style: const pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                );
              }

              // Puces markdown
              if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 12, bottom: 3),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 4,
                        height: 4,
                        margin: const pw.EdgeInsets.only(top: 4, right: 6),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.blue800,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          trimmed.substring(2),
                          style: const pw.TextStyle(
                            fontSize: 10,
                            lineSpacing: 1.3,
                            color: PdfColors.grey900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Paragraphe standard
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Text(
                  trimmed,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    lineSpacing: 1.4,
                    color: PdfColors.grey900,
                  ),
                ),
              );
            }),
          ];
        },
      ),
    );

    // Enregistrement dans le répertoire de stockage
    final dir = await getPdfStorageDirectory();
    final sanitizedTitle =
        title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_').toLowerCase();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'fiche_${sanitizedTitle.takeSafe(25)}_$timestamp.pdf';
    final file = File(p.join(dir.path, fileName));

    final pdfBytes = await pdf.save();
    await file.writeAsBytes(pdfBytes);

    // Export public miroir dans Documents/CompagnonPedagogique/ pour extraction USB
    try {
      final publicDir = await getPublicDocumentsDirectory();
      if (publicDir != null) {
        final publicFile = File(p.join(publicDir.path, fileName));
        await publicFile.writeAsBytes(pdfBytes);
      }
    } catch (_) {
      // Le fichier principal dans getPdfStorageDirectory() reste disponible
    }

    return file;
  }

  /// Ouvre directement le fichier PDF avec l'application par défaut (via open_filex).
  /// Tente en priorité d'ouvrir la copie publique si disponible pour une compatibilité
  /// maximale avec les visualiseurs tiers sur Android 11+ sans restrictions de bac à sable.
  static Future<OpenResult> openPdf(File file) async {
    try {
      final publicDir = await getPublicDocumentsDirectory();
      if (publicDir != null) {
        final publicFile = File(p.join(publicDir.path, p.basename(file.path)));
        if (await publicFile.exists()) {
          final res = await OpenFilex.open(publicFile.path);
          if (res.type == ResultType.done) {
            return res;
          }
        }
      }
    } catch (_) {}
    return await OpenFilex.open(file.path);
  }

  /// Supprime une fiche PDF du stockage interne ainsi que sa copie miroir publique
  static Future<void> deletePdf(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
    try {
      final publicDir = await getPublicDocumentsDirectory();
      if (publicDir != null) {
        final publicFile = File(p.join(publicDir.path, p.basename(file.path)));
        if (await publicFile.exists()) {
          await publicFile.delete();
        }
      }
    } catch (_) {}
  }

  /// Exporte ou copie explicitement une fiche dans le répertoire public
  static Future<File?> copyToPublicDocuments(File file) async {
    try {
      final publicDir = await getPublicDocumentsDirectory();
      if (publicDir == null) return null;
      final targetFile = File(p.join(publicDir.path, p.basename(file.path)));
      return await file.copy(targetFile.path);
    } catch (_) {
      return null;
    }
  }

  /// Partager le PDF via Bluetooth, Xender, etc.
  static Future<void> sharePdf(File file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Fiche pédagogique générée par le Compagnon Pédagogique',
      ),
    );
  }

  /// Imprimer directement la fiche
  static Future<void> printPdf(File file) async {
    final bytes = await file.readAsBytes();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: p.basename(file.path),
    );
  }

  /// Liste tous les PDF enregistrés
  static Future<List<File>> listSavedPdfs() async {
    final dir = await getPdfStorageDirectory();
    if (!await dir.exists()) return [];

    final entities = dir.listSync();
    final pdfFiles = entities
        .whereType<File>()
        .where((file) => file.path.endsWith('.pdf'))
        .toList();

    // Tri décroissant par date de dernière modification
    pdfFiles
        .sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return pdfFiles;
  }
}

extension on String {
  String takeSafe(int count) {
    if (length <= count) return this;
    return substring(0, count);
  }
}
