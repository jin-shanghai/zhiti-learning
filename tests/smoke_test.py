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
import re
version=(ROOT/'VERSION').read_text(encoding='utf-8').strip()
assert re.fullmatch(r'\d+\.\d+\.\d+',version), 'invalid release version'
assert f'v{version}' in (ROOT/'README.md').read_text(encoding='utf-8')
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
assert not re.search(r'<(?:script|link)[^>]+(?:src|href)="https?://',html), 'remote runtime dependency'
assert 'async function importCustomBank' in html
assert 'if(Object.values(data.history' not in html
import json
embedded={}
for name,min_count in [('QUESTIONS',300),('JUDGMENTS',300)]:
 match=re.search(r'let '+name+r'=(\[.*?\]);',html)
 assert match, f'{name} bank missing'
 rows=json.loads(match.group(1));embedded[name]=rows;assert len(rows)==min_count
 ids=[str(row['id']) for row in rows];assert len(ids)==len(set(ids))
 for row in rows:
  assert row.get('q') and row.get('answer') and len(row.get('options',[]))>=2
judgments=embedded['JUDGMENTS']
assert [row['id'] for row in judgments]==[f'J{i:03d}' for i in range(1,301)]
assert sum(row['answer']=='A' for row in judgments)==152
assert sum(row['answer']=='B' for row in judgments)==148
assert len({row['category'] for row in judgments})==17
assert all(row.get('kind')=='judge' and row.get('explanation') and row.get('step') for row in judgments)
assert all('未提供解析' not in row['explanation'] for row in judgments)
assert not any('答题规律小结' in row['explanation'] or '猜题技巧' in row['explanation'] for row in judgments)
assert {row['sourceNo'] for row in judgments if row.get('risk')}=={2,9,19,36,58,70,125,165,203,204,256}
assert not any('阅读须知' in row['q'] or '答题规律小结' in row['q'] for row in judgments)
assert "const JUDGMENT_BANK_VERSION='zhiti-ai600-judge-explained-20261013'" in html
assert 'zhiti_v6_ai600' not in html
print('PASS: embedded JavaScript syntax; explained 600-question bundled bank integrity; local import hooks; license/docs; mobile breakpoint')
