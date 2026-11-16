#!/usr/bin/env python3
"""Règle la signature de l'APK dans android/app/build.gradle.kts.

Sur GitHub, l'APK est signé avec la clé gardée dans les secrets.
Sur ton PC, sans ces variables, il est signé avec la clé de test habituelle.

  python3 tools/signature_android.py [dossier_de_l_appli]

Sans risque à relancer : le changement n'est fait qu'une fois.
"""
import re
import sys
from pathlib import Path

SIGNING = '''signingConfigs {
    create("release") {
        val keystorePath = System.getenv("KEYSTORE_PATH")
        if (keystorePath != null) {
            storeFile = file(keystorePath)
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
        }
    }
}

buildTypes {
    release {
        // GitHub : clé de publication (secrets). PC sans ces variables : clé de test.
        signingConfig = if (System.getenv("KEYSTORE_PATH") != null) {
            signingConfigs.getByName("release")
        } else {
            signingConfigs.getByName("debug")
        }
    }
}'''


def replace_block(text, start_pattern, new_block):
    """Remplace le bloc `nom { ... }` trouvé (accolades équilibrées)."""
    matches = list(re.finditer(start_pattern, text, re.MULTILINE))
    if len(matches) != 1:
        return None
    match = matches[0]
    indent = match.group(1)
    depth = 0
    for index in range(match.end() - 1, len(text)):
        if text[index] == '{':
            depth += 1
        elif text[index] == '}':
            depth -= 1
            if depth == 0:
                block = '\n'.join(indent + line if line else line for line in new_block.splitlines())
                return text[:match.start()] + block + text[index + 1:]
    return None


def main():
    app_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('.')
    path = app_dir / 'android/app/build.gradle.kts'
    if not path.exists():
        print(f'ERREUR : {path} introuvable (lance d’abord flutter create)')
        return 1
    text = path.read_text(encoding='utf-8')
    if 'KEYSTORE_PATH' in text:
        print('✓ signature déjà réglée')
        return 0
    updated = replace_block(text, r'^([ \t]*)buildTypes\s*\{', SIGNING)
    if updated is None:
        print('ERREUR : bloc buildTypes introuvable, à régler à la main (docs/signature-android.md)')
        return 1
    path.write_text(updated, encoding='utf-8')
    print('✓ signature réglée dans', path)
    return 0


sys.exit(main())
