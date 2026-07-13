# THESIS 2 - SYSTEM COMPLETION ASSESSMENT

**Title:** VaccSync: A QR Code-Based Child Immunization Tracking System with Maternal Health Profiling  
**Researchers:** Cristian B. Perez and Joemar S. Camallere Jr.  
**Assessment Date:** July 10, 2026

## Basis

This assessment follows the objectives and scope in Chapters 1 and 2: secure role-based access, QR-linked child records, digital immunization tracking, maternal health profiling, risk-based follow-up, and automated vaccination reminders for the Calape RHU.

## Completed Processes

| Process | Remarks | Status |
|---|---|---|
| Authentication and role-based access | Firebase Authentication supports parent, healthcare provider, and RHU head accounts. Provider access requires RHU head approval. | Completed |
| Child and maternal profile registration | Child records and maternal data, including age, education, civil status, parity, pregnancy status, and antenatal visits, are saved in Firestore. | Completed |
| Maternal risk classification | The system assigns low, moderate, or high family-risk levels using defined maternal and vaccination factors. | Completed |
| Vaccination record and schedule management | Providers can register patients and create or update vaccination schedules stored in Firestore. | Completed |
| Parent monitoring and QR access | Parents can view linked children, schedules, reminders, QR codes, and printable child records. | Completed |
| Notification infrastructure | Firebase Messaging and local notification handling are implemented for vaccination reminders. | Completed |

## Processes Needing Revision

| Process | Required Revision | Status |
|---|---|---|
| QR validation and record retrieval | Scanned QR data is displayed without verifying the patient against Firestore. The scan should validate a unique patient ID and open the authoritative record. | Partially implemented |
| Risk-based reminders and follow-up | Maternal risk is calculated and stored, but reminder timing and provider prioritization do not use the risk level. High-risk families should receive earlier reminders and appear first in follow-up lists. | Partially implemented |
| Persistent clinical records | The clinical-record page still uses the temporary `globalPatients` list. It should query Firestore and show actual administered vaccines, doses, dates, vaccinator, and remarks. | Partially implemented |
| System-wide data consistency | Some provider screens rely on in-memory data, which may differ from Firestore after restart or navigation. All patient and vaccination views should use persistent queries or streams. | Partially implemented |

## Lacking Processes

| Process | Remarks | Status |
|---|---|---|
| Verified QR-to-record workflow | There is no complete scan, Firestore verification, and patient-record opening process. | Not implemented |
| Maternal-risk-driven intervention | The system does not yet automatically adjust reminders or generate prioritized outreach based on maternal risk. | Not implemented |
| User acceptability and usability evaluation | The objective requires evaluation with parents and healthcare providers, but this must be completed through actual testing and documented results. | Pending research activity |
| User manual and RHU turnover | A finalized user manual and documented delivery of the system to the Calape RHU are still required by the study objectives. | Pending documentation |

## Overall Status

VaccSync's main technical foundation is implemented. However, the system remains **partially completed** because verified QR retrieval, Firestore-backed clinical records, and maternal-risk-based reminders and prioritization are not yet complete.
