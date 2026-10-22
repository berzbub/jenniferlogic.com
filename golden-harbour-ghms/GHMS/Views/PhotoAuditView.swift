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

import SwiftUI
import SwiftData
import PhotosUI

/// Photo audit calculator: photograph the shelf, enter the counted quantity, see variance vs system stock.
struct PhotoAuditView: View {
    @Query(sort: \MedicineItem.medicineName) private var inventory: [MedicineItem]
    @Query(sort: \InventoryAudit.timestamp, order: .reverse) private var audits: [InventoryAudit]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedID: UUID?
    @State private var countedStock = 0
    @State private var auditor = ""
    @State private var notes = ""
    @State private var tolerance = 0.0
    @State private var pickerItem: PhotosPickerItem?
    @State private var photoData: Data?

    private var selected: MedicineItem? { inventory.first { $0.id == selectedID } }

    var body: some View {
        NavigationView {
            Form {
                Section("Item") {
                    Picker("Medicine", selection: $selectedID) {
                        Text("Select…").tag(UUID?.none)
                        ForEach(inventory) { Text($0.medicineName).tag(Optional($0.id)) }
                    }
                    if let item = selected { Text("System stock: \(item.stockLevel)") }
                }

                Section("Photo evidence") {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(photoData == nil ? "Choose photo" : "Replace photo", systemImage: "camera")
                    }
                    if let data = photoData, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200)
                    }
                }

                Section("Count") {
                    Stepper("Counted: \(countedStock)", value: $countedStock, in: 0...100000)
                    Stepper("Tolerance: \(Int(tolerance))%", value: $tolerance, in: 0...20, step: 1)
                    if let item = selected { resultView(for: item) }
                }

                Section("Audit details") {
                    TextField("Auditor name", text: $auditor)
                    TextField("Notes", text: $notes)
                    Button("Save Audit") { save() }
                        .disabled(selected == nil || photoData == nil || auditor.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section("Past audits") {
                    ForEach(audits) { a in
                        let v = ClinicalLogic.auditVariance(systemStock: a.systemStock, countedStock: a.countedStock)
                        VStack(alignment: .leading) {
                            Text(a.medicineName).font(.headline)
                            Text("System \(a.systemStock) / Counted \(a.countedStock) / Variance \(v)").font(.caption)
                            Text("\(a.auditor) · \(a.timestamp.formatted())").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Photo Audit")
            .onChange(of: pickerItem) { _, newItem in
                Task { photoData = try? await newItem?.loadTransferable(type: Data.self) }
            }
        }
    }

    @ViewBuilder
    private func resultView(for item: MedicineItem) -> some View {
        let variance = ClinicalLogic.auditVariance(systemStock: item.stockLevel, countedStock: countedStock)
        let ok = ClinicalLogic.auditWithinTolerance(systemStock: item.stockLevel, countedStock: countedStock, tolerancePercent: tolerance)
        let pct = ClinicalLogic.auditVariancePercent(systemStock: item.stockLevel, countedStock: countedStock)
        VStack(alignment: .leading) {
            Text("Variance: \(variance > 0 ? "+" : "")\(variance)").bold().foregroundColor(ok ? .green : .red)
            if let pct = pct { Text(String(format: "%.1f%% of system stock", pct)).font(.caption) }
            Text(ok ? "Within tolerance" : "Discrepancy – investigate").font(.caption)
        }
    }

    private func save() {
        guard let item = selected else { return }
        modelContext.insert(InventoryAudit(medicineName: item.medicineName, systemStock: item.stockLevel, countedStock: countedStock,
                                           auditor: auditor, notes: notes, photoData: photoData))
        pickerItem = nil; photoData = nil; notes = ""; countedStock = 0
    }
}
