'use strict';
const clean=x=>typeof x==='string'?x.replace(/[\u0000-\u001f]/g,' ').slice(0,400):'';
function mapPlace(p){
 if(!p||typeof p.id!=='string'||!p.id||!p.displayName?.text)return null;
 let url=null;try{const u=new URL(p.googleMapsUri);if(u.protocol==='https:'&&['maps.google.com','www.google.com','maps.app.goo.gl'].includes(u.hostname)&&!u.username&&!u.password)url=u.href}catch{}
 return{id:clean(p.id),name:clean(p.displayName.text),address:clean(p.formattedAddress),rating:typeof p.rating==='number'&&p.rating>=0&&p.rating<=5?p.rating:null,reviews:Number.isInteger(p.userRatingCount)&&p.userRatingCount>=0?p.userRatingCount:null,url};
}
module.exports=({fetcher=fetch,key=()=>process.env.GOOGLE_MAPS_API_KEY,now=()=>new Date().toISOString()}={})=>async b=>{
 if(!b||typeof b.lat!=='number'||!Number.isFinite(b.lat)||b.lat < -90||b.lat>90||typeof b.lon!=='number'||!Number.isFinite(b.lon)||b.lon < -180||b.lon>180||![1000,3000,5000,10000].includes(b.radius))return[400,{error:'Choose a valid location and supported radius.'}];
 if(!key())return[503,{error:'Google popularity is not configured. Set GOOGLE_MAPS_API_KEY on your discovery server with Places API (New) enabled and billing configured. Apple Maps nearby remains available.'}];
 let response;
 try{response=await fetcher('https://places.googleapis.com/v1/places:searchNearby',{method:'POST',redirect:'error',signal:AbortSignal.timeout(15000),headers:{'Content-Type':'application/json','X-Goog-Api-Key':key(),'X-Goog-FieldMask':'places.id,places.displayName,places.formattedAddress,places.rating,places.userRatingCount,places.googleMapsUri'},body:JSON.stringify({includedTypes:['restaurant'],maxResultCount:20,rankPreference:'POPULARITY',locationRestriction:{circle:{center:{latitude:Math.round(b.lat*1000)/1000,longitude:Math.round(b.lon*1000)/1000},radius:b.radius}}})});}catch{return[502,{error:'Google Places is unavailable. No mock recommendations have been substituted.'}];}
 if(!response.ok)return[response.status===429?429:502,{error:response.status===429?'Google request limit reached. Wait before trying again.':'Google request failed. Check server credentials, API restrictions and billing.'}];
 let data;try{data=await response.json()}catch{return[502,{error:'Unreadable Google response.'}];}
 if(data.error||(data.places!==undefined&&!Array.isArray(data.places)))return[502,{error:'Incomplete Google response.'}];
 const places=(data.places||[]).slice(0,20).map(mapPlace).filter(Boolean);
 return[200,{places,checkedAt:now(),source:'Google Maps',ranking:'Google popularity; not recent growth or verified real-time trending.',coverage:'Provider coverage can be incomplete. Ratings, opening hours and availability require confirmation with the venue.'}];
};
module.exports.mapPlace=mapPlace;
