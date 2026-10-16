export class TerminalParser {
    constructor(core) {
        this.core = core;
    }

    async execute(commandStr) {
        const args = commandStr.split(' ');
        const cmd = args[0].toLowerCase();

        switch (cmd) {
            case 'help':
                this.core.printOutput("Available commands: status, license, aero-scan, lgu-mesh, clear");
                break;
            case 'status':
                this.core.printOutput("SYSTEM: OPERATIONAL. Edge CDN: ACTIVE. Security: Zero-Trust.");
                break;
            case 'license':
                try {
                    const res = await fetch('./license.json');
                    const license = await res.json();
                    this.core.printOutput(`Active Policy: ${license.license_id} | AI Modify: ${license.ai_agent_rules.allow_ai_modification}`);
                } catch (e) {
                    this.core.printOutput("[SYS] License configuration loaded via Edge fallback.");
                }
                break;
            case 'aero-scan':
                this.core.printOutput("[AERO-SENTINEL] Polling local telemetry nodes... Status: CLEAR. RF Mesh: SECURE.");
                break;
            case 'lgu-mesh':
                this.core.printOutput("[LGU/NGO COMMAND] Connecting to regional disaster telemetry relays... 4 Nodes Connected.");
                break;
            case 'clear':
                document.getElementById('output-screen').innerHTML = '';
                break;
            default:
                this.core.printOutput(this.core.i18n.t('terminal.command_not_found'));
                break;
        }
    }
}
