"""Compile every Luau file, build both places, and run all real test suites.
Uses pinned local tools when available, otherwise executables from PATH.
"""
from pathlib import Path
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)
os.environ['PATH'] = str(ROOT / '.tooling' / 'bin') + os.pathsep + os.environ.get('PATH', '')

def run(*args):
    print('+ ' + ' '.join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), check=True)

for tool in ('luau', 'luau-compile', 'lune', 'rojo'):
    if not shutil.which(tool):
        raise SystemExit(f'{tool} is missing. Run tools/bootstrap.sh on Linux x86_64 or install the pinned versions.')
sources = sorted(Path('src').rglob('*.lua'))
checks = sorted(Path('tests').rglob('*.luau')) + sorted(Path('tools').rglob('*.luau'))
run('luau-compile', '--null', *sources, *checks)
Path('dist').mkdir(exist_ok=True)
intermediate = Path('dist/CatchMeIfYouCan.sources.rbxlx')
run('rojo', 'build', 'default.project.json', '-o', intermediate)
run('lune', 'run', 'tools/bake-place.luau', intermediate)
intermediate.unlink()
run('luau', 'tests/rules.spec.luau')
for name in ('data_service', 'gameplay', 'appearance', 'cosmetics', 'client_controllers', 'map', 'mall', 'hub', 'enums'):
    run('lune', 'run', f'tests/{name}.spec.luau')
run('git', 'diff', '--check')
print(f'PASS: {len(sources)} production scripts compiled; ten test suites; both Studio place formats validated.')
print('This does not run the Roblox engine. Complete docs/TESTING.md in Studio before launch.')
