import 'package:flutter/material.dart';
import 'package:ban_hang/services/customer_services/customer_order_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ban_hang/utils/message.dart';

class CustomerOrderScreen extends StatefulWidget {
  const CustomerOrderScreen({super.key});

  @override
  State<CustomerOrderScreen> createState() => _CustomerOrderScreenState();
}

class _CustomerOrderScreenState extends State<CustomerOrderScreen> {
  final CustomerOrderService _orderService = CustomerOrderService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn hàng của tôi')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _orderService.getMyOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Bạn chưa có đơn hàng nào.'));
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data() as Map<String, dynamic>;

              final createdAt = (data['createdAt'] as Timestamp).toDate();
              final orderCode = data['orderCode'] ?? '';
              final paymentMethod = data['paymentMethod'] ?? '';
              final status = data['status'] ?? '';
              final totalAmount = data['totalAmount'] ?? 0;
              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  title: Text(
                    'Mã đơn: $orderCode',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}'),
                      Text('Phương thức: $paymentMethod'),
                      Text('Trạng thái: $status'),
                      Text('Tổng tiền: ${message.formatCurrency(totalAmount)}'),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'details') {
                        Navigator.pushNamed(
                          context,
                          '/orderDetails',
                          arguments: {
                            'orderId': doc.id,
                            'orderData': data,
                          },
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Text('Chi tiết đơn hàng'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
