import 'package:ban_hang/screens/auth/signin.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AccountTab extends StatelessWidget {
  final VoidCallback onSignOut;

  const AccountTab({super.key, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Xin chào!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
              ),
            ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/customer_account_information');
              },
              icon: const Icon(Icons.person),
              label: const Text('Tài khoản của tôi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
            ),

            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất'),
            ),
          ],
        ),
      ),
    );
  }
}
