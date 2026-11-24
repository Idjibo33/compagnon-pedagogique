import 'package:compagnon_pedagogique/features/rag_engine/domain/document_chunk.dart';

/// Contrat du référentiel pour le moteur RAG local hors ligne.
abstract class RagRepository {
  /// Initialise la base de données vectorielle locale en copiant l'asset si nécessaire,
  /// ouvrant la connexion SQLite et chargeant l'extension native sqlite_vec.
  Future<void> initialize();

  /// Alias de rétrocompatibilité pour initialize()
  Future<void> initializeDatabase();

  /// Recherche les extraits de programmes scolaires les plus pertinents pour la requête.
  /// Vectorise la requête utilisateur avec multilingual-e5-small (préfixe "query: "),
  /// et exécute la recherche KNN dans la table virtuelle vec_documents jointe à documents.
  Future<List<DocumentChunk>> searchRelevantChunks(
    String query, {
    int limit = 3,
  });

  /// Formate les extraits récupérés pour insertion dans le prompt système du LLM.
  String formatChunksForPrompt(List<DocumentChunk> chunks);

  /// Libère les ressources du modèle d'embedding et ferme la base de données.
  Future<void> dispose();
}
