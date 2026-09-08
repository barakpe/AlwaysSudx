#!/usr/bin/env python3
"""Audit source identity and actual full-system timing before release."""
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
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
started = datetime.strptime(record['source_capture_utc'], '%Y-%m-%dT%H:%M:%S.%fZ') \
    .replace(tzinfo=timezone.utc).timestamp()
clock_qsf = (gen / 'k5_de10lite_common_rc3.qsf').read_text()
clock = re.search(r'ALTERA_MHZ=(\d+)', clock_qsf)
assert clock and int(clock.group(1)) == record['configured_physical_clock_mhz'], \
    'Configured physical clock differs from the build record'
xlr_qsf = (gen / 'crnt_xlr.qsf').read_text()
full_sources = {Path(p).resolve() for p in re.findall(r'SYSTEMVERILOG_FILE\s+(\S+)', xlr_qsf)}
expected_sources = {p.resolve() for p in (ROOT / 'hw/xlrs/ineqsudx_scan').glob('*.sv')}
assert full_sources == expected_sources, 'Full-system source list points at another implementation'
for file, marker in [
    ('map_k5_xbox_rc3.log','Analysis & Synthesis was successful'),
    ('fit_k5_xbox_rc3.log','Fitter was successful'),
    ('sta_k5_xbox_rc3.log','Timing Analyzer was successful'),
]:
    log = gen / 'output_files' / file
    assert log.stat().st_mtime >= started, 'Stale full-system log: '+file
    assert marker in log.read_text(), file+' did not finish successfully'
timing = (gen / 'output_files/k5_xbox_rc3.sta.summary').read_text()
slacks = [float(x) for x in re.findall(r'^Slack\s*:\s*(-?[\d.]+)', timing, re.M)]
assert slacks and min(slacks) >= 0, 'Full-system timing is not closed: '+str(slacks)
assert ' Setup ' in timing and ' Hold ' in timing, 'Incomplete timing summary'

syn = ROOT / record.get('standalone_output_dir', 'hw/xlrs/ineqsudx_scan/qsyn_output_files')
for file, marker in [
    ('map_ineqsudx_scan.log','Analysis & Synthesis was successful'),
    ('fit_ineqsudx_scan.log','Fitter was successful'),
    ('sta_ineqsudx_scan.log','Timing Analyzer was successful'),
]:
    assert marker in (syn / file).read_text(), file+' did not finish successfully'
standalone_sources = list((syn / 'src_ref').glob('*.sv'))
assert {p.name for p in standalone_sources} == {p.name for p in expected_sources}, \
    'Missing standalone source snapshots'
for path in standalone_sources:
    relative = 'hw/xlrs/ineqsudx_scan/'+path.name
    assert hashlib.sha256(path.read_bytes()).hexdigest() == record['source_sha256'][relative], \
        'Standalone synthesis used different RTL: '+path.name

for extension in ['sof','svf']:
    artifact = gen / 'prog_files' / ('k5_xbox_ineqsudx_scan.'+extension)
    assert artifact.stat().st_size > 0
    assert artifact.stat().st_mtime >= started, 'Stale programming artifact: '+artifact.name
    print(hashlib.sha256(artifact.read_bytes()).hexdigest(), artifact.name)
print('Source identity, standalone completion, and full-system timing PASS')
print('Minimum reported full-system slack:', min(slacks), 'ns')
