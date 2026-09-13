# -*- coding: utf-8 -*-
"""Check that every key is translated in both locales and actually used.

Reports four problems, each of which shows up as Arabic on an English screen
or as a raw key on any screen:

  missing-en   key exists in `ar` but not in `en`
  missing-ar   the mirror case
  arabic-en    the English value still holds Arabic letters
  unknown      a `t()`/`tr()` call whose key is in neither map

Unused keys are counted but not listed; they are harmless.
"""
import pathlib
import re
import sys

AR_LETTERS = re.compile(r'[\u0600-\u06FF]')
STRINGS = pathlib.Path('lib/l10n/app_strings.dart')
CALL = re.compile(r"(?:context\.t|\bt|\btr)\(\s*'([\w.]+)'")


def load_maps() -> tuple[dict, dict]:
    text = STRINGS.read_text(encoding='utf-8')
    blocks = re.findall(
        r'static const (\w+) = <String, String>\{(.*?)\n  \};', text, re.S
    )
    maps = {}
    for name, body in blocks:
        entries = {}
        for m in re.finditer(r"^\s+'([\w.]+)':\s*(?:'(.*)'|\"(.*)\"),$", body, re.M):
            entries[m.group(1)] = m.group(2) if m.group(2) is not None else m.group(3)
        maps[name] = entries
    return maps['ar'], maps['en']


def used_keys() -> set[str]:
    keys = set()
    for f in pathlib.Path('lib').rglob('*.dart'):
        if f == STRINGS:
            continue
        keys |= set(CALL.findall(f.read_text(encoding='utf-8')))
    return keys


def main() -> int:
    ar, en = load_maps()
    used = used_keys()

    missing_en = sorted(set(ar) - set(en))
    missing_ar = sorted(set(en) - set(ar))
    arabic_en = sorted(k for k, v in en.items() if AR_LETTERS.search(v))
    unknown = sorted(k for k in used if k not in ar and k not in en)

    for label, items in (
        ('missing-en', missing_en),
        ('missing-ar', missing_ar),
        ('arabic-en', arabic_en),
        ('unknown', unknown),
    ):
        for k in items:
            print(f'{label}\t{k}' + (f'\t{en.get(k, "")}' if label == 'arabic-en' else ''))

    print(f'\nar={len(ar)} en={len(en)} used={len(used)} unused={len(set(ar) - used)}')
    return 1 if (missing_en or missing_ar or arabic_en or unknown) else 0


if __name__ == '__main__':
    sys.exit(main())
