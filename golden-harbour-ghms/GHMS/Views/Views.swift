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


struct GoldenHarbourMainView: View {
    @StateObject private var aiEngine = AIEngineManager()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PatientDashboardView()
                .tabItem { Label("Patients & Visits", systemImage: "cross.case.fill") }
                .tag(0)

            InventoryView()
                .tabItem { Label("Pharma Inventory", systemImage: "pills.fill") }
                .tag(1)

            VoiceAIEncoderView(aiEngine: aiEngine)
                .tabItem { Label("AI Voice / Notes", systemImage: "waveform.and.mic") }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

struct PatientDashboardView: View {
    @Query private var patients: [Patient]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddPatient = false

    var body: some View {
        NavigationView {
            List {
                ForEach(patients) { patient in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(patient.fullName).font(.headline)
                        Text("Type: \(patient.patientType) | Contact: \(patient.contactNumber)").font(.subheadline).foregroundColor(.gray)
                        Text("Required Labs: \(patient.requiredLabTests)").font(.caption).foregroundColor(.blue)
                    }
                }
                .onDelete(perform: deletePatients)
            }
            .navigationTitle("Golden Harbour Patients")
            .toolbar {
                Button(action: { showingAddPatient.toggle() }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddPatient) {
                AddPatientView()
            }
        }
    }

    private func deletePatients(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(patients[index])
        }
    }
}

struct AddPatientView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var contactNumber = ""
    @State private var patientType = "Outpatient"
    @State private var requiredLabTests = ""

    var body: some View {
        NavigationView {
            Form {
                TextField("Full Name", text: $fullName)
                TextField("Contact Number", text: $contactNumber)
                Picker("Patient Type", selection: $patientType) {
                    Text("Outpatient").tag("Outpatient")
                    Text("Inpatient").tag("Inpatient")
                }
                TextField("Required Lab Tests", text: $requiredLabTests)

                Button("Save Patient Record") {
                    let newPatient = Patient(fullName: fullName, contactNumber: contactNumber, patientType: patientType, requiredLabTests: requiredLabTests)
                    modelContext.insert(newPatient)
                    dismiss()
                }
            }
            .navigationTitle("New Patient Record")
        }
    }
}

struct InventoryView: View {
    @Query private var inventory: [MedicineItem]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddMedicine = false

    var body: some View {
        NavigationView {
            List {
                ForEach(inventory) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.medicineName).font(.headline)
                            Text("Category: \(item.category)").font(.subheadline).foregroundColor(.gray)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Stock: \(item.stockLevel)").bold().foregroundColor(ClinicalLogic.needsReorder(stockLevel: item.stockLevel, reorderPoint: item.reorderPoint) ? .red : .green)
                            Text("Reorder: \(item.reorderPoint)").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteInventory)
            }
            .navigationTitle("Pharma Inventory Log")
            .toolbar {
                Button(action: { showingAddMedicine.toggle() }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddMedicine) {
                AddMedicineView()
            }
        }
    }

    private func deleteInventory(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(inventory[index])
        }
    }
}

struct AddMedicineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var medicineName = ""
    @State private var category = ""
    @State private var stockLevel = 0
    @State private var reorderPoint = 10
    @State private var expiryDate = Date()

    var body: some View {
        NavigationView {
            Form {
                TextField("Medicine Name", text: $medicineName)
                TextField("Category", text: $category)
                Stepper("Stock Level: \(stockLevel)", value: $stockLevel, in: 0...1000)
                Stepper("Reorder Point: \(reorderPoint)", value: $reorderPoint, in: 0...100)
                DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)

                Button("Save Inventory Item") {
                    let newItem = MedicineItem(medicineName: medicineName, category: category, stockLevel: stockLevel, reorderPoint: reorderPoint, expiryDate: expiryDate)
                    modelContext.insert(newItem)
                    dismiss()
                }
            }
            .navigationTitle("Add Pharma Item")
        }
    }
}

struct VoiceAIEncoderView: View {
    @ObservedObject var aiEngine: AIEngineManager
    @Environment(\.modelContext) private var modelContext

    @State private var attendingMD = ""
    @State private var diagnosis = ""
    @State private var advice = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("AI Voice Data Transcription & Auto-Encode")) {
                    TextEditor(text: $aiEngine.transcribedText)
                        .frame(height: 120)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))

                    Button(action: { aiEngine.toggleListening() }) {
                        HStack {
                            Image(systemName: aiEngine.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .foregroundColor(aiEngine.isRecording ? .red : .blue)
                            Text(aiEngine.isRecording ? "Stop Voice Recognition" : "Start Voice Input")
                        }
                    }
                }

                Section(header: Text("Clinical Note-Taking (Doctor Advice & Prognosis)")) {
                    TextField("Attending Doctor Name", text: $attendingMD)
                    TextField("Diagnosis / Prognosis", text: $diagnosis)
                    TextField("Doctor Advice / Action Plan", text: $advice)

                    Button("Encode Clinical Record") {
                        let note = ClinicalNote(attendingMD: attendingMD, diagnosis: diagnosis, doctorAdvice: advice)
                        modelContext.insert(note)
                        attendingMD = ""
                        diagnosis = ""
                        advice = ""
                    }
                }
            }
            .navigationTitle("AI Voice & Notes")
        }
    }
}
