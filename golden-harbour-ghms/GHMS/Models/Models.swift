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
import SwiftData


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
