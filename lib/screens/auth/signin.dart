import 'package:ban_hang/screens/auth/forgot_password.dart';
import 'package:ban_hang/screens/auth/signup.dart';
import 'package:ban_hang/services/auth_services/auth_service.dart';
import 'package:ban_hang/utils/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';

class SignInScreen extends StatefulWidget {
  final String? redirectRoute;
  final Map<String, dynamic>? arguments;

  const SignInScreen({
    super.key,
    this.redirectRoute,
    this.arguments,
  });
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;
  bool isLoading = false;

  void _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final uid = userCredential.user?.uid;

      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        final userData = userDoc.data();

        if (userData != null && userData.containsKey('status')) {
          final status = userData['status'];

          if (status == 'chờ duyệt' || status == 'từ chối' || status == 'đã vô hiệu hóa') {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              setState(() => isLoading = false);
              message.showSnackbarfalse(context, "Tài khoản của bạn hiện không khả dụng.");
            }
            return;
          }
        }

        if (!mounted) return;
        if (widget.redirectRoute != null) {
          Navigator.pushReplacementNamed(
            context,
            widget.redirectRoute!,
            arguments: widget.arguments,
          );
        } else {
          await AuthService().navigateUserByRole(context);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);

      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message.showSnackbarfalse(
            context, "Tài khoản hoặc mật khẩu không chính xác.");
      } else if (e.code == 'network-request-failed') {
        message.showSnackbarfalse(context, 'Không có kết nối mạng.');
      } else {
        message.showSnackbarfalse(context, "Đăng nhập thất bại: ${e.message}");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      message.showSnackbarfalse(context, "Lỗi không xác định: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // final themeColor = Colors.indigo;

    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo, Colors.blueAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: const [
                  Text(
                    'Chào mừng bạn!',
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Đến với Quân đoàn mua sắm',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Image.asset("assets/images/logo_quandoanmuasam.png", height: 100),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: MultiValidator([
                          RequiredValidator(errorText: "Vui lòng nhập email"),
                          EmailValidator(errorText: "Email không hợp lệ"),
                        ]),
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        validator:
                        RequiredValidator(errorText: "Vui lòng nhập mật khẩu"),
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setState(() => obscurePassword = !obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _handleSignIn,
                          child: isLoading
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                              : const Text('Đăng nhập'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          side: const BorderSide(color: Colors.grey),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: Image.asset(
                          'assets/images/logo_google.png',
                          height: 24,
                        ),
                        label: const Text('Đăng nhập bằng Google'),
                        onPressed: () async {
                          setState(() => isLoading = true);
                          final error = await AuthService().signInWithGoogleAndCheckUserExists();
                          setState(() => isLoading = false);
                          if (!mounted) return;
                          if (error != null) {
                            message.showSnackbarfalse(context, error);
                          } else {
                            if (widget.redirectRoute != null) {
                              Navigator.pushReplacementNamed(
                                context,
                                widget.redirectRoute!,
                                arguments: widget.arguments,
                              );
                            } else {
                              await AuthService().navigateUserByRole(context);
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1877F2), // Màu Facebook
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: Image.asset(
                          'assets/images/iconfb.png', // bạn cần thêm icon này vào assets
                          height: 24,
                        ),
                        label: const Text('Đăng nhập bằng Facebook'),
                        onPressed: () async {
                          setState(() => isLoading = true);
                          final error = await AuthService().signInWithFacebookAndCheckUserExists();
                          setState(() => isLoading = false);
                          if (!mounted) return;
                          if (error != null) {
                            message.showSnackbarfalse(context, error);
                          } else {
                            if (widget.redirectRoute != null) {
                              Navigator.pushReplacementNamed(
                                context,
                                widget.redirectRoute!,
                                arguments: widget.arguments,
                              );
                            } else {
                              await AuthService().navigateUserByRole(context);
                            }
                          }
                        },
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const ForgotPasswordScreen()));
                            },
                            child: const Text('Quên mật khẩu?'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const SignUpScreen()));
                            },
                            child: const Text('Tạo tài khoản'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
