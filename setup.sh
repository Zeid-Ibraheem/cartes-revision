#!/usr/bin/env bash
# =============================================================================
# setup.sh : prépare le projet Flutter autour du code de lib/, puis vérifie
# tout (analyse, tests, construction de l'APK).
#
#   bash setup.sh
#
# Sans risque à relancer : rien d'existant n'est écrasé, chaque réglage n'est
# appliqué qu'une fois. S'arrête à la première étape qui échoue en disant
# laquelle. Les vérifications (5 à 7) tournent toutes, puis un bilan s'affiche.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

ORG="io.github.zeid_ibraheem"   # identifiant Android : io.github.zeid_ibraheem.cartes_revision
NAME="cartes_revision"
LABEL="Cartes"
MANIFEST=android/app/src/main/AndroidManifest.xml

etape="début"
trap 'echo; echo "✗ Échec à l’étape : $etape. Envoie cette sortie à Claude."' ERR
titre() { etape="$1"; echo; echo "== $1"; }
ok()    { echo "   ✓ $*"; }
note()  { echo "   ! $*"; }

# ── 1. Outils ────────────────────────────────────────────────────────────────
titre "1/7 Outils"
command -v flutter >/dev/null || { echo "   ✗ Flutter introuvable dans le PATH."; exit 1; }
command -v python3 >/dev/null || { echo "   ✗ python3 manque : sudo pacman -S python"; exit 1; }
command -v git >/dev/null     || { echo "   ✗ git manque : sudo pacman -S git"; exit 1; }
# Sortie lue en entier : couper la lecture (head) fait planter Flutter quand
# il affiche son encadré « nouvelle version disponible ».
version=$(flutter --version 2>&1)
printf '%s\n' "$version" | grep -E '^(Flutter|Tools) ' | sed 's/^/   /'
if ! command -v clang >/dev/null; then
  note "clang absent : les tests de la base de données risquent d'échouer (sudo pacman -S --needed clang)"
fi

# ── 2. Dossier android/ ──────────────────────────────────────────────────────
titre "2/7 Fichiers Android (seuls les manquants sont créés)"
flutter create --platforms=android --org "$ORG" --project-name "$NAME" . | tail -n 3 | sed "s/^/   /"
# Test d'exemple généré par flutter create : il ne correspond pas à l'appli.
if [ -f test/widget_test.dart ] && grep -q 'MyApp' test/widget_test.dart; then
  rm test/widget_test.dart
fi
ok "android/ en place"

# ── 3. Réglages Android ──────────────────────────────────────────────────────
titre "3/7 Nom affiché, signature, pas d'accès réseau"
sed -i "s/android:label=\"$NAME\"/android:label=\"$LABEL\"/" "$MANIFEST"
grep -q "android:label=\"$LABEL\"" "$MANIFEST"
ok "nom sous l'icône : $LABEL"
python3 tools/signature_android.py | sed 's/^/   /'
# L'appli n'a pas besoin d'Internet : la permission ne doit pas être dans la
# version publiée (Flutter ne l'ajoute qu'aux versions de développement).
if grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  echo "   ✗ $MANIFEST demande l'accès à Internet : à retirer."
  exit 1
fi
ok "aucune permission Internet dans la version publiée"

# ── 4. Paquets ───────────────────────────────────────────────────────────────
titre "4/7 Paquets"
# Cherche la vraie ligne de dépendance, pas le commentaire qui en parle.
if ! grep -qE '^[[:space:]]+sqflite_common_ffi:' pubspec.yaml; then
  flutter pub add dev:sqflite_common_ffi
fi
flutter pub get
ok "paquets installés"

# ── 5 à 7. Vérifications : toutes lancées, bilan à la fin ───────────────────
trap - ERR
set +e
bilan=()

titre "5/7 Analyse du code"
if flutter analyze --no-fatal-infos; then bilan+=("✓ analyse"); else bilan+=("✗ analyse"); fi

titre "6/7 Tests"
if flutter test; then bilan+=("✓ tests"); else bilan+=("✗ tests"); fi

titre "7/7 Construction de l'APK (clé de test du PC)"
if flutter build apk --release; then bilan+=("✓ APK"); else bilan+=("✗ APK"); fi
set -e

# ── Dépôt Git et verrous anti-fuite ──────────────────────────────────────────
echo
echo "== Dépôt Git"
if [ ! -d .git ]; then
  git init -q -b main
  ok "dépôt créé (branche main, aucun commit)"
fi
if [ "$(git config core.hooksPath || true)" != ".githooks" ]; then
  bash scripts/install-hooks.sh | sed 's/^/   /' || true
else
  ok "verrous déjà actifs"
fi

echo
echo "== Bilan"
printf '   %s\n' "${bilan[@]}"
if [[ " ${bilan[*]} " == *✗* ]]; then
  echo
  echo "Au moins une vérification a échoué : envoie cette sortie à Claude."
  exit 1
fi
echo
echo "Tout est vert. Téléphone branché (ou débogage sans fil) : flutter run --release"
