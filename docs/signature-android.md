# Signature de l'APK Android

Android n'installe une mise à jour que si elle est signée avec **la même clé** que la version déjà installée. C'est ce qui permet la mise à jour sans câble (Obtainium). Règle du socle : une seule clé pour toutes les applis, celle créée pour PC Transfer.

`setup.sh` règle déjà le projet (`tools/signature_android.py`) : sur GitHub l'APK est signé avec la clé des secrets, sur le PC avec la clé de test.

## Donner la clé à GitHub (une fois, depuis le dossier du dépôt)

```
base64 -w0 ~/cles-android/pc-transfer-release.jks | gh secret set ANDROID_KEYSTORE_BASE64
gh secret set ANDROID_KEYSTORE_PASSWORD     # demande le mot de passe, rien dans l'historique
gh secret set ANDROID_KEY_PASSWORD          # le même mot de passe
gh secret set ANDROID_KEY_ALIAS --body release
gh variable set ANDROID_CERT_SHA256 --body "$(keytool -list -v -keystore ~/cles-android/pc-transfer-release.jks -alias release | grep -m1 'SHA256:' | awk '{print $2}' | tr -d ':' | tr 'A-F' 'a-f')"
gh secret set HOMELAB_BLACKLIST < ~/.config/homelab/blacklist.txt
```

`release.yml` refuse de publier si l'APK n'est pas signé avec la clé dont l'empreinte est `ANDROID_CERT_SHA256`.

## Passage du câble à Obtainium

Une appli installée par `flutter run` est signée avec la clé de test du PC. Android refusera de la remplacer par la version publiée : il faut la désinstaller une fois, ce qui efface ses cartes et son historique. Pour ne rien perdre, installe la version publiée **avant** de réviser pour de vrai.
