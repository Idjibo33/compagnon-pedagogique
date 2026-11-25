# sqlite_vec (Module Local Compagnon Pédagogique)

Ce module fournit les liaisons Dart FFI pour l'extension SQLite `sqlite-vec`, permettant une recherche vectorielle rapide (similarité cosinus, produit scalaire) 100% hors-ligne au sein de l'application **Compagnon Pédagogique**.

---

## 1. Rôle dans l'Architecture RAG

Dans le cadre du pipeline RAG (Retrieval-Augmented Generation) du Compagnon Pédagogique :
- Les programmes scolaires officiels sont pré-encodés sous forme d'embeddings (384 dimensions générées par `multilingual-e5-small-q8_0.gguf`).
- La base SQLite locale `assets/db/programmes_scolaires.db` stocke ces vecteurs dans des tables virtuelles ou indexées `vec0`.
- L'extension native `libsqlite_vec.so` est chargée par SQLite lors de l'initialisation de `LocalRagRepositoryImpl`.
- Les requêtes de recherche utilisent la fonction vectorielle `vec_distance_cosine(embedding, ?)` pour identifier les 3 extraits didactiques les plus pertinents sans aucun appel réseau.

---

## 2. Structure des Fichiers

```text
packages/sqlite_vec/
├── lib/
│   └── sqlite_vec.dart        # Liaison FFI Dart (chargement dynamique de libsqlite_vec.so / .dll / .dylib)
├── pubspec.yaml               # Déclaration du package local
└── README.md                  # Cette documentation

android/app/src/main/jniLibs/
├── arm64-v8a/
│   └── libsqlite_vec.so       # Binaire natif 64-bit ARM (appareils Android récents)
├── armeabi-v7a/
│   └── libsqlite_vec.so       # Binaire natif 32-bit ARM (appareils Android d'entrée de gamme)
└── x86_64/
    └── libsqlite_vec.so       # Binaire natif x86_64 (émulateur Android)
```

---

## 3. Compilation Reproductible avec Clang NDK

Un script automatisé est disponible à la racine du projet : `scripts/build_sqlite_vec.sh`.

### Prérequis :
- Android NDK (version 24 ou supérieure).
- Variable d'environnement `ANDROID_NDK_HOME` définie, ou NDK installé dans le SDK Android standard (`~/Android/Sdk/ndk/...`).

### Exécution :
```bash
./scripts/build_sqlite_vec.sh
```

Le script :
1. Détecte automatiquement la version la plus récente du NDK installée.
2. Télécharge l'amalgamation officielle C `sqlite-vec.c` et `sqlite-vec.h` si nécessaire.
3. Compile les binaires partagés avec les drapeaux optimisés :
   `-O3 -fPIC -shared -std=c99 -Wall -Wextra`
4. Déploie automatiquement les fichiers `.so` compilés dans les répertoires `android/app/src/main/jniLibs/` cibles.

---

## 4. Intégration dans pubspec.yaml

Le projet principal référence directement ce package via un chemin local propre :

```yaml
dependencies:
  sqlite_vec:
    path: packages/sqlite_vec
```

Cette configuration garantit l'indépendance vis-à-vis des dépôts tiers et la reproductibilité complète des builds hors-ligne.
