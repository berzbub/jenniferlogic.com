import { GigleClient } from './gigle.js';
import { THEMES, applyTheme } from './themes.js';

const SYSTEM = `You are Gigle-AI, the design engine of a web page builder. You control the page being built and the builder UI.
Reply with ONLY one JSON object: {"message": "<short note to the user>", "ops": [ ... ]}.
Operations:
 {"op":"set_html","html":"<full <body> markup with inline <style>>"}  replace the whole page
 {"op":"add_css","css":"<css rules>"}                                  append styling to the page
 {"op":"set_title","title":"..."}
 {"op":"set_viewport","mode":"desktop|tablet|mobile"}                   builder preview size
 {"op":"set_theme","name":"cyber|synth|amber|aurora|matrix"}            builder UI theme
No scripts, no external resources except https images. Pages must be responsive and accessible.`;

// Strips scripts, event handlers and javascript: URLs; the preview iframe is also fully sandboxed.
export function sanitizeHtml(html) {
    const doc = new DOMParser().parseFromString(String(html), 'text/html');
    doc.querySelectorAll('script, iframe, object, embed, link, meta[http-equiv], base, form[action]').forEach(n => n.remove());
    doc.querySelectorAll('*').forEach(el => {
        for (const a of [...el.attributes]) {
            const v = a.value.trim().toLowerCase();
            if (a.name.startsWith('on') || /^(javascript|data|vbscript):/.test(v) && !(el.tagName === 'IMG' && v.startsWith('data:image/'))) {
                el.removeAttribute(a.name);
            }
        }
    });
    return doc.body.innerHTML;
}

export function sanitizeCss(css) {
    return String(css).replace(/@import[^;]*;?/gi, '').replace(/expression\s*\(/gi, '(')
        .replace(/url\(\s*['"]?\s*(?!https:|data:image\/)[^)]*\)/gi, 'none').replace(/<\/?style/gi, '');
}

// Accepts raw JSON, fenced JSON, or a bare HTML reply and normalises it into {message, ops}.
export function parseAiReply(text) {
    const fenced = text.match(/```(?:json|html)?\s*([\s\S]*?)```/i);
    const body = (fenced ? fenced[1] : text).trim();
    try {
        const start = body.indexOf('{'), end = body.lastIndexOf('}');
        const obj = JSON.parse(body.slice(start, end + 1));
        if (Array.isArray(obj.ops)) return { message: obj.message || '', ops: obj.ops };
    } catch (e) { /* fall through to HTML */ }
    if (/<[a-z][\s\S]*>/i.test(body)) return { message: 'Page updated.', ops: [{ op: 'set_html', html: body }] };
    return { message: text, ops: [] };
}

export class Builder {
    constructor({ frame, log, onTheme }) {
        this.ai = new GigleClient();
        this.frame = frame;
        this.log = log;
        this.onTheme = onTheme;
        this.state = { title: 'Untitled', html: '', css: '' };
        this.undoStack = [];
        this.redoStack = [];
        this.render();
    }

    snapshot() { return JSON.stringify(this.state); }

    commit(fn) {
        this.undoStack.push(this.snapshot());
        this.undoStack = this.undoStack.slice(-50);
        this.redoStack = [];
        fn();
        this.render();
    }

    undo() { if (this.undoStack.length) { this.redoStack.push(this.snapshot()); this.state = JSON.parse(this.undoStack.pop()); this.render(); } }
    redo() { if (this.redoStack.length) { this.undoStack.push(this.snapshot()); this.state = JSON.parse(this.redoStack.pop()); this.render(); } }

    render() {
        const { title, html, css } = this.state;
        this.frame.srcdoc = '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' +
            "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; img-src https: data:; style-src 'unsafe-inline'\">" +
            `<title>${title.replace(/[<>&]/g, '')}</title><style>body{font-family:system-ui,sans-serif;margin:0}${css}</style></head><body>${html}</body></html>`;
    }

    applyOps(ops) {
        const applied = [];
        this.commit(() => {
            for (const o of ops) {
                switch (o && o.op) {
                    case 'set_html': this.state.html = sanitizeHtml(o.html ?? ''); this.state.css = ''; applied.push('html'); break;
                    case 'add_css': this.state.css += '\n' + sanitizeCss(o.css ?? ''); applied.push('css'); break;
                    case 'set_title': this.state.title = String(o.title ?? '').slice(0, 120); applied.push('title'); break;
                    case 'set_viewport': this.setViewport(o.mode); applied.push('viewport'); break;
                    case 'set_theme': if (THEMES[o.name]) { applyTheme(o.name); this.onTheme?.(o.name); applied.push('theme'); } break;
                    default: break; // ignore unknown ops
                }
            }
        });
        return applied;
    }

    setViewport(mode) {
        const w = { desktop: '100%', tablet: '768px', mobile: '390px' }[mode];
        if (w) this.frame.style.width = w;
    }

    async prompt(text, onToken) {
        const context = `Current page title: ${this.state.title}\nCurrent HTML (may be truncated):\n${this.state.html.slice(0, 6000)}\nCurrent extra CSS:\n${this.state.css.slice(0, 2000)}\n\nUser request: ${text}`;
        const reply = await this.ai.ask(context, [], onToken, undefined, { system: SYSTEM, remember: false });
        const { message, ops } = parseAiReply(reply);
        if (!ops.length) throw new Error('Gigle-AI returned no usable instructions.');
        this.applyOps(ops);
        return message;
    }

    // Backend-pushed instructions (see server/gigle_server.py /api/gigle/builder/instructions).
    startInstructionPolling(intervalMs = 5000) {
        const url = this.ai.endpoint.replace(/\/chat$/, '/builder/instructions');
        this.pollTimer = setInterval(async () => {
            try {
                const res = await fetch(url);
                if (!res.ok) return;
                const { ops } = await res.json();
                if (ops?.length) { this.applyOps(ops); this.log('[BACKEND] Applied ' + ops.length + ' instruction(s).'); }
            } catch (e) { /* backend offline: keep polling quietly */ }
        }, intervalMs);
    }

    exportHtml() {
        return '<!DOCTYPE html>\n<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' +
            `<title>${this.state.title.replace(/[<>&]/g, '')}</title><style>${this.state.css}</style></head>\n<body>${this.state.html}</body></html>`;
    }
}
