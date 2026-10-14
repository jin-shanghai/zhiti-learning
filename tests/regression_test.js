const fs=require('fs'),vm=require('vm'),assert=require('assert');
const html=fs.readFileSync(require('path').join(__dirname,'..','index.html'),'utf8');
function section(start,end){const a=html.indexOf(start),b=html.indexOf(end,a);assert(a>=0&&b>a,'section missing: '+start);return html.slice(a,b)}
const simulated=[
{id:1,answer:'A'},{id:2,answer:'B'},{id:3,answer:'A'},{id:4,answer:'A'},{id:5,answer:'B'},{id:6,answer:'A'}
],judges=[{id:'J001',answer:'A'},{id:'J002',answer:'B'},{id:'J003',answer:'A'},{id:'J004',answer:'B'}];
const data={history:{},bookmarks:[],comments:{},multiQuestions:[{id:'M001',q:'multi',options:['a','b','c'],answer:'AB',category:'test'}],session:{type:'sequential',kind:'mixed',filter:{kind:'mixed'},ids:[1,'J001',2,'J002',3,'J003',4,'J004',5,6],answers:{1:'A','J001':'A',2:'B','J002':'B',3:'A','J003':'A',4:'A','J004':'B',5:'B',6:'A'},startedAt:Date.now()-1000,finished:false},sessions:[],exams:[],seqCursorMixed:0};
const ctx={cancelAutoNext:()=>{},data,QUESTIONS:simulated,JUDGMENTS:judges,byId:id=>/^\d+$/.test(String(id))?simulated[Number(id)-1]:judges.find(q=>q.id===id),sessionName:()=> 'mixed',recordAnswer:()=>{},persist:()=>{},setPage:p=>ctx.page=p,reportSelected:null,latestExam:null,Math,Date,JSON,Object,Array,String,Number,console};
vm.createContext(ctx);
vm.runInContext(section('function finishSession(asExam){','function sessionData(){'),ctx);
ctx.finishSession(false);
assert.equal(ctx.data.sessions.length,1,'mixed sequential session should complete');
assert.equal(ctx.data.seqCursorMixed,0,'fully finished mixed session wraps to 0');
ctx.data.session=null;
ctx.freshData=()=>({history:{},bookmarks:[],comments:{},multiQuestions:[],sessions:[],exams:[],session:null});
ctx.confirm=()=>true;ctx.toast=()=>{};ctx.setPage=()=>{};
ctx.safeAIConfig=raw=>raw||{};
ctx.data.aiConfig={provider:'deepseek',model:'test-model',baseUrl:'https://api.deepseek.com'};
vm.runInContext(section('function resetData(){','function toggleMobile(){'),ctx);
ctx.resetData();
assert.equal(ctx.data.multiQuestions.length,1,'reset must preserve imported multiple-answer bank');
assert.equal(ctx.data.aiConfig.provider,'deepseek','study reset must preserve bound AI configuration');
assert(html.includes("bankFingerprints:{mc:bankFingerprint('mc')"),'study backup requires bank fingerprints');
assert(html.includes("parsed.bankFingerprints.mc!==bankFingerprint('mc')"),'restore must validate MC bank identity');
assert(html.includes("escapeHTML(current.pattern)"),'imported pattern must be HTML-escaped');
assert(!html.includes("'\/300'"),'report must use dynamic bank length');

const migrationCode=`
const LS_KEY='zhiti_ai600_v1';
const BANK_MC_KEY='zhiti_user_mc_v1',BANK_JUDGE_KEY='zhiti_user_judge_v1';
const JUDGMENT_BANK_VERSION='zhiti-ai600-judge-explained-20261013';
${section('function freshData(){','migrate();')}
migrate();this.result=data;`;
function migrateStored(stored,customJudge){
 const values=new Map([["zhiti_ai600_v1",JSON.stringify(stored)]]);if(customJudge)values.set('zhiti_user_judge_v1',JSON.stringify(customJudge));
 const migrationCtx={localStorage:{getItem:key=>values.get(key)||null},safeAIConfig:raw=>raw||{},Date,JSON,Object,Array,String,Number,console};
 vm.createContext(migrationCtx);vm.runInContext(migrationCode,migrationCtx);return migrationCtx.result;
}
const oldData={version:7,judgmentBankVersion:'zhiti-ai600-20250527',history:{1:[{ok:true}],J001:[{ok:false}]},bookmarks:[1,'J001'],multiQuestions:[],correctEver:{1:true,J001:true},session:{finished:false,ids:[1,'J001'],answers:{1:'A',J001:'B'}},exams:[{ids:['J001'],answers:{J001:'B'}}],sessions:[{id:'old-report',ids:[1,'J001'],answers:{1:'A',J001:'B'}}],comments:{1:[{text:'mc'}],J001:[{text:'judge'}]},nickname:'我',seqCursor:1,seqCursorJudge:12,seqCursorMixed:9,legacyJudgments:[],autoNextCorrect:true,aiConfig:{},aiCoach:{J001:{explanation:'old',fingerprint:'old'}}};
const migrated=migrateStored(oldData);
assert.equal(migrated.judgmentBankVersion,'zhiti-ai600-judge-explained-20261013');
assert.equal(migrated.version,8);assert(migrated.history[1]);assert(!migrated.history.J001,'old judgment history must leave the active bank');
assert(!migrated.correctEver.J001);assert(!migrated.aiCoach.J001);assert.equal(migrated.session,null);assert.equal(migrated.sessions.length,0);assert.equal(migrated.exams.length,0);
assert.equal(migrated.seqCursorJudge,0);assert.equal(migrated.seqCursorMixed,0);assert.equal(migrated.legacyJudgments.length,1);
assert(migrated.legacyJudgments[0].history.J001);assert(migrated.legacyJudgments[0].aiCoach.J001);assert.equal(migrated.legacyJudgments[0].bank,'判断题旧版300题（无逐题解析）');
const customPreserved=migrateStored(oldData,[{id:'J001',q:'custom'}]);
assert(customPreserved.history.J001,'a locally imported judgment bank must keep its matching history');assert.equal(customPreserved.legacyJudgments.length,0);
console.log('PASS: mixed session, bank migration archive, preserve custom bank, fingerprint identity and escaped labels');
