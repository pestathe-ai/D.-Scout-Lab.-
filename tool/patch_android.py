"""Modifiche native ad android/ dopo `flutter create`."""
import glob
import os
import re
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, 'android', 'app')
MANIFEST = os.path.join(APP, 'src', 'main', 'AndroidManifest.xml')

# 1. Manifest: nome app, permesso notifiche, servizio lettura notifiche.
m = open(MANIFEST, encoding='utf-8').read()
m = re.sub(r'android:label="[^"]*"', 'android:label="D. Scout Lab"', m, count=1)
if 'POST_NOTIFICATIONS' not in m:
    m = m.replace(
        '<application',
        '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n'
        '    <uses-permission android:name="android.permission.INTERNET"/>\n'
        '    <application', 1)
service = '''
        <service android:label="D. Scout Lab"
            android:name="notification.listener.service.NotificationListener"
            android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"
            android:exported="true">
            <intent-filter>
                <action android:name="android.service.notification.NotificationListenerService" />
            </intent-filter>
        </service>
'''
if 'NotificationListener"' not in m:
    m = m.replace('</application>', service + '    </application>', 1)
open(MANIFEST, 'w', encoding='utf-8').write(m)

# 2. MainActivity con il canale per gli avvisi.
acts = glob.glob(os.path.join(APP, 'src', 'main', 'kotlin', '**', 'MainActivity.kt'), recursive=True)
assert acts, 'MainActivity.kt non trovata'
act = acts[0]
pkg = re.search(r'^package\s+([\w.]+)', open(act, encoding='utf-8').read(), re.M).group(1)
tpl = open(os.path.join(ROOT, 'tool', 'android', 'MainActivity.kt'), encoding='utf-8').read()
open(act, 'w', encoding='utf-8').write(tpl.replace('__PACKAGE__', pkg))

# 3. Icona per la barra delle notifiche.
drawable = os.path.join(APP, 'src', 'main', 'res', 'drawable')
os.makedirs(drawable, exist_ok=True)
shutil.copy(os.path.join(ROOT, 'tool', 'android', 'ic_stat_scout.xml'), drawable)

print('patch android ok, package', pkg)
