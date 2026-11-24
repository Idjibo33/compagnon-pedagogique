# Compagnon Pédagogique 📱🏫

> **Assistant IA 100 % hors ligne (offline) pour les enseignants du primaire en milieu rural**, propulsé par des modèles d'IA générative locaux et les programmes scolaires officiels.

---

## 🌟 Points Forts & Valeur d'Usage

- **100 % Hors Ligne :** Zéro connexion internet requise en classe. Les inférences LLM et la recherche vectorielle (RAG) s'exécutent entièrement en local sur le processeur (NPU/CPU) du smartphone.
- **Conformité Pédagogique :** Le moteur RAG hybride (`sqlite_vec` + BM25) interroge directement la base locale `programmes_scolaires.db` pour garantir que chaque fiche respecte les progressions officielles (CP, CE1, CE2, CM1, CM2).
- **Sobriété & Réalité du Terrain :** Activités adaptées au matériel disponible (craie, ardoises, bâtonnets, matériel de récupération, gestion des classes à double niveau).
- **Export & Partage Sans Internet :** Génération instantanée de fiches PDF avec option d'impression ou d'échange direct entre collègues via **Xender / Bluetooth / Carte SD**.

---

## 🛠️ Stack Technique Verrouillée

- **Framework :** Flutter (Stable) + Dart
- **Architecture :** Clean Architecture (Feature-First) avec `flutter_bloc` (Cubit) et `get_it` (Injection de dépendances)
- **Interface Chat & Voix :** `flutter_ai_toolkit` (`LlmChatView`)
- **Moteur d'inférence IA local :** `flutter_edge_ai` + `flutter_edge_ai_llama`
- **Base Vectorielle (RAG) :** `sqlite_vec` + `sqflite` + `path_provider`
- **Téléchargement & Import local :** `background_downloader` (téléchargement avec reprise) + `file_picker` (import `.gguf` via Xender ou carte SD)
- **Export & Impression :** `pdf` + `printing` + `open_filex` + `share_plus`
- **Modèles embarqués (GGUF) :**
  - **LLM :** `qwen2.5-1.5b-instruct-q4_k_m.gguf` (~1.1 Go)
  - **Embedding :** `multilingual-e5-small-q8_0.gguf` (~130 Mo, 384 dimensions)

---

## 🎨 Design System ("EdTech Lumineux & Direct")

- **Fond principal :** Blanc cassé froid très doux `#F7F9FC`
- **Cartes & surfaces :** Blanc pur `#FFFFFF`, `BorderRadius.circular(20)`, élévation neutre
- **Couleur primaire :** Bleu Royal vif `#1A6FEE` (bulles utilisateur, boutons principaux, progression, badges)
- **Textes :** Ardoise foncé `#0F172A` (titres et corps), Gris doux `#64748B` (sous-titres)
- **Statut hors ligne :** Vert émeraude `#16A34A`

---

## 📱 Les 3 Écrans de l'Application

1. **`ModelSetupScreen` (Premier lancement / Paramètres) :**
   - Suivi visuel du stockage des modèles IA (`1.1 Go` + `130 Mo`).
   - Bouton principal : *Continuer* ou *Télécharger les modèles*.
   - Bouton secondaire : *Importer depuis Xender / Carte SD* (sans consommer de forfait 4G).
2. **`TeacherChatScreen` (Écran principal) :**
   - En-tête épuré avec logo, badge vert *100% Hors Ligne*, accès aux fiches et aux paramètres.
   - Suggestions rapides au démarrage (*Préparer une fiche de cours*, *Créer des exercices corrigés*, *Idée d'activité classe double*).
   - Corps propulsé par `LlmChatView` avec affichage des sources officielles RAG.
   - Bouton **"Exporter en PDF"** sous chaque réponse générée.
3. **`SavedPdfsScreen` (Historique des fiches) :**
   - Liste plate des fiches pédagogiques exportées.
   - Actions directes : Ouvrir, Imprimer, Partager (Bluetooth/Xender), Supprimer.

---

## 📂 Architecture des Dossiers (`lib/`)

```text
lib/
├── core/
│   ├── constants/
│   │   ├── app_constants.dart       # Noms des fichiers .gguf, dimensions vecteurs (384), chemins assets
│   │   └── prompt_templates.dart    # System prompt Qwen 2.5 (<|im_start|>system...)
│   ├── di/
│   │   └── injection_container.dart # Configuration GetIt (Singletons lazy pour le moteur IA)
│   ├── theme/
│   │   └── app_theme.dart           # ThemeData Material 3 (#F7F9FC, #FFFFFF, #1A6FEE)
│   └── utils/
│       └── pdf_exporter.dart        # Génération de fiches pédagogiques PDF propres
├── features/
│   ├── model_manager/
│   │   ├── data/                    # Stockage local, background_downloader, file_picker
│   │   ├── domain/                  # Entités ModelStatus & vérification fichiers
│   │   └── presentation/            # ModelManagerCubit + ModelSetupScreen
│   ├── rag_engine/
│   │   ├── data/                    # Copie assets/db/programmes_scolaires.db + recherche KNN sqlite_vec
│   │   └── domain/                  # RagRepository & DocumentChunk
│   └── teacher_chat/
│       ├── data/                    # EdgeAiLlmProvider extends LlmProvider (pont flutter_edge_ai <-> flutter_ai_toolkit)
│       └── presentation/            # TeacherChatScreen (LlmChatView) + SavedPdfsScreen
└── main.dart
```

---

## 🚀 Installation & Exécution

```bash
# 1. Récupération des dépendances
flutter pub get

# 2. Lancement sur un appareil Android / Émulateur
flutter run
```
