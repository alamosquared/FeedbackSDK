import FeedbackSDK
import CryptoKit
import Foundation
@testable import FeedbackSDK
import XCTest

final class FeedbackSDKTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: IdentityKeySync.userPreferenceKey)
        super.tearDown()
    }

    func testEffectiveSyncEnabledForICloudPolicy() {
        XCTAssertTrue(IdentityKeySync.effectiveSyncEnabled(policy: .iCloud, storedPreference: nil))
        XCTAssertTrue(IdentityKeySync.effectiveSyncEnabled(policy: .iCloud, storedPreference: false))
    }

    func testEffectiveSyncEnabledForDeviceOnlyPolicy() {
        XCTAssertFalse(IdentityKeySync.effectiveSyncEnabled(policy: .deviceOnly, storedPreference: nil))
        XCTAssertFalse(IdentityKeySync.effectiveSyncEnabled(policy: .deviceOnly, storedPreference: true))
    }

    func testEffectiveSyncEnabledForUserConfigurablePolicy() {
        XCTAssertTrue(
            IdentityKeySync.effectiveSyncEnabled(
                policy: .userConfigurable(defaultSyncs: true),
                storedPreference: nil
            )
        )
        XCTAssertFalse(
            IdentityKeySync.effectiveSyncEnabled(
                policy: .userConfigurable(defaultSyncs: true),
                storedPreference: false
            )
        )
        XCTAssertFalse(
            IdentityKeySync.effectiveSyncEnabled(
                policy: .userConfigurable(defaultSyncs: false),
                storedPreference: nil
            )
        )
        XCTAssertTrue(
            IdentityKeySync.effectiveSyncEnabled(
                policy: .userConfigurable(defaultSyncs: false),
                storedPreference: true
            )
        )
    }

    func testIsRuntimeConfigurable() {
        XCTAssertFalse(IdentityKeySync.isRuntimeConfigurable(.iCloud))
        XCTAssertFalse(IdentityKeySync.isRuntimeConfigurable(.deviceOnly))
        XCTAssertTrue(IdentityKeySync.isRuntimeConfigurable(.userConfigurable(defaultSyncs: true)))
    }

    func testSetIdentityKeySyncEnabledRequiresUserConfigurablePolicy() {
        FeedbackSDK.configure(
            apiKey: "pk_test",
            baseURL: URL(string: "https://feedback.example")!,
            identityKeySyncPolicy: .iCloud
        )

        XCTAssertThrowsError(try FeedbackSDK.setIdentityKeySyncEnabled(false)) { error in
            guard case FeedbackSDKError.identitySyncNotConfigurable = error else {
                XCTFail("Expected identitySyncNotConfigurable, got \(error)")
                return
            }
        }
    }

    func testIdentityKeySyncEnabledReflectsUserConfigurablePreference() {
        FeedbackSDK.configure(
            apiKey: "pk_test",
            baseURL: URL(string: "https://feedback.example")!,
            identityKeySyncPolicy: .userConfigurable(defaultSyncs: true)
        )

        XCTAssertTrue(FeedbackSDK.identityKeySyncEnabled)

        IdentityKeySync.setStoredPreference(false)
        XCTAssertFalse(FeedbackSDK.identityKeySyncEnabled)
    }

    func testAutomaticMetadataIncludesExpectedKeys() {
        let metadata = FeedbackSDK.automaticMetadata()

        XCTAssertFalse(metadata["platform"]?.isEmpty ?? true)
        XCTAssertFalse(metadata["os"]?.isEmpty ?? true)
        XCTAssertFalse(metadata["locale"]?.isEmpty ?? true)
        XCTAssertNotNil(UUID(uuidString: metadata["installId"] ?? ""))
        XCTAssertNil(metadata["idfv"])
        if let deviceModel = metadata["deviceModel"] {
            XCTAssertNotEqual(deviceModel, "arm64")
            XCTAssertNotEqual(deviceModel, "x86_64")
        }
    }

    func testAutomaticMetadataIncludesVendorIdentifierWhenOptedIn() {
        FeedbackSDK.configure(
            apiKey: "pk_test",
            baseURL: URL(string: "https://feedback.example")!,
            includeVendorIdentifier: true
        )

        let metadata = FeedbackSDK.automaticMetadata()

        #if canImport(UIKit) && !os(watchOS)
            XCTAssertNotNil(UUID(uuidString: metadata["idfv"] ?? ""))
        #else
            XCTAssertNil(metadata["idfv"])
        #endif
    }

    func testInstallIdIsStableAcrossCalls() {
        let first = InstallIdStorage.current()
        let second = InstallIdStorage.current()

        XCTAssertEqual(first, second)
        XCTAssertNotNil(UUID(uuidString: first))
    }

    func testMetadataMergeCallerOverridesAutomatic() {
        let merged = DeviceMetadata.merged(
            includeAutomatic: true,
            includeVendorIdentifier: false,
            defaultMetadata: [
                "platform": "CustomPlatform",
                "appVersion": "9.9.9",
            ],
            submissionMetadata: [
                "appVersion": "1.2.3",
                "customField": "value",
            ]
        )

        XCTAssertEqual(merged["platform"], "CustomPlatform")
        XCTAssertEqual(merged["appVersion"], "1.2.3")
        XCTAssertEqual(merged["customField"], "value")
        XCTAssertFalse(merged["os"]?.isEmpty ?? true)
        XCTAssertNotNil(UUID(uuidString: merged["installId"] ?? ""))
        XCTAssertNil(merged["idfv"])
    }

    func testMetadataMergeCanDisableAutomaticGathering() {
        let merged = DeviceMetadata.merged(
            includeAutomatic: false,
            includeVendorIdentifier: false,
            defaultMetadata: ["platform": "Web"],
            submissionMetadata: [:]
        )

        XCTAssertEqual(merged["platform"], "Web")
        XCTAssertNil(merged["os"])
        XCTAssertNil(merged["installId"])
    }

    func testSubmitPayloadEncodingUsesCamelCaseKeys() throws {
        let request = SubmitFeedbackRequest(
            type: .bug,
            title: "Crash on launch",
            body: "App crashes immediately after opening.",
            metadata: ["appVersion": "1.0.0"],
            externalUserId: "user-123",
            attachmentIds: nil
        )

        let data = try JSONEncoder.feedback.encode(request)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(json.contains("\"externalUserId\":\"user-123\""))
        XCTAssertFalse(json.contains("external_user_id"))
    }

    func testUnrecognizedIdentityErrorDetection() {
        XCTAssertTrue(
            CustomerIdentityRecovery.isUnrecognizedOnServer(
                FeedbackSDKError.httpError(statusCode: 401, message: "Invalid customer identity")
            )
        )
        XCTAssertTrue(
            CustomerIdentityRecovery.isUnrecognizedOnServer(
                FeedbackSDKError.httpError(statusCode: 401, message: "Customer identity revoked")
            )
        )
        XCTAssertFalse(
            CustomerIdentityRecovery.isUnrecognizedOnServer(
                FeedbackSDKError.httpError(statusCode: 401, message: "Invalid API key")
            )
        )
        XCTAssertFalse(
            CustomerIdentityRecovery.isUnrecognizedOnServer(
                FeedbackSDKError.httpError(statusCode: 401, message: "Invalid customer signature")
            )
        )
        XCTAssertFalse(
            CustomerIdentityRecovery.isUnrecognizedOnServer(
                FeedbackSDKError.httpError(statusCode: 403, message: "Invalid customer identity")
            )
        )
    }

    func testSignaturePayloadUsesUppercaseMethodAndBodyHash() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let identity = CustomerIdentity(id: UUID(), externalUserId: nil, label: nil)
        let body = Data("{\"body\":\"Hello\"}".utf8)
        let url = URL(string: "https://feedback.example/api/v1/tickets/abc/messages")!

        let headers = try RequestSigning.signedHeaders(
            identity: identity,
            privateKey: privateKey,
            method: "post",
            url: url,
            body: body
        )

        XCTAssertNotNil(headers["X-Feedback-Identity"])
        XCTAssertNotNil(headers["X-Feedback-Timestamp"])
        XCTAssertNotNil(headers["X-Feedback-Signature"])
    }

    func testAttachmentContentTypeRawValuesMatchAllowlist() {
        let expected: [AttachmentContentType: String] = [
            .png: "image/png",
            .jpeg: "image/jpeg",
            .webp: "image/webp",
            .heic: "image/heic",
            .heif: "image/heif",
            .json: "application/json",
            .plainText: "text/plain",
            .csv: "text/csv",
            .gzip: "application/gzip",
            .zlib: "application/zlib",
            .octetStream: "application/octet-stream",
        ]

        XCTAssertEqual(AttachmentContentType.allCases.count, expected.count)
        for (contentType, rawValue) in expected {
            XCTAssertEqual(contentType.rawValue, rawValue)
            XCTAssertEqual(AttachmentContentType(rawValue: rawValue), contentType)
        }
    }

    func testAttachmentContentTypeParsesMimeTypeWithParameters() {
        XCTAssertEqual(AttachmentContentType(mimeType: "IMAGE/PNG; charset=binary"), .png)
        XCTAssertEqual(AttachmentContentType(mimeType: "application/json; charset=utf-8"), .json)
        XCTAssertNil(AttachmentContentType(mimeType: "application/pdf"))
        XCTAssertNil(AttachmentContentType(mimeType: "text/html"))
    }

    func testAttachmentInputUsesContentTypeEnum() {
        let input = AttachmentInput(
            filename: "payload.bin",
            data: Data([0x78, 0x9C]),
            contentType: .octetStream
        )

        XCTAssertEqual(input.contentType, .octetStream)
        XCTAssertEqual(input.contentType.rawValue, "application/octet-stream")
    }
}

private extension JSONEncoder {
    static let feedback: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        return encoder
    }()
}
