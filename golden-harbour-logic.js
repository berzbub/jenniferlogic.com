// Copyright 2026 Jennifer Logic. Licensed under the Apache License, Version 2.0.
// JS port of golden-harbour-ghms/GHMS/Logic/ClinicalLogic.swift (used by the browser demo).
const ClinicalLogic = {
  needsReorder: (stock, reorder) => stock <= reorder,
  isExpired: (expiry, now = new Date()) => expiry < now,
  telURL(number) {
    const cleaned = [...String(number)].filter(c => /[0-9+]/.test(c)).join('');
    return /[0-9]/.test(cleaned) ? 'tel:' + cleaned : null;
  },
  reminderDate: (appt) => new Date(appt.getTime() - 3600 * 1000),
  auditVariance: (system, counted) => counted - system,
  auditVariancePercent: (system, counted) => system > 0 ? (counted - system) / system * 100 : null,
  suggestions(query, candidates, limit = 5) {
    const q = String(query).trim().toLowerCase();
    if (!q) return [];
    const seen = new Set();
    const unique = candidates.filter(c => !seen.has(c.toLowerCase()) && seen.add(c.toLowerCase()));
    const prefix = unique.filter(c => c.toLowerCase().startsWith(q));
    const contains = unique.filter(c => !c.toLowerCase().startsWith(q) && c.toLowerCase().includes(q));
    return [...prefix, ...contains].filter(c => c.toLowerCase() !== q).slice(0, limit);
  },
  auditWithinTolerance(system, counted, tol = 0) {
    if (counted - system === 0) return true;
    const pct = this.auditVariancePercent(system, counted);
    return pct !== null && Math.abs(pct) <= tol;
  },
};
if (typeof module !== 'undefined') module.exports = ClinicalLogic;
