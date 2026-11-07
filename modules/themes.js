export const THEMES = {
    cyber:   { label: 'Cyber Mint',     fg: '#00ffcc', bg: '#0a0a0c', accent: 0x00ffcc, shape: 'icosahedron' },
    synth:   { label: 'Synthwave',      fg: '#ff4fd8', bg: '#120a24', accent: 0xff4fd8, shape: 'torusknot' },
    amber:   { label: 'Amber CRT',      fg: '#ffb000', bg: '#100a00', accent: 0xffb000, shape: 'octahedron' },
    aurora:  { label: 'Aurora Glass',   fg: '#7cf5ff', bg: '#06142a', accent: 0x7cf5ff, shape: 'torus' },
    matrix:  { label: 'Matrix Rain',    fg: '#39ff14', bg: '#000800', accent: 0x39ff14, shape: 'dodecahedron' }
};

export function applyTheme(name, spatial) {
    const t = THEMES[name];
    if (!t) return false;
    const root = document.documentElement.style;
    root.setProperty('--fg', t.fg);
    root.setProperty('--bg', t.bg);
    localStorage.setItem('theme', name);
    if (spatial) spatial.setTheme(t);
    return true;
}
