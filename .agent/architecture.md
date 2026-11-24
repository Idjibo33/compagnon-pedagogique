# Architecture & Flux de Données

## 1. Flux du RAG et de l'Inférence Locale (Edge AI)

```
[ Enseignant ]
      │ (Saisie en langage naturel : "Fiche fractions CM1")
      ▼
[ TeacherChatScreen ] ──► [ LlmChatView ]
                                │
                                ▼
                     [ EdgeAiLlmProvider ]
                                │
        ┌───────────────────────┴───────────────────────┐
        │ 1. Recherche RAG                              │ 2. Formatage Prompt
        ▼                                               ▼
[ RagRepository ]                              [ PromptTemplates ]
  - Interroge SQLite (programmes_scolaires.db)   - Injecte system prompt rural
  - Recherche KNN 384d / BM25                    - Encapsule ChatML Qwen 2.5
  - Filtre par niveau (CM1, etc.)                - Concatène les extraits RAG
        │                                               │
        └───────────────────────┬───────────────────────┘
                                ▼
                     [ Inférence Edge AI ]
                     (flutter_edge_ai_llama)
                     Modèle: qwen2.5-1.5b (1.1 Go)
                                │
                                ▼
                     [ Streaming de Tokens ]
                                │
                                ▼
                       [ UI TeacherChatScreen ]
                       + Bouton "Exporter en PDF"
                                │
                                ▼
                     [ PdfExporter (Local) ]
                     - Enregistrement A4 stylisé
                     - Partage Xender/Bluetooth
                     - Impression directe
```

## 2. Cycle de Vie des Modèles (`ModelManager`)

1. **Vérification Initiale :** Au démarrage dans `main.dart`, `ModelManagerRepository.areAllModelsReady()` scanne le dossier `<appDocDir>/models/`.
2. **Si prêts :** Redirection immédiate vers `TeacherChatScreen`.
3. **Si absents ou incomplets :** Affichage de `ModelSetupScreen` :
   - Option A : Téléchargement en tâche de fond avec reprise (`background_downloader`).
   - Option B : Importation d'un fichier `.gguf` local depuis Xender ou la carte SD (`file_picker`), sans consommation de forfait de données.
