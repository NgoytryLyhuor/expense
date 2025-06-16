import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

class BiometricAuth {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if biometric authentication is available on the device
  static Future<Map<String, dynamic>> isBiometricAvailable() async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      final List<BiometricType> availableBiometrics =
      await _localAuth.getAvailableBiometrics();

      final bool hasFingerprint = availableBiometrics.contains(BiometricType.fingerprint) ||
          availableBiometrics.contains(BiometricType.strong);

      return {
        'isAvailable': canCheckBiometrics && isDeviceSupported && hasFingerprint,
        'hasEnrolledFingerprints': hasFingerprint,
        'availableBiometrics': availableBiometrics.map((e) => e.name).toList(),
        'error': null,
      };
    } catch (e) {
      return {
        'isAvailable': false,
        'hasEnrolledFingerprints': false,
        'availableBiometrics': <String>[],
        'error': 'Failed to check biometric availability: $e',
      };
    }
  }

  /// Authenticate user using biometric authentication
  static Future<Map<String, dynamic>> authenticate() async {
    try {
      final bool isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Scan your fingerprint to access the app',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Fingerprint Authentication',
            cancelButton: 'Cancel',
            biometricHint: 'Place your finger on the sensor',
            biometricNotRecognized: 'Fingerprint not recognized. Try again.',
            biometricRequiredTitle: 'Fingerprint Required',
            biometricSuccess: 'Authentication successful',
            goToSettingsButton: 'Go to Settings',
            goToSettingsDescription:
            'Fingerprint is not set up. Go to Settings > Security to add your fingerprint.',
          ),
        ],
      );

      return {
        'success': isAuthenticated,
        'error': null,
      };
    } on PlatformException catch (e) {
      final String errorMessage = _getErrorMessage(e.code);

      return {
        'success': false,
        'error': errorMessage,
        'errorCode': e.code,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'An unexpected error occurred: $e',
        'errorCode': 'unknown',
      };
    }
  }

  /// Get user-friendly error message based on error code
  static String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case auth_error.notEnrolled:
        return 'No fingerprints enrolled. Please add a fingerprint in device settings.';
      case auth_error.lockedOut:
        return 'Fingerprint sensor temporarily locked. Try again later.';
      case auth_error.permanentlyLockedOut:
        return 'Fingerprint sensor permanently locked. Use PIN to unlock in device settings.';
      case auth_error.notAvailable:
        return 'Fingerprint authentication is not available on this device.';
      case auth_error.passcodeNotSet:
        return 'No device credential set. Please set up a PIN or password in device settings.';
      case 'UserCancel':
        return 'Authentication cancelled by user.';
      case 'SystemCancel':
        return 'Authentication cancelled by system.';
      case 'TouchIDNotAvailable':
      case 'BiometricNotAvailable':
        return 'Biometric authentication is not available.';
      case 'TouchIDNotEnrolled':
      case 'BiometricNotEnrolled':
        return 'No biometrics enrolled on this device.';
      case 'no_fragment_activity':
        return 'App configuration error. Please restart the app.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  /// Check if biometric authentication is ready to use
  static Future<bool> isReadyForAuthentication() async {
    final result = await isBiometricAvailable();
    return result['isAvailable'] == true;
  }

  /// Get user-friendly biometric type name
  static String getBiometricTypeName(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) {
      return 'Face Recognition';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (types.contains(BiometricType.iris)) {
      return 'Iris Scan';
    } else if (types.contains(BiometricType.strong) ||
        types.contains(BiometricType.weak)) {
      return 'Biometric Authentication';
    }
    return 'Unknown Biometric';
  }
}