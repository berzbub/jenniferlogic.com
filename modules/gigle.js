// Gigle-AI client (berzbub/Gigle-AI). Talks to the Gigle-AI gateway (server/gigle_server.py
// by default) which holds all credentials; no API keys are stored in the browser.
const DEFAULT_ENDPOINT = '/api/gigle/chat';

export class GigleClient {
    constructor() { this.history = []; }

    get endpoint() { return localStorage.getItem('gigle_url') || DEFAULT_ENDPOINT; }
    setEndpoint(url) {
        if (url) localStorage.setItem('gigle_url', url.trim());
        else localStorage.removeItem('gigle_url');
    }

    // Streams a reply; calls onToken(text) per chunk and resolves with the full text.
    async ask(prompt, attachments = [], onToken = () => {}, signal) {
        const messages = [...this.history, { role: 'user', content: prompt }];
        let res;
        try {
            res = await fetch(this.endpoint, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Accept': 'text/event-stream' },
                body: JSON.stringify({ messages, attachments, stream: true }),
                signal
            });
        } catch (e) {
            throw new Error('Gigle-AI unreachable at ' + this.endpoint + '. Set it with: gigle-url <endpoint>');
        }
        if (!res.ok) {
            let detail = 'HTTP ' + res.status;
            try { const j = await res.json(); detail = j.error || j.detail || detail; } catch (e) { /* non-JSON body */ }
            throw new Error('Gigle-AI: ' + detail);
        }

        let full = '';
        const handle = data => {
            if (data === '[DONE]') return;
            let evt;
            try { evt = JSON.parse(data); } catch (e) { evt = { text: data }; }
            if (evt.error) throw new Error('Gigle-AI: ' + evt.error);
            const text = evt.text ?? evt.token ?? evt.delta ?? evt.content ?? '';
            if (text) { full += text; onToken(text); }
        };

        if (!res.body) {
            handle(JSON.stringify(await res.json()));
        } else {
            const reader = res.body.getReader();
            const dec = new TextDecoder();
            let buf = '';
            for (;;) {
                const { done, value } = await reader.read();
                if (done) break;
                buf += dec.decode(value, { stream: true });
                let i;
                while ((i = buf.indexOf('\n')) >= 0) {
                    const line = buf.slice(0, i).replace(/\r$/, '');
                    buf = buf.slice(i + 1);
                    if (line.startsWith('data:')) handle(line.slice(5).trim());
                }
            }
            if (buf.startsWith('data:')) handle(buf.slice(5).trim());
        }

        this.history.push({ role: 'user', content: prompt }, { role: 'assistant', content: full });
        this.history = this.history.slice(-20);
        return full;
    }

    pickImage() {
        return new Promise((resolve, reject) => {
            const input = document.createElement('input');
            input.type = 'file';
            input.accept = 'image/*';
            input.onchange = () => {
                const file = input.files[0];
                if (!file) return reject(new Error('No image selected.'));
                const reader = new FileReader();
                reader.onload = () => resolve({ mime: file.type, data: reader.result.split(',')[1] });
                reader.onerror = () => reject(new Error('Could not read image.'));
                reader.readAsDataURL(file);
            };
            input.click();
        });
    }
}
