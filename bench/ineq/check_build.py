#!/usr/bin/env python3
"""Audit source identity and actual full-system timing before release."""
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERSION = sys.argv[1]
record = json.loads((ROOT / 'logs' / VERSION / 'build_source.json').read_text())
for relative, expected in record['source_sha256'].items():
    actual = hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()
    assert actual == expected, 'Changed build input: '+relative
    blob = subprocess.check_output(['git','-C',str(ROOT),'show',record['build_commit']+':'+relative])
    assert hashlib.sha256(blob).hexdigest() == expected, 'Build commit mismatch: '+relative

gen = ROOT / 'hw/gen_fpga'
for file, marker in [
    ('map_k5_xbox_rc3.log','Analysis & Synthesis was successful'),
    ('fit_k5_xbox_rc3.log','Fitter was successful'),
    ('sta_k5_xbox_rc3.log','Timing Analyzer was successful'),
]:
    assert marker in (gen / 'output_files' / file).read_text(), file+' did not finish successfully'
timing = (gen / 'output_files/k5_xbox_rc3.sta.summary').read_text()
slacks = [float(x) for x in re.findall(r'^Slack\s*:\s*(-?[\d.]+)', timing, re.M)]
assert slacks and min(slacks) >= 0, 'Full-system timing is not closed: '+str(slacks)
assert ' Setup ' in timing and ' Hold ' in timing, 'Incomplete timing summary'

syn = ROOT / 'hw/xlrs/ineqsudx_scan/qsyn_output_files'
for file, marker in [
    ('map_ineqsudx_scan.log','Analysis & Synthesis was successful'),
    ('fit_ineqsudx_scan.log','Fitter was successful'),
    ('sta_ineqsudx_scan.log','Timing Analyzer was successful'),
]:
    assert marker in (syn / file).read_text(), file+' did not finish successfully'
for path in (syn / 'src_ref').glob('*.sv'):
    relative = 'hw/xlrs/ineqsudx_scan/'+path.name
    assert hashlib.sha256(path.read_bytes()).hexdigest() == record['source_sha256'][relative], \
        'Standalone synthesis used different RTL: '+path.name

for extension in ['sof','svf']:
    artifact = gen / 'prog_files' / ('k5_xbox_ineqsudx_scan.'+extension)
    assert artifact.stat().st_size > 0
    print(hashlib.sha256(artifact.read_bytes()).hexdigest(), artifact.name)
print('Source identity, standalone completion, and full-system timing PASS')
print('Minimum reported full-system slack:', min(slacks), 'ns')
