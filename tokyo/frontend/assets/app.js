// ===== CONFIG =====
// API_BASE is now set via environment variable in index.html
export const API_BASE = window.API_GATEWAY_URL || "https://your-api-id.execute-api.ap-northeast-1.amazonaws.com";
const STORAGE_KEY = "portal.jwt";

// ===== UTIL =====
export const $ = (q)=>document.querySelector(q);
export const fmt = (d)=> new Date(d).toLocaleString();
export function toast(msg){
  const t = document.getElementById('toast');
  if(!t) return;
  t.textContent = msg;
  t.classList.add('show');
  setTimeout(()=>t.classList.remove('show'), 2200);
}
export function getToken(){
  try{ return JSON.parse(localStorage.getItem(STORAGE_KEY)||'{}'); }catch{ return null; }
}
export function setTokens(tokens){
  localStorage.setItem(STORAGE_KEY, JSON.stringify(tokens));
}
export function clearTokens(){
  localStorage.removeItem(STORAGE_KEY);
}
export async function api(path, init={}){
  const headers = Object.assign({ 'Content-Type':'application/json' }, init.headers||{});
  const token = getToken()?.idToken;
  if(token){ headers['Authorization'] = `Bearer ${token}`; }
  const res = await fetch(`${API_BASE}${path}`, Object.assign({}, init, { headers }));
  if(!res.ok){ throw new Error(await res.text()||res.status); }
  const ct = res.headers.get('content-type')||'';
  return ct.includes('application/json') ? res.json() : res.text();
}
export async function login(username, password){
  const r = await fetch(`${API_BASE}/auth/login`, {
    method:'POST', headers:{'Content-Type':'application/json'},
    body:JSON.stringify({username,password})
  });
  if(!r.ok) throw new Error(await r.text());
  const data = await r.json(); // { idToken, accessToken, refreshToken, employee }
  setTokens(data);
  return data;
}
export function requireAuth(){
  if(!getToken()?.idToken){
    window.location.href = "index.html";
  }
}