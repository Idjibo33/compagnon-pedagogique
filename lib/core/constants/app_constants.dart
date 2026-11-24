class AppConstants {
  AppConstants._();

  // Nom de l'application
  static const String appName = 'Compagnon Pédagogique';
  static const String appTagline = 'Assistant IA 100% Hors Ligne';

  // Noms des modèles GGUF
  static const String llmModelFileName = 'qwen2.5-1.5b-instruct-q4_k_m.gguf';
  static const String embeddingModelFileName =
      'multilingual-e5-small-q8_0.gguf';

  // Tailles approximatives des modèles en octets
  static const int llmModelExpectedSize = 1180000000; // ~1.1 Go
  static const int embeddingModelExpectedSize = 135000000; // ~130 Mo
  static const int totalModelsExpectedSize =
      llmModelExpectedSize + embeddingModelExpectedSize; // ~1.23 Go

  // URLs de téléchargement direct Hugging Face avec support de reprise (Range request)
  static const String llmModelDownloadUrl =
      'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf';
  static const String embeddingModelDownloadUrl =
      'https://huggingface.co/cstr/multilingual-e5-small-GGUF/resolve/main/multilingual-e5-small-q8_0.gguf';

  // Dimensions des vecteurs de plongement (embedding)
  static const int embeddingDimension = 384;

  // Chemins d'assets
  static const String logoAssetPath = 'assets/images/logo.png';
  static const String databaseAssetPath = 'assets/db/programmes_scolaires.db';
  static const String databaseFileName = 'programmes_scolaires.db';

  // Dossiers sous-jacents
  static const String modelsDirectoryName = 'models';
  static const String pdfsDirectoryName = 'fiches_pdf';

  // Suggestions rapides au lancement du chat
  static const List<String> chatQuickSuggestions = [
    'Préparer une fiche de cours sur les fractions (CM1)',
    'Créer des exercices corrigés d\'accord sujet-verbe (CM1/CM2)',
    'Idée d\'activité en autonomie pour classe double niveau (CE1-CE2)',
  ];
}
