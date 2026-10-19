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
import Combine
import Speech
import AVFoundation
import UserNotifications


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
