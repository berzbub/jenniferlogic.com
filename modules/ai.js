// Google Gemini multimodal client. The API key is supplied by the user at runtime
// and kept only in this browser's localStorage; never commit keys to the repo.
const MODEL = 'gemini-1.5-flash';

export class GeminiClient {
    get key() { return localStorage.getItem('gemini_key') || ''; }
    setKey(k) { localStorage.setItem('gemini_key', k.trim()); }

    async ask(prompt, image) {
        if (!this.key) throw new Error("No API key. Run: ai-key <your Gemini API key>");
        const parts = [{ text: prompt }];
        if (image) parts.push({ inline_data: { mime_type: image.mime, data: image.data } });
        const res = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
            {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'x-goog-api-key': this.key },
                body: JSON.stringify({ contents: [{ parts }] })
            }
        );
        const json = await res.json();
        if (!res.ok) throw new Error(json.error?.message || `HTTP ${res.status}`);
        return json.candidates?.[0]?.content?.parts?.map(p => p.text).join('') || '(empty response)';
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
