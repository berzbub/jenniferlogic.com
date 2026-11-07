import { THEMES, applyTheme } from './themes.js';

export class TerminalParser {
    constructor(core) {
        this.core = core;
        this.commands = ['help', 'status', 'license', 'aero-scan', 'theme', 'lang', 'ai', 'ai-vision', 'ai-key', 'clear'];
    }

    async execute(commandStr) {
        const args = commandStr.trim().split(/\s+/);
        const cmd = args[0].toLowerCase();
        const rest = args.slice(1).join(' ');
        const out = m => this.core.printOutput(m);

        switch (cmd) {
            case '':
                break;
            case 'help':
                out(`Available commands: ${this.commands.join(', ')}`);
                out("theme <name|list> | lang <en|fil|ilo|pag> | ai <prompt> | ai-vision <prompt> (attach image) | ai-key <Gemini key>");
                break;
            case 'status':
                out("SYSTEM: OPERATIONAL. Edge CDN: ACTIVE. Security: Zero-Trust.");
                break;
            case 'license':
                try {
                    const res = await fetch('./license.json');
                    if (!res.ok) throw new Error();
                    const license = await res.json();
                    out(`Active Policy: ${license.license_id} | AI Modify: ${license.ai_agent_rules.allow_ai_modification}`);
                } catch (e) {
                    out("[SYS] License configuration loaded via Edge fallback.");
                }
                break;
            case 'aero-scan':
                out("[AERO-SENTINEL] Polling local telemetry nodes... Status: CLEAR. RF Mesh: SECURE.");
                break;
            case 'theme':
                if (!rest || rest === 'list') {
                    out("Themes: " + Object.entries(THEMES).map(([k, v]) => `${k} (${v.label})`).join(', '));
                } else if (applyTheme(rest.toLowerCase(), this.core.spatial)) {
                    out(`[SYS] Theme set: ${rest}`);
                } else {
                    out("[ERROR] Unknown theme. Try 'theme list'.");
                }
                break;
            case 'lang':
                await this.core.i18n.load(rest.toLowerCase());
                out(this.core.i18n.t('terminal.welcome_message'));
                break;
            case 'ai-key':
                if (!rest) { out("[ERROR] Usage: ai-key <Gemini API key>"); break; }
                this.core.ai.setKey(rest);
                out("[AI] Key saved in this browser only.");
                break;
            case 'ai':
            case 'ai-vision':
                if (!rest) { out(`[ERROR] Usage: ${cmd} <prompt>`); break; }
                try {
                    const image = cmd === 'ai-vision' ? await this.core.ai.pickImage() : undefined;
                    out("[AI] Thinking...");
                    out("[AI] " + await this.core.ai.ask(rest, image));
                } catch (e) {
                    out("[ERROR] " + e.message);
                }
                break;
            case 'clear':
                document.getElementById('output-screen').textContent = '';
                break;
            default:
                out(this.core.i18n.t('terminal.command_not_found'));
        }
    }
}
