import 'dart:io';
import 'package:compagnon_pedagogique/features/rag_engine/data/local_rag_repository_impl.dart';
import 'package:compagnon_pedagogique/features/rag_engine/data/rag_context_formatter.dart';
import 'package:compagnon_pedagogique/features/rag_engine/domain/document_chunk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path_provider for unit tests
  const MethodChannel pathChannel =
      MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
    if (methodCall.method == 'getApplicationDocumentsDirectory') {
      return Directory.systemTemp.path;
    }
    return null;
  });

  group('LocalRagRepositoryImpl Tests', () {
    late LocalRagRepositoryImpl repository;
    const formatter = RagContextFormatter();

    setUp(() {
      repository = LocalRagRepositoryImpl(formatter: formatter);
    });

    tearDown(() async {
      await repository.dispose();
    });

    test('formatChunksForPrompt should delegate to RagContextFormatter', () {
      const chunk = DocumentChunk(
        id: 1,
        niveau: 'CM1',
        matiere: 'Mathématiques',
        page: 42,
        content: 'Fractions',
      );
      final formatted = repository.formatChunksForPrompt([chunk]);
      expect(formatted, contains('[Source : Mathématiques CM1, p. 42] :'));
      expect(formatted, contains('Fractions'));
    });

    test(
        'searchRelevantChunks with empty or whitespace query returns empty list without error',
        () async {
      final resEmpty = await repository.searchRelevantChunks('');
      final resWhitespace = await repository.searchRelevantChunks('   ');

      expect(resEmpty, isEmpty);
      expect(resWhitespace, isEmpty);
    });

    test('searchRelevantChunks with zero or negative limit returns empty list',
        () async {
      final resZero =
          await repository.searchRelevantChunks('fractions', limit: 0);
      final resNegative =
          await repository.searchRelevantChunks('fractions', limit: -5);

      expect(resZero, isEmpty);
      expect(resNegative, isEmpty);
    });

    test('searchRelevantChunks handles emojis and special characters safely',
        () async {
      final results = await repository
          .searchRelevantChunks('📝 Préparer une fiche fractions !!! 💡');
      expect(results, isA<List<DocumentChunk>>());
    });

    test('initialize is idempotent and supports concurrent calls safely',
        () async {
      // Launch two concurrent initialize() calls
      await Future.wait([
        repository.initialize(),
        repository.initialize(),
      ]);
      // Subsequent call should also be safe
      await repository.initialize();
    });

    test('dispose can be called multiple times safely without throwing',
        () async {
      await repository.dispose();
      await repository.dispose();
    });
  });
}
