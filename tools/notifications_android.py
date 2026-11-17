#!/usr/bin/env python3
"""Règle le projet Android pour les rappels (paquet flutter_local_notifications).

  python3 tools/notifications_android.py [dossier_de_l_appli]

1. android/app/build.gradle.kts : « desugaring » (exigé par le paquet) ;
2. android/app/src/main/AndroidManifest.xml : redémarrage du téléphone et
   récepteurs qui affichent les notifications programmées.

Sans risque à relancer : chaque changement n'est fait qu'une fois.
"""
import re
import sys
from pathlib import Path

DESUGAR_DEP = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
BOOT = '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>'
RECEIVERS = '''        <!-- Rappels programmés (flutter_local_notifications) -->
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
'''


def gradle(path):
    text = path.read_text(encoding='utf-8')
    changed = False
    if 'isCoreLibraryDesugaringEnabled' not in text:
        new, n = re.subn(r'(compileOptions\s*\{\n)', r'\1        isCoreLibraryDesugaringEnabled = true\n', text, count=1)
        if n != 1:
            raise SystemExit(f'ERREUR : bloc compileOptions introuvable dans {path}')
        text, changed = new, True
    if 'desugar_jdk_libs' not in text:
        if re.search(r'^dependencies\s*\{', text, re.M):
            text = re.sub(r'^(dependencies\s*\{\n)', r'\1    ' + DESUGAR_DEP + '\n', text, count=1, flags=re.M)
        else:
            text = text.rstrip('\n') + '\n\ndependencies {\n    ' + DESUGAR_DEP + '\n}\n'
        changed = True
    if changed:
        path.write_text(text, encoding='utf-8')
    return changed


def manifest(path):
    text = path.read_text(encoding='utf-8')
    changed = False
    if 'RECEIVE_BOOT_COMPLETED' not in text:
        new, n = re.subn(r'(<manifest[^>]*>\n)', r'\1    ' + BOOT + '\n', text, count=1)
        if n != 1:
            raise SystemExit(f'ERREUR : balise <manifest> introuvable dans {path}')
        text, changed = new, True
    if 'ScheduledNotificationReceiver' not in text:
        if text.count('</application>') != 1:
            raise SystemExit(f'ERREUR : balise </application> introuvable dans {path}')
        text = text.replace('    </application>', RECEIVERS + '    </application>', 1) \
            if '    </application>' in text else text.replace('</application>', RECEIVERS + '</application>', 1)
        changed = True
    if changed:
        path.write_text(text, encoding='utf-8')
    return changed


def main():
    app = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('.')
    g = app / 'android/app/build.gradle.kts'
    m = app / 'android/app/src/main/AndroidManifest.xml'
    for p in (g, m):
        if not p.exists():
            print(f'ERREUR : {p} introuvable (lance d’abord flutter create)')
            return 1
    a, b = gradle(g), manifest(m)
    print('✓ rappels : réglages Android ' + ('appliqués' if a or b else 'déjà en place'))
    return 0


sys.exit(main())
