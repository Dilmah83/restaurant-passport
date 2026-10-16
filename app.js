'use strict';
const $=s=>document.querySelector(s);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const TYPES=['Italian','Chinese','Japanese','Thai','Indian','Pizza','Pub','Steakhouse','Seafood','Cafe','Fast food','Mexican','Bakery','Other'];
const uid=()=>Date.now().toString(36)+Math.random().toString(36).slice(2,7);
const today=()=>{const d=new Date();return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0')};
const str=x=>String(x??'').trim(), num=(x,d=0)=>{const n=parseFloat(x);return isFinite(n)&&n>=0?n:d};
const aud=n=>'$'+(+n||0).toLocaleString('en-AU',{minimumFractionDigits:2,maximumFractionDigits:2});
const stars=r=>'★'.repeat(r)+'☆'.repeat(5-r), cpp=v=>v.total/v.people;
const key=x=>(x.name+'|'+x.suburb).toLowerCase().trim();
const loc=x=>[x.suburb,x.city,x.country].filter(Boolean).join(', ');
const fd=d=>new Date(d+'T00:00:00').toLocaleDateString('en-AU',{day:'numeric',month:'short',year:'numeric'});
let S={visits:[],wants:[]},tab='home',F={q:'',min:0,type:'',sort:'new'},W='new',X={};
function cleanVisit(v){if(!v||typeof v!=='object'||!str(v.name))return null;
 return{id:str(v.id)||uid(),name:str(v.name),suburb:str(v.suburb),city:str(v.city),country:str(v.country)||'Australia',date:/^\d{4}-\d\d-\d\d$/.test(v.date)?v.date:today(),type:str(v.type)||'Other',rating:Math.min(5,Math.round(num(v.rating))),total:num(v.total),people:Math.max(1,Math.round(num(v.people,1))),order:str(v.order),notes:str(v.notes),fav:!!v.fav,again:v.again==='yes'||v.again==='no'?v.again:'',photo:typeof v.photo==='string'&&v.photo.startsWith('data:image/')?v.photo:''}}
function cleanWant(w){if(!w||typeof w!=='object'||!str(w.name))return null;
 return{id:str(w.id)||uid(),name:str(w.name),suburb:str(w.suburb),city:str(w.city),country:str(w.country)||'Australia',type:str(w.type)||'Other',price:['$','$$','$$$','$$$$'].includes(w.price)?w.price:'',why:str(w.why)}}
// storage (IndexedDB)
const db=()=>new Promise((ok,no)=>{const r=indexedDB.open('passport',1);r.onupgradeneeded=()=>r.result.createObjectStore('kv');r.onsuccess=()=>ok(r.result);r.onerror=()=>no(r.error)});
async function load(){try{const d=await db();return await new Promise(ok=>{const q=d.transaction('kv').objectStore('kv').get('state');q.onsuccess=()=>ok(q.result);q.onerror=()=>ok(null)})}catch(e){return null}}
async function save(){try{const d=await db();await new Promise((ok,no)=>{const t=d.transaction('kv','readwrite');t.objectStore('kv').put(S,'state');t.oncomplete=ok;t.onerror=()=>no(t.error)})}catch(e){alert('Could not save your data: '+e.message+'. Please make a backup now.')}}
// views
const bars=r=>{const m=Math.max(...r.map(x=>x[1]),1);return r.map(x=>`<div class="bar"><span>${esc(x[0])}</span><i style="--w:${x[1]/m*100}%"></i><b>${esc(x[2])}</b></div>`).join('')};
const card=v=>`<div class="card" data-a="view" data-id="${v.id}"><div class="top"><b>${v.fav?'♥ ':''}${esc(v.name)}</b><span class="stars">${stars(v.rating)}</span></div><div class="sub">${esc(loc(v))}</div><div class="sub">${fd(v.date)} · ${esc(v.type)} · ${aud(v.total)} (${aud(cpp(v))} each)</div></div>`;
function viewHome(){const v=S.visits;if(!v.length)return`<div class="empty"><h2>Your passport is empty</h2><p>Tap the + button to add your first restaurant visit.</p></div>`;
 const g={},mo={},ty={};let rs=0,rn=0,tot=0,pp=0;
 v.forEach(x=>{const o=g[key(x)]??={name:x.name,n:0,rs:0,rn:0};o.n++;if(x.rating){o.rs+=x.rating;o.rn++;rs+=x.rating;rn++}tot+=x.total;pp+=cpp(x);mo[x.date.slice(0,7)]=(mo[x.date.slice(0,7)]||0)+x.total;ty[x.type]??={n:0,s:0};ty[x.type].n++;ty[x.type].s+=x.total});
 const gs=Object.values(g),top=(a,f,n=5)=>a.sort(f).slice(0,n);
 const months=Object.entries(mo).sort().slice(-12);
 return`<div class="grid"><div class="stat"><b>${gs.length}</b><span>Restaurants (unique)</span></div><div class="stat"><b>${v.length}</b><span>Total visits</span></div>
 <div class="stat"><b>${aud(tot)}</b><span>Total spent</span></div><div class="stat"><b>${rn?(rs/rn).toFixed(1)+' ★':'–'}</b><span>Average rating</span></div>
 <div class="stat"><b>${aud(tot/v.length)}</b><span>Average per visit</span></div><div class="stat"><b>${aud(pp/v.length)}</b><span>Average per person</span></div></div>
 <h2>Most visited</h2>${bars(top(gs.slice(),(a,b)=>b.n-a.n).map(x=>[x.name,x.n,x.n+'×']))}
 <h2>Highest rated</h2>${bars(top(gs.filter(x=>x.rn).map(x=>({...x,a:x.rs/x.rn})),(a,b)=>b.a-a.a||b.n-a.n).map(x=>[x.name,x.a,x.a.toFixed(1)+' ★']))||'<p class="sub">Rate a visit to see this.</p>'}
 <h2>Favourite cuisines</h2>${bars(top(Object.entries(ty),(a,b)=>b[1].n-a[1].n,6).map(([k,o])=>[k,o.n,o.n+' visits']))}
 <h2>Spending by month</h2>${bars(months.map(([k,s])=>[k,s,aud(s)]))}
 <h2>Spending by category</h2>${bars(Object.entries(ty).sort((a,b)=>b[1].s-a[1].s).map(([k,o])=>[k,o.s,aud(o.s)]))}
 <h2>Recent visits</h2>${v.slice().sort((a,b)=>b.date.localeCompare(a.date)).slice(0,5).map(card).join('')}`}
function list(){let r=S.visits.filter(v=>v.rating>=F.min&&(!F.type||v.type===F.type));const q=F.q.toLowerCase();
 if(q)r=r.filter(v=>[v.name,v.suburb,v.city,v.country,v.type,v.order,v.notes].join(' ').toLowerCase().includes(q));
 r.sort(F.sort==='rating'?(a,b)=>b.rating-a.rating:F.sort==='cost'?(a,b)=>b.total-a.total:(a,b)=>b.date.localeCompare(a.date));
 return r.length?r.map(card).join(''):'<div class="empty">No visits match.</div>'}
const opts=(a,sel)=>a.map(([v,l])=>`<option value="${esc(v)}" ${String(v)===String(sel)?'selected':''}>${esc(l)}</option>`).join('');
function viewHistory(){const ts=[...new Set(S.visits.map(v=>v.type))].sort();
 return`<input id="q" type="search" placeholder="Search name, place, dish, notes" value="${esc(F.q)}"><div class="row"><label>Minimum rating<select id="fmin">${opts([[0,'Any'],[1,'1+'],[2,'2+'],[3,'3+'],[4,'4+'],[5,'5']],F.min)}</select></label><label>Cuisine<select id="ftype">${opts([['','All'],...ts.map(t=>[t,t])],F.type)}</select></label></div>
 <label>Sort by<select id="fsort">${opts([['new','Newest'],['rating','Highest rated'],['cost','Most expensive']],F.sort)}</select></label><div id="list">${list()}</div>`}
function viewWant(){const gk={loc:w=>w.suburb||w.city||'No location',type:w=>w.type,price:w=>w.price||'No price',new:()=>''}[W];
 const r=S.wants.slice().sort((a,b)=>W==='new'?0:gk(a).localeCompare(gk(b)));let last=null;
 return`<label>View by<select id="wsort">${opts([['new','Date added'],['loc','Location'],['type','Cuisine'],['price','Price']],W)}</select></label><button class="p" data-a="addwant">+ Add restaurant</button>`+
 (r.length?r.map(w=>{const h=gk(w)!==last&&W!=='new'?`<div class="gh">${esc(last=gk(w))}</div>`:'';return h+`<div class="card"><b>${esc(w.name)}</b> <span class="sub">${esc(w.price)}</span><div class="sub">${esc([w.suburb,w.city].filter(Boolean).join(', '))} · ${esc(w.type)}</div>${w.why?`<p>${esc(w.why)}</p>`:''}<button class="p" data-a="wvisit" data-id="${w.id}">Mark visited</button><button data-a="wedit" data-id="${w.id}">Edit</button><button class="d" data-a="wdel" data-id="${w.id}">Remove</button></div>`}).join(''):'<div class="empty">Nothing saved yet. Add places you want to try.</div>');}
function viewMore(){const lb=localStorage.getItem('lastBackup');
 return`<h2>Backup and restore</h2><p class="sub">Last backup: ${lb?fd(lb):'never'}. ${S.visits.length} visits and ${S.wants.length} saved places on this phone.</p>
 <button class="p" data-a="xjson">Save backup (JSON)</button><button data-a="xcsv">Export spreadsheet (CSV)</button>
 <label>Restore from a backup file<input id="imp" type="file" accept=".json,application/json"></label>
 <h2>Please read</h2><p>Your data is stored only inside Safari on this iPhone. It is <b>not</b> synced anywhere. If you change phones, delete the app and its website data, or clear Safari history and website data, it will be lost unless you have a backup. Save a backup regularly and store it in iCloud Drive (choose "Save to Files").</p>
 <button class="d" data-a="erase">Erase everything</button>`}
function render(){document.querySelectorAll('#tabs button').forEach(b=>b.classList.toggle('on',b.dataset.id===tab));
 $('#main').innerHTML={home:viewHome,history:viewHistory,want:viewWant,more:viewMore}[tab]();$('#fab').hidden=tab==='more';window.scrollTo(0,0)}
// modal + forms
const modal=h=>{$('#modal').innerHTML=`<div class="sheet">${h}</div>`;$('#modal').hidden=false};
const close=()=>{$('#modal').hidden=true;$('#modal').innerHTML=''};
const starBtns=n=>[1,2,3,4,5].map(i=>`<button type="button" data-a="star" data-id="${i}" aria-label="${i} stars">${i<=n?'★':'☆'}</button>`).join('');
const typeOpts=t=>opts([...new Set([...TYPES,t].filter(Boolean))].map(x=>[x,x]),t||'Italian');
function visitForm(v,wantId){const edit=S.visits.some(x=>x.id===v.id);X={id:edit?v.id:null,wantId:wantId||null,rating:v.rating||0,photo:v.photo||''};
 modal(`<h2>${edit?'Edit visit':'Add visit'}</h2><label>Restaurant name *<input id="f_name" value="${esc(v.name)}"></label>
 <div class="row"><label>Suburb<input id="f_suburb" value="${esc(v.suburb)}"></label><label>City<input id="f_city" value="${esc(v.city)}"></label></div>
 <label>Country<input id="f_country" value="${esc(v.country||'Australia')}"></label>
 <div class="row"><label>Date visited<input id="f_date" type="date" value="${v.date||today()}"></label><label>Type<select id="f_type">${typeOpts(v.type)}</select></label></div>
 <div class="sub">Your rating</div><div id="stars">${starBtns(X.rating)}</div>
 <div class="row"><label>Total cost (AUD)<input id="f_total" type="number" inputmode="decimal" min="0" step="0.01" value="${v.total||''}"></label><label>Number of people<input id="f_people" type="number" inputmode="numeric" min="1" value="${v.people||1}"></label></div>
 <p class="cpp" id="cpp"></p><label>What I ordered<textarea id="f_order" rows="2">${esc(v.order)}</textarea></label>
 <label>Notes (food, service, atmosphere)<textarea id="f_notes" rows="3">${esc(v.notes)}</textarea></label>
 <label>Would I visit again?<select id="f_again">${opts([['','Not sure'],['yes','Yes'],['no','No']],v.again)}</select></label>
 <label class="ck"><input id="f_fav" type="checkbox" ${v.fav?'checked':''}> Favourite restaurant</label>
 <label>Photo<input id="f_photo" type="file" accept="image/*"></label><div id="pv">${X.photo?`<img class="ph" src="${X.photo}">`:''}</div>
 <button class="p" data-a="savev">Save</button><button data-a="close">Cancel</button>`);cppUpd()}
function cppUpd(){const t=num($('#f_total')?.value),p=Math.max(1,num($('#f_people')?.value,1));if($('#cpp'))$('#cpp').textContent='Cost per person: '+aud(t/p)}
function wantForm(w){X={wid:w.id||null};modal(`<h2>${w.id?'Edit place':'Add place to try'}</h2><label>Restaurant name *<input id="w_name" value="${esc(w.name)}"></label>
 <div class="row"><label>Suburb<input id="w_suburb" value="${esc(w.suburb)}"></label><label>City<input id="w_city" value="${esc(w.city)}"></label></div>
 <div class="row"><label>Type<select id="w_type">${typeOpts(w.type)}</select></label><label>Price<select id="w_price">${opts([['','Unknown'],['$','$ cheap'],['$$','$$ moderate'],['$$$','$$$ pricey'],['$$$$','$$$$ splurge']],w.price)}</select></label></div>
 <label>Why do I want to go?<textarea id="w_why" rows="3">${esc(w.why)}</textarea></label><button class="p" data-a="savew">Save</button><button data-a="close">Cancel</button>`)}
const blank={name:'',suburb:'',city:'',country:'Australia',type:'Italian',rating:0,total:0,people:2,order:'',notes:'',fav:false,again:'',photo:''};
const g=id=>$('#'+id).value;
function download(name,text,mime){const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([text],{type:mime}));a.download=name;document.body.appendChild(a);a.click();a.remove();localStorage.setItem('lastBackup',today());setTimeout(render,300)}
const resize=f=>new Promise(ok=>{const r=new FileReader();r.onload=()=>{const i=new Image();i.onload=()=>{const s=Math.min(1,900/Math.max(i.width,i.height)),c=document.createElement('canvas');c.width=i.width*s;c.height=i.height*s;c.getContext('2d').drawImage(i,0,0,c.width,c.height);ok(c.toDataURL('image/jpeg',.7))};i.onerror=()=>ok('');i.src=r.result};r.onerror=()=>ok('');r.readAsDataURL(f)});
const find=id=>S.visits.find(v=>v.id===id);
const ACT={
 tab:id=>{tab=id;render()},close,
 add:()=>tab==='want'?wantForm({}):visitForm(blank),addwant:()=>wantForm({}),
 star:id=>{X.rating=X.rating==id?0:+id;$('#stars').innerHTML=starBtns(X.rating)},
 view:id=>{const v=find(id);modal(`<h2>${esc(v.name)}</h2><div class="stars">${stars(v.rating)} ${v.fav?'♥ Favourite':''}</div>${v.photo?`<img class="ph" src="${v.photo}">`:''}
  <p class="sub">${esc(loc(v))}<br>${fd(v.date)} · ${esc(v.type)}</p><p><b>${aud(v.total)}</b> for ${v.people} (${aud(cpp(v))} per person)</p>
  ${v.order?`<p><b>Ordered:</b> ${esc(v.order)}</p>`:''}${v.notes?`<p>${esc(v.notes)}</p>`:''}${v.again?`<p>Visit again: ${v.again==='yes'?'Yes':'No'}</p>`:''}
  <p class="sub">Visits to this restaurant: ${S.visits.filter(x=>key(x)===key(v)).length}</p>
  <button class="p" data-a="edit" data-id="${id}">Edit</button><button data-a="again" data-id="${id}">Log another visit</button><button class="d" data-a="del" data-id="${id}">Delete</button><button data-a="close">Close</button>`)},
 edit:id=>visitForm(find(id)),
 again:id=>visitForm({...find(id),id:'',date:today(),rating:0,notes:'',order:'',photo:'',total:0}),
 del:async id=>{if(confirm('Permanently delete this visit? This cannot be undone.')){S.visits=S.visits.filter(v=>v.id!==id);await save();close();render()}},
 savev:async()=>{if(!str(g('f_name')))return alert('Please enter the restaurant name.');
  const v=cleanVisit({id:X.id||uid(),name:g('f_name'),suburb:g('f_suburb'),city:g('f_city'),country:g('f_country'),date:g('f_date'),type:g('f_type'),rating:X.rating,total:g('f_total'),people:g('f_people'),order:g('f_order'),notes:g('f_notes'),fav:$('#f_fav').checked,again:g('f_again'),photo:X.photo});
  S.visits=X.id?S.visits.map(x=>x.id===X.id?v:x):[...S.visits,v];if(X.wantId)S.wants=S.wants.filter(w=>w.id!==X.wantId);
  await save();close();render()},
 savew:async()=>{if(!str(g('w_name')))return alert('Please enter the restaurant name.');
  const w=cleanWant({id:X.wid||uid(),name:g('w_name'),suburb:g('w_suburb'),city:g('w_city'),type:g('w_type'),price:g('w_price'),why:g('w_why')});
  S.wants=X.wid?S.wants.map(x=>x.id===X.wid?w:x):[...S.wants,w];await save();close();render()},
 wedit:id=>wantForm(S.wants.find(w=>w.id===id)),
 wvisit:id=>{const w=S.wants.find(x=>x.id===id);visitForm({...blank,name:w.name,suburb:w.suburb,city:w.city,country:w.country,type:w.type},id)},
 wdel:async id=>{if(confirm('Remove this restaurant from your list?')){S.wants=S.wants.filter(w=>w.id!==id);await save();render()}},
 xjson:()=>download(`restaurant-passport-${today()}.json`,JSON.stringify({app:'restaurant-passport',version:1,exported:new Date().toISOString(),visits:S.visits,wants:S.wants},null,1),'application/json'),
 xcsv:()=>{const c=['name','suburb','city','country','date','type','rating','total','people','costPerPerson','order','notes','favourite','visitAgain'];
  const q=x=>'"'+String(x).replace(/"/g,'""')+'"';
  download(`restaurant-history-${today()}.csv`,'\ufeff'+[c.join(','),...S.visits.map(v=>[v.name,v.suburb,v.city,v.country,v.date,v.type,v.rating,v.total,v.people,cpp(v).toFixed(2),v.order,v.notes,v.fav?'yes':'no',v.again].map(q).join(','))].join('\r\n'),'text/csv')},
 erase:async()=>{if(confirm('Erase ALL visits and saved places from this phone?')&&confirm('Really erase everything? Make sure you have a backup.')){S={visits:[],wants:[]};await save();render()}}};
document.addEventListener('click',e=>{const b=e.target.closest('[data-a]');if(b&&ACT[b.dataset.a])ACT[b.dataset.a](b.dataset.id)});
document.addEventListener('input',e=>{const i=e.target.id;
 if(i==='q'){F.q=e.target.value;$('#list').innerHTML=list()}else if(i==='f_total'||i==='f_people')cppUpd()});
document.addEventListener('change',async e=>{const t=e.target,i=t.id;
 if(i==='fmin'||i==='ftype'||i==='fsort'){F[{fmin:'min',ftype:'type',fsort:'sort'}[i]]=i==='fmin'?+t.value:t.value;$('#list').innerHTML=list()}
 else if(i==='wsort'){W=t.value;render()}
 else if(i==='f_photo'&&t.files[0]){X.photo=await resize(t.files[0]);$('#pv').innerHTML=X.photo?`<img class="ph" src="${X.photo}">`:'<p class="sub">Could not read that photo.</p>'}
 else if(i==='imp'&&t.files[0]){try{const d=JSON.parse(await t.files[0].text()),vs=(Array.isArray(d)?d:d.visits||[]).map(cleanVisit).filter(Boolean),ws=(d.wants||[]).map(cleanWant).filter(Boolean);
  const nv=vs.filter(v=>!find(v.id)),nw=ws.filter(w=>!S.wants.some(x=>x.id===w.id));
  if(!vs.length&&!ws.length)throw new Error('empty');
  if(confirm(`Found ${vs.length} visits and ${ws.length} saved places. Add ${nv.length} visits and ${nw.length} places that are not already here?`)){S.visits.push(...nv);S.wants.push(...nw);await save();alert('Backup restored.');render()}}
  catch(err){alert('That file is not a valid Restaurant Passport backup.')}t.value=''}});
(async()=>{const d=await load();if(d){S.visits=(d.visits||[]).map(cleanVisit).filter(Boolean);S.wants=(d.wants||[]).map(cleanWant).filter(Boolean)}
 if(navigator.storage?.persist)navigator.storage.persist();render();
 if('serviceWorker'in navigator)addEventListener('load',()=>navigator.serviceWorker.register('sw.js').catch(()=>{}))})();
