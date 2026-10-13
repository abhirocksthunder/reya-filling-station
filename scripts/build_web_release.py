"""Build Firebase web assets with an independent deployment revision."""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
from datetime import datetime, timezone, timedelta
from pathlib import Path

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--flutter', default=shutil.which('flutter') or 'C:/Users/cso/flutter/flutter/bin/flutter.bat')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    subprocess.run([args.flutter, 'build', 'web', '--release', '--pwa-strategy=none'], cwd=root, check=True)
    version = re.search(r'^version: (\S+)', (root/'pubspec.yaml').read_text(), re.M).group(1)
    name, build = version.split('+')
    web = root/'build/web'
    # Web updates must retain the identity-verified migration APK, not a
    # stale web/static copy or the APK overwritten by a later patch build.
    source_apk = root/'web/static/reya-filling-station.bin'
    base_record = Path.home()/'.reya-ota'/('base-'+version+'.json')
    if base_record.exists():
        record = json.loads(base_record.read_text(encoding='utf-8'))
        actual = hashlib.sha256(source_apk.read_bytes()).hexdigest()
        if actual != record['apk_sha256']:
            raise RuntimeError('Hosted APK source differs from the identity-verified base. Recover the original base before deploying web.')
    if source_apk.exists():
        target = web/'static/reya-filling-station.bin'
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_apk, target)
    digest = hashlib.sha256((web/'main.dart.js').read_bytes()).hexdigest()[:16]
    now = datetime.now(timezone(timedelta(hours=5, minutes=30)))
    revision = now.strftime('%Y%m%d%H%M%S') + '-' + digest
    metadata = dict(version=name, build_number=int(build), web_revision=revision,
                    deployed_at_ist=now.isoformat())
    (web/'version.json').write_text(json.dumps(metadata, indent=2)+'\n')
    index = web/'index.html'
    html = index.read_text(encoding='utf-8')
    html = re.sub(r"var DEPLOYED_VERSION = '[^']+'", "var DEPLOYED_VERSION = '"+revision+"'", html)
    html = re.sub(r'flutter_bootstrap\.js\?v=[^"\s]+', 'flutter_bootstrap.js?v='+revision, html)
    index.write_text(html, encoding='utf-8')
    print('Web revision:', revision, '(APK version unchanged:', version+')')
    print('Publish existing Firebase Hosting project after reviewing build/web.')

if __name__ == '__main__':
    main()
