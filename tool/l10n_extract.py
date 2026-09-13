# -*- coding: utf-8 -*-
"""Dump the Arabic string literals of a Dart file so they can be given keys.

Prints one record per literal: line number, whether it interpolates, and the
raw text. Literals that are plainly not user-facing (map lookups, API argument
values, equality checks) are marked SKIP so they are not translated by mistake.
"""
import pathlib
import re
import sys

AR = re.compile(r'[\u0600-\u06FF]')
LIT = re.compile(r"'(?:[^'\\\n]|\\.)*'")
INTERP = re.compile(r'\$\{[^}]*\}|\$\w+')

# A literal on one of these is a value the code compares or sends, not a label.
SKIP_CONTEXT = re.compile(
    r"==\s*$|!=\s*$|\[\s*$|contains\(|containsKey\(|"
    r"^\s*(case|return)\s+'[^']*'\s*[;:]\s*$"
)


def classify(line: str, lit: str) -> str:
    if 'isAr' in line:
        return 'SKIP'          # already has an English counterpart
    if line.lstrip().startswith('//'):
        return 'SKIP'          # comment
    before = line[: line.index(lit)] if lit in line else ''
    if re.search(r"==\s*$|!=\s*$|contains\(\s*$|startsWith\(\s*$", before):
        return 'SKIP'          # matched against data, not shown
    if re.search(r"\[\s*$", before) and not re.search(r'label|title|text|hint', before, re.I):
        return 'SKIP'
    return 'TEXT'


def scan(path) -> None:
    for i, line in enumerate(path.open(encoding='utf-8'), 1):
        for m in LIT.finditer(line):
            lit = m.group()
            if not AR.search(lit):
                continue
            kind = classify(line, lit)
            interp = 'INTERP' if INTERP.search(lit) else '-'
            print(f'{path}\t{i}\t{kind}\t{interp}\t{lit}')


def main(*paths: str) -> None:
    for raw in paths:
        path = pathlib.Path(raw)
        for f in sorted(path.rglob('*.dart')) if path.is_dir() else [path]:
            scan(f)


if __name__ == '__main__':
    main(*sys.argv[1:])
