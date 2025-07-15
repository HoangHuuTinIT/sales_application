import 'package:flutter/material.dart';
import 'package:ban_hang/screens/delivery/packaged_product.dart';
import 'package:ban_hang/screens/delivery/delivery_products.dart';
import 'package:ban_hang/screens/auth/signin.dart'; // 👈 Thêm import SignInScreen!
import 'package:ban_hang/services/delivery/delivery_home_services.dart';

class DeliveryHomeScreen extends StatelessWidget {
  const DeliveryHomeScreen({super.key});

  void _signOut(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SignInScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deliveryHomeServices = DeliveryHomeServices();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao diện Shipper'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                deliveryHomeServices.goToPackagedProducts(context);
              },
              child: const Text('Hàng đã được đóng gói'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                deliveryHomeServices.goToDeliveryProducts(context);
              },
              child: const Text('Đơn hàng bạn đã nhận'),
            ),
          ],
        ),
      ),
    );
  }
}
