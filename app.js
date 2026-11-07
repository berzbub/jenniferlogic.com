import { I18n } from './modules/i18n.js';
import { TerminalParser } from './modules/parser.js';
import { SpatialInterface } from './modules/spatial.js';
import { GigleClient } from './modules/gigle.js';
import { applyTheme } from './modules/themes.js';

class Core {
    constructor() {
        this.i18n = new I18n();
        this.ai = new GigleClient();
        this.parser = new TerminalParser(this);
        this.screen = document.getElementById('output-screen');
        this.input = document.getElementById('command-input');
        this.history = [];
        this.hIdx = 0;
    }

    printOutput(text) {
        const line = document.createElement('div');
        line.className = 'terminal-line';
        line.textContent = text; // textContent prevents HTML injection from AI/user output
        this.screen.appendChild(line);
        this.screen.scrollTop = this.screen.scrollHeight;
    }

    beginStream(prefix) {
        const line = document.createElement('div');
        line.className = 'terminal-line';
        line.textContent = prefix;
        this.screen.appendChild(line);
        return {
            append: t => { line.textContent += t; this.screen.scrollTop = this.screen.scrollHeight; }
        };
    }

    async start() {
        await this.i18n.load();
        try { this.spatial = new SpatialInterface('bg-canvas'); } catch (e) { console.warn('3D disabled', e); }
        applyTheme(localStorage.getItem('theme') || 'cyber', this.spatial);
        this.printOutput(this.i18n.t('terminal.welcome_message'));

        this.input.addEventListener('keydown', async e => {
            if (e.key === 'Enter') {
                const v = this.input.value;
                this.input.value = '';
                if (v.trim()) { this.history.push(v); this.hIdx = this.history.length; }
                this.printOutput('> ' + v);
                await this.parser.execute(v);
            } else if (e.key === 'ArrowUp' && this.hIdx > 0) {
                this.input.value = this.history[--this.hIdx];
                e.preventDefault();
            } else if (e.key === 'ArrowDown') {
                this.input.value = this.history[++this.hIdx] || '';
                this.hIdx = Math.min(this.hIdx, this.history.length);
            }
        });
    }
}

new Core().start();
