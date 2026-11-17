# Cartes

Mon appli de révision par répétition espacée, pour Android.

Le principe : tu écris des cartes question / réponse, et l'appli te les repose juste avant que tu les oublies. Une carte que tu connais bien revient dans plusieurs semaines, une carte ratée revient dans dix minutes. C'est ce que fait Anki, mais je voulais quelque chose de plus simple, rangé comme mes cours :

- un **dossier** par matière (chez moi, une ressource du BUT : R3.07, R3.04…),
- des **paquets** dedans, un par contrôle ou par chapitre,
- et je révise un paquet, un dossier entier, ou tout d'un coup.

Pourquoi ce fonctionnement : se tester (au lieu de relire) et espacer les révisions sont les deux méthodes d'apprentissage les mieux prouvées (Dunlosky et al., 2013 ; Cepeda et al., 2008). Le calcul des dates utilise FSRS, l'algorithme qu'Anki utilise aussi aujourd'hui.

Un rappel par jour, à l'heure que tu choisis, te dit combien de cartes t'attendent, seulement s'il y en a.

Rien ne quitte le téléphone : pas de compte, pas de serveur, et l'appli n'a même pas la permission d'accéder à Internet.

> Captures d'écran : à venir avec la première version publiée.

## Installer

Avec [Obtainium](https://github.com/ImranR98/Obtainium) : ajoute l'adresse de ce dépôt, il récupère l'APK des Releases et te propose les mises à jour.

## Ajouter des cartes

À la main dans l'appli, ou en important un fichier texte, une carte par ligne :

```
# dossier: R3.07
# paquet: Contrôle 1
Que vaut l'atténuation de la fibre à 1550 nm ?	Moins de 0,25 dB/km
```

Entre la question et la réponse, une tabulation. Tout le format est dans [docs/FORMAT-DES-CARTES.md](docs/FORMAT-DES-CARTES.md). Réimporter un fichier corrigé met les réponses à jour sans perdre ce que tu as déjà révisé.

## Les réglages

Nouvelles cartes par jour, mémorisation visée (90 % par défaut : plus haut = plus de révisions), étapes courtes en minutes, intervalle maximum, 2 ou 4 boutons, taille du texte, thème clair, sombre ou noir.

## Développer

Il faut Flutter et le SDK Android.

```
bash setup.sh            # prépare android/, installe les paquets, analyse, teste, construit l'APK
flutter run --release    # sur le téléphone
```

Le code est rangé en trois couches (écrans, données, règles) : voir [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

Publier une version : `tools/release.sh patch` (ou `minor`), puis la commande `git push` qu'il affiche. GitHub construit l'APK signé et le met dans une Release.

## Licence

MIT. Le moteur FSRS vient du paquet [fsrs](https://pub.dev/packages/fsrs) (MIT également).
