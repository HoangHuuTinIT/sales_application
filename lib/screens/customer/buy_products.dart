import 'package:ban_hang/screens/auth/signup_information.dart';
import 'package:ban_hang/services/customer_services/buy_products_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ban_hang/utils/message.dart';

class BuyProductsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> selectedItems;

  const BuyProductsScreen({
    super.key,
    required this.selectedItems,
  });

  @override
  State<BuyProductsScreen> createState() => _OrderedProductsScreenState();
}

bool _isEditing = false;

class _OrderedProductsScreenState extends State<BuyProductsScreen> {
  Map<String, dynamic>? userData;
  String paymentMethod = 'Thanh toán khi nhận hàng';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        userData = snapshot.data();
      });
    }
  }

  double get total {
    return widget.selectedItems.fold<double>(
      0,
          (sum, item) => sum + (item['totalAmount'] as num).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận đơn hàng')),
      body: userData == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () async {
                setState(() => _isEditing = true);

                final userInfo =
                await BuyProductsService().fetchUserInfo();

                setState(() => _isEditing = false);

                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SignUpInformationScreen(
                        redirectToOrder: true,
                        initialData: userInfo,
                      ),
                    ),
                  ).then((_) => _loadUserInfo());
                }
              },
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thông tin người nhận',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Tên: ${userData?['name'] ?? ''}'),
                        Text('Địa chỉ: ${userData?['address'] ?? ''}'),
                        Text('SĐT: ${userData?['phone'] ?? ''}'),
                      ],
                    ),
                  ),
                  _isEditing
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.edit, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sản phẩm đã chọn',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: widget.selectedItems.length,
                itemBuilder: (context, index) {
                  final item = widget.selectedItems[index];
                  return ListTile(
                    leading: item['productImage'] != null
                        ? Image.network(item['productImage'], width: 60)
                        : const Icon(Icons.image_not_supported),
                    title: Text(item['productName'] ?? ''),
                    subtitle: Text('SL: ${item['quantity']} | '
                        'Tổng: ${message.formatCurrency(item['totalAmount'])}'),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Phương thức thanh toán',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            DropdownButton<String>(
              value: paymentMethod,
              items: [
                'Thanh toán khi nhận hàng',
                'Ngân hàng'
              ].map((method) {
                return DropdownMenuItem(
                  value: method,
                  child: Text(method),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  paymentMethod = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng cộng: ${message.formatCurrency(total)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    for (final item in widget.selectedItems) {
                      await BuyProductsService().createOrder(
                        name: userData?['name'] ?? '',
                        address: userData?['address'] ?? '',
                        phone: userData?['phone'] ?? '',
                        productId: item['productId'],
                        productName: item['productName'],
                        total: (item['totalAmount'] as num).toDouble(),
                        quantity: item['quantity'] as int,
                        paymentMethod: paymentMethod,
                      );
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('✅ Đặt hàng thành công!')),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Đặt hàng'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
