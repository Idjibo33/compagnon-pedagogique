import 'package:equatable/equatable.dart';

/// Entité représentant un extrait officiel de programme scolaire indexé dans le moteur RAG.
class DocumentChunk extends Equatable {
  final int id;
  final String niveau; // ex: CP, CE1, CE2, CM1, CM2, Cycle 2, Cycle 3
  final String matiere; // ex: Mathématiques, Français, Sciences, Pédagogie
  final int page; // Numéro de page dans le document officiel
  final String content; // Texte de l'extrait officiel
  final double distance; // Score de proximité / distance KNN (0.0 = identique)

  const DocumentChunk({
    required this.id,
    required this.niveau,
    required this.matiere,
    required this.page,
    required this.content,
    this.distance = 0.0,
  });

  /// Getters de rétrocompatibilité pour teacher_chat et edge_ai_llm_provider
  String get grade => niveau;
  String get subject => matiere;
  String get title => '$matiere $niveau (p. $page)';
  double get score => distance;

  /// Conversion vers Map SQLite / JSON
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'niveau': niveau,
      'matiere': matiere,
      'page': page,
      'content': content,
      'distance': distance,
    };
  }

  /// Création depuis une ligne de résultat SQLite
  factory DocumentChunk.fromMap(
    Map<String, dynamic> map, {
    double distance = 0.0,
  }) {
    return DocumentChunk(
      id: map['id'] as int? ?? 0,
      niveau: (map['niveau'] ?? map['grade'] ?? '') as String,
      matiere: (map['matiere'] ?? map['subject'] ?? '') as String,
      page: map['page'] as int? ?? 1,
      content: (map['content'] ?? '') as String,
      distance: (map['distance'] as num?)?.toDouble() ?? distance,
    );
  }

  @override
  List<Object?> get props => [
        id,
        niveau,
        matiere,
        page,
        content,
        distance,
      ];
}
