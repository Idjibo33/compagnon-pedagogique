import 'package:compagnon_pedagogique/core/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConstants - URLs des modèles', () {
    test('le fichier servi par le LLM correspond au nom local attendu', () {
      final uri = Uri.parse(AppConstants.llmModelDownloadUrl);

      expect(uri.pathSegments.last, AppConstants.llmModelFileName);
    });

    test(
        'le fichier servi par le modèle vectoriel correspond au nom local attendu',
        () {
      final uri = Uri.parse(AppConstants.embeddingModelDownloadUrl);

      expect(uri.pathSegments.last, AppConstants.embeddingModelFileName);
    });
  });
}
