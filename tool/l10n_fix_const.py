# -*- coding: utf-8 -*-
"""Drop the `const` keywords that a context.t() call has just invalidated.

Turning a literal into a method call makes the enclosing const expression
illegal. Rather than analyse once per fix, this collects every reported line in
a pass and strips the whole batch before re-analysing, which keeps a large file
to two or three analyzer runs instead of dozens.
"""
import re
import subprocess
import sys

ERR = r':(\d+):\d+ • (?:const_eval_method_invocation|const_with_non_constant_argument|invalid_constant|non_constant_[\w]+)'


def analyze(paths: list[str]) -> dict[str, list[int]]:
    """Reported paths are always files, so a directory argument is expanded."""
    out = subprocess.run(['flutter', 'analyze', *paths], capture_output=True, text=True).stdout
    found: dict[str, list[int]] = {}
    for m in re.finditer(r'(\S+\.dart)' + ERR, out):
        if m.group(1).endswith('app_strings.dart'):
            continue           # the translation tables, never a widget tree
        found.setdefault(m.group(1), []).append(int(m.group(2)))
    return {p: sorted(set(v)) for p, v in found.items()}


# A `const` here belongs to a declaration, not to the widget tree above the
# error, and removing it changes meaning or breaks the file outright. The `({`
# is what separates a constructor declaration from a widget being built.
PROTECTED = re.compile(r'static\s+const|const\s+\w+\(\{|super\(|=\s*const\s')


def strip_enclosing_const(lines: list[str], target: int) -> bool:
    """Remove the `const` that opens the expression containing line `target`."""
    i = target - 1
    indent = lambda s: len(s) - len(s.lstrip())
    base = indent(lines[i])
    for j in range(i, max(-1, i - 80), -1):
        s = lines[j]
        if 'const' not in s or PROTECTED.search(s):
            continue
        if j != i and indent(s) > base:
            continue
        new = re.sub(r'\bconst\s+', '', s, count=1)
        if new != s:
            lines[j] = new
            return True
    return False


def main(paths: list[str]) -> None:
    for _ in range(8):
        found = analyze(paths)
        if not found:
            print('const errors: 0')
            return
        changed = False
        for path, targets in found.items():
            lines = open(path, encoding='utf-8').read().split('\n')
            # Work bottom-up so earlier line numbers stay valid.
            for ln in sorted(targets, reverse=True):
                changed |= strip_enclosing_const(lines, ln)
            open(path, 'w', encoding='utf-8').write('\n'.join(lines))
        if not changed:
            print('stuck:', {p: v[:5] for p, v in found.items()})
            return
    print('gave up after 8 rounds:', {p: v[:5] for p, v in analyze(paths).items()})


if __name__ == '__main__':
    main(sys.argv[1:])
