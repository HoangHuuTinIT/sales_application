import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneVerificationService {
  final _auth = FirebaseAuth.instance;

  Future<String> sendCode(String phoneNumber) async {
    final completer = Completer<String>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (_) {},
      verificationFailed: (e) => completer.completeError(e),
      codeSent: (verificationId, resendToken) =>
          completer.complete(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );

    return completer.future;
  }

  PhoneAuthCredential getCredential({
    required String verificationId,
    required String smsCode,
  }) {
    return PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }
}
