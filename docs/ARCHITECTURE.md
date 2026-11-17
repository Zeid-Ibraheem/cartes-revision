# Architecture

Trois couches. Chacune ne connaît que celle du dessous.

```
lib/
├── main.dart, app_info.dart   démarrage, thème, nom et version
├── ui/                        les écrans (Flutter)
│   ├── home_screen.dart         dossiers, paquets, import
│   ├── deck_screen.dart         les cartes d'un paquet
│   ├── card_editor_screen.dart  écrire ou corriger une carte
│   ├── review_screen.dart       la séance de révision
│   ├── settings_screen.dart     les réglages
│   ├── theme.dart               toutes les couleurs de l'appli
│   └── common.dart              blocs, compteurs, menus partagés
├── data/                      stockage et moteur
│   ├── database.dart          SQLite : decks, cards, reviews, settings
│   ├── fsrs_scheduler.dart    le SEUL fichier qui connaît le paquet fsrs
│   └── store.dart             l'état de l'appli, écouté par les écrans
└── domain/                    les règles, sans Flutter ni base
    ├── models.dart            Deck, Flashcard, Memory, Grade
    ├── scheduler.dart         l'interface du moteur de répétition
    ├── study_session.dart     quelles cartes, dans quel ordre
    ├── card_file.dart         lecture des fichiers de cartes
    ├── settings.dart          réglages, valeurs par défaut et bornes
    └── format.dart            délais en français
```

## Où changer quoi

| Pour… | Fichier |
|---|---|
| Changer de moteur de répétition | une nouvelle classe qui implémente `Scheduler`, branchée dans `store.dart` |
| Changer une couleur | `ui/theme.dart`, et nulle part ailleurs |
| Ajouter un réglage | `domain/settings.dart` (valeur, borne, clé) puis `ui/settings_screen.dart` |
| Changer le format des fichiers | `domain/card_file.dart` et `docs/FORMAT-DES-CARTES.md` |
| Ajouter une table ou une colonne | `data/database.dart` : nouvelle version du schéma, jamais de modification directe |

## Choix faits

- **FSRS** (Free Spaced Repetition Scheduler) plutôt que l'ancien algorithme d'Anki (SM-2) : à mémorisation égale, il demande moins de révisions. Le paquet Dart `fsrs` est un port officiel de py-fsrs, licence MIT.
- **Les délais affichés sont ceux appliqués.** Le moteur calcule les 4 résultats possibles quand la carte s'affiche ; la note choisie enregistre exactement celui-là, même avec la variation aléatoire des intervalles.
- **Toutes les réponses sont gardées** (table `reviews`) : c'est ce qu'il faudra pour les statistiques, et pour ajuster les paramètres de FSRS sur tes propres révisions.
- **Pas d'accès réseau.** La permission Internet n'est pas dans l'APK publié ; `setup.sh` le vérifie.
