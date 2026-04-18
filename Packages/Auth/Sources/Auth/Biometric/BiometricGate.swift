import Foundation
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

/// Optional Face ID / Touch ID / device-passcode gate at app launch.
///
/// Configurable: a user opts in via Settings → Security. When enabled, the
/// app calls `evaluate(reason:)` on launch and only reveals workspace data
/// after success.
public protocol BiometricGate: Sendable {
    func availability() async -> BiometricAvailability
    func evaluate(reason: String) async throws -> Bool
}

public enum BiometricAvailability: Sendable, Equatable {
    case available(BiometryKind)
    case notEnrolled
    case notAvailable
    case unknown
}

public enum BiometryKind: Sendable, Equatable {
    case faceID
    case touchID
    case opticID
    case none
}

public enum BiometricError: Error, Sendable, Equatable {
    case notAvailable
    case userCanceled
    case authenticationFailed
    case underlying(String)
}

#if canImport(LocalAuthentication)
public struct LiveBiometricGate: BiometricGate {
    public init() {}

    public func availability() async -> BiometricAvailability {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        if !canEvaluate {
            if let nsError = error, nsError.code == LAError.biometryNotEnrolled.rawValue {
                return .notEnrolled
            }
            return .notAvailable
        }
        switch context.biometryType {
        case .faceID:  return .available(.faceID)
        case .touchID: return .available(.touchID)
        case .opticID: return .available(.opticID)
        case .none:    return .available(.none)
        @unknown default: return .unknown
        }
    }

    public func evaluate(reason: String) async throws -> Bool {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .systemCancel, .appCancel:
                throw BiometricError.userCanceled
            case .authenticationFailed:
                throw BiometricError.authenticationFailed
            case .biometryNotAvailable, .biometryNotEnrolled:
                throw BiometricError.notAvailable
            default:
                throw BiometricError.underlying(error.localizedDescription)
            }
        }
    }
}
#endif

/// Test fake — always returns whatever the test sets up.
public struct FakeBiometricGate: BiometricGate {
    public let availabilityResult: BiometricAvailability
    public let evaluateResult: Result<Bool, BiometricError>

    public init(
        availabilityResult: BiometricAvailability = .available(.faceID),
        evaluateResult: Result<Bool, BiometricError> = .success(true)
    ) {
        self.availabilityResult = availabilityResult
        self.evaluateResult = evaluateResult
    }

    public func availability() async -> BiometricAvailability { availabilityResult }
    public func evaluate(reason: String) async throws -> Bool { try evaluateResult.get() }
}
