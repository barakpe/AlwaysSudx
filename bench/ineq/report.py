#!/usr/bin/env python3
"""Read measured logs only; never estimate an unavailable frequency or score."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def rtl(path):
    result = {}
    if path.exists():
        for line in path.read_text().splitlines():
            words = line.split()
            result[words[0]] = {'cycles': int(words[1]), 'status': words[2]}
    return result


def apps(path):
    result = {}
    for log in path.glob('*.app.log'):
        text = log.read_text()
        match = re.search(r'Sudoku solve\s+(\d+) cycles', text)
        if match:
            result[log.name[:-8]] = {
                'cycles': int(match.group(1)),
                'passed': ('PASSED basic Sudoku checker' in text
                           and 'PASSED inequalities checker' in text
                           and 'FAILED' not in text and 'FAIL:' not in text),
            }
    return result


def frequency(path):
    if not path.exists():
        return None
    # Clock named clk in standalone reports; take the slowest reported corner.
    values = re.findall(r';\s*([\d.]+) MHz\s*;[^\n]*;\s*clk\s*;', path.read_text())
    return min(map(float, values)) if values else None


def summary(path):
    if not path.exists():
        return {}
    return dict(line.split(' : ', 1) for line in path.read_text().splitlines() if ' : ' in line)


measurements = {}
versions = sys.argv[1:] or ['ineq-v0', 'ineq-v1', 'ineq-v2', 'ineq-v3']
for milestone in versions:
    base = ROOT / 'logs' / milestone
    reports = base / 'synthesis'
    data = {'rtl': {}, 'application': apps(base / 'app')}
    for group in ['official', 'classic', 'generated', 'heldout', 'rejects', 'contract']:
        entries = rtl(base / group / 'cycles.txt')
        if not entries:
            continue
        cycles = [v['cycles'] for v in entries.values() if v['status'] == 'PASS']
        data['rtl'][group] = {
            'executions': len(entries), 'solved': len(cycles),
            'rejected': sum(v['status']=='PASS_UNSAT' for v in entries.values()),
            'mean_core_cycles': sum(cycles)/len(cycles) if cycles else None,
            'max_core_cycles': max(cycles) if cycles else None,
        }
    data['fmax_mhz'] = frequency(reports / 'ineqsudx_scan.sta.rpt')
    data['map'] = summary(reports / 'ineqsudx_scan.map.summary')
    data['fit'] = summary(reports / 'ineqsudx_scan.fit.summary')
    hardware = base / 'hardware_validation.json'
    data['hardware_execution_tested'] = hardware.exists() and \
        json.loads(hardware.read_text()).get('hardware_execution_tested', False)
    if data['fmax_mhz']:
        for app in data['application'].values():
            app['score_us'] = app['cycles']/data['fmax_mhz']
    measurements[milestone] = data

(ROOT / 'logs/inequality_measurements.json').write_text(json.dumps(measurements, indent=2)+'\n')
names = sorted(set().union(*(set(v['application']) for v in measurements.values())))
print('| Board | ' + ' | '.join(v+' app cycles' for v in versions) + ' |')
print('|---|' + '---:|' * len(versions))
for name in names:
    values = [str(measurements[m]['application'].get(name,{}).get('cycles','—'))
              for m in measurements]
    print('| {} | {} |'.format(name, ' | '.join(values)))
for name, data in measurements.items():
    print(name, 'Fmax:', data['fmax_mhz'], 'MHz')
