import 'package:compagnon_pedagogique/features/rag_engine/domain/document_chunk.dart';

/// Service helper transformant une liste d'extraits documentaires (DocumentChunk)
/// en un bloc de texte sourcé et structuré pour injection dans le prompt système Qwen 2.5.
class RagContextFormatter {
  const RagContextFormatter();

  /// Transforme les chunks en bloc de texte au format :
  /// [Source : Mathématiques CM1, p. 42] :
  /// <contenu de l'extrait>
  String format(List<DocumentChunk> chunks) {
    if (chunks.isEmpty) return '';

    final buffer = StringBuffer();
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      buffer.writeln(
        '[Source : ${chunk.matiere} ${chunk.niveau}, p. ${chunk.page}] :',
      );
      buffer.writeln(chunk.content.trim());
      if (i < chunks.length - 1) {
        buffer.writeln();
      }
    }
    return buffer.toString().trim();
  }
}
