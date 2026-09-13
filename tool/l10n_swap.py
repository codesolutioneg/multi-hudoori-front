# -*- coding: utf-8 -*-
"""Swap whole Arabic literals for `context.t(...)` calls across a file.

Unlike `l10n_apply`, this replaces *every* occurrence — the settings sections
repeat the same labels in a header, an empty state and a dialog, and each one
should read from the same key. Only exact, complete literals are matched, so a
literal that merely contains the text is left alone.

    python3 tool/l10n_swap.py <file> <mapping.json> [import-path]
"""
import json
import re
import sys


def main(path: str, mapping_file: str, import_path: str | None = None) -> None:
    mapping = json.load(open(mapping_file, encoding='utf-8'))
    text = open(path, encoding='utf-8').read()

    swapped = 0
    # Longest first so a label that is a prefix of another cannot win.
    for literal in sorted(mapping, key=len, reverse=True):
        pattern = re.escape(literal)
        hits = len(re.findall(pattern, text))
        if hits:
            text = re.sub(pattern, mapping[literal].replace('\\', '\\\\'), text)
            swapped += hits

    if import_path and f"import '{import_path}';" not in text:
        last = list(re.finditer(r"^import '[^']+';$", text, re.M))[-1]
        text = text[: last.end()] + f"\nimport '{import_path}';" + text[last.end():]

    open(path, 'w', encoding='utf-8').write(text)
    print(f'  {path}: {swapped} literals')


if __name__ == '__main__':
    main(*sys.argv[1:])
