# Règles de Développement pour les Agents IA (Compagnon Pédagogique)

Ces règles sont strictement contraignantes pour tout agent intervenant sur ce référentiel.

---

## 1. Stack Technique Verrouillée
- **Framework :** Flutter (Stable) + Dart 3
- **State Management :** `flutter_bloc` (utiliser prioritairement `Cubit` pour sa simplicité et concision)
- **Dependency Injection :** `get_it` via `lib/core/di/injection_container.dart`
- **Inférence Locale :** `flutter_edge_ai` + `flutter_edge_ai_llama` (Modèle GGUF `qwen2.5-1.5b-instruct-q4_k_m.gguf`)
- **RAG & Vecteurs :** `sqlite_vec` + `sqflite` (Base `assets/db/programmes_scolaires.db`, Embedding `multilingual-e5-small-q8_0.gguf`, 384 dimensions)
- **Interface Chat :** `flutter_ai_toolkit` (`LlmChatView`)
- **Export :** `pdf` + `printing` + `open_filex` + `share_plus`
- **Ne jamais remplacer ni retirer ces dépendances sans accord explicite de l'utilisateur.**

---

## 2. Principes Architecturaux (Clean Architecture Feature-First)
Chaque fonctionnalité réside dans `lib/features/<nom_feature>/` avec son découpage strict :
- `data/` : Sources de données (SQLite, fichiers locaux, repositories d'implémentation, bridges).
- `domain/` : Entités pures et interfaces abstraites de repositories (aucune dépendance à Flutter UI).
- `presentation/` : Cubits/Blocs, écrans et widgets spécialisés.

### Principes transverses (`lib/core/`) :
- `constants/` : Constantes immuables (chemins, tailles attendues, prompts).
- `theme/` : Palette centralisée (Bleu Royal `#1A6FEE`, Blanc cassé `#F7F9FC`, Vert émeraude `#16A34A`).
- `utils/` : Utilitaires réutilisables (exportateur PDF, formatters).
- `di/` : Enregistrement GetIt ordonné (Singletons et Factories).

---

## 3. Contraintes d'Usage & Spécificités Rurales
- **Zéro dépendance au Cloud :** L'application doit fonctionner à 100% sans connectivité internet une fois les modèles ou la base installés.
- **Sobriété mémoire :** Ne pas charger de fichiers lourds entièrement en mémoire RAM. Toujours privilégier les flux (`Stream<List<int>>`) lors de la copie ou du streaming de tokens.
- **Résilience :** Toujours prévoir un fallback robuste (par ex. recherche textuelle/lexicale si l'extension vectorielle native est en cours d'initialisation).
- **Simplicité UI :** Maintenir les 3 écrans uniques sans surcharger de menus, formulaires complexes ou sous-arborescences.

---

## 4. Standards de Code
- Formatter systématiquement le code avec `dart format`.
- Utiliser `const` partout où c'est possible pour préserver les performances de rendu.
- Tout nouveau composant doit être documenté avec des commentaires clairs en français.
