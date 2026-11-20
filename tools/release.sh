#!/usr/bin/env bash
# Crée la version suivante et son étiquette. GitHub construit ensuite l'APK
# signé et le publie ; Obtainium le propose sur le téléphone.
#   tools/release.sh patch   0.1.0 -> 0.1.1  (corrections)
#   tools/release.sh minor   0.1.1 -> 0.2.0  (nouveautés)
#   tools/release.sh major   0.2.0 -> 1.0.0
# La version n'est écrite qu'à UN endroit : pubspec.yaml. L'appli la reçoit à
# la construction (APP_VERSION), elle n'est recopiée nulle part à la main.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_DIR="${APP_DIR:-.}"
PUBSPEC="$APP_DIR/pubspec.yaml"
part="${1:-patch}"

[ -f "$PUBSPEC" ] || { echo "Introuvable : $PUBSPEC (règle APP_DIR)."; exit 1; }
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Commite d'abord tes changements."
  exit 1
fi

# Dernière version : la plus haute entre l'étiquette la plus récente et
# pubspec.yaml (une copie sans les étiquettes ne recrée pas une version).
tag="$(git tag --list 'v*' --sort=-v:refname | sed -n 1p)"
pub="v$(sed -n -E 's/^version: *([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' "$PUBSPEC")"
[ "$pub" != "v" ] || pub="v0.0.0"
last="$(printf '%s\n' "${tag:-v0.0.0}" "$pub" | sort -V | tail -n1)"
IFS=. read -r major minor patch <<< "${last#v}"
patch="${patch%%[^0-9]*}"

case "$part" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
  *) echo "Usage : $0 [patch|minor|major]"; exit 1 ;;
esac
next="$major.$minor.$patch"

sed -i -E "s/^version: .*/version: $next+1/" "$PUBSPEC"
if [ -f CHANGELOG.md ] && grep -q '^## \[Unreleased\]' CHANGELOG.md; then
  sed -i "s/^## \[Unreleased\]/## [Unreleased]\n\n## [$next] - $(date +%F)/" CHANGELOG.md
fi

git commit -qam "Version $next"
git tag "v$next"
branch="$(git rev-parse --abbrev-ref HEAD)"
echo "Étiquette v$next créée. Pour publier :"
echo "  git push origin $branch v$next"
