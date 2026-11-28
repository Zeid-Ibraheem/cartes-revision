# Changelog

Les changements de chaque version. Format : [Keep a Changelog](https://keepachangelog.com/).
`tools/release.sh` transforme la partie « Unreleased » en nouvelle version.

## [Unreleased]

### Ajouté
- Façon de répondre par paquet (écran du paquet, ou `# mode:` dans le fichier) : classique, **écrire** la réponse au clavier, ou **QCM**.
- Écrire : réponse exacte lettre pour lettre = « Correct » en un appui (note modifiable) ; sinon l'appli montre la différence lettre par lettre et dit si c'est juste aux accents ou majuscules près, ou à combien de lettres près ; c'est toi qui te notes.
- QCM : 4 réponses, la bonne, les mauvaises écrites sur la carte (colonnes après la réponse dans le fichier, ou champ dans l'éditeur), complétées par des réponses d'autres cartes du paquet. Mauvais choix : « À revoir » ; bon choix : « Je savais » ou « J'ai hésité ».

### Changé
- Base de données en version 2 (façon de réviser, mauvaises réponses) : mise à jour automatique au premier lancement, rien n'est perdu.
- Fichiers de cartes : les colonnes après la réponse sont maintenant les mauvaises réponses du QCM (avant, une tabulation en trop devenait un espace dans la réponse).
- L'export garde le mode des paquets et les mauvaises réponses.

## [0.10.0] - 2026-11-26

### Ajouté
- Recevoir des fichiers : Cartes apparaît dans « Partager » et « Ouvrir avec » pour les fichiers texte (et le texte partagé). Un aperçu montre où iront les cartes (dossier › paquet : nombre de cartes) ; rien n'est importé sans appuyer sur « Importer ». 5 Mo et 20 fichiers au plus, aucune permission en plus.

## [0.9.0] - 2026-11-21

### Ajouté
- Exporter : appui long sur un paquet ou un dossier › Exporter, ou bouton + › Exporter toutes les cartes. Le fichier texte (`cartes-<nom>-<date>.txt`) est au format d'import et se réimporte tel quel, chaque paquet revenant à sa place. Sans les dates de révision ni l'historique.

### Changé
- Import : une ligne avec tabulation est une carte même si elle commence par « # » (avant, elle était prise pour un commentaire).

## [0.8.0] - 2026-11-20

### Ajouté
- Ranger en glissant : sur l'accueil, appui long sur un paquet ou un dossier, puis glisse-le sur un dossier pour l'y ranger. Le dossier visé s'encadre ; un dossier replié se déplie si tu restes dessus un instant. Lâcher sur un paquet range dans son dossier. Pendant qu'on glisse un sous-dossier, une zone « tout en haut » apparaît. Message de confirmation avec « Annuler ».

### Changé
- Le menu des actions d'un paquet ou d'un dossier s'ouvre maintenant quand on relâche l'appui long sans bouger.

### Corrigé
- tools/release.sh : le numéro de version part du plus haut entre la dernière étiquette et pubspec.yaml (une copie du dépôt sans étiquettes ne republie plus une ancienne version).

## [0.7.0] - 2026-11-20

### Ajouté
- Entraînement libre : revoir toutes les cartes d'un paquet ou d'un dossier quand tu veux (avant un contrôle, par exemple), sans rien changer à leurs dates de révision ni aux statistiques. Deux boutons : « À revoir » (la carte revient 3 cartes plus loin) et « Su » (elle sort). Barre de progression, bilan à la fin, et « Revoir les cartes ratées ».
- Accès : appui long sur un paquet ou un dossier › Entraînement libre, ou bouton « Entraînement libre » dans l'écran d'un paquet.

## [0.6.0] - 2026-11-20

### Ajouté
- Annuler la dernière réponse pendant une séance (↶ en haut) : la carte revient telle qu'avant, et la réponse disparaît des statistiques. Plusieurs annulations d'affilée possibles.
- Bilan en fin de séance : cartes, temps et pourcentage de réussite.
- « Tout réviser · N » en bas de l'accueil : une seule séance avec les cartes dues de tous les dossiers.
- Un appui sur la notification ouvre directement la séance « Tout réviser », même appli fermée.
- Écrire des cartes : case « Créer aussi la carte inverse » (la réponse devient la question).
- Écrire des cartes : l'appli propose le dernier paquet utilisé.

### Changé
- Boutons gris foncé au lieu de blancs, messages du bas de l'écran sombres : le noir sur noir n'est plus coupé par des pavés blancs. Les boutons de suppression sont en rouge.
- Zéros des compteurs et textes d'aide dans un gris lisible (contraste 3:1 au lieu de 1,5:1).
- La phrase « Réponds dans ta tête, puis touche l'écran » disparaît des cartes.
- « Ajouter » devient « Ajouter des cartes » dans le menu du bouton +.

### Corrigé
- Un double appui pendant la révision pouvait noter la carte suivante sans l'avoir vue (ou noter « Difficile » en voulant voir la réponse) : les appuis sont ignorés 0,3 s après chaque changement.
- Le temps d'une réponse est plafonné à 60 s : un téléphone posé sur une carte ne fausse plus les statistiques.
- Quitter l'écran d'écriture avec du texte tapé demande maintenant confirmation au lieu de tout effacer.

## [0.5.0] - 2026-11-18

## [0.4.0] - 2026-11-18

### Ajouté
- Dossiers dans des dossiers, sur autant de niveaux que tu veux (ex. Cours › R3.07 › Contrôle 1, Connaissances › Physique). Chaque dossier additionne les compteurs de tout ce qu'il contient.
- Accueil en arbre : un appui sur un dossier le déplie ou le replie (tout est replié au départ, l'appli retient ce que tu ouvres). Appui long : réviser tout le dossier, nouveau paquet, nouveau sous-dossier, renommer, déplacer dans un autre dossier, supprimer.
- Fichiers de cartes : `# dossier: Cours/R3.07` range directement dans un sous-dossier.

### Corrigé
- La notification comptait seulement les cartes dues avant l'heure du rappel ; elle compte maintenant toute la journée de révision, comme l'appli.

## [0.3.0] - 2026-11-17

### Ajouté
- Rappel quotidien : une notification à l'heure choisie (19 h par défaut), seulement s'il y a des cartes à réviser, avec le nombre de cartes à revoir et de nouvelles. Réglable ou désactivable dans les réglages, bloc « Rappel ». Sans accès à Internet.

## [0.2.0] - 2026-11-17

### Changé
- Nouvelle interface, proche d'Anki : fond noir, blocs gris, la couleur réservée à ce qui porte une information.
- Trois compteurs en couleur partout (accueil, paquet, séance) : nouvelles en bleu, en apprentissage en rouge, à réviser en vert. Pendant une séance, celui de la carte affichée est souligné.
- Accueil : un appui sur un paquet ou un dossier lance la révision ; un appui long ouvre ses actions (voir les cartes, écrire, renommer, supprimer).
- Écrire une carte se fait sur un écran entier, avec de grands champs. On choisit le paquet en haut (ou on le crée sur place) et on enchaîne les cartes.
- Séance : la question et la réponse sont chacune dans leur bloc ; un appui n'importe où montre la réponse ; boutons de réponse en couleur.
- Réglages rangés par blocs. Le thème par défaut est le noir.
- Import : un simple message quand tout s'est bien passé, le détail seulement s'il y a des remarques.

### Ajouté
- Renommer et supprimer un dossier entier.
- Supprimer une carte par appui long, et depuis une séance.

## [0.1.0] - 2026-11-16

### Ajouté
- Dossiers (par exemple une ressource, R3.07) contenant des paquets (un par contrôle ou chapitre).
- Révision d'un paquet, d'un dossier, ou de tout, avec le moteur FSRS.
- Séance : question, « Voir la réponse », puis À revoir / Difficile / Correct / Facile avec le délai de retour sous chaque bouton.
- Import de fichiers de cartes (texte, une carte par ligne) ; réimporter un fichier corrigé garde l'historique.
- Cartes à la main : ajout, correction (aussi pendant une séance), suppression. Recherche dans un paquet.
- Paquets : création, renommage, déplacement dans un autre dossier, suppression.
- Réglages : nouvelles cartes par jour, mémorisation visée, étapes d'apprentissage et après un oubli, intervalle maximum, variation des intervalles, début de la journée, 2 ou 4 boutons, délais affichés, ordre aléatoire, taille du texte, thème (auto, clair, sombre, noir).
- Aucun accès à Internet : tout reste sur le téléphone.
