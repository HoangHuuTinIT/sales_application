// lib/screens/owner/create_order_for_customer.dart
import 'dart:async';

import 'package:ban_hang/services/customer_services/customer_order_services.dart';
import 'package:ban_hang/services/owner_services/customer_order_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'edit_customer_for_order.dart';


class CreateOrderForCustomerScreen extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> customerDoc;

  const CreateOrderForCustomerScreen({super.key, required this.customerDoc});

  @override
  State<CreateOrderForCustomerScreen> createState() => _CreateOrderForCustomerScreenState();
}

class _CreateOrderForCustomerScreenState extends State<CreateOrderForCustomerScreen> {
  late Map<String, dynamic> customerData;

  Map<String, dynamic>? selectedProduct;
  int quantity = 1;
  double totalPrice = 0;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    customerData = widget.customerDoc.data();
    // Bỏ _loadProducts() ở đây vì không cần load danh sách sản phẩm
  }

  void _selectProduct() async {
    final product = await Navigator.pushNamed(context, '/chose_product_for_order');
    if (product != null && product is Map<String, dynamic>) {
      setState(() {
        selectedProduct = product;
        quantity = 1;
        totalPrice = (selectedProduct!['price'] ?? 0) * quantity;
      });
    }
  }

  void _onQuantityChanged(int newQuantity) {
    if (newQuantity < 1) return;
    setState(() => quantity = newQuantity);

    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      setState(() {
        totalPrice = (selectedProduct?['price'] ?? 0) * quantity;
      });
    });
  }

  Color _statusColor(String status) {
    if (status == 'Bình thường') return Colors.green;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = customerData['avatarUrl'] as String?;
    final name = (customerData['name'] as String?)?.isNotEmpty == true ? customerData['name'] : 'Chưa có tên';
    final status = (customerData['status'] as String?) ?? '';
    final phone = (customerData['phone'] as String?)?.isNotEmpty == true ? customerData['phone'] : 'Chưa có số điện thoại';
    final address = (customerData['address'] as String?)?.isNotEmpty == true ? customerData['address'] : 'Chưa có địa chỉ';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo đơn cho khách hàng'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditCustomerForOrderScreen(
                      customerId: widget.customerDoc.id,
                      initialData: customerData,
                    ),
                  ),
                ).then((updatedData) async {
                  if (updatedData != null && updatedData is Map<String, dynamic>) {
                    final doc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.customerDoc.id)
                        .get();

                    if (doc.exists) {
                      setState(() {
                        customerData = doc.data()!;
                      });
                    }
                  }
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Chỉnh sửa thông tin khách hàng'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thông tin khách hàng
            Row(
              children: [
                avatarUrl != null
                    ? CircleAvatar(radius: 40, backgroundImage: NetworkImage(avatarUrl))
                    : const CircleAvatar(radius: 40, child: Icon(Icons.person)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(status),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(status, style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('Số điện thoại: $phone')),
                const SizedBox(width: 16),
                Expanded(child: Text('Địa chỉ: $address')),
              ],
            ),
            const SizedBox(height: 20),

            // Nút chọn sản phẩm để sang màn hình chọn
            ElevatedButton(
              onPressed: _selectProduct,
              child: const Text('Chọn sản phẩm'),
            ),

            // Hiển thị sản phẩm được chọn
            if (selectedProduct != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  selectedProduct!['imageUrl'] != null && selectedProduct!['imageUrl'].isNotEmpty
                      ? CircleAvatar(backgroundImage: NetworkImage(selectedProduct!['imageUrl']))
                      : CircleAvatar(child: Text(selectedProduct!['name'][0].toUpperCase())),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(selectedProduct!['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Tồn kho: ${selectedProduct!['stock'] ?? 0}', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Row(
                        children: [
                          IconButton(onPressed: () => _onQuantityChanged(quantity - 1), icon: const Icon(Icons.remove)),
                          Text('$quantity'),
                          IconButton(onPressed: () => _onQuantityChanged(quantity + 1), icon: const Icon(Icons.add)),
                        ],
                      ),
                      Text('Tổng: ${totalPrice.toStringAsFixed(0)} đ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}


