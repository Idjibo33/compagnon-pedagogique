# Journal des Tâches & Statut du Projet

## Jalons

- [x] Initialisation de la structure Clean Architecture (Feature-First)
- [x] Définition des constantes et templates de prompt Qwen 2.5 (`lib/core/constants/`)
- [x] Configuration du Design System EdTech Lumineux & Direct (`lib/core/theme/`)
- [x] Implémentation du moteur d'export PDF avec prévisualisation et partage (`lib/core/utils/pdf_exporter.dart`)
- [x] Module `model_manager` avec `background_downloader` et `file_picker` pour Xender / SD
- [x] Module `rag_engine` avec `sqlite_vec` / `sqflite` et base `programmes_scolaires.db`
- [x] Intégration `flutter_ai_toolkit` via `EdgeAiLlmProvider`
- [x] Écran 1 : `ModelSetupScreen`
- [x] Écran 2 : `TeacherChatScreen` avec suggestions et export PDF
- [x] Écran 3 : `SavedPdfsScreen` avec historique, impression et partage
- [x] Configuration des plateformes natives (`android/` avec permissions stockage & services)
- [x] Mise en place de l'espace de développement pour agents IA (`.agent/` et `AGENTS.md`)
- [x] Suite de tests d'intégration End-to-End (`integration_test/app_e2e_test.dart` & `test_driver/`)
- [x] **Phase 1 : Dynamisme Réactif UI & Expérience Terrain Rural**
  - [x] Machine d'état réactive `GenerationPhase` (`idle`, `clarifying`, `retrievingCurriculum`, `loadingModel`, `streamingTokens`, `completed`, `error`) dans `EdgeAiLlmProvider`
  - [x] Indicateur d'état de génération compact & animé `GenerationStateIndicator` (sans layout shift, radius 16px, `#E8F1FD`, `#BFDBFE`)
  - [x] Mode streaming réactif avec curseur respiratoire `▋` teinté en Bleu Royal `#1A6FEE` et isolation des balises Markdown/LaTeX dans `MarkdownAnswerView`
  - [x] Puces de cadrage pédagogique interactives Zéro Clavier (`ActionChip`) au-dessus de la saisie
  - [x] Retours haptiques sensoriels (`HapticFeedback` léger, impulsion premier token, complétion et export PDF)
  - [x] Élimination du layout shift de 38px & Pastille Sources RAG compacte dans l'AppBar avec feuille modale
  - [x] Barre d'actions finales animée `FinalActionsBar` (200ms slide/fade, export PDF, copier le texte avec coche verte temporaire)
  - [x] Commutateur Mode Plein Soleil (WCAG AAA) avec contraste renforcé pour forte luminosité rurale
- [x] **Phase 2 : Robustesse, Stockage & Consolidation DX**
  - [x] Contrôle pré-vol de l'espace disque (vérification >= 1.5 Go via `statvfs` FFI, blocage et affichage d'une alerte claire `AlertDialog` avant téléchargement et import)
  - [x] Validation stricte du Magic Number GGUF (`0x47 0x47 0x55 0x46` = "GGUF") dès la sélection/importation via Xender/SD avant toute copie
  - [x] Suppression de `android.permission.MANAGE_EXTERNAL_STORAGE` et de `requestLegacyExternalStorage="true"` dans AndroidManifest.xml (conformité Google Play sans impact SAF)
  - [x] Export public miroir des fiches PDF dans `Documents/CompagnonPedagogique/` pour faciliter l'extraction USB sur PC sans explorateur root
  - [x] Amélioration de `SavedPdfsScreen` : recherche textuelle en temps réel, filtres par date ("Toutes", "Aujourd'hui", "Cette semaine"), réinitialisation et ouverture directe avec `open_filex` en plus du partage/impression
  - [x] Assainissement de `packages/sqlite_vec` : référence locale directe dans `pubspec.yaml` sans override, script de build reproductible Clang NDK `scripts/build_sqlite_vec.sh`, et documentation `packages/sqlite_vec/README.md`
  - [x] Validation de la suite de tests (73 tests réussis) et `flutter analyze` sans aucun avertissement
- [x] **Durcissement & Revue Phase 2 :**
  - [x] Correction UX alerte espace disque : suppression du pop-up bloquant intempestif quand les modèles sont déjà installés, et élimination de la SnackBar d'erreur fantôme lors de la fermeture de l'alerte
  - [x] Robustesse `SystemDiskSpaceChecker` : résolution des chemins non existants vers le répertoire ancêtre existant
  - [x] Intégrité de copie GGUF : écriture atomique sur fichier temporaire `.tmp` et rollback/nettoyage en cas d'erreur de transfert
  - [x] Gestion miroir et nettoyage des PDF : suppression coordonnée dans le stockage interne et public, désactivation des avertissements de polices Helvetica via assainissement emoji
  - [x] Optimisation de l'ouverture PDF : résolution prioritaire de la copie publique `Documents/CompagnonPedagogique/` pour compatibilité maximale avec les visionneuses tierces sans restrictions SAF

## Statut Final - Validation Complète (Mission 1, 2, 3, E2E & Phase 1 - Revue et Durcissement)
- **Durcissement Phase 1 :**
  - Reconnaissance didactique multigrade : intégration stricte de `Double niveau` / `multi-niveau` / `cours double` / `classe double` dans le filtrage d'étapes pour éviter les répétitions de questions.
  - Détection fiabilisée des questions de cadrage : exclusion absolue des fiches d'exercices se terminant par un point d'interrogation.
  - Masquage de la barre d'actions finales lors des messages d'erreur du modèle.
  - Support intégral WCAG AAA Plein Soleil sur `GenerationStateIndicator` et bordures contrastées de `FinalActionsBar`.
  - Élimination des doublons de titres `#` et préservation du sous-titre didactique dans `MarkdownAnswerView`.
  - Correction grammaticale de la pastille RAG dans l'AppBar (`1 source` / `X sources`).
- **Formatage du code :** 100% conforme `dart format lib/ test/`.
- **Compatibilité 100% Hors Ligne :** Polices et modèles GGUF embarqués/gérés localement sans requête internet requise.
