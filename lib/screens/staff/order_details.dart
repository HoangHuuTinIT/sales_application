import 'package:ban_hang/services/staff_services/order_details_services.dart';
import 'package:ban_hang/utils/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> orderData;
  final String orderId;

  const OrderDetailsScreen({
    required this.orderId,
    required this.orderData,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final orderDetailsService = OrderDetailsService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đơn hàng'),
        backgroundColor: Colors.indigo,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: orderDetailsService.getOrderDetails(orderId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final details = snapshot.data!.docs;
          int total = 0;

          final items = details.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final data = entry.value.data() as Map<String, dynamic>;
            total += ((data['total'] ?? 0) as num).toInt();

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo.shade100,
                  child: const Icon(Icons.shopping_bag, color: Colors.indigo),
                ),
                title: Text(
                  '${data['productName']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'x${data['quantity']} • ${message.formatCurrency(data['price'])}',
                ),
                trailing: Text(
                  message.formatCurrency(data['total']),
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Danh sách sản phẩm
                ...items,
                const SizedBox(height: 12),
                const Divider(thickness: 1.2),
                // Thông tin đơn hàng
                Container(
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.attach_money,
                        label: "Tổng cộng",
                        value: message.formatCurrency(total),
                        valueColor: Colors.red,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.payment,
                        label: "Phương thức",
                        value: orderData['paymentMethod'] ?? '',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.date_range,
                        label: "Ngày đặt",
                        value: DateFormat('dd/MM/yyyy HH:mm').format(
                          (orderData['createdAt'] as Timestamp).toDate(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.info_outline,
                        label: "Trạng thái",
                        value: orderData['status'] ?? '',
                        valueColor: Colors.blue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color valueColor = Colors.black87,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.indigo),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
