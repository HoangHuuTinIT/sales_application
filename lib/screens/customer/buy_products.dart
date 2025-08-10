
import 'package:ban_hang/screens/customer/home_customer.dart';
import 'package:ban_hang/services/customer_services/stripe_payment_service.dart';
import 'package:flutter/material.dart';
import 'package:ban_hang/utils/message.dart';
import 'package:ban_hang/screens/auth/signup_information.dart';
import 'package:ban_hang/services/customer_services/buy_products_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BuyProductsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> selectedItems;

  const BuyProductsScreen({super.key, required this.selectedItems});

  @override
  State<BuyProductsScreen> createState() => _BuyProductsScreenState();
}

class _BuyProductsScreenState extends State<BuyProductsScreen> {
  String paymentMethod = 'Thanh toán khi nhận hàng';
  bool _isSubmitting = false;
  bool _isEditing = false;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    print('🛒 selectedItems truyền vào: ${widget.selectedItems}');
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (snapshot.exists && snapshot.data() != null) {
        setState(() => userData = snapshot.data());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy thông tin người dùng')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải thông tin người dùng: $e')),
      );
    }
  }

  Future<void> _submitOrders() async {
    setState(() => _isSubmitting = true);
    try {
      for (final item in widget.selectedItems) {
        final orderData = {
          'productId': item['productId'],
          'productName': item['productName'],
          'total': ((item['totalAmount'] ?? 0) as num).toDouble(),
          'quantity': item['quantity'] as int,
          'paymentMethod': paymentMethod,
          'status': 'Đang chờ xác nhận',
        };

        // final barcodeData = '${item['productId']}_${DateTime.now().millisecondsSinceEpoch}';

        // await BuyProductsService().createOrderWithBarcode(
        //   barcodeData: barcodeData,
        //   orderData: orderData,
        // );

      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Đặt hàng thành công!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  double get total => widget.selectedItems.fold<double>(
    0,
        (sum, item) => sum + ((item['totalAmount'] ?? 0) as num).toDouble(),
  );


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác nhận đơn hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              setState(() => _isEditing = true);
              final userInfo = await BuyProductsService().fetchUserInfo();
              setState(() => _isEditing = false);
              if (!mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SignUpInformationScreen(
                    redirectToOrder: true,
                    initialData: userInfo,
                  ),
                ),
              );
              _loadUserInfo();
            },
          ),
        ],
      ),
      body: userData == null
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: ListTile(
                        leading: const Icon(Icons.person, size: 36),
                        title: Text(userData?['name'] ?? 'Chưa có'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Địa chỉ: ${userData?['address'] ?? 'Chưa có'}'),
                            Text('SĐT: ${userData?['phone'] ?? 'Chưa có'}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Sản phẩm đã chọn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...widget.selectedItems.map(
                          (item) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item['productImage'] ?? '',
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 50),
                            ),
                          ),
                          title: Text(item['productName'] ?? ''),
                          subtitle: Text(
                              'SL: ${item['quantity']}\nĐơn giá: ${message.formatCurrency((item['price'] ?? 0) as num)}'
                          ),
                          trailing: Text(
                            message.formatCurrency(item['totalAmount']),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Phương thức thanh toán', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            DropdownButton<String>(
                              value: paymentMethod,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'Thanh toán khi nhận hàng',
                                  child: Text('Thanh toán khi nhận hàng'),
                                ),
                                DropdownMenuItem(
                                  value: 'Chuyển khoản ngân hàng',
                                  child: Text('Chuyển khoản ngân hàng'),
                                ),
                              ],
                              onChanged: (value) => setState(() => paymentMethod = value!),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tổng cộng:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(message.formatCurrency(total), style: const TextStyle(fontSize: 16, color: Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                          if (paymentMethod == 'Chuyển khoản ngân hàng') {
                            final stripeService = StripePaymentService();
                            if (total < 13000) {
                              message.showSnackbarfalse(context, "CHỈ ÁP DỤNG VỚI ĐƠN HÀNG CÓ GIÁ TRỊ TỪ 13.000 VND TRỞ LÊN");
                              return;
                            }
                            final success = await stripeService.processPayment(total);
                            if (success) {
                              for (final item in widget.selectedItems) {
                                await stripeService.addOrderToFirestore(
                                  item: item,
                                  paymentMethod: paymentMethod,
                                );
                              }
                              message.showSnackbartrue(context, 'Đơn hàng đã được ghi nhận và thanh toán thành công');
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => HomeCustomer()),
                                    (route) => false, // Xóa toàn bộ stack trước đó
                              );

                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Bạn chưa hoàn tất thanh toán'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } else {
                            await _submitOrders(); // COD
                          }
                        },
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('ĐẶT HÀNG', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
