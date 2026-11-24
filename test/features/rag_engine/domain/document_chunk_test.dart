import 'package:compagnon_pedagogique/features/rag_engine/domain/document_chunk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentChunk Entity Tests', () {
    const chunk = DocumentChunk(
      id: 1,
      niveau: 'CM1',
      matiere: 'Mathématiques',
      page: 42,
      content: 'Contenu sur les fractions simples.',
      distance: 0.12,
    );

    test('should hold all specified domain fields', () {
      expect(chunk.id, equals(1));
      expect(chunk.niveau, equals('CM1'));
      expect(chunk.matiere, equals('Mathématiques'));
      expect(chunk.page, equals(42));
      expect(chunk.content, equals('Contenu sur les fractions simples.'));
      expect(chunk.distance, equals(0.12));
    });

    test('should support backward compatibility getters', () {
      expect(chunk.grade, equals('CM1'));
      expect(chunk.subject, equals('Mathématiques'));
      expect(chunk.title, equals('Mathématiques CM1 (p. 42)'));
      expect(chunk.score, equals(0.12));
    });

    test('should properly serialize toMap and deserialize fromMap', () {
      final map = chunk.toMap();
      expect(map['id'], equals(1));
      expect(map['niveau'], equals('CM1'));
      expect(map['matiere'], equals('Mathématiques'));
      expect(map['page'], equals(42));
      expect(map['content'], equals('Contenu sur les fractions simples.'));
      expect(map['distance'], equals(0.12));

      final deserialized = DocumentChunk.fromMap(map);
      expect(deserialized, equals(chunk));
    });

    test('should handle legacy keys in fromMap (grade, subject)', () {
      final legacyMap = {
        'id': 2,
        'grade': 'CM2',
        'subject': 'Français',
        'page': 15,
        'content': 'Grammaire',
      };
      final fromLegacy = DocumentChunk.fromMap(legacyMap, distance: 0.45);
      expect(fromLegacy.id, equals(2));
      expect(fromLegacy.niveau, equals('CM2'));
      expect(fromLegacy.matiere, equals('Français'));
      expect(fromLegacy.page, equals(15));
      expect(fromLegacy.distance, equals(0.45));
    });

    test('equatable value equality holds', () {
      const chunkA = DocumentChunk(
        id: 1,
        niveau: 'CE1',
        matiere: 'Calcul',
        page: 5,
        content: 'Addition',
        distance: 0.1,
      );
      const chunkB = DocumentChunk(
        id: 1,
        niveau: 'CE1',
        matiere: 'Calcul',
        page: 5,
        content: 'Addition',
        distance: 0.1,
      );
      expect(chunkA, equals(chunkB));
    });
  });
}
