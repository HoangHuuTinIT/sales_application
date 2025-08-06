import 'package:ban_hang/services/customer_services/phone_verification_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ban_hang/utils/message.dart';

class EnterPhoneCodeScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final bool isForChange;

  const EnterPhoneCodeScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.isForChange = false,
  });

  @override
  State<EnterPhoneCodeScreen> createState() => _EnterPhoneCodeScreenState();
}

class _EnterPhoneCodeScreenState extends State<EnterPhoneCodeScreen> {
  final codeController = TextEditingController();
  bool _isVerifying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhập mã OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Nhập mã OTP đã nhận'),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Mã OTP',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            _isVerifying
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _handleVerify,
              child: const Text('Xác minh'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleVerify() async {
    final smsCode = codeController.text.trim();
    if (smsCode.isEmpty) return;

    setState(() => _isVerifying = true);

    try {
      final service = PhoneVerificationService();
      final credential = service.getCredential(
        verificationId: widget.verificationId,
        smsCode: smsCode,
      );

      if (widget.isForChange) {
        await FirebaseAuth.instance.currentUser?.updatePhoneNumber(credential);
      } else {
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
      if (mounted) Navigator.pop(context, widget.phoneNumber);
    } catch (e) {
      message.showSnackbarfalse(context, "Sai mã OTP hoặc lỗi: $e");
    }

    setState(() => _isVerifying = false);
  }
}
