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
//
// APP: Golden Harbour Hospital Management System (GHMS)
// MODULE: Core Data, Voice-to-Text Encoding, AI SMS Reminders, & Clinical Notes
// TARGET: iOS / Swift

import Foundation
import SwiftUI
import SwiftData
import Speech
import AVFoundation
import UserNotifications

// MARK: - 1. SWIFT DATA MODELS

@Model
final class Patient {
    var id: UUID
    var fullName: String
    var contactNumber: String
    var patientType: String // "Inpatient" or "Outpatient"
    var dischargeDate: Date?
    var followUpDate: Date?
    var requiredLabTests: String

    @Relationship(deleteRule: .cascade) var appointments: [Appointment]?
    @Relationship(deleteRule: .cascade) var clinicalNotes: [ClinicalNote]?

    init(fullName: String, contactNumber: String, patientType: String, requiredLabTests: String) {
        self.id = UUID()
        self.fullName = fullName
        self.contactNumber = contactNumber
        self.patientType = patientType
        self.requiredLabTests = requiredLabTests
    }
}

@Model
final class MedicineItem {
    var id: UUID
    var medicineName: String
    var category: String
    var stockLevel: Int
    var reorderPoint: Int
    var expiryDate: Date

    init(medicineName: String, category: String, stockLevel: Int, reorderPoint: Int, expiryDate: Date) {
        self.id = UUID()
        self.medicineName = medicineName
        self.category = category
        self.stockLevel = stockLevel
        self.reorderPoint = reorderPoint
        self.expiryDate = expiryDate
    }
}

@Model
final class Appointment {
    var id: UUID
    var doctorName: String
    var dateTime: Date
    var status: String // "Scheduled", "Completed", "Cancelled"
    var isLabTest: Bool

    var patient: Patient?

    init(doctorName: String, dateTime: Date, status: String, isLabTest: Bool) {
        self.id = UUID()
        self.doctorName = doctorName
        self.dateTime = dateTime
        self.status = status
        self.isLabTest = isLabTest
    }
}

@Model
final class ClinicalNote {
    var id: UUID
    var timestamp: Date
    var attendingMD: String
    var diagnosis: String
    var doctorAdvice: String

    var patient: Patient?

    init(attendingMD: String, diagnosis: String, doctorAdvice: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.attendingMD = attendingMD
        self.diagnosis = diagnosis
        self.doctorAdvice = doctorAdvice
    }
}

// MARK: - 2. AI VOICE & AUTOMATED REMINDER ENGINE

class AIEngineManager: NSObject, ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isRecording: Bool = false

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    override init() {
        super.init()
        requestPermissions()
    }

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Speech recognition authorized.")
                default:
                    print("Speech recognition not authorized.")
                }
            }
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted { print("Notifications granted.") }
        }
    }

    func toggleListening() {
        if isRecording {
            stopListening()
        } else {
            startListening()
        }
    }

    private func startListening() {
        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed.")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        let inputNode = audioEngine.inputNode

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                DispatchQueue.main.async { self.isRecording = false }
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            print("Audio engine failed to start.")
        }
    }

    private func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        isRecording = false
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session.")
        }
    }

    // Notifies hospital staff to call the patient before the visit.
    // The patient's number is carried in userInfo so the app can open a tel: link on tap.
    func scheduleCallReminder(patientName: String, contactNumber: String, appointmentDate: Date, reason: String) {
        let content = UNMutableNotificationContent()
        content.title = "Call Patient: \(reason)"
        content.body = "Please call \(patientName) at \(contactNumber) about the visit on \(appointmentDate.formatted())."
        content.sound = .default
        let digits = contactNumber.filter { $0.isNumber || $0 == "+" }
        content.userInfo = ["callURL": "tel:\(digits)"]

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: appointmentDate.addingTimeInterval(-3600))
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Call reminder successfully queued.")
            }
        }
    }
}

// MARK: - 3. USER INTERFACE (SWIFTUI)

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
                            Text("Stock: \(item.stockLevel)").bold().foregroundColor(item.stockLevel <= item.reorderPoint ? .red : .green)
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

// MARK: - 4. APP ENTRY POINT

@main
struct GoldenHarbourApp: App {
    var body: some Scene {
        WindowGroup {
            GoldenHarbourMainView()
        }
        .modelContainer(for: [Patient.self, MedicineItem.self, Appointment.self, ClinicalNote.self])
    }
}
