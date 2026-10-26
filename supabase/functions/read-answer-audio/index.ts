// À déployer uniquement après accord propriétaire. Pas de lien signé réutilisable après expiration.
import { createClient } from 'npm:@supabase/supabase-js@2';
const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const fail = (status:number) => new Response(JSON.stringify({error:'audio_unavailable'}),{status,headers:{...cors,'Content-Type':'application/json','Cache-Control':'no-store'}});
Deno.serve(async req => {
 if(req.method==='OPTIONS') return new Response('ok',{headers:cors});
 if(req.method!=='POST') return fail(405);
 try {
  const url=Deno.env.get('SUPABASE_URL')!;
  const user=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:req.headers.get('Authorization')??''}},auth:{persistSession:false}});
  const {data:auth,error:authError}=await user.auth.getUser();
  if(authError || !auth.user) return fail(401);
  const {id}=await req.json();
  if(typeof id!=='string' || !/^[0-9a-f-]{36}$/i.test(id))return fail(400);
  const {data:access,error}=await user.rpc('get_answer_audio',{p_id:id});
  if(error || !access?.ok || Date.parse(access.expires_at)<=Date.now())return fail(404);
  const admin=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
  const {data:blob,error:downloadError}=await admin.storage.from('answer-audio').download(access.path);
  // Revérifie après téléchargement : révocation du partage/fin de partie/expiration peuvent survenir entre-temps.
  const {data:still}=await user.rpc('get_answer_audio',{p_id:id});
  if(downloadError || !blob || !still?.ok || Date.parse(still.expires_at)<=Date.now())return fail(404);
  return new Response(blob,{headers:{...cors,'Content-Type':'application/octet-stream','Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff'}});
 } catch {return fail(400);}
});
