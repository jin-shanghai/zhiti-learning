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
vm.runInContext(section('function resetData(){','function toggleMobile(){'),ctx);
ctx.resetData();
assert.equal(ctx.data.multiQuestions.length,1,'reset must preserve imported multiple-answer bank');
assert(html.includes("bankFingerprints:{mc:bankFingerprint('mc')"),'study backup requires bank fingerprints');
assert(html.includes("parsed.bankFingerprints.mc!==bankFingerprint('mc')"),'restore must validate MC bank identity');
assert(html.includes("escapeHTML(current.pattern)"),'imported pattern must be HTML-escaped');
assert(!html.includes("'\/300'"),'report must use dynamic bank length');
console.log('PASS: mixed session, preserve imported bank, fingerprint identity and escaped labels');
