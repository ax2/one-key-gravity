#!/usr/bin/env python3
"""Package source and desktop exports without caches, credentials, or toolchains."""
from pathlib import Path
import hashlib
import shutil
import zipfile

root = Path(__file__).resolve().parents[1]
out = root.parent / 'compact-deliverables'
out.mkdir(exist_ok=True)
notices = ['README.md', 'TEST_REPORT.md', 'LICENSE', 'THIRD_PARTY_NOTICES.md',
           'assets/FONT-LICENSE.txt', 'assets/GODOT-LICENSE.txt', 'assets/GODOT-THIRD-PARTY.txt']

def archive(path, files):
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for file, name in files:
            z.write(file, name)
    print(path.name, path.stat().st_size)

source = []
for p in sorted(root.rglob('*')):
    if not p.is_file():
        continue
    rel = p.relative_to(root)
    if any(part in {'.git', '.godot', 'build', '__pycache__'} for part in rel.parts):
        continue
    if p.suffix in {'.log', '.pyc', '.keystore', '.jks'} or p.name.startswith('render_probe'):
        continue
    if p.name == 'export_credentials.cfg':
        continue
    source.append((p, 'one-key-gravity/' + str(rel)))
archive(out / 'OneKeyGravity-1.0.0-Source.zip', source)
for platform, executable in [('Windows', 'windows/OneKeyGravity.exe'), ('Linux', 'linux/OneKeyGravity.x86_64')]:
    binary = root / 'build' / executable
    if binary.exists():
        files = [(binary, binary.name)] + [(root/n, n) for n in notices if (root/n).exists()]
        archive(out / f'OneKeyGravity-1.0.0-{platform}.zip', files)
apk = root / 'build/android/OneKeyGravity-test.apk'
if apk.exists():
    shutil.copy2(apk, out/'OneKeyGravity-1.0.0-Android-test.apk')
for name in ['01-menu.png', '02-gameplay.png']:
    shutil.copy2(root/'screenshots'/name, out/name)
shutil.copy2(root/'TEST_REPORT.md', out/'TEST_REPORT.md')
checksums=[]
for p in sorted(out.iterdir()):
    if p.is_file() and p.name != 'SHA256SUMS.txt':
        checksums.append(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name)
(out/'SHA256SUMS.txt').write_text('\n'.join(checksums)+'\n')
