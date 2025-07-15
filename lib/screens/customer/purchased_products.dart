import 'package:ban_hang/services/customer_services/purchased_products_services.dart';
import 'package:flutter/material.dart';
import 'package:ban_hang/utils/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PurchasedProductsScreen extends StatelessWidget {
  const PurchasedProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PurchasedProductsService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn hàng đã mua'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.getPurchasedProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Bạn chưa có đơn hàng đã mua.'));
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final data = orders[index].data() as Map<String, dynamic>;
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final formattedDate = createdAt != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt)
                  : 'N/A';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  title: Text(data['productName'] ?? ''),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Số lượng: ${data['quantity'] ?? ''}'),
                      Text('Tổng tiền: ${message.formatCurrency(data['total'] ?? 0)}'),
                      Text('Ngày mua: $formattedDate'),
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
