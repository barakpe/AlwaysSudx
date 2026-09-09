#!/usr/bin/env python3
"""Package a committed, built milestone into release assets.

Usage: python3 bench/package_release.py v7
       python3 bench/package_release.py v6 --no-hardware

Assets land in artifacts/<version>-release/ and the directory must not already
exist, so a retry never mixes in files from an earlier attempt. Publishing is a
separate `gh release create` step; this script only builds and fingerprints.
"""
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
version = sys.argv[1]
with_hardware = '--no-hardware' not in sys.argv[2:]


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT)] + list(args)).decode().strip()


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


assert not git('status', '--porcelain'), 'Commit tracked changes before packaging'
tag_commit = git('rev-parse', version + '^{commit}')

out = ROOT / 'artifacts' / (version + '-release')
out.mkdir(parents=True)

manifest = {
    'repository': 'https://github.com/barakpe/AlwaysSudx',
    'release_tag': version,
    'tag_commit': tag_commit,
    'documentation_commit': git('rev-parse', 'HEAD'),
    'hardware_execution_tested': False,
}

if with_hardware:
    record = json.loads((ROOT / 'logs' / version / 'build_source.json').read_text())
    # The bitstream must correspond to the RTL this tag actually contains.
    for rel, digest in record['files'].items():
        assert sha(ROOT / rel) == digest, 'Working tree RTL differs from the build record: ' + rel
    for rel, digest in record['artifacts'].items():
        assert sha(ROOT / rel) == digest, 'Programming file differs from the build record: ' + rel
        shutil.copy2(str(ROOT / rel), str(out))
    shutil.copy2(str(ROOT / 'logs' / version / 'build_source.json'), str(out))
    manifest['rtl_build_commit'] = record['rtl_commit']

for name in ['DESIGN_WALKTHROUGH.md', 'HARDWARE_HANDOFF.md', 'RUNNING.md']:
    shutil.copy2(str(ROOT / 'docs' / name), str(out))

prefix = 'AlwaysSudx-' + version + '/'
bundle = out / ('AlwaysSudx-' + version + '.zip')
subprocess.run(['git', '-C', str(ROOT), 'archive', '--format=zip', '--prefix=' + prefix,
                '-o', str(bundle), version], check=True)

manifest['assets'] = {p.name: sha(p) for p in sorted(out.iterdir())
                      if p.name != 'RELEASE_MANIFEST.json'}
(out / 'RELEASE_MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n')

sums = out / 'SHA256SUMS'
sums.write_text(''.join('%s  %s\n' % (sha(p), p.name)
                        for p in sorted(out.iterdir()) if p.name != 'SHA256SUMS'))

print('Packaged', version, 'into', out)
for p in sorted(out.iterdir()):
    print('  %10d  %s' % (p.stat().st_size, p.name))
