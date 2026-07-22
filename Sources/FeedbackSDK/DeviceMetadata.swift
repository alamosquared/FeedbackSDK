import Darwin
import Foundation
#if canImport(UIKit)
    import UIKit
#endif

enum DeviceMetadata {
    static func gather(includeVendorIdentifier: Bool = false) -> [String: String] {
        var metadata: [String: String] = [:]

        metadata["platform"] = platformName
        metadata["os"] = ProcessInfo.processInfo.operatingSystemVersionString
        metadata["locale"] = Locale.current.identifier
        metadata["installId"] = InstallIdStorage.current()

        if let deviceModel = deviceModel {
            metadata["deviceModel"] = deviceModel
        }
        if let bundleId = Bundle.main.bundleIdentifier {
            metadata["bundleId"] = bundleId
        }
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            metadata["appVersion"] = version
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            metadata["appBuild"] = build
        }
        if includeVendorIdentifier, let idfv = vendorIdentifier {
            metadata["idfv"] = idfv
        }

        return metadata
    }

    static func merged(
        includeAutomatic: Bool,
        includeVendorIdentifier: Bool,
        defaultMetadata: [String: String],
        submissionMetadata: [String: String]
    ) -> [String: String] {
        var metadata = includeAutomatic ? gather(includeVendorIdentifier: includeVendorIdentifier) : [:]
        defaultMetadata.forEach { metadata[$0.key] = $0.value }
        submissionMetadata.forEach { metadata[$0.key] = $0.value }
        return metadata
    }

    private static var vendorIdentifier: String? {
        #if canImport(UIKit) && !os(watchOS)
            return UIDevice.current.identifierForVendor?.uuidString
        #else
            return nil
        #endif
    }

    private static var platformName: String {
        #if os(iOS)
            return "iOS"
        #elseif os(macOS)
            return "macOS"
        #elseif os(watchOS)
            return "watchOS"
        #elseif os(tvOS)
            return "tvOS"
        #elseif os(visionOS)
            return "visionOS"
        #else
            return ProcessInfo.processInfo.operatingSystemName
        #endif
    }

    private static var deviceModel: String? {
        #if os(macOS)
            // Marketing model identifier, e.g. MacBookPro18,1
            return sysctlString("hw.model")
        #else
            // Device model identifier, e.g. iPhone15,2 (uname().machine is just arm64 on simulators)
            return sysctlString("hw.machine")
        #endif
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
            return nil
        }

        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else {
            return nil
        }

        return String(cString: value)
    }
}
