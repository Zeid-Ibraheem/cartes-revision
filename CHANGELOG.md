# Changelog

Les changements de chaque version. Format : [Keep a Changelog](https://keepachangelog.com/).
`tools/release.sh` transforme la partie « Unreleased » en nouvelle version.

## [Unreleased]

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
