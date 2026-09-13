<!--
Copyright © 2026 Christopher McMahon-Sutton.
Licensed under the PolyForm Perimeter License 1.0.1.
Author: Christopher McMahon-Sutton.
Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.
-->

# ``HOA_ACC_Organizer``

Maintain Smoketree HOA property records, violation enforcement, Architectural Control Committee (ACC) applications, attachments, audit history, reminders, backups, and nearby-device synchronization.

## Overview

HOA ACC Organizer is a native SwiftUI application for iPhone, iPad, and macOS. The local SQLite database is the authoritative working store on each installation. Photos and PDF documents are stored as app-managed attachment files and are referenced by database metadata and content hashes.

The app has two primary operational workflows:

- **Violations** — create or import a violation, review the applicable governing rule, track the enforcement stages, generate a violation PDF, and maintain a complete history.
- **ACC applications** — import a homeowner PDF or enter the application manually, review recognized fields, adjudicate the request, attach supporting photos, and generate a decision letter.

Most workflows are intentionally local-first. Nearby synchronization uses Network.framework and Bonjour. ACC document recognition uses Vision and, on eligible Apple Intelligence hardware, can optionally use Apple’s on-device Foundation Models framework to organize OCR text. Unsupported devices always fall back to the deterministic OCR path.

> Important: Start with <doc:DeveloperOnboarding> before changing persistence, authentication, synchronization, or the record-removal workflow.

## Topics

### Start Here

- <doc:DeveloperOnboarding>
- <doc:Architecture>
- <doc:SourceDocumentationStandards>

### Data and Persistence

- <doc:DataModelAndPersistence>
- ``SQLiteStore``
- ``ISODateStorage``
- ``LotSummary``
- ``LotDetail``

### Violation Workflow

- <doc:ViolationWorkflow>
- ``ViolationCreationDraft``
- ``ViolationImporter``
- ``ViolationPDFReportGenerator``
- ``ViolationListItem``

### ACC Workflow

- <doc:ACCApplicationWorkflow>
- <doc:OCRAndFoundationModels>
- ``ACCApplicationImporter``
- ``ACCApplicationDraft``
- ``ACCOnDeviceApplicationParser``
- ``ACCDecisionLetterPDFRenderer``

### Authentication, Audit, and Cleanup

- <doc:AuthenticationAndAuthorization>
- <doc:AuditAndRemoval>
- ``ProvisionedAccounts``
- ``PasswordHasher``
- ``BiometricKeychain``
- ``AuditEntry``

### Transfer and Recovery

- <doc:SyncBackupAndImport>
- <doc:PDFAndAttachmentHandling>
- ``NetworkSyncService``
- ``FullDataTransferService``
- ``BackupService``

### Quality and Release

- <doc:ResponsiveLayout>
- <doc:TestingStrategy>
- <doc:ReleaseChecklist>
- <doc:DataAndPrivacy>
- <doc:LicensingPrivacyAndDistribution>
