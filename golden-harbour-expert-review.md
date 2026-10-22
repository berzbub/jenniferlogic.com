# Golden Harbour GHMS — Medical Expert Review Packet

Version 1.0 (draft) · Jennifer Logic · Apache 2.0

**Status: NOT approved.** This packet is for review. No clinician, regulator or institution has approved this software. Do not use it for patient care until the sign-off below is completed.

## 1. Automated test results
Unit tests (`cd golden-harbour-ghms && swift test`) — 6 of 6 pass:
| Rule | Expected behaviour |
|---|---|
| Reorder flag | Flagged when stock ≤ reorder point |
| Expiry | Expired when expiry date is before today |
| Call link | Phone number reduced to digits/`+`; rejected if no digits |
| Reminder timing | Fires 1 hour before the appointment |
| Audit variance | Counted minus system stock; percentage of system; tolerance check |

Not covered: UI, speech transcription accuracy, notification delivery, data persistence. These need device testing.

## 2. Items for clinical review
1. Default reorder point (10) and stock limit (1000) — appropriate for each medicine?
2. Is a 1-hour call reminder the right lead time for appointments, lab tests and discharge follow-ups?
3. Is speech-to-text acceptable for clinical notes? Transcripts are not verified; a clinician must review before saving.
4. Required fields: allergies, dosage, units, batch numbers and patient identifiers are absent.
5. Notification text includes the patient's name and phone number on the lock screen. Is this acceptable?

## 3. Known limitations
- Data stored on device only, unencrypted by the app; no login or audit trail.
- No real SMS; local notifications only.
- Not a medical device; provides no diagnosis or treatment decisions.
- HIPAA/GDPR compliance not assessed.

## 4. Sign-off
| Reviewer | Credentials | Date | Decision (Approve / Changes / Reject) | Signature |
|---|---|---|---|---|
| | | | | |
