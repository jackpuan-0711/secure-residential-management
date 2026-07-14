import Flutter
import LocalAuthentication
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var localAuthChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LocalAuthBridge")
    localAuthChannel = FlutterMethodChannel(
      name: "secure_residential/local_auth",
      binaryMessenger: registrar.messenger()
    )
    localAuthChannel?.setMethodCallHandler { call, result in
      guard call.method == "authenticate" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any]
      let reason = args?["reason"] as? String ?? "Verify your biometrics to continue."
      self.authenticateWithBiometrics(reason: reason, result: result)
    }
  }

  private func authenticateWithBiometrics(reason: String, result: @escaping FlutterResult) {
    let context = LAContext()
    var error: NSError?
    let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics

    guard context.canEvaluatePolicy(policy, error: &error) else {
      result(
        FlutterError(
          code: "not_configured",
          message: error?.localizedDescription
            ?? "Set up Face ID or Touch ID on this device first.",
          details: nil
        )
      )
      return
    }

    context.evaluatePolicy(policy, localizedReason: reason) { success, authError in
      DispatchQueue.main.async {
        if success {
          result(true)
        } else if let authError {
          result(
            FlutterError(
              code: self.flutterBiometricCode(from: authError),
              message: authError.localizedDescription,
              details: nil
            )
          )
        } else {
          result(false)
        }
      }
    }
  }

  private func flutterBiometricCode(from error: Error) -> String {
    guard let laError = error as? LAError else {
      return "unavailable"
    }

    switch laError.code {
    case .biometryNotAvailable:
      return "unavailable"
    case .biometryNotEnrolled, .passcodeNotSet:
      return "not_configured"
    case .userCancel, .systemCancel, .appCancel, .userFallback:
      return "cancelled"
    default:
      return "unavailable"
    }
  }
}
