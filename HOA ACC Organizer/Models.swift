// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import Foundation

/// Represents a batch of violation reports imported from the companion violation application.
struct ViolationBatch: Codable {
    /// The date or timestamp associated with exported at.
    let exportedAt: String?
    /// The format identifier used to validate this import, export, or backup payload.
    let format: String
    /// The violation reports contained in this imported batch.
    let reports: [ViolationReport]
}

/// Represents one violation report in the external violation JSON format.
struct ViolationReport: Codable, Identifiable {
    /// The stable identifier for this value.
    let id: String
    /// The ISO-8601 deadline by which the violation should be corrected.
    let correctionDeadline: String?
    /// The ISO-8601 creation timestamp for this record.
    let createdAt: String?
    /// The date or timestamp associated with escalation date.
    let escalationDate: String?
    /// The date or timestamp associated with final warning date.
    let finalWarningDate: String?
    /// The name of the inspector associated with the violation.
    let inspectorName: String?
    /// User-entered notes associated with this record.
    let notes: String?
    /// The ISO-8601 timestamp when the violation was observed.
    let observedAt: String?
    /// The date or timestamp associated with resolved date.
    let resolvedDate: String?
    /// The photo records or attachments associated with this value.
    let photos: [ViolationPhoto]?
    /// The property identity embedded in an imported violation report.
    let property: PropertyPayload?
    /// The governing-rule records associated with this value.
    let rules: [ViolationRule]?
    /// The raw status string received from an external violation feed.
    let statusRaw: String?
}

/// Represents the property identity embedded in a violation report.
struct PropertyPayload: Codable {
    /// The stable identifier for this value.
    let id: String?
    /// The alternate billing address recorded for the homeowner.
    let billingAddress: String?
    /// Indicates whether the property is recorded as a rental unit.
    let isRentalUnit: Bool?
    /// The HOA lot number associated with this record.
    let lotNumber: String?
    /// The primary property address recorded for the lot.
    let primaryAddress: String?
    /// The current homeowner name recorded for the lot.
    let ownerName: String?
}

/// Represents one homeowner master-data row from the SHOA owner JSON source.
struct OwnerMasterRecord: Codable, Identifiable {
    /// The HOA lot number associated with this record.
    let lotNumber: Int
    /// The homeowner name string from the owner-master source data.
    let homeownerListing: String
    /// The complete Smoketree property address from the owner-master source data.
    let fullSmoketreeAddress: String
    /// The alternate billing address recorded for the homeowner.
    let billingAddress: String?
    /// The primary phone number recorded for the homeowner.
    let primaryPhone: String?
    /// The secondary phone number recorded for the homeowner.
    let secondaryPhone: String?
    /// The primary email address recorded for the homeowner.
    let primaryEmail: String?
    /// The secondary email address recorded for the homeowner.
    let secondaryEmail: String?
    /// The raw owner-master rental flag before it is converted to `Bool`.
    let rentalUnit: String?

    /// The stable identifier for this value.
    var id: Int { lotNumber }

    /// Defines the supported coding keys values used by the application.
    enum CodingKeys: String, CodingKey {
        case lotNumber = "Lot Number"
        case homeownerListing = "Homeowner Listing"
        case fullSmoketreeAddress = "Full Smoketree Address"
        case billingAddress = "Billing address"
        case primaryPhone = "Primary Phone"
        case secondaryPhone = "Secondary Phone"
        case primaryEmail = "Primary Email"
        case secondaryEmail = "Secondary email"
        case rentalUnit = "Rental Unit"
    }

    /// Indicates whether the property is recorded as a rental unit.
    var isRentalUnit: Bool {
        rentalUnit?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "yes"
    }
}

/// Represents a Base64-encoded photograph in imported violation JSON.
struct ViolationPhoto: Codable, Identifiable {
    /// The stable identifier for this value.
    let id: String
    /// The user-visible caption associated with the attachment or photo.
    let caption: String?
    /// The ISO-8601 timestamp associated with the captured photo or observation.
    let capturedAt: String?
    /// The binary or encoded data used for image data.
    let imageData: String?
}

/// Represents the rule details embedded in an imported violation report.
struct ViolationRule: Codable, Identifiable {
    /// The stable identifier for this value.
    let id: String
    /// The rule or workflow category associated with this value.
    let category: String?
    /// The number of days allowed for correction under this rule.
    let correctionDays: Int?
    /// The standardized corrective action associated with this rule.
    let correctiveAction: String?
    /// Indicates whether is active.
    let isActive: Bool?
    /// The standardized notice language associated with this rule.
    let noticeText: String?
    /// The governing-document section cited by this rule.
    let ruleSection: String?
    /// The complete governing-rule text stored with the violation.
    let ruleText: String?
    /// The human-readable title displayed for this value.
    let title: String?
}

/// Contains the property fields and issue counts required by the main lot list.
struct LotSummary: Identifiable, Hashable {
    /// The stable identifier for this value.
    let id: String
    /// The HOA lot number associated with this record.
    let lotNumber: String
    /// The current homeowner name recorded for the lot.
    let ownerName: String
    /// The primary property address recorded for the lot.
    let primaryAddress: String
    /// The number of currently active violations for the lot.
    let openViolations: Int
    /// The number of historical violations recorded for the lot.
    let previousViolations: Int
    /// The number of ACC applications currently requiring action for the lot.
    let activeACCApplications: Int
    /// The most recent activity timestamp associated with the lot.
    let lastActivity: String?
}

/// Contains owner and contact information for a single property.
struct LotDetail: Identifiable {
    /// The stable identifier for this value.
    let id: String
    /// The HOA lot number associated with this record.
    let lotNumber: String
    /// The current homeowner name recorded for the lot.
    let ownerName: String
    /// The primary property address recorded for the lot.
    let primaryAddress: String
    /// The alternate billing address recorded for the homeowner.
    let billingAddress: String
    /// The primary phone number recorded for the homeowner.
    let primaryPhone: String
    /// The secondary phone number recorded for the homeowner.
    let secondaryPhone: String
    /// The primary email address recorded for the homeowner.
    let primaryEmail: String
    /// The secondary email address recorded for the homeowner.
    let secondaryEmail: String
    /// Indicates whether the property is recorded as a rental unit.
    let isRentalUnit: Bool
}

/// Contains the violation fields needed by lot and violation detail screens.
struct ViolationListItem: Identifiable, Hashable {
    /// The stable identifier for this value.
    let id: String
    /// The current workflow status.
    let status: String
    /// The ISO-8601 timestamp when the violation was observed.
    let observedAt: String?
    /// The ISO-8601 deadline by which the violation should be corrected.
    let correctionDeadline: String?
    /// The date or timestamp associated with escalation date.
    let escalationDate: String?
    /// The date or timestamp associated with final warning date.
    let finalWarningDate: String?
    /// The date or timestamp associated with fee assessment date.
    let feeAssessmentDate: String?
    /// The date or timestamp associated with resolved date.
    let resolvedDate: String?
    /// User-entered notes associated with this record.
    let notes: String
    /// Administrator-only notes associated with this record.
    let adminNotes: String
    /// The combined rule titles shown for a violation summary.
    let ruleTitles: String
    /// The number of photo attachments associated with the record.
    let photoCount: Int
}

/// Summarizes a completed import operation for display and diagnostics.
struct ImportBatchSummary: Identifiable {
    /// The stable identifier for this value.
    let id: String
    /// The import/export/audit record type associated with this value.
    let type: String
    /// The name of the source file used for this import.
    let sourceFileName: String
    /// The ISO-8601 timestamp when this record was imported.
    let importedAt: String
    /// The number of records contained in the associated import or export operation.
    let recordCount: Int
}

/// Summarizes inserted, updated, and duplicate violation import records.
struct ImportResult {
    /// The number of new records inserted by the operation.
    let inserted: Int
    /// The number of existing records updated by the operation.
    let updated: Int
    /// The number of input records skipped because they were already present or unchanged.
    let duplicates: Int
}

/// Summarizes owner-master inserts, updates, and detected address differences.
struct HomeownerImportResult {
    /// The number of new records inserted by the operation.
    let inserted: Int
    /// The number of existing records updated by the operation.
    let updated: Int
    /// The number of owner rows that could not be matched to a valid lot.
    let unmatched: Int
    /// The number of imported owner addresses that differ from existing property data.
    let addressMismatches: Int
}


/// Describes a stored violation attachment without loading its binary contents.
struct ViolationAttachment: Identifiable, Hashable {
    /// The stable identifier for this value.
    let id: String
    /// The app-managed filename used to store this attachment.
    let fileName: String
    /// The MIME type describing the attachment contents.
    let mimeType: String
    /// The ISO-8601 timestamp associated with the captured photo or observation.
    let capturedAt: String?
    /// The user-visible caption associated with the attachment or photo.
    let caption: String
}


// MARK: - Phase Two: ACC Applications

/// Contains the ACC application fields required by lot-level lists and status indicators.
struct ACCRequestSummary: Identifiable, Hashable {
    /// The stable identifier for this value.
    let id: String
    /// The stable identifier of the lot associated with this record.
    let lotID: String
    /// The applicant name recorded on the ACC application.
    let applicantName: String
    /// The applicant’s description of the proposed property change.
    let description: String
    /// The current workflow status.
    let status: String
    /// The ISO-8601 timestamp when the ACC application was submitted or received.
    let submittedAt: String?
    /// The ISO-8601 timestamp when this record was imported.
    let importedAt: String
    /// The ISO-8601 timestamp of the most recent update.
    let updatedAt: String
}

/// Represents a neighbor acknowledgement captured from an ACC application.
nonisolated struct ACCNeighbor: Identifiable, Hashable, Codable {
    /// The stable identifier for this value.
    var id: String = UUID().uuidString
    /// The human-readable name associated with this value.
    var name: String = ""
    /// The property or neighbor address associated with this value.
    var address: String = ""
    /// The HOA lot number associated with this record.
    var lotNumber: String = ""
    /// Indicates whether the neighbor signature was visible on the source ACC application.
    var signatureObserved: Bool = false
}

/// Holds editable ACC application data before it is committed to persistent storage.
struct ACCApplicationDraft: Identifiable, Hashable {
    /// The stable identifier for this value.
    var id: String = UUID().uuidString
    /// The stable identifier of the lot associated with this record.
    var lotID: String
    /// The applicant name recorded on the ACC application.
    var applicantName: String = ""
    /// The applicant phone number recorded on the ACC application.
    var applicantPhone: String = ""
    /// The property address associated with the proposed ACC change.
    var proposedChangeAddress: String = ""
    /// The applicant’s description of the proposed property change.
    var description: String = ""
    /// The color or material information recorded for the proposed change.
    var color: String = ""
    /// The proposed start date for the ACC project.
    var proposedStartDate: Date?
    /// The proposed completion date for the ACC project.
    var proposedCompletionDate: Date?
    /// The current workflow status.
    var status: String = "Under Review"
    /// The ISO-8601 timestamp when the ACC application was submitted or received.
    var submittedAt: Date?
    /// The applicant signature or printed-name text recorded on the application.
    var applicantSignature: String = ""
    /// The date associated with the applicant signature.
    var applicantSignatureDate: Date?
    /// The ACC recommendation recorded for the application.
    var accRecommendation: String = ""
    /// Additional ACC remarks recorded for the application.
    var remarks: String = ""
    /// The ACC chairperson signature or printed-name text recorded for the decision.
    var chairpersonSignature: String = ""
    /// The date associated with the ACC chairperson decision signature.
    var chairpersonSignatureDate: Date?
    /// The neighbor-acknowledgement records associated with the ACC application.
    var neighbors: [ACCNeighbor] = [
        ACCNeighbor(), ACCNeighbor(), ACCNeighbor(), ACCNeighbor()
    ]
    /// The app-managed filename of the original ACC PDF staged with the draft.
    var sourcePDFFileName: String?
    /// The original homeowner-supplied ACC PDF filename.
    var sourcePDFOriginalName: String?
    /// The raw recognized text retained for OCR review and troubleshooting.
    var ocrText: String = ""
    /// Indicates whether on-device Foundation Models assistance was used for the draft.
    var ocrUsedOnDeviceModel: Bool = false
    /// The user-facing message associated with ocr assistance message.
    var ocrAssistanceMessage: String = "Vision OCR and the standard form parser were used."
}

/// Describes a stored ACC attachment, including homeowner photos and generated decision letters.
struct ACCAttachment: Identifiable, Hashable {
    /// The stable identifier for this value.
    let id: String
    /// The attachment or message kind used to interpret this value.
    let kind: String
    /// The app-managed filename used to store this attachment.
    let fileName: String
    /// The original filename supplied by the user or source application.
    let originalFileName: String
    /// The MIME type describing the attachment contents.
    let mimeType: String
    /// The content hash used for attachment deduplication and synchronization.
    let contentHash: String
    /// The user-visible caption associated with the attachment or photo.
    let caption: String
    /// The ISO-8601 creation timestamp for this record.
    let createdAt: String
}

/// Contains the complete persisted ACC application shown by the detail and adjudication screens.
struct ACCRequestDetail: Identifiable, Hashable {
    /// The stable identifier for this value.
    let id: String
    /// The stable identifier of the lot associated with this record.
    let lotID: String
    /// The applicant name recorded on the ACC application.
    let applicantName: String
    /// The applicant phone number recorded on the ACC application.
    let applicantPhone: String
    /// The property address associated with the proposed ACC change.
    let proposedChangeAddress: String
    /// The applicant’s description of the proposed property change.
    let description: String
    /// The color or material information recorded for the proposed change.
    let color: String
    /// The proposed start date for the ACC project.
    let proposedStartDate: String?
    /// The proposed completion date for the ACC project.
    let proposedCompletionDate: String?
    /// The ISO-8601 timestamp when the ACC application was submitted or received.
    let submittedAt: String?
    /// The ISO-8601 timestamp when this record was imported.
    let importedAt: String
    /// The current workflow status.
    let status: String
    /// The applicant signature or printed-name text recorded on the application.
    let applicantSignature: String
    /// The date associated with the applicant signature.
    let applicantSignatureDate: String?
    /// The ACC recommendation recorded for the application.
    let accRecommendation: String
    /// Additional ACC remarks recorded for the application.
    let remarks: String
    /// The ACC chairperson signature or printed-name text recorded for the decision.
    let chairpersonSignature: String
    /// The date associated with the ACC chairperson decision signature.
    let chairpersonSignatureDate: String?
    /// The ISO-8601 creation timestamp for this record.
    let createdAt: String
    /// The ISO-8601 timestamp of the most recent update.
    let updatedAt: String
    /// The neighbor-acknowledgement records associated with the ACC application.
    let neighbors: [ACCNeighbor]
    /// The app-managed filename of the original PDF stored with the ACC application.
    let pdfFileName: String?
    /// The original filename of the stored ACC application PDF.
    let pdfOriginalName: String?
}


/// Contains the active violation-property and active ACC application counts shown on the dashboard.
struct DashboardSummary {
    /// The number of properties that currently have at least one active violation.
    let propertiesWithActiveViolations: Int
    /// The number of ACC applications currently requiring action for the lot.
    let activeACCApplications: Int
}

/// Captures an ACC decision and the notes recorded with that decision.
struct ACCAdjudication {
    /// The current workflow status.
    var status: String
    /// The ACC recommendation recorded as part of an adjudication.
    var recommendation: String
    /// Additional ACC remarks recorded for the application.
    var remarks: String
    /// The ACC chairperson signature or printed-name text recorded for the decision.
    var chairpersonSignature: String
    /// The date or timestamp associated with chairperson date.
    var chairpersonDate: Date?
}


// MARK: - Violation adjudication

/// Contains the governing-rule text associated with a persisted violation.
struct ViolationRuleDetail: Identifiable, Hashable {
    /// The stable identifier for this value.
    let id: String
    /// The human-readable title displayed for this value.
    let title: String
    /// The rule or workflow category associated with this value.
    let category: String
    /// The governing-document section cited by this rule.
    let ruleSection: String
    /// The standardized notice language associated with this rule.
    let noticeText: String
    /// The standardized corrective action associated with this rule.
    let correctiveAction: String
    /// The complete governing-rule text stored with the violation.
    let ruleText: String
}

/// Represents one timestamped status transition in a violation enforcement history.
struct ViolationAction: Identifiable, Hashable {
    /// The stable identifier for this value.
    let id: String
    /// The violation status before this enforcement action was recorded.
    let fromStatus: String
    /// The violation status after this enforcement action was recorded.
    let toStatus: String
    /// User-entered notes associated with this record.
    let notes: String
    /// The date or timestamp associated with changed at.
    let changedAt: String
}

/// Represents an unresolved violation or ACC application in the combined work queue.
struct OpenIssue: Identifiable, Hashable {
    /// Defines the supported kind values used by the application.
    enum Kind: String, Hashable {
        case violation
        case accApplication
    }

    /// The stable identifier for this value.
    let id: String
    /// The attachment or message kind used to interpret this value.
    let kind: Kind
    /// The stable identifier of the lot associated with this record.
    let lotID: String
    /// The HOA lot number associated with this record.
    let lotNumber: String
    /// The current homeowner name recorded for the lot.
    let ownerName: String
    /// The human-readable title displayed for this value.
    let title: String
    /// The current workflow status.
    let status: String
    /// The date or timestamp associated with sort date.
    let sortDate: String?
}


// MARK: - Administration and audit

/// Represents an administrator account stored in the local database.
struct UserAccount: Identifiable, Hashable {
    /// The stable identifier for this value.
    let id: String
    /// The account username associated with this value.
    let username: String
    /// The human-readable name displayed for this value.
    let displayName: String
    /// The authorization role assigned to this account.
    let role: String
    /// Indicates whether is active.
    let isActive: Bool
    /// The ISO-8601 creation timestamp for this record.
    let createdAt: String
    /// The ISO-8601 timestamp of the most recent update.
    let updatedAt: String
    /// The date or timestamp associated with last login at.
    let lastLoginAt: String?

    /// Indicates whether is administrator.
    var isAdministrator: Bool {
        role.lowercased() == "admin" && isActive
    }
}

/// Represents a timestamped administrator action in the immutable audit history.
struct AuditEntry: Identifiable, Hashable {
    /// The stable identifier for this value.
    let id: String
    /// The local user-account identifier associated with this audit entry.
    let userID: String
    /// The account username associated with this value.
    let username: String
    /// The audit or workflow action recorded for this entry.
    let action: String
    /// The logical record type affected by this audit, sync, or deletion entry.
    let entityType: String
    /// The stable identifier of the affected record.
    let entityID: String
    /// The serialized record snapshot captured before the audited change.
    let beforeJSON: String
    /// The serialized record snapshot captured after the audited change.
    let afterJSON: String
    /// The date or timestamp associated with changed at.
    let changedAt: String
    /// The stable identifier used to distinguish this installation during synchronization.
    let deviceID: String
}

/// Represents the application identity associated with the current authenticated session.
struct AuthenticatedUser: Hashable {
    /// The stable identifier for this value.
    let id: String
    /// The account username associated with this value.
    let username: String
    /// The human-readable name displayed for this value.
    let displayName: String
    /// The authorization role assigned to this account.
    let role: String

    /// Returns whether the signed-in account has administrator privileges.
    var isAdministrator: Bool {
        role.caseInsensitiveCompare(
            "admin"
        ) == .orderedSame
    }
}


/// Represents the administrator identity associated with the current authenticated session.
struct AuthenticatedAdmin: Hashable {
    /// The stable identifier for this value.
    let id: String
    /// The account username associated with this value.
    let username: String
    /// The human-readable name displayed for this value.
    let displayName: String
}


// MARK: - Full JSON data transfer

/// Defines the complete portable JSON package used by backup and device-to-device transfer.
nonisolated struct FullDataExportPackage: Codable {
    /// The format identifier used to validate this import, export, or backup payload.
    let format: String
    /// The schema or transfer-format version supported by this component.
    let version: Int
    /// The date or timestamp associated with exported at.
    let exportedAt: String
    /// The lot records included in this view, transfer, or result.
    let lots: [ExportLotRecord]
    /// The durable SuperUser deletion tombstones included in this transfer package.
    let deletions: [ExportDeletionRecord]

    /// Creates a portable data package. `deletions` defaults to an empty list so
    /// older call sites and test fixtures remain source-compatible.
    init(
        format: String,
        version: Int,
        exportedAt: String,
        lots: [ExportLotRecord],
        deletions: [ExportDeletionRecord] = []
    ) {
        self.format = format
        self.version = version
        self.exportedAt = exportedAt
        self.lots = lots
        self.deletions = deletions
    }

    /// Defines the supported coding keys values used by the application.
    private enum CodingKeys: String, CodingKey {
        case format
        case version
        case exportedAt
        case lots
        case deletions
    }

    /// Decodes older transfer packages that predate deletion tombstones by
    /// treating a missing `deletions` field as an empty list.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        format = try container.decode(
            String.self,
            forKey: .format
        )
        version = try container.decode(
            Int.self,
            forKey: .version
        )
        exportedAt = try container.decode(
            String.self,
            forKey: .exportedAt
        )
        lots = try container.decode(
            [ExportLotRecord].self,
            forKey: .lots
        )
        deletions = try container.decodeIfPresent(
            [ExportDeletionRecord].self,
            forKey: .deletions
        ) ?? []
    }
}

/// Represents a durable removal tombstone used to prevent a deleted workflow
/// record from reappearing during backup restore or nearby synchronization.
nonisolated struct ExportDeletionRecord: Codable, Hashable {
    /// The logical record type affected by this audit, sync, or deletion entry.
    let entityType: String
    /// The stable identifier of the affected record.
    let entityID: String
    /// The date or timestamp associated with deleted at.
    let deletedAt: String
    /// The account username associated with this value.
    let username: String
    /// The required human-entered reason explaining a destructive record removal.
    let reason: String
}

/// Defines one lot and its nested records in a full-data export.
nonisolated struct ExportLotRecord: Codable {
    /// The stable identifier for this value.
    let id: String
    /// The HOA lot number associated with this record.
    let lotNumber: String
    /// The current homeowner name recorded for the lot.
    let ownerName: String
    /// The primary property address recorded for the lot.
    let primaryAddress: String
    /// The alternate billing address recorded for the homeowner.
    let billingAddress: String
    /// The primary phone number recorded for the homeowner.
    let primaryPhone: String
    /// The secondary phone number recorded for the homeowner.
    let secondaryPhone: String
    /// The primary email address recorded for the homeowner.
    let primaryEmail: String
    /// The secondary email address recorded for the homeowner.
    let secondaryEmail: String
    /// Indicates whether the property is recorded as a rental unit.
    let isRentalUnit: Bool
    /// The violation records included in this view, transfer, or result.
    let violations: [ExportViolationRecord]
    /// The ACC application records included with this exported lot.
    let accApplications: [ExportACCRequestRecord]
}

/// Defines one violation and its related rules and attachments in a full-data export.
nonisolated struct ExportViolationRecord: Codable {
    /// The stable identifier for this value.
    let id: String
    /// The ISO-8601 timestamp when the violation was observed.
    let observedAt: String?
    /// The ISO-8601 deadline by which the violation should be corrected.
    let correctionDeadline: String?
    /// The ISO-8601 creation timestamp for this record.
    let createdAt: String?
    /// The date or timestamp associated with escalation date.
    let escalationDate: String?
    /// The date or timestamp associated with final warning date.
    let finalWarningDate: String?
    /// The date or timestamp associated with fee assessment date.
    let feeAssessmentDate: String?
    /// The date or timestamp associated with resolved date.
    let resolvedDate: String?
    /// The name of the inspector associated with the violation.
    let inspectorName: String
    /// User-entered notes associated with this record.
    let notes: String
    /// Administrator-only notes associated with this record.
    let adminNotes: String
    /// The current workflow status.
    let status: String
    /// The hash value used for source hash.
    let sourceHash: String
    /// The ISO-8601 timestamp of the most recent update.
    let updatedAt: String
    /// The governing-rule records associated with this value.
    let rules: [ExportViolationRule]
    /// The attachment metadata associated with this record.
    let attachments: [ExportAttachment]
}

/// Defines one violation rule in a full-data export.
nonisolated struct ExportViolationRule: Codable {
    /// The stable governing-rule identifier associated with this exported rule snapshot.
    let ruleID: String
    /// The human-readable title displayed for this value.
    let title: String
    /// The rule or workflow category associated with this value.
    let category: String
    /// The governing-document section cited by this rule.
    let ruleSection: String
    /// The number of days allowed for correction under this rule.
    let correctionDays: Int?
    /// The standardized notice language associated with this rule.
    let noticeText: String
    /// The standardized corrective action associated with this rule.
    let correctiveAction: String
    /// The complete governing-rule text stored with the violation.
    let ruleText: String
}

/// Defines one ACC application and its related acknowledgements and attachments in a full-data export.
nonisolated struct ExportACCRequestRecord: Codable {
    /// The stable identifier for this value.
    let id: String
    /// The applicant name recorded on the ACC application.
    let applicantName: String
    /// The applicant phone number recorded on the ACC application.
    let applicantPhone: String
    /// The property address associated with the proposed ACC change.
    let proposedChangeAddress: String
    /// The applicant’s description of the proposed property change.
    let description: String
    /// The color or material information recorded for the proposed change.
    let color: String
    /// The proposed start date for the ACC project.
    let proposedStartDate: String?
    /// The proposed completion date for the ACC project.
    let proposedCompletionDate: String?
    /// The ISO-8601 timestamp when the ACC application was submitted or received.
    let submittedAt: String?
    /// The ISO-8601 timestamp when this record was imported.
    let importedAt: String
    /// The current workflow status.
    let status: String
    /// The ACC recommendation recorded for the application.
    let accRecommendation: String
    /// Additional ACC remarks recorded for the application.
    let remarks: String
    /// The applicant signature or printed-name text recorded on the application.
    let applicantSignature: String
    /// The date associated with the applicant signature.
    let applicantSignatureDate: String?
    /// The ACC chairperson signature or printed-name text recorded for the decision.
    let chairpersonSignature: String
    /// The date associated with the ACC chairperson decision signature.
    let chairpersonSignatureDate: String?
    /// The OCR transcript retained with the exported ACC application record.
    let sourceOCRText: String
    /// The ISO-8601 creation timestamp for this record.
    let createdAt: String
    /// The ISO-8601 timestamp of the most recent update.
    let updatedAt: String
    /// The neighbor-acknowledgement records associated with the ACC application.
    let neighbors: [ACCNeighbor]
    /// The attachment metadata associated with this record.
    let attachments: [ExportAttachment]
}

/// Defines attachment metadata and optional Base64 contents in a full-data export.
nonisolated struct ExportAttachment: Codable {
    /// The stable identifier for this value.
    let id: String
    /// The attachment or message kind used to interpret this value.
    let kind: String
    /// The app-managed filename used to store this attachment.
    let fileName: String
    /// The original filename supplied by the user or source application.
    let originalFileName: String
    /// The MIME type describing the attachment contents.
    let mimeType: String
    /// The content hash used for attachment deduplication and synchronization.
    let contentHash: String
    /// The ISO-8601 timestamp associated with the captured photo or observation.
    let capturedAt: String?
    /// The user-visible caption associated with the attachment or photo.
    let caption: String
    /// The ISO-8601 creation timestamp for this record.
    let createdAt: String
    /// The binary or encoded data used for base64 data.
    let base64Data: String
}


// MARK: - Reminder candidates

/// Contains the violation dates needed to schedule deadline reminders.
struct ViolationReminderCandidate {
    /// The stable identifier for this value.
    let id: String
    /// The HOA lot number associated with this record.
    let lotNumber: String
    /// The current workflow status.
    let status: String
    /// The ISO-8601 deadline by which the violation should be corrected.
    let correctionDeadline: String?
    /// The date or timestamp associated with escalation date.
    let escalationDate: String?
}

/// Contains the ACC application dates needed to schedule review reminders.
struct ACCReminderCandidate {
    /// The stable identifier for this value.
    let id: String
    /// The HOA lot number associated with this record.
    let lotNumber: String
    /// The current workflow status.
    let status: String
    /// The ISO-8601 timestamp when this record was imported.
    let importedAt: String
}

/// Groups all reminder-eligible violations and ACC applications.
struct ReminderCandidates {
    /// The violation records included in this view, transfer, or result.
    let violations: [ViolationReminderCandidate]
    /// The ACC application reminder candidates returned by the scheduler query.
    let applications: [ACCReminderCandidate]
}


// MARK: - Sync and backup

/// Defines the supported automatic nearby-sync intervals.
nonisolated enum SyncCadence: String, CaseIterable, Identifiable, Codable {
    case daily
    case weekly

    /// The stable identifier for this value.
    var id: String { rawValue }

    /// The human-readable name displayed for this value.
    var displayName: String {
        switch self {
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        }
    }

    /// The time interval represented by this sync cadence.
    var interval: TimeInterval {
        switch self {
        case .daily:
            return 24 * 60 * 60
        case .weekly:
            return 7 * 24 * 60 * 60
        }
    }
}

/// Captures the last successful sync date, method, and peer for user-facing status.
struct SyncStateSnapshot: Hashable {
    /// The date or timestamp associated with last successful sync at.
    let lastSuccessfulSyncAt: String?
    /// The method used for the most recent successful synchronization.
    let lastSyncMethod: String
    /// The display name of the device involved in the most recent successful nearby sync.
    let lastPeerName: String
}

/// Contains the content hash and filename needed for attachment synchronization and backup.
struct AttachmentTransferInfo: Hashable {
    /// The content hash used for attachment deduplication and synchronization.
    let contentHash: String
    /// The app-managed filename used to store this attachment.
    let fileName: String
}
