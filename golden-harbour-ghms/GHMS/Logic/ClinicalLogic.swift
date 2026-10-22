// Copyright 2026 Jennifer Logic
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// Pure, framework-free logic kept separate so it can be unit-tested and reviewed by clinical staff.
public enum ClinicalLogic {
    /// Stock at or below the reorder point must be flagged for reorder.
    public static func needsReorder(stockLevel: Int, reorderPoint: Int) -> Bool {
        stockLevel <= reorderPoint
    }

    /// True when the expiry date is before `now`.
    public static func isExpired(_ expiry: Date, now: Date = Date()) -> Bool {
        expiry < now
    }

    /// Builds a dialable `tel:` URL string, or nil if the number has no digits.
    public static func telURL(for contactNumber: String) -> String? {
        let cleaned = contactNumber.filter { $0.isASCII && ($0.isNumber || $0 == "+") }
        guard cleaned.contains(where: { $0.isNumber }) else { return nil }
        return "tel:\(cleaned)"
    }

    /// Reminder fires one hour before the visit.
    public static func reminderDate(for appointment: Date) -> Date {
        appointment.addingTimeInterval(-3600)
    }

    /// Counted minus system stock. Negative = shortage, positive = surplus.
    public static func auditVariance(systemStock: Int, countedStock: Int) -> Int {
        countedStock - systemStock
    }

    /// Variance as a percentage of system stock. Nil when system stock is zero.
    public static func auditVariancePercent(systemStock: Int, countedStock: Int) -> Double? {
        guard systemStock > 0 else { return nil }
        return Double(countedStock - systemStock) / Double(systemStock) * 100
    }

    /// True when the count matches the system within `tolerancePercent` (default 0 = exact match).
    public static func auditWithinTolerance(systemStock: Int, countedStock: Int, tolerancePercent: Double = 0) -> Bool {
        let variance = countedStock - systemStock
        if variance == 0 { return true }
        guard let pct = auditVariancePercent(systemStock: systemStock, countedStock: countedStock) else { return false }
        return abs(pct) <= tolerancePercent
    }

    /// Autocomplete: case-insensitive matches, prefix matches first, duplicates removed, capped at `limit`.
    public static func suggestions(for query: String, from candidates: [String], limit: Int = 5) -> [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        var seen = Set<String>()
        let unique = candidates.filter { seen.insert($0.lowercased()).inserted }
        let prefix = unique.filter { $0.lowercased().hasPrefix(q) }
        let contains = unique.filter { !$0.lowercased().hasPrefix(q) && $0.lowercased().contains(q) }
        return Array((prefix + contains).filter { $0.lowercased() != q }.prefix(limit))
    }
}
