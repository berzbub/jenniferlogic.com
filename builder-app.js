import { Builder } from './modules/builder.js';
import { THEMES, applyTheme } from './modules/themes.js';

const $ = id => document.getElementById(id);
const chat = $('chat');

function say(text, cls = '') {
    const d = document.createElement('div');
    d.className = 'msg ' + cls;
    d.textContent = text;
    chat.appendChild(d);
    chat.scrollTop = chat.scrollHeight;
    return d;
}

const themeSel = $('theme');
for (const [k, v] of Object.entries(THEMES)) themeSel.add(new Option(v.label, k));
const saved = localStorage.getItem('theme') || 'cyber';
themeSel.value = saved;
applyTheme(saved);
themeSel.onchange = () => applyTheme(themeSel.value);

const builder = new Builder({ frame: $('preview'), log: say, onTheme: n => { themeSel.value = n; } });
builder.startInstructionPolling();
say('Describe the page you want. Gigle-AI will generate and restyle it live.');

async function send() {
    const text = $('prompt').value.trim();
    if (!text) return;
    $('prompt').value = '';
    say(text, 'me');
    $('send').disabled = true;
    const status = say('Gigle-AI is designing…');
    try {
        status.textContent = await builder.prompt(text) || 'Done.';
    } catch (e) {
        status.textContent = '[ERROR] ' + e.message;
    } finally {
        $('send').disabled = false;
    }
}

$('send').onclick = send;
$('prompt').addEventListener('keydown', e => { if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) send(); });
$('undo').onclick = () => builder.undo();
$('redo').onclick = () => builder.redo();
$('viewport').onchange = e => builder.setViewport(e.target.value);
$('export').onclick = () => {
    const url = URL.createObjectURL(new Blob([builder.exportHtml()], { type: 'text/html' }));
    const a = Object.assign(document.createElement('a'), { href: url, download: 'page.html' });
    a.click();
    URL.revokeObjectURL(url);
};
