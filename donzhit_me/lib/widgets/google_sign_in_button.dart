import 'package:flutter/material.dart';

/// Stub for non-web platforms
/// On web, this is replaced by the actual renderButton from google_sign_in_web
Widget buildGoogleSignInButton() {
  // This should never be called on non-web platforms
  // as we use a custom button there
  return const SizedBox.shrink();
}
