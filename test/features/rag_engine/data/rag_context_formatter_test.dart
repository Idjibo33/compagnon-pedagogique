import 'package:compagnon_pedagogique/features/rag_engine/data/rag_context_formatter.dart';
import 'package:compagnon_pedagogique/features/rag_engine/domain/document_chunk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RagContextFormatter Tests', () {
    const formatter = RagContextFormatter();

    test('should return empty string when chunk list is empty', () {
      final result = formatter.format([]);
      expect(result, isEmpty);
    });

    test('should format single chunk with proper source banner and page', () {
      const chunk = DocumentChunk(
        id: 1,
        niveau: 'CM1',
        matiere: 'Mathématiques',
        page: 42,
        content:
            'Les fractions simples. Comprendre et manipuler la notion de partage.',
        distance: 0.15,
      );

      final result = formatter.format([chunk]);
      expect(
        result,
        equals(
          '[Source : Mathématiques CM1, p. 42] :\n'
          'Les fractions simples. Comprendre et manipuler la notion de partage.',
        ),
      );
    });

    test('should format multiple chunks separated by blank lines', () {
      const chunk1 = DocumentChunk(
        id: 1,
        niveau: 'CM1',
        matiere: 'Mathématiques',
        page: 42,
        content: 'Fractions simples.',
      );
      const chunk2 = DocumentChunk(
        id: 2,
        niveau: 'CM2',
        matiere: 'Français',
        page: 22,
        content: 'Accord sujet-verbe.',
      );

      final result = formatter.format([chunk1, chunk2]);
      const expected = '[Source : Mathématiques CM1, p. 42] :\n'
          'Fractions simples.\n\n'
          '[Source : Français CM2, p. 22] :\n'
          'Accord sujet-verbe.';

      expect(result, equals(expected));
    });
  });
}
