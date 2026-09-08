#!/usr/bin/env python3
"""Prepare deterministic tests; no puzzle-specific information enters RTL."""
from pathlib import Path
import random

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'bench/ineq/puzzles'
OUT.mkdir(exist_ok=True)


def record(name, board, fail=0):
    assert len(board) == 81
    return '{} {} {}\n'.format(name, fail, ''.join('{:02x}'.format(x) for x in board))


official = []
shared = ROOT / 'sw/apps/sud_shared'
for path in sorted(shared.rglob('*.txt')):
    board = [int(x, 16) for x in path.read_text().split()]
    name = str(path.relative_to(shared))[len('sudoku_input_'):-4]
    fail = int('p6_contradiction' in name or 'p7_impossible' in name)
    official.append(record(name, board, fail))
(OUT / 'official.txt').write_text(''.join(official))

classic = []
for group in ['top95', 'gen_classic_min', 'ho_hardest', 'ho_published', 'corners']:
    for i, line in enumerate((ROOT / 'bench/puzzles' / (group+'.txt')).read_text().splitlines()):
        if len(line) >= 81:
            classic.append(record(group+'_'+str(i), [int(x) if x != '.' else 0 for x in line[:81]]))
(OUT / 'classic.txt').write_text(''.join(classic))

# Different row/column permutations and digit orders; recompute inequalities
# from each resulting solution because digit permutations do not preserve order.
rng = random.Random(260908)
generated = []
for i in range(300):
    def shuffled(values):
        values = list(values)
        rng.shuffle(values)
        return values
    rows = [3*b+k for b in shuffled(range(3)) for k in shuffled(range(3))]
    cols = [3*b+k for b in shuffled(range(3)) for k in shuffled(range(3))]
    digits = shuffled(range(1, 10))
    solution = [digits[(r*3+r//3+c)%9] for r in rows for c in cols]
    clue_density = [0.0, 0.1, 0.25, 0.45, 0.8][i%5]
    edge_density = [0.0, 0.05, 0.2, 0.5, 1.0][(i//5)%5]
    board = [v if rng.random()<clue_density else 0 for v in solution]
    for c in range(81):
        for shift, neighbor, valid in [(6,c+1,c%9<8), (4,c+9,c//9<8)]:
            if valid and rng.random()<edge_density:
                code = 1 if solution[c]<solution[neighbor] else 2
            elif valid:
                code = rng.choice([0,3])
            else:
                code = rng.randrange(4)  # All boundary encodings must be ignored.
            board[c] |= code << shift
    generated.append(record('generated_'+str(i), board))
(OUT / 'generated.txt').write_text(''.join(generated))

# Add constraints to independently checked difficult classic solutions. This
# complements the patterned Latin-square generator with different puzzle roots.
solutions = {}
for line in (ROOT / 'logs/ineq-v0/classic/cycles.txt').read_text().splitlines():
    parts = line.split()
    if parts[0].startswith('top95_'):
        solutions[parts[0]] = [int(x) for x in parts[-1]]
heldout = []
for line in classic:
    name, _, encoded = line.split()
    if name not in solutions:
        continue
    solution = solutions[name]
    givens = [int(encoded[i:i+2], 16) for i in range(0,162,2)]
    for density in [0.05, 0.2, 0.75]:
        board = list(givens)
        for c in range(81):
            for shift, neighbor, valid in [(6,c+1,c%9<8), (4,c+9,c//9<8)]:
                if valid and rng.random() < density:
                    board[c] |= (1 if solution[c]<solution[neighbor] else 2) << shift
        heldout.append(record(name+'_ineq_'+str(density), board))
(OUT / 'heldout.txt').write_text(''.join(heldout))

rejects = []
for i, line in enumerate((ROOT / 'bench/puzzles/unsat.txt').read_text().splitlines()):
    if len(line) >= 81:
        rejects.append(record('classic_unsat_'+str(i), [int(x,16) if x != '.' else 0 for x in line[:81]], 1))
(OUT / 'rejects.txt').write_text(''.join(rejects))
print('Prepared {} official, {} classic, {} generated boards'.format(
    len(official), len(classic), len(generated)))
print('Added {} difficult inequality boards and {} rejection cases'.format(len(heldout),len(rejects)))
