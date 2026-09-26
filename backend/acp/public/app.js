const $ = id => document.getElementById(id);
const token = location.hash.slice(1) || sessionStorage.getItem('alice-token');
if (location.hash) { sessionStorage.setItem('alice-token', token); history.replaceState(null, '', '/'); }
let sequence = 0, currentBob, state, pendingSignature = '', polling = false;
const toolNodes = new Map();
async function api(path, data) {
  const response = await fetch('/api/' + path, { method: data === undefined ? 'GET' : 'POST',
    headers: { Authorization: 'Bearer ' + token, ...(data === undefined ? {} : { 'Content-Type': 'application/json' }) },
    ...(data === undefined ? {} : { body: JSON.stringify(data) }) });
  const result = await response.json();
  if (!response.ok) throw new Error(result.error || 'Connection failed');
  return result;
}
function error(message) { $('error').textContent = message || ''; $('error').hidden = !message; }
function node(tag, text, cls) { const e = document.createElement(tag); if (text) e.textContent = text; if (cls) e.className = cls; return e; }
function message(text, type) {
  $('welcome')?.remove(); const el = node('div', '', 'message ' + type);
  el.append(node('span', type === 'user' ? 'YOU' : type === 'bob' ? 'BOB' : 'ALICE', 'label'), node('span', text));
  $('messages').append(el); return el.lastChild;
}
function event(e) {
  if (e.type === 'user') { currentBob = null; message(e.text, 'user'); }
  if (e.type === 'text') { if (!currentBob) currentBob = message('', 'bob'); currentBob.textContent += e.text; }
  if (e.type === 'done') currentBob = null;
  if (['connected', 'failure', 'status'].includes(e.type)) message(e.message, 'note');
  if (e.type === 'phone_instruction') { message('Voice input from Alice: ' + e.text, 'note'); $('prompt').value = e.text; }
  if (e.type === 'permission_error') message('Approval cancelled: ' + e.message + '. Ask Bob to split this into a smaller operation.', 'note');
  if (e.type === 'permission_resolved') message(e.expired ? 'Approval closed: ' + e.expired : (e.optionId === 'reject' ? 'Rejected' : 'Approved once') + ' — returned to Bob.', 'note');
  if (e.type === 'tool') {
    currentBob = null;
    const t = e.tool; let el = toolNodes.get(t.toolCallId);
    if (!el) { el = node('details', '', 'tool'); el.append(node('summary'), node('pre')); $('messages').append(el); toolNodes.set(t.toolCallId, el); }
    el.firstChild.textContent = (t.status || 'pending') + ' · ' + (t.title || t.toolCallId);
    el.lastChild.textContent = [t.rawInput ? JSON.stringify(t.rawInput, null, 2) : '', ...(t.content || []).map(c => c.type === 'diff' ? `File: ${c.path}\nBefore:\n${c.oldText ?? '(new file)'}\nAfter:\n${c.newText}` : c.content?.text || '')].filter(Boolean).join('\n\n');
  }
}
function render(s) {
  state = s;
  $('workspace').textContent = s.workspace;
  $('phoneState').textContent = s.phone ? 'Phone connected' : s.relay ? 'Waiting for phone' : 'Relay offline';
  $('phoneState').className = 'pill' + (s.phone ? ' online' : '');
  const labels = { disconnected: 'Not connected', connecting: 'Connecting…', ready: s.busy ? (s.pending.length ? 'Waiting for your decision' : 'Bob is working…') : 'Ready', license: 'Review the Bob Shell license', authentication: 'Sign in required', authenticating: 'Complete sign-in in your browser', setup: 'Setup needed' };
  $('bobState').textContent = labels[s.status] || s.status;
  $('send').disabled = s.status !== 'ready' || s.busy;
  $('stop').hidden = !s.busy;
  $('connect').hidden = s.status === 'ready';
  $('connect').disabled = ['connecting', 'authenticating'].includes(s.status);
  $('login').hidden = !['authentication', 'authenticating'].includes(s.status);
  $('login').disabled = s.status === 'authenticating';
  $('license').hidden = s.status !== 'license';
  if (s.error) error(s.error);
  const nearBottom = $('messages').scrollHeight - $('messages').scrollTop - $('messages').clientHeight < 100;
  for (const e of s.events) { event(e); sequence = e.sequence; }
  if (nearBottom) $('messages').scrollTop = $('messages').scrollHeight;
  const signature = JSON.stringify(s.pending.map(c => c.id));
  if (signature === pendingSignature) return;
  pendingSignature = signature; $('approvals').replaceChildren();
  for (const card of s.pending) {
    const box = node('div', '', 'approval');
    box.append(node('strong', card.title), node('p', s.phone ? 'Waiting for your decision in Alice. You can also answer here.' : 'Open Alice or answer here.'), node('pre', card.command));
    for (const option of card.options) {
      const button = node('button', option.label, option.id === 'reject' ? 'reject' : 'allow');
      button.onclick = async () => {
        if (card.risk === 'high' && option.id !== 'reject' && !confirm('Allow this operation once?\n\n' + card.title)) return;
        box.querySelectorAll('button').forEach(b => b.disabled = true);
        try { await api('answer', { id: card.id, optionId: option.id }); }
        catch (e) { error(e.message); pendingSignature = ''; }
      };
      box.append(button);
    }
    $('approvals').append(box);
  }
}
async function poll() {
  if (polling) return; polling = true;
  try { render(await api('state?after=' + sequence)); }
  catch (e) { error(e.message); $('send').disabled = true; }
  finally { polling = false; }
}
$('connect').onclick = async () => { error(''); $('connect').disabled = true; try { await api('connect', {}); } catch (e) { error(e.message); } await poll(); };
$('login').onclick = async () => { error(''); $('login').disabled = true; try { await api('authenticate', {}); } catch (e) { error(e.message); } await poll(); };
$('license').onclick = async () => {
  try {
    const result = await api('license'); $('licenseText').replaceChildren();
    for (const file of result.files) { const section = node('details'); section.append(node('summary', file.name), node('pre', file.text)); $('licenseText').append(section); }
    $('licenseText').firstChild.open = true; $('licenseAccepted').checked = false; $('licenseContinue').disabled = true; $('licenseDialog').showModal();
  } catch (e) { error(e.message); }
};
$('licenseAccepted').onchange = () => { $('licenseContinue').disabled = !$('licenseAccepted').checked; };
$('licenseClose').onclick = () => $('licenseDialog').close();
$('licenseContinue').onclick = async () => {
  if (!$('licenseAccepted').checked) return;
  $('licenseContinue').disabled = true; $('licenseDialog').close(); error('');
  try { await api('accept-license', { accept: true }); } catch (e) { error(e.message); } await poll();
};
$('stop').onclick = async () => { try { await api('cancel', {}); } catch (e) { error(e.message); } };
$('example').onclick = () => { $('prompt').value = 'Bitte führe genau diesen harmlosen Befehl aus: printf "Alice ACP test\\n". Frage die Ausführung über deine normale Werkzeug-Freigabe an und warte auf meine Entscheidung. Keine Dateien ändern und keine weiteren Befehle ausführen.'; $('prompt').focus(); };
$('composer').onsubmit = async e => { e.preventDefault(); const text = $('prompt').value; if (!text.trim() || state?.busy) return; error(''); $('send').disabled = true; try { await api('prompt', { text }); $('prompt').value = ''; } catch (e) { error(e.message); } await poll(); };
$('prompt').onkeydown = e => { if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) $('composer').requestSubmit(); };
api('pair').then(p => { const image = node('img'); image.src = URL.createObjectURL(new Blob([p.svg], { type: 'image/svg+xml' })); image.alt = 'Scan with Alice to pair this chat'; image.style.width = '100%'; $('qr').append(image); $('relayHost').textContent = p.relayUrl; }).catch(e => error(e.message));
poll(); setInterval(poll, 1000);
