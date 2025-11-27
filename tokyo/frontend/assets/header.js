import { $, clearTokens, getToken } from "./app.js";

export async function loadHeader(active){
  const container = document.getElementById("header");
  const frag = await fetch("./assets/header.html").then(r=>r.text());
  container.innerHTML = frag;

  document.querySelectorAll('#nav a').forEach(a=>{
    a.classList.toggle('active', a.dataset.tab === active);
  });

  const btnLogin = document.getElementById('btnLogin');
  const btnLogout = document.getElementById('btnLogout');
  const who = document.getElementById('who');

  const tokens = getToken();
  if(tokens?.idToken){
    btnLogin.classList.add('hidden');
    btnLogout.classList.remove('hidden');
    const emp = tokens.employee || {};
    who.textContent = `${emp.name||'사용자'} (${emp.department||'-'} / ${emp.title||'-'})`;
  } else {
    btnLogin.classList.remove('hidden');
    btnLogout.classList.add('hidden');
  }

  btnLogin?.addEventListener('click', ()=> location.href="index.html#login");
  btnLogout?.addEventListener('click', ()=>{ clearTokens(); location.href="index.html"; });
}