'use strict';
const http=require('node:http'),crypto=require('node:crypto'),fs=require('node:fs'),path=require('node:path');
const popular=require('./places')();
function createServer(){const hits=new Map();return http.createServer(async(req,res)=>{
 const send=(status,data,type='application/json')=>{res.writeHead(status,{'Content-Type':type,'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer'});res.end(type==='application/json'?JSON.stringify(data):data)};
 try{
 const url=new URL(req.url,'http://localhost');
 if(['/privacy','/terms'].includes(url.pathname)){const name=url.pathname.slice(1);return send(200,fs.readFileSync(path.join(__dirname,name+'.html')),'text/html; charset=utf-8')}
 if(url.pathname==='/health')return send(200,{ok:true});
 const token=process.env.ACCESS_TOKEN||'';if(!token)return send(503,{error:'Set ACCESS_TOKEN on the discovery server before using the API.'});
 const supplied=String(req.headers['x-access-token']||'');if(Buffer.byteLength(token)!==Buffer.byteLength(supplied)||!crypto.timingSafeEqual(Buffer.from(token),Buffer.from(supplied)))return send(401,{error:'Discovery server access code required.'});
 const ip=req.socket.remoteAddress||'unknown',now=Date.now(),previous=hits.get(ip);const entry=previous&&previous.until>now?previous:{until:now+60000,count:0};entry.count++;if(hits.size>5000)hits.clear();hits.set(ip,entry);if(entry.count>30)return send(429,{error:'Request limit reached. Try again in a minute.'});
 if(url.pathname==='/api/status')return send(200,{ok:true,configured:!!process.env.GOOGLE_MAPS_API_KEY});
 if(url.pathname!=='/api/popular')return send(404,{error:'Unknown endpoint.'});
 if(req.method!=='POST')return send(405,{error:'Use POST with a selected search area.'});
 let text='',oversized=false;for await(const chunk of req){if(Buffer.byteLength(text)+chunk.length>4096){oversized=true;break}text+=chunk;}if(oversized)return send(413,{error:'Request too large.'});
 let body;try{body=JSON.parse(text)}catch{return send(400,{error:'Invalid JSON.'})}
 const[status,data]=await popular(body);return send(status,data);
 }catch{if(!res.headersSent)send(502,{error:'Discovery service unavailable. Your local passport remains available.'});else res.end()}
})}
module.exports=createServer;if(require.main===module)createServer().listen(process.env.PORT||3000,()=>console.log('Restaurant Passport discovery server ready'));
