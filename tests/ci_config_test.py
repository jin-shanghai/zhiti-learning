from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

check = (ROOT / '.github/workflows/check.yml').read_text(encoding='utf-8')
release = (ROOT / '.github/workflows/release.yml').read_text(encoding='utf-8')
screenshots = (ROOT / '.github/workflows/screenshots.yml').read_text(encoding='utf-8')
browser_e2e = (ROOT / '.github/workflows/browser-e2e.yml').read_text(encoding='utf-8')
macos_security = (ROOT / '.github/workflows/macos-security.yml').read_text(encoding='utf-8')
pages = (ROOT / '.github/workflows/pages.yml').read_text(encoding='utf-8')
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

linux_workflows = (check, release, screenshots, browser_e2e, pages)
assert all('ubuntu-latest' not in workflow for workflow in linux_workflows), (
    'Linux workflows must pin Ubuntu 24.04 instead of following ubuntu-latest migrations'
)
assert all('runs-on: ubuntu-24.04' in workflow for workflow in linux_workflows)

all_workflows = '\n'.join((*linux_workflows, macos_security))
assert 'actions/checkout@v4' not in all_workflows
assert 'actions/setup-node@v4' not in all_workflows
assert 'actions/setup-python@v5' not in all_workflows
assert all_workflows.count('actions/checkout@v7') == 6
assert all_workflows.count('actions/setup-node@v7') == 4
assert all_workflows.count('actions/setup-python@v7') == 2

for required in (
    'actions/configure-pages@v6',
    'actions/upload-pages-artifact@v5',
    'actions/deploy-pages@v5',
    'pages: write',
    'id-token: write',
    'environment:',
    'name: github-pages',
    'workflow_run:',
    'workflows: [Refresh Screenshots]',
    "github.event.workflow_run.conclusion == 'success'",
    "github.event.workflow_run.head_branch == 'main'",
):
    assert required in pages, f'Pages workflow is missing: {required}'
assert 'persist-credentials: false' in pages
assert 'cancel-in-progress: true' in pages

storage_key = re.search(r"const LS_KEY='([^']+)'", html)
capture_key = re.search(r"localStorage\.setItem\('([^']+)'", capture)
assert storage_key and capture_key, 'unable to read app or screenshot storage key'
assert storage_key.group(1) == capture_key.group(1), 'screenshot seed uses a stale storage key'
assert 'process.env.CHROME_PATH || undefined' in capture
assert "['--no-sandbox', '--disable-setuid-sandbox']" in capture

print('PASS: CI checks, pinned runners/actions, Pages deployment, screenshot capture and release guards')
