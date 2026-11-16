# Sécurité

## Niveau 2 : dépôt public, appli sans réseau

- L'appli n'a pas la permission Internet : les cartes et l'historique ne quittent pas le téléphone.
- Le code est public : aucune donnée personnelle dans le dépôt (noms de machines, adresses, comptes, clés).
- L'APK publié est signé, toujours avec la même clé, gardée hors du dépôt (`docs/signature-android.md`).

## Les verrous

| Quand | Quoi |
|---|---|
| Avant chaque commit | `scripts/check-public.sh` (liste noire personnelle, adresses MAC, adresses du VPN, fichiers sensibles) puis gitleaks (mots de passe, jetons) |
| Sur chaque message de commit | les mêmes vérifications, et pas de ligne `Co-Authored-By` ni `Claude-Session` |
| Avant chaque push | tout l'historique, ce qui rattrape un `git commit --no-verify` |
| Sur GitHub | `public-safety.yml` revérifie l'historique à chaque push |

La liste noire vit hors du dépôt, dans `~/.config/homelab/blacklist.txt` (modèle : `config/blacklist.example.txt`). Mise en place : `scripts/install-hooks.sh` (lancé par `setup.sh`).

## En cas de fuite

1. **Considérer le secret comme compromis**, même si le commit est supprimé aussitôt : des robots analysent GitHub en continu.
2. **Le remplacer immédiatement.**
3. **Ensuite seulement**, nettoyer l'historique (`git filter-repo`) et forcer l'envoi.

## Signaler un problème

Pour une faille, utiliser le signalement privé de GitHub (onglet *Security*, « Report a vulnerability ») plutôt qu'un ticket public.
