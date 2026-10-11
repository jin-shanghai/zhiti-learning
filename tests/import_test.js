const fs=require('fs'),vm=require('vm'),assert=require('assert');
const html=fs.readFileSync(require('path').join(__dirname,'..','index.html'),'utf8');
const start=html.indexOf('async function importCustomBank(event,kind){');
const end=html.indexOf('async function importMultiBank(event){',start);
assert(start>=0&&end>start,'custom import handler was not found');
const source=html.slice(start,end);
const store=new Map();
const ctx={
 QUESTIONS:[{id:1,q:'demo',options:['a','b'],answer:'A',category:'demo'}],
 JUDGMENTS:[{id:'J001',q:'demo',options:['正确','错误'],answer:'A',category:'demo'}],
 JUDGMENT_MAP:{J001:{id:'J001'}},CATEGORIES:['demo'],
 BANK_MC_KEY:'mc',BANK_JUDGE_KEY:'judge',data:{history:{},bookmarks:[],comments:{},sessions:[],exams:[]},
 localStorage:{setItem:(k,v)=>store.set(k,v)},backupCounts:()=>({attempts:0,bookmarks:0,sessions:0,exams:0,comments:0,active:0}),
 confirm:()=>true,alert:()=>{},render:()=>{},
};
vm.createContext(ctx);vm.runInContext(source,ctx);
const fileEvent=content=>({target:{files:[{size:Buffer.byteLength(content),text:async()=>content}],value:'x'}});
(async()=>{
 await ctx.importCustomBank(fileEvent(JSON.stringify({questions:[{q:'New MC',options:['A','B'],answer:'B',category:'Basics'}]})),'mc');
 assert.equal(ctx.QUESTIONS.length,1);assert.equal(ctx.QUESTIONS[0].answer,'B');assert(store.has('mc'));
 const before=ctx.QUESTIONS[0].q;
 await ctx.importCustomBank(fileEvent(JSON.stringify({questions:[{q:'Bad',options:['A','B'],answer:'Z'}]})),'mc');
 assert.equal(ctx.QUESTIONS[0].q,before,'invalid import must not replace current bank');
 await ctx.importCustomBank(fileEvent(JSON.stringify({questions:[{q:'New judge',answer:'错误',category:'Basics'}]})),'judge');
 assert.equal(ctx.JUDGMENTS[0].answer,'B');assert.equal(ctx.JUDGMENT_MAP.J001.answer,'B');assert(store.has('judge'));
 console.log('PASS: valid single/judgment import persists locally; invalid import leaves prior bank unchanged');
})().catch(e=>{console.error(e);process.exit(1)});
