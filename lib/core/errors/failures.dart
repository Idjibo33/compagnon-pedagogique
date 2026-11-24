/// Erreurs métier manipulées sous forme de `Either<Failure, T>` / `TaskEither`.
///
/// Elles remplacent les exceptions brutes à la frontière entre la couche
/// `data` et la couche `presentation` : le Cubit peut ainsi afficher un
/// message explicite à l'utilisateur au lieu de perdre l'information.
sealed class Failure {
  const Failure(this.message);

  /// Message technique ou brut, utile pour les logs.
  final String message;

  /// Message destiné à l'utilisateur final (SnackBar, état du modèle...).
  String get displayMessage => message;
}

/// Échec lié au téléchargement d'un fichier de modèle (réseau, HTTP, ...).
class DownloadFailure extends Failure {
  const DownloadFailure(super.message, {this.fileName});

  /// Nom du fichier concerné, si connu.
  final String? fileName;

  @override
  String get displayMessage => fileName == null
      ? 'Échec du téléchargement : $message'
      : 'Échec du téléchargement de $fileName : $message';
}

/// Échec lié au système de fichiers local (lecture, écriture, copie...).
class StorageFailure extends Failure {
  const StorageFailure(super.message);

  @override
  String get displayMessage => 'Erreur de stockage local : $message';
}

/// Échec lié à l'import d'un fichier depuis Xender / la carte SD.
class ImportFailure extends Failure {
  const ImportFailure(super.message);

  @override
  String get displayMessage => 'Échec de l\'importation du fichier : $message';
}

/// Erreur inattendue, utilisée comme filet de sécurité par `TaskEither.tryCatch`.
class UnknownFailure extends Failure {
  const UnknownFailure(super.message);

  @override
  String get displayMessage => 'Une erreur inattendue est survenue : $message';
}

/// Convertit une exception brute en [Failure], sans encapsuler une erreur
/// métier déjà typée.
Failure toFailure(Object error, [String context = 'Opération impossible']) =>
    error is Failure ? error : UnknownFailure('$context : $error');
