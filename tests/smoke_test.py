from html.parser import HTMLParser
from pathlib import Path
import subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
html=(ROOT/'index.html').read_text(encoding='utf-8')
class Scripts(HTMLParser):
 def __init__(self): super().__init__(); self.active=False; self.parts=[]; self.current=[]
 def handle_starttag(self,tag,attrs):
  if tag=='script': self.active=True; self.current=[]
 def handle_endtag(self,tag):
  if tag=='script' and self.active: self.parts.append(''.join(self.current)); self.active=False
 def handle_data(self,data):
  if self.active:self.current.append(data)
p=Scripts();p.feed(html)
assert p.parts,'no embedded JS found'
subprocess.run(['node',str(ROOT/'tests'/'import_test.js')],check=True,capture_output=True,text=True)
with tempfile.TemporaryDirectory() as td:
 for i,js in enumerate(p.parts):
  f=Path(td)/f'script-{i}.js';f.write_text(js,encoding='utf-8')
  subprocess.run(['node','--check',str(f)],check=True,capture_output=True,text=True)
assert (ROOT/'VERSION').read_text(encoding='utf-8').strip()=='1.0.0'
assert 'V1 正式版' in html
assert 'zhiti_ai600_v1' in html
assert 'importCustomBank(event' in html
assert '[NOTICE](NOTICE)' in (ROOT/'README.md').read_text(encoding='utf-8')
assert 'commercial use' in (ROOT/'README.en.md').read_text(encoding='utf-8').lower()
assert 'MIT License' in (ROOT/'LICENSE').read_text(encoding='utf-8')
assert '@media(max-width:570px)' in html
repo_url='https://github.com/jin-shanghai/zhiti-learning'
assert f'href="{repo_url}"' in html
assert 'target="_blank" rel="noopener noreferrer"' in html
assert 'http://' not in html and 'https://' not in html.replace(repo_url,'')
assert 'async function importCustomBank' in html
assert 'if(Object.values(data.history' not in html
import json,re
for name,min_count in [('QUESTIONS',300),('JUDGMENTS',300)]:
 match=re.search(r'let '+name+r'=(\[.*?\]);',html)
 assert match, f'{name} bank missing'
 rows=json.loads(match.group(1));assert len(rows)==min_count
 ids=[str(row['id']) for row in rows];assert len(ids)==len(set(ids))
 for row in rows:
  assert row.get('q') and row.get('answer') and len(row.get('options',[]))>=2
assert 'zhiti_v6_ai600' not in html
print('PASS: embedded JavaScript syntax; 600-question bundled bank integrity; local import hooks; license/docs; mobile breakpoint')
