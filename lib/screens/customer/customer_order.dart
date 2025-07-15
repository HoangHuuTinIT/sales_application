import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ban_hang/services/customer_services/customer_order_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ban_hang/utils/message.dart';

class CustomerOrderScreen extends StatefulWidget {
  const CustomerOrderScreen({super.key});

  @override
  State<CustomerOrderScreen> createState() => _CustomerProductsScreenState();
}

class _CustomerProductsScreenState extends State<CustomerOrderScreen> {
  final _service = CustomerOrderService();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn hàng của tôi')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _service.getMyOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Bạn chưa có đơn hàng nào.'));
          }

          // 📌 LỌC đơn hàng
          final orders = snapshot.data!.docs.where((doc) {
            final status = (doc['status'] ?? '').toString();
            return status != 'Hoàn tất thanh toán';
          }).toList();

          if (orders.isEmpty) {
            return const Center(child: Text('Bạn chưa có đơn hàng nào.'));
          }

          return ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data() as Map<String, dynamic>;

              return FutureBuilder<String?>(
                future: _service.getProductImage(data['productName']),
                builder: (context, imageSnapshot) {
                  final imageUrl = imageSnapshot.data;

                  return ListTile(
                    leading: imageUrl != null
                        ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                        : const Icon(Icons.image_not_supported),
                    title: Text(data['productName'] ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Số lượng: ${data['quantity'] ?? ''}'),
                        Text('Tổng tiền: ${message.formatCurrency(data['total'] ?? 0)}'),
                        Text('Trạng thái: ${data['status'] ?? 'N/A'}'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Xác nhận hủy đơn'),
                            content: const Text('Bạn có muốn hủy đơn hàng này không?'),
                            actions: [
                              TextButton(
                                child: const Text('Không'),
                                onPressed: () => Navigator.pop(context, false),
                              ),
                              TextButton(
                                child: const Text('Xác nhận'),
                                onPressed: () => Navigator.pop(context, true),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await _service.cancelOrderAndSave(doc.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã hủy đơn hàng')),
                          );
                        }
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),

    );
  }
}
