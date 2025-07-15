import 'package:ban_hang/screens/customer/enter_phone_code.dart';
import 'package:ban_hang/services/customer_services/phone_verification_service.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:ban_hang/utils/message.dart';

class VerifyPhoneNumberScreen extends StatefulWidget {
  final bool isForChange; // true: đổi số, false: đăng ký

  const VerifyPhoneNumberScreen({super.key, this.isForChange = false});

  @override
  State<VerifyPhoneNumberScreen> createState() => _VerifyPhoneNumberScreenState();
}

class _VerifyPhoneNumberScreenState extends State<VerifyPhoneNumberScreen> {
  String? _completePhoneNumber;
  String? _rawPhoneNumber;
  bool _isPhoneValid = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isForChange ? "Đổi số điện thoại" : "Xác minh số điện thoại")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Nhập số điện thoại'),
            const SizedBox(height: 16),
            IntlPhoneField(
              decoration: const InputDecoration(
                labelText: 'Số điện thoại',
                border: OutlineInputBorder(),
              ),
              initialCountryCode: 'VN',
              onChanged: (phone) {
                setState(() {
                  _completePhoneNumber = phone.completeNumber;
                  _rawPhoneNumber = phone.number;
                  _isPhoneValid = phone.number.length >= 9;
                });
              },
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _isPhoneValid ? _handleSendCode : null,
              child: const Text('Gửi mã xác minh'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSendCode() async {
    if (_completePhoneNumber == null) return;

    // Validate đầu 0
    if (_rawPhoneNumber!.startsWith('0')) {
      message.showSnackbarfalse(context, "Không cần nhập số 0 đầu!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = PhoneVerificationService();
      final verificationId = await service.sendCode(_completePhoneNumber!);

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EnterPhoneCodeScreen(
            verificationId: verificationId,
            phoneNumber: _completePhoneNumber!,
            isForChange: widget.isForChange,
          ),
        ),
      );

      if (result != null) {
        Navigator.pop(context, result); // Trả về số đã xác minh
      }
    } catch (e) {
      message.showSnackbarfalse(context, "Lỗi gửi mã: $e");
    }

    setState(() => _isLoading = false);
  }
}
