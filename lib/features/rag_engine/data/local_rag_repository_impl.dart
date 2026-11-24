import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:compagnon_pedagogique/core/constants/app_constants.dart';
import 'package:compagnon_pedagogique/features/rag_engine/data/rag_context_formatter.dart';
import 'package:compagnon_pedagogique/features/rag_engine/domain/document_chunk.dart';
import 'package:compagnon_pedagogique/features/rag_engine/domain/rag_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_llama/flutter_edge_ai_llama.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqlite_vec/sqlite_vec.dart' as sqlite_vec;

/// Implémentation locale et 100% hors ligne du référentiel RAG (RagRepository).
/// Interroge la base vectorielle SQLite (programmes_scolaires.db) couplée à sqlite_vec
/// et au modèle d'embedding local multilingual-e5-small.
class LocalRagRepositoryImpl implements RagRepository {
  final RagContextFormatter _formatter;

  Database? _database;
  EmbeddingModel? _embeddingModel;
  bool _isInitialized = false;
  bool _isVectorExtensionLoaded = false;
  bool _isVectorTableReady = false;
  Completer<void>? _initCompleter;

  LocalRagRepositoryImpl({RagContextFormatter? formatter})
      : _formatter = formatter ?? const RagContextFormatter();

  /// Tente de charger l'extension native sqlite_vec via sqlite3_auto_extension
  void _loadSqliteVec() {
    if (_isVectorExtensionLoaded) return;
    try {
      final Pointer<Void> initFunc = sqlite_vec.vec0.lookup('sqlite3_vec_init');

      DynamicLibrary sqliteLib;
      try {
        sqliteLib = DynamicLibrary.process();
      } catch (_) {
        sqliteLib = Platform.isAndroid
            ? DynamicLibrary.open('libsqlite.so')
            : DynamicLibrary.process();
      }

      int Function(Pointer<Void>) autoExt;
      try {
        autoExt = sqliteLib.lookupFunction<Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)>('sqlite3_auto_extension');
      } catch (_) {
        final fallbackLib = DynamicLibrary.open(
            Platform.isAndroid ? 'libsqlite.so' : 'libsqlite3.so');
        autoExt = fallbackLib.lookupFunction<Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)>('sqlite3_auto_extension');
      }

      final rc = autoExt(initFunc);
      _isVectorExtensionLoaded = (rc == 0);
      debugPrint('[RAG Engine] sqlite_vec auto_extension registered (rc: $rc)');
    } catch (e) {
      debugPrint('[RAG Engine] sqlite_vec native loading skipped/fallback: $e');
      _isVectorExtensionLoaded = false;
    }
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized && _database != null) return;
    if (_initCompleter != null) return _initCompleter!.future;

    final completer = Completer<void>();
    _initCompleter = completer;

    try {
      // 1. Initialisation de l'extension native sqlite_vec
      _loadSqliteVec();

      // 2. Préparation du chemin de stockage local (getApplicationDocumentsDirectory)
      final appDir = await getApplicationDocumentsDirectory();
      final dbDir = Directory(appDir.path);
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }
      final dbPath = p.join(appDir.path, AppConstants.databaseFileName);

      // 3. Copie de l'asset pré-vectorisé au premier lancement si absent
      final dbFile = File(dbPath);
      if (!await dbFile.exists() || await dbFile.length() == 0) {
        try {
          final data = await rootBundle.load(AppConstants.databaseAssetPath);
          final bytes =
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          await dbFile.writeAsBytes(bytes, flush: true);
          debugPrint(
              '[RAG Engine] Base pré-remplie copiée avec succès vers $dbPath (${bytes.length} octets)');
        } catch (e) {
          debugPrint('[RAG Engine] Erreur chargement asset DB : $e');
        }
      }

      // 4. Ouverture de la base de données SQLite
      try {
        _database = await openDatabase(
          dbPath,
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS documents (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                niveau TEXT NOT NULL,
                matiere TEXT NOT NULL,
                page INTEGER NOT NULL,
                content TEXT NOT NULL
              )
            ''');
          },
        );

        // S'assurer que la table documents existe bien
        await _database!.execute('''
          CREATE TABLE IF NOT EXISTS documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            niveau TEXT NOT NULL,
            matiere TEXT NOT NULL,
            page INTEGER NOT NULL,
            content TEXT NOT NULL
          )
        ''');

        // Tenter la création de la table virtuelle KNN sqlite_vec
        if (_isVectorExtensionLoaded) {
          try {
            await _database!.execute('''
              CREATE VIRTUAL TABLE IF NOT EXISTS vec_documents USING vec0(
                id INTEGER PRIMARY KEY,
                embedding float[${AppConstants.embeddingDimension}]
              )
            ''');
            _isVectorTableReady = true;
            debugPrint('[RAG Engine] Table virtuelle vec_documents prête.');
          } catch (e) {
            debugPrint(
                '[RAG Engine] Création vec_documents échouée (fallback textuel actif): $e');
            _isVectorTableReady = false;
          }
        }
      } catch (e) {
        debugPrint('[RAG Engine] Erreur lors de l\'ouverture de la base : $e');
      }

      // 5. Chargement paresseux du modèle d'embedding si disponible
      await _tryLoadEmbeddingModel(appDir.path);

      _isInitialized = true;
      completer.complete();
    } catch (e) {
      debugPrint('[RAG Engine] Erreur lors de l\'initialisation : $e');
      _isInitialized = false;
      completer.complete();
    } finally {
      _initCompleter = null;
    }
  }

  @override
  Future<void> initializeDatabase() => initialize();

  /// Tente de charger le modèle d'embedding local multilingual-e5-small s'il est présent
  Future<void> _tryLoadEmbeddingModel(String appDirPath) async {
    if (_embeddingModel != null) return;

    try {
      final embPath = p.join(
        appDirPath,
        AppConstants.modelsDirectoryName,
        AppConstants.embeddingModelFileName,
      );
      final embFile = File(embPath);

      if (await embFile.exists() &&
          await embFile.length() >=
              (AppConstants.embeddingModelExpectedSize * 0.5)) {
        FlutterEdgeAi.initialize(
          embeddingBackends: const [LlamaEmbeddingBackend()],
        );

        final builder = FlutterEdgeAi.installEmbedder();
        builder.modelFromFile(embPath);
        await builder.install();

        _embeddingModel =
            await FlutterEdgeAiPlugin.instance.createEmbeddingModel();
        debugPrint('[RAG Engine] Modèle d\'embedding Multilingual-E5 chargé.');
      }
    } catch (e) {
      debugPrint('[RAG Engine] Modèle d\'embedding non disponible : $e');
      _embeddingModel = null;
    }
  }

  @override
  Future<List<DocumentChunk>> searchRelevantChunks(
    String query, {
    int limit = 3,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty || limit <= 0) return [];

    try {
      if (_database == null || !_isInitialized) {
        await initialize();
      }

      if (_database == null) return [];

      // 1. Tenter de charger le modèle d'embedding s'il vient d'être téléchargé
      if (_embeddingModel == null) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          await _tryLoadEmbeddingModel(appDir.path);
        } catch (_) {}
      }

      // 2. Recherche vectorielle KNN si le modèle d'embedding et la table vec0 sont prêts
      if (_isVectorTableReady && _embeddingModel != null) {
        final vectorResults = await _searchKnn(cleanQuery, limit);
        if (vectorResults.isNotEmpty) {
          return vectorResults;
        }
      }

      // 3. Fallback robuste : Recherche textuelle / BM25 avec pondération pédagogique
      return await _searchLexical(cleanQuery, limit);
    } catch (e) {
      debugPrint('[RAG Engine] Erreur lors de searchRelevantChunks : $e');
      return [];
    }
  }

  /// Recherche KNN native via sqlite_vec
  Future<List<DocumentChunk>> _searchKnn(String query, int limit) async {
    try {
      // Préfixe obligatoire pour les requêtes asymétriques E5 ("query: ")
      final e5Query = 'query: $query';
      final List<double> vector = await _embeddingModel!.embed(
        EmbeddingInput.text(e5Query),
        taskType: TaskType.retrievalQuery,
      );

      // Conversion en Float32List binaire
      final float32List = Float32List.fromList(vector);
      final binaryEmbedding = float32List.buffer.asUint8List(
        float32List.offsetInBytes,
        float32List.lengthInBytes,
      );

      final List<Map<String, dynamic>> results = await _database!.rawQuery(
        '''
        SELECT
          d.id,
          d.niveau,
          d.matiere,
          d.page,
          d.content,
          v.distance
        FROM vec_documents v
        JOIN documents d ON d.id = v.id
        WHERE v.embedding MATCH ? AND k = ?
        ORDER BY v.distance ASC
        ''',
        [binaryEmbedding, limit],
      );

      if (results.isNotEmpty) {
        return results
            .map((row) => DocumentChunk.fromMap(
                  row,
                  distance: (row['distance'] as num?)?.toDouble() ?? 0.0,
                ))
            .toList();
      }
    } catch (e) {
      debugPrint('[RAG Engine] KNN search exception: $e');
    }
    return [];
  }

  /// Recherche textuelle et lexicale robuste (Fallback si sqlite_vec ou modèle non prêt)
  Future<List<DocumentChunk>> _searchLexical(String query, int limit) async {
    final effectiveLimit = limit <= 0 ? 0 : limit;
    if (effectiveLimit == 0) return [];

    final db = _database;
    if (db == null) return [];

    final normalized = query.toLowerCase();

    // Mots vides en français
    const stopWords = {
      'le',
      'la',
      'les',
      'un',
      'une',
      'des',
      'de',
      'du',
      'en',
      'pour',
      'sur',
      'dans',
      'avec',
      'fais',
      'moi',
      'creer',
      'donne',
      'fiche',
      'cours',
      'comment',
      'faire',
      'qui',
      'que',
      'quoi',
      'est',
      'lesquels',
    };

    final tokens = normalized
        .replaceAll(RegExp(r'[^\w\sàâäéèêëîïôöùûüç]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2 && !stopWords.contains(t))
        .toList();

    // Détection de niveau scolaire (CM1, CM2, CE1, CE2, CP, Cycle 2, Cycle 3)
    String? detectedGrade;
    for (final grade in [
      'cm1',
      'cm2',
      'ce1',
      'ce2',
      'cp',
      'cycle 2',
      'cycle 3'
    ]) {
      if (normalized.contains(grade)) {
        detectedGrade = grade;
        break;
      }
    }

    // Récupération des documents (soit depuis documents, soit depuis chunks si présent)
    List<Map<String, dynamic>> records = [];
    try {
      records = await db.query('documents');
    } catch (_) {}

    if (records.isEmpty) {
      try {
        records = await db.query('chunks');
      } catch (_) {}
    }

    if (records.isEmpty) return [];

    final scoredList = <Map<String, dynamic>>[];

    for (final row in records) {
      final niveau =
          (row['niveau'] ?? row['grade'] ?? '').toString().toLowerCase();
      final matiere =
          (row['matiere'] ?? row['subject'] ?? '').toString().toLowerCase();
      final content = (row['content'] ?? '').toString().toLowerCase();
      final title = (row['title'] ?? '').toString().toLowerCase();

      double score = 0.0;

      // Bonus si le niveau scolaire correspond
      if (detectedGrade != null && niveau.contains(detectedGrade)) {
        score += 4.0;
      }

      // Pondération par terme
      for (final token in tokens) {
        if (title.contains(token)) score += 4.0;
        if (matiere.contains(token)) score += 3.0;
        if (content.contains(token)) score += 1.5;
      }

      if (score > 0) {
        scoredList.add({
          'chunk': DocumentChunk.fromMap(row, distance: 1.0 / (1.0 + score)),
          'score': score,
        });
      }
    }

    // Si aucune correspondance stricte, renvoyer les premiers documents par défaut
    if (scoredList.isEmpty) {
      return records
          .take(effectiveLimit)
          .map((row) => DocumentChunk.fromMap(row, distance: 1.0))
          .toList();
    }

    // Tri décroissant selon le score de pertinence
    scoredList
        .sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    return scoredList
        .take(effectiveLimit)
        .map((item) => item['chunk'] as DocumentChunk)
        .toList();
  }

  @override
  String formatChunksForPrompt(List<DocumentChunk> chunks) {
    return _formatter.format(chunks);
  }

  @override
  Future<void> dispose() async {
    try {
      await _embeddingModel?.close();
      _embeddingModel = null;
    } catch (_) {}

    try {
      await _database?.close();
      _database = null;
    } catch (_) {}

    _isInitialized = false;
  }
}
