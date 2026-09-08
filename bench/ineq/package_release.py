#!/usr/bin/env python3
"""Package a completed, committed inequality build without rerunning synthesis.

Usage: python3 bench/ineq/package_release.py ineq-v2 path/to/course-output.tgz
The output directory must not exist. Publishing remains a separate gh command.
"""
import hashlib
import json
import shutil
import subprocess
import sys
import tarfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
version, tgz_arg = sys.argv[1:]
tgz = Path(tgz_arg).resolve()


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT)] + list(args))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


assert not git('diff', 'HEAD', '--name-only').strip(), 'Commit final tracked changes first'
record = json.loads((ROOT / 'logs' / version / 'build_source.json').read_text())
assert git('rev-parse', version+'^{commit}').decode().strip() == record['build_commit'], \
    'Release tag differs from the recorded build commit'
audit = subprocess.check_output([sys.executable, str(ROOT / 'bench/ineq/check_build.py'), version])
assert record.get('full_system_timing_passed') is True, 'Finalize build record first'
with tarfile.open(str(tgz)) as archive:
    sources = [m for m in archive.getmembers()
               if m.name.startswith('qsyn_output_files/src_ref/') and m.name.endswith('.sv')]
    assert len(sources) == 3, 'Incomplete course TGZ'
    for member in sources:
        relative = 'hw/xlrs/ineqsudx_scan/' + Path(member.name).name
        assert hashlib.sha256(archive.extractfile(member).read()).hexdigest() == \
            record['source_sha256'][relative], 'TGZ contains different RTL: '+relative

out = ROOT / 'artifacts' / (version+'-release')
out.mkdir()  # Refuse to mix with assets from a previous attempt.
for ext in ['sof', 'svf']:
    shutil.copy2(str(ROOT / 'hw/gen_fpga/prog_files' / ('k5_xbox_ineqsudx_scan.'+ext)), str(out))
shutil.copy2(str(tgz), str(out))
for name in ['INEQUALITY_DESIGN.md', 'INEQUALITY_RESULTS.md', 'INEQUALITY_HARDWARE_HANDOFF.md']:
    shutil.copy2(str(ROOT / 'docs' / name), str(out))
shutil.copy2(str(ROOT / 'logs' / version / 'build_source.json'), str(out))
(out / 'BUILD_AUDIT.txt').write_bytes(audit)

manifest = dict(record)
manifest['release_tag'] = version
manifest['documentation_commit'] = git('rev-parse', 'HEAD').decode().strip()
manifest['programming_files_sha256'] = {p.name: sha(p) for p in out.iterdir()
                                      if p.suffix in ['.sof', '.svf']}
manifest['course_tgz_sha256'] = {tgz.name: sha(tgz)}
manifest_bytes = (json.dumps(manifest, indent=2)+'\n').encode()
(out / 'RELEASE_MANIFEST.json').write_bytes(manifest_bytes)

prefix = 'AlwaysSudx-'+version+'/'
source_zip = out / ('AlwaysSudx-'+version+'-source.zip')
subprocess.run(['git', '-C', str(ROOT), 'archive', '--format=zip', '--prefix='+prefix,
                '-o', str(source_zip), 'HEAD'], check=True)
with zipfile.ZipFile(str(source_zip), 'a', zipfile.ZIP_DEFLATED) as archive:
    archive.writestr(prefix+'RELEASE_MANIFEST.json', manifest_bytes)

# Compact authored-source bundle; the full source ZIP additionally provides the
# unchanged course library, boards, experiments, and all committed evidence.
authored = [p for p in record['source_sha256'] if '/sud_shared/' not in p and not p.endswith('.f')]
with zipfile.ZipFile(str(out / ('AlwaysSudx-'+version+'-submission-sources.zip')),
                     'w', zipfile.ZIP_DEFLATED) as archive:
    for relative in authored:
        archive.writestr(relative, git('show', 'HEAD:'+relative))
    archive.writestr('INEQUALITY_RESULTS.md', (ROOT / 'docs/INEQUALITY_RESULTS.md').read_bytes())

files = sorted(p for p in out.iterdir() if p.is_file())
(out / 'SHA256SUMS').write_text(''.join(sha(p)+'  '+p.name+'\n' for p in files))
print(out)
print('Packaged exact-source SOF/SVF, course TGZ, source ZIPs, documentation, and hashes.')
