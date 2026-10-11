const {chromium}=require('playwright');const assert=require('assert');
(async()=>{
 const browser=await chromium.launch({headless:true});
 const page=await browser.newPage({viewport:{width:1440,height:900}});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('dialog',dialog=>dialog.accept());
 await page.goto('http://127.0.0.1:8765/index.html',{waitUntil:'domcontentloaded'});
 assert((await page.title()).includes('知题'));
 await page.evaluate(()=>{trainingKind='mixed';trainingOrder='sequential';trainingSize='all';startSession('sequential',{kind:'mixed',size:'all'});});
 let session=await page.evaluate(()=>({ids:data.session.ids,kind:data.session.kind}));
 assert.equal(session.ids.length,10,'six MC + four judgments should produce ten IDs');
 await page.evaluate(()=>{for(const id of data.session.ids){data.session.answers[id]=byId(id).answer;}finishSession(false)});
 assert.equal(await page.evaluate(()=>data.sessions.length),1,'finishing mixed practice should save report');
 assert(await page.locator('#app').innerText().then(t=>t.includes('本轮学习报告')),'result rendered');
 await page.evaluate(()=>{
  data.multiQuestions=[{id:'M001',q:'样例多选',options:['一','二','三'],answer:'AB',category:'其他专题',pattern:'多选判断',kind:'multi'}];
  persist();resetData();
 });
 assert.equal(await page.evaluate(()=>data.multiQuestions.length),1,'reset must preserve multiple-answer questions');
 await page.evaluate(()=>{
  setPage('report');
  if(!document.querySelector('#app').innerText.includes('知识板块答题表现'))throw Error('report not shown');
 });
 await page.evaluate(()=>{setPage('mock')});
 assert(await page.locator('#app').innerText().then(t=>t.includes('模拟考试')));
 const maxButtons=await page.evaluate(()=>document.querySelector('#app').innerText);
 assert(!maxButtons.includes('100题'),'demo bank must not offer 100 questions');
 const mobile=await browser.newPage({viewport:{width:390,height:844},isMobile:true,deviceScaleFactor:1});
 const mobileErrors=[];mobile.on('pageerror',e=>mobileErrors.push(e.message));
 await mobile.goto('http://127.0.0.1:8765/index.html',{waitUntil:'domcontentloaded'});
 await mobile.evaluate(()=>setPage('trainingSetup'));
 assert(await mobile.locator('#app').innerText().then(t=>t.includes('自定义练习')));
 assert.deepStrictEqual(errors,[]);assert.deepStrictEqual(mobileErrors,[]);
 await browser.close();
 console.log('PASS browser: mixed-session report, multi-bank reset, report, mock sizes, mobile view, no runtime errors');
})().catch(e=>{console.error(e);process.exit(1)});
