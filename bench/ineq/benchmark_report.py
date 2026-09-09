#!/usr/bin/env python3
"""Fill only the eight inequality benchmark rows from checked application logs.

Usage: python3 bench/ineq/benchmark_report.py ineq-v4
Preserves the course workbook's formatting; leaves the project column blank.
"""
import hashlib
import json
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
version = sys.argv[1]
base = ROOT / 'logs' / version
inputs = json.loads((ROOT / 'bench/ineq/puzzles/benchmark_sources.json').read_text())
build = json.loads((base / 'build_source.json').read_text())
timing = (base / 'synthesis/ineqsudx_scan.sta.rpt').read_text()
frequencies = re.findall(r';\s*([\d.]+) MHz\s*;[^\n]*;\s*clk\s*;', timing)
frequency = min(map(float, frequencies))
rows = []
for board in inputs['board_order']:
    label = board.replace('/', '_')
    log = base / 'benchmark-app' / (label + '.app.log')
    text = log.read_text()
    assert 'PASSED basic Sudoku checker' in text, board
    assert 'PASSED inequalities checker' in text, board
    assert 'FAILED' not in text and 'FAIL:' not in text, board
    cycles = int(re.search(r'Sudoku solve\s+(\d+) cycles', text).group(1))
    for line in log.with_name(label + '.sources.sha256').read_text().splitlines():
        digest, name = line.split(None, 1)
        source = 'hw/xlrs/ineqsudx_scan/' + Path(name).name
        assert digest == build['source_sha256'][source], source
    rows.append({'board': board, 'application_cycles': cycles, 'checkers_passed': True})
assert len(rows) == 8
for name, digest in inputs['sha256'].items():
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name

total = sum(row['application_cycles'] for row in rows)
summary = {'version': version, 'course_commit': inputs['course_commit'],
           'build_commit': build['build_commit'], 'rows': rows,
           'standalone_fmax_mhz': frequency, 'total_cycles': total,
           'normalized_total_us': total / frequency, 'hardware_execution_tested': False}
(base / 'benchmark_summary.json').write_text(json.dumps(summary, indent=2) + '\n')


def replace_cell(xml, reference, content, inline=False):
    """Replace one cell's contents while retaining its original style."""
    pattern = r'<c r="' + reference + r'"([^>]*?)(?:/>|>.*?</c>)'

    def replacement(match):
        attributes = re.sub(r'\s+t="[^"]*"', '', match.group(1))
        cell_type = ' t="inlineStr"' if inline else ''
        return '<c r="' + reference + '"' + attributes + cell_type + '>' + content + '</c>'

    result, count = re.subn(pattern, replacement, xml)
    assert count == 1, reference
    return result


destination = ROOT / 'docs' / ('benchmark-' + version + '-complete.xlsx')
with zipfile.ZipFile(str(ROOT / 'docs/course/sud_benchmark.xlsx')) as original, \
        zipfile.ZipFile(str(destination), 'w', zipfile.ZIP_DEFLATED) as output:
    for item in original.infolist():
        data = original.read(item.filename)
        if item.filename == 'xl/worksheets/sheet1.xml':
            xml = data.decode()
            for cell in ['C4', 'C6', 'D6', 'C7', 'D7', 'C8', 'D8', 'C9', 'D9',
                         'C10', 'D10', 'C11', 'D11', 'C19', 'C20']:
                xml = replace_cell(xml, cell, '')
            title = 'Complete inequality benchmark — ' + version + ' (project column blank)'
            for cell, text in [('A2', title), ('A19', 'Total cycles'), ('A20', 'Time (µs)')]:
                xml = replace_cell(xml, cell, '<is><t>' + text + '</t></is>', inline=True)
            xml = replace_cell(xml, 'E4', '<v>' + str(frequency) + '</v>')
            for number, row in enumerate(rows, 10):
                xml = replace_cell(xml, 'E' + str(number), '<v>' + str(row['application_cycles']) + '</v>')
                xml = replace_cell(xml, 'F' + str(number), '<is><t>Y</t></is>', inline=True)
            xml = replace_cell(xml, 'E19', '<f>SUM(E6:E17)</f><v>' + str(total) + '</v>')
            xml = replace_cell(xml, 'E20', '<f>E19/E4</f><v>' + str(total / frequency) + '</v>')
            ET.fromstring(xml)  # Catch malformed XML before publishing the workbook.
            data = xml.encode()
        output.writestr(item, data)
print('{}: {} cycles / {:.2f} MHz = {:.4f} us'.format(version, total, frequency, total / frequency))
print(destination)
