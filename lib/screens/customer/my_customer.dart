import 'package:ban_hang/screens/auth/signin.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AccountTab extends StatelessWidget {
  final VoidCallback onSignOut;

  const AccountTab({super.key, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      elevation: 4,
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // căn trái
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignInScreen(
                                  redirectRoute: '/my_orders',
                                ),
                              ),
                            );
                          } else {
                            Navigator.pushNamed(context, '/my_orders');
                          }
                        },
                        icon: const Icon(Icons.list_alt),
                        label: const Text('Đơn hàng của bạn'),
                        style: buttonStyle.copyWith(
                          backgroundColor:
                          MaterialStateProperty.all(Colors.deepOrange),
                          minimumSize:
                          MaterialStateProperty.all(Size(double.infinity, 48)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignInScreen(
                                  redirectRoute: '/purchased_products',
                                ),
                              ),
                            );
                          } else {
                            Navigator.pushNamed(context, '/purchased_products');
                          }
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Đơn hàng đã mua'),
                        style: buttonStyle.copyWith(
                          backgroundColor:
                          MaterialStateProperty.all(Colors.green),
                          minimumSize:
                          MaterialStateProperty.all(Size(double.infinity, 48)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                              context, '/customer_account_information');
                        },
                        icon: const Icon(Icons.person),
                        label: const Text('Tài khoản của tôi'),
                        style: buttonStyle.copyWith(
                          backgroundColor:
                          MaterialStateProperty.all(Colors.blue),
                          minimumSize:
                          MaterialStateProperty.all(Size(double.infinity, 48)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: onSignOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Đăng xuất'),
                        style: buttonStyle.copyWith(
                          backgroundColor:
                          MaterialStateProperty.all(Colors.grey.shade700),
                          minimumSize:
                          MaterialStateProperty.all(Size(double.infinity, 48)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
