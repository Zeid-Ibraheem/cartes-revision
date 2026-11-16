# Format des fichiers de cartes

Un fichier texte en UTF-8 (extension `.txt` ou `.tsv`), une carte par ligne.

```
# dossier: R3.07
# paquet: Contrôle 1
Question<TABULATION>Réponse
Autre question<TABULATION>Ligne 1<br>Ligne 2
```

## Les règles

| Ce que tu écris | Ce que ça fait |
|---|---|
| `# dossier: R3.07` | Les cartes suivantes vont dans ce dossier. Repart du paquet par défaut. |
| `# paquet: Contrôle 1` | Les cartes suivantes vont dans ce paquet. |
| `Question` + tabulation + `Réponse` | Une carte. |
| `<br>` | Un retour à la ligne dans la question ou la réponse. |
| Une autre ligne qui commence par `#` | Commentaire, ignoré. |
| Une ligne vide | Ignorée. |

- Sans `# dossier:`, les cartes vont dans le dossier « Divers ».
- Sans `# paquet:`, le paquet porte le nom du fichier.
- Un fichier peut contenir plusieurs dossiers et plusieurs paquets.
- Majuscules et espaces autour des deux-points n'ont pas d'importance (`# Dossier : R3.07` marche).
- Une ligne sans tabulation, ou avec une question ou une réponse vide, est ignorée. L'appli le dit à la fin de l'import, avec le numéro de la ligne.

## Réimporter un fichier corrigé

Une carte est reconnue par son **paquet** (dossier + nom) et sa **question**.

- Question déjà connue, même réponse : rien ne change.
- Question déjà connue, réponse différente : la réponse est remplacée, l'historique de révision est gardé.
- Question nouvelle : carte ajoutée.
- Changer le texte d'une question crée une nouvelle carte. Pour corriger une question sans perdre son historique, corrige-la dans l'appli.
- Une carte retirée du fichier n'est pas supprimée de l'appli.

## Attention à la tabulation

C'est un vrai caractère de tabulation, pas des espaces. Certains éditeurs et certaines applis de discussion remplacent les tabulations par des espaces quand on copie-colle : télécharge le fichier plutôt que de copier son texte.
