# -*- coding: utf-8 -*-
"""Apply a batch of localisation edits and add the keys to both locales.

Reads a JSON job:

    {
      "keys":  {"key": {"ar": "...", "en": "..."}},
      "files": {"path.dart": [["old snippet", "new snippet"], ...]},
      "import": "../../l10n/l10n_extension.dart"   // per file, optional
    }

Every snippet must match exactly once or the run aborts, so a stale job never
half-applies.
"""
import json
import re
import sys

STRINGS = 'lib/l10n/app_strings.dart'


def add_keys(keys: dict) -> int:
    src = open(STRINGS, encoding='utf-8').read()
    mid = src.index("    'common.cancel': 'Cancel',")
    ar_block, en_block = src[:mid], src[mid:]
    existing = set(re.findall(r"^\s+'([\w.]+)':", ar_block, re.M))

    def quote(text: str) -> str:
        """An apostrophe in English copy would close a single-quoted literal."""
        return f'"{text}"' if "'" in text and '"' not in text else f"'{text}'"

    ar_add, en_add = [], []
    for k, v in keys.items():
        if k in existing:
            continue
        ar_add.append(f"    '{k}': {quote(v['ar'])},\n")
        en_add.append(f"    '{k}': {quote(v['en'])},\n")

    if not ar_add:
        return 0

    ar_anchor = "    'common.cancel': 'إلغاء',\n"
    en_anchor = "    'common.cancel': 'Cancel',\n"
    ar_block = ar_block.replace(ar_anchor, ar_anchor + ''.join(ar_add), 1)
    en_block = en_block.replace(en_anchor, en_anchor + ''.join(en_add), 1)
    open(STRINGS, 'w', encoding='utf-8').write(ar_block + en_block)
    return len(ar_add)


def edit_file(path: str, pairs: list, import_line: str | None) -> None:
    text = open(path, encoding='utf-8').read()
    for old, new in pairs:
        hits = text.count(old)
        if hits != 1:
            raise SystemExit(f'{path}: snippet matched {hits}x, expected 1:\n  {old[:120]!r}')
        text = text.replace(old, new, 1)
    if import_line and import_line not in text:
        anchor = re.search(r"^import '[^']+';\n(?!import)", text, re.M)
        text = text[: anchor.end()] + f"import '{import_line}';\n" + text[anchor.end():]
    open(path, 'w', encoding='utf-8').write(text)


def main(job_path: str) -> None:
    job = json.load(open(job_path, encoding='utf-8'))
    added = add_keys(job.get('keys', {}))
    for path, pairs in job.get('files', {}).items():
        edit_file(path, pairs, job.get('import'))
        print(f'  {path}: {len(pairs)} edits')
    print(f'keys added: {added}')


if __name__ == '__main__':
    main(sys.argv[1])
