import 'package:flutter/material.dart';
import 'package:ban_hang/services/auth_services/auth_service.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  void _handleGoogleSignUp(BuildContext context) async {
    await AuthService().signUpWithGoogleAndCheck(context: context);
  }

  void _handleFacebookSignUp(BuildContext context) async {
    await AuthService().signUpWithFacebookAndCheck(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tạo tài khoản")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () => _handleGoogleSignUp(context),
              icon: const Icon(Icons.account_circle),
              label: const Text("Đăng ký bằng Google"),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _handleFacebookSignUp(context),
              icon: const Icon(Icons.facebook, color: Colors.white),
              label: const Text("Đăng ký bằng Facebook"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
