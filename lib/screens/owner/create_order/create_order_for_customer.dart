// lib/screens/owner/create_order_for_customer.dart
import 'dart:async';

import 'package:ban_hang/utils/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_customer_for_order.dart';
import 'edit_address_for_order.dart';

class CreateOrderForCustomerScreen extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> customerDoc;
  const CreateOrderForCustomerScreen({super.key, required this.customerDoc});

  @override
  State<CreateOrderForCustomerScreen> createState() =>
      _CreateOrderForCustomerScreenState();
}

class _CreateOrderForCustomerScreenState
    extends State<CreateOrderForCustomerScreen> {
  late Map<String, dynamic> customerData;
  Map<String, dynamic>? selectedProduct;
  int quantity = 1;
  double totalPrice = 0;
  List<Map<String, dynamic>> selectedProducts = [];
  Timer? _debounce;
  int totalQuantity = 0;
  double totalWeight = 0; // Khối lượng tính theo số lượng sản phẩm
  String sellerName = '';

  // Thêm biến lưu địa chỉ giao hàng tạm thời
  Map<String, dynamic>? temporaryShippingAddress;

  // Phương thức thanh toán
  String paymentMethod = 'Tiền mặt';

  @override
  void initState() {
    super.initState();
    customerData = widget.customerDoc.data();
    _getSellerName();

  }
  Future<void> _getSellerName() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    if (doc.exists) {
      setState(() {
        sellerName = doc.data()?['name'] ?? 'Chưa có tên';
      });
    }
  }

  void _selectProduct() async {
    final products =
    await Navigator.pushNamed(context, '/chose_product_for_order');
    if (products != null && products is List<Map<String, dynamic>>) {
      setState(() {
        selectedProducts =
            products.map((p) => {...p, 'quantity': 1}).toList();
        _calculateTotal();
      });
    }
  }

  void _calculateTotal() {
    totalPrice = 0;
    totalQuantity = 0;
    totalWeight = 0;
    for (var p in selectedProducts) {
      int qty = p['quantity'] ?? 1;
      double price = (p['price'] ?? 0).toDouble();
      double weight = (p['weight'] ?? 0).toDouble();
      totalPrice += price * qty;
      totalQuantity += qty;
      totalWeight += weight * qty;
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
    final name = (customerData['name'] as String?)?.isNotEmpty == true
        ? customerData['name']
        : 'Chưa có tên';
    final status = (customerData['status'] as String?) ?? '';
    final phone =
    (customerData['phone'] as String?)?.isNotEmpty == true
        ? customerData['phone']
        : 'Chưa có số điện thoại';
    final address =
    (customerData['address'] as String?)?.isNotEmpty == true
        ? customerData['address']
        : 'Chưa có địa chỉ';

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
                  if (updatedData != null &&
                      updatedData is Map<String, dynamic>) {
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Thông tin khách hàng ---
            Container(
              width: double.infinity,
              color: Colors.white70,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      avatarUrl != null
                          ? CircleAvatar(
                          radius: 40,
                          backgroundImage: NetworkImage(avatarUrl))
                          : const CircleAvatar(
                          radius: 40, child: Icon(Icons.person)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(status),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(status,
                                  style:
                                  const TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$phone-$address'),
                    ],
                  ),
                ],
              ),
            ),

            Container(height: 8, color: Colors.grey[200]),

            // --- Sản phẩm ---
            Container(
              width: double.infinity,
              color: Colors.white70,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _selectProduct,
                    child: const Text('Chọn sản phẩm khác'),
                  ),
                  if (selectedProducts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Column(
                      children: selectedProducts.map((product) {
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('Products')
                              .doc(product['id'])
                              .get(),
                          builder: (context, snapshot) {
                            Widget imageWidget;

                            if (snapshot.connectionState == ConnectionState.waiting) {
                              imageWidget = Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[300],
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            } else if (snapshot.hasData && snapshot.data!.exists) {
                              final data = snapshot.data!.data() as Map<String, dynamic>;
                              final currentUserId = FirebaseAuth.instance.currentUser!.uid;

                              if (data['creatorId'] == currentUserId &&
                                  data['imageUrls'] != null &&
                                  data['imageUrls'] is List &&
                                  (data['imageUrls'] as List).isNotEmpty) {
                                imageWidget = Image.network(
                                  data['imageUrls'][0],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                );
                              } else {
                                imageWidget = _buildFallbackAvatar(product['name']);
                              }
                            } else {
                              imageWidget = _buildFallbackAvatar(product['name']);
                            }

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: imageWidget,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product['name'] ?? 'Tên sản phẩm',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Giá: ${(product['price'] ?? 0).toStringAsFixed(0)} đ',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Tồn kho: ${product['stockQuantity'] ?? 0}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        onPressed: () {
                                          setState(() {
                                            if (product['quantity'] > 1) product['quantity']--;
                                            _calculateTotal();
                                          });
                                        },
                                      ),
                                      SizedBox(
                                        width: 50,
                                        height: 35,
                                        child: TextField(
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          controller: TextEditingController(
                                            text: product['quantity'].toString(),
                                          ),
                                          onChanged: (value) {
                                            final qty = int.tryParse(value) ?? 1;
                                            setState(() {
                                              product['quantity'] = qty < 1 ? 1 : qty;
                                              _calculateTotal();
                                            });
                                          },
                                          decoration: const InputDecoration(
                                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        onPressed: () {
                                          setState(() {
                                            product['quantity']++;
                                            _calculateTotal();
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Tổng cộng: ${message.formatCurrency(totalPrice)}',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Số lượng: $totalQuantity',
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Khối lượng: ${totalWeight.toStringAsFixed(2)} kg',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 12),

            // --- Thông tin thanh toán ---
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payment,color: Colors.green,),
                      const Text(
                        'Thông tin thanh toán',
                        style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Phương thức thanh toán',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'Tiền mặt', child: Text('Tiền mặt')),
                      DropdownMenuItem(
                          value: 'Chuyển khoản',
                          child: Text('Chuyển khoản')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          paymentMethod = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tổng cộng: ${message.formatCurrency(totalPrice)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // --- Địa chỉ giao hàng ---
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.map, color: Colors.green,),
                          const Text(
                            'Địa chỉ giao hàng',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),

                      IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.blue),
                        onPressed: () async {
                          final updatedAddress =
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditAddressForOrderScreen(
                                    initialData:
                                    temporaryShippingAddress ??
                                        {
                                          'phone': phone,
                                          'name': name,
                                          'address': address,
                                        },
                                  ),
                            ),
                          );
                          if (updatedAddress != null && mounted) {
                            setState(() {
                              temporaryShippingAddress =
                                  updatedAddress;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${temporaryShippingAddress?['name'] ?? name}|${temporaryShippingAddress?['phone'] ?? phone}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    '${temporaryShippingAddress?['address'] ?? address}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12,),
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error , color: Colors.green,),
                      const Text(
                        'Thông tin khác',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold ,),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ngày hóa đơn: ${DateTime.now().day.toString().padLeft(2, '0')}/'
                        '${DateTime.now().month.toString().padLeft(2, '0')}/'
                        '${DateTime.now().year}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Người bán: $sellerName',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ghi chú: ',
                    style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildFallbackAvatar(String? productName) {
    return Container(
      width: 60,
      height: 60,
      color: Colors.blue[100],
      child: Center(
        child: Text(
          (productName?.isNotEmpty == true
              ? productName![0]
              : 'S')
              .toUpperCase(),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
