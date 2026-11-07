export class I18n {
    constructor(defaultLang = 'en') {
        this.lang = localStorage.getItem('lang') || defaultLang;
        this.strings = {};
    }

    async load(lang = this.lang) {
        const supported = ['en', 'fil', 'ilo', 'pag'];
        if (!supported.includes(lang)) lang = 'en';
        try {
            const res = await fetch(`./locales/${lang}.json`);
            this.strings = await res.json();
            this.lang = lang;
            localStorage.setItem('lang', lang);
        } catch (e) {
            if (lang !== 'en') return this.load('en');
        }
    }

    t(key) {
        const value = key.split('.').reduce((o, k) => (o ? o[k] : undefined), this.strings);
        return value ?? key;
    }
}
