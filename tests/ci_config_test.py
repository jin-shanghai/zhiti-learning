from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

check = (ROOT / '.github/workflows/check.yml').read_text(encoding='utf-8')
release = (ROOT / '.github/workflows/release.yml').read_text(encoding='utf-8')
screenshots = (ROOT / '.github/workflows/screenshots.yml').read_text(encoding='utf-8')
capture = (ROOT / 'scripts/capture-screenshots.js').read_text(encoding='utf-8')
html = (ROOT / 'index.html').read_text(encoding='utf-8')

for command in (
    'python3 tests/smoke_test.py',
    'node tests/regression_test.js',
    'node tests/import_test.js',
    'python3 tests/ci_config_test.py',
):
    assert command in check, f'Check workflow is missing: {command}'
    assert command in release, f'Release workflow is missing: {command}'

assert "gh release view \"$tag\"" in release, 'repeat releases must be idempotent'
assert '--title "知题 ZHITI · v${{ steps.version.outputs.version }}"' in release
assert "if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'" in release

assert 'npx playwright install --with-deps chromium' in screenshots
assert "if: github.event_name != 'pull_request'" in screenshots
assert 'git rebase origin/main && git push origin HEAD:main' in screenshots
assert 'refresh-screenshots-${{ github.ref }}' in screenshots

storage_key = re.search(r"const LS_KEY='([^']+)'", html)
capture_key = re.search(r"localStorage\.setItem\('([^']+)'", capture)
assert storage_key and capture_key, 'unable to read app or screenshot storage key'
assert storage_key.group(1) == capture_key.group(1), 'screenshot seed uses a stale storage key'
assert 'process.env.CHROME_PATH || undefined' in capture
assert "['--no-sandbox', '--disable-setuid-sandbox']" in capture

assert not (ROOT / '.github/workflows/pages.yml').exists(), (
    'custom Pages workflow conflicts with the repository native branch deployment'
)

print('PASS: CI checks, native Pages mode, screenshot capture and release guards')
