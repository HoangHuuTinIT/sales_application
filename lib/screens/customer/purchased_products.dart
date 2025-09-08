// lib/screens/customer/purchased_products_screen.dart

import 'package:ban_hang/services/customer_services/purchased_products_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.getPurchasedProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Đã xảy ra lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Bạn chưa có đơn hàng đã mua.'));
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final data = orders[index].data();

              // Lấy các trường thông tin giống bên CustomerOrderScreen
              final txlogisticId = data['txlogisticId'] ?? '';
              final billCode = data['billCode'] ?? '';
              // Lấy status từ đơn hàng đã thanh toán, hoặc mặc định là 'Đã thanh toán'
              final status = data['status'] == 'Hủy đơn' ? 'Hủy đơn' : 'Đã thanh toán';
              final totalAmount = data['totalAmount'] ?? 0;

              String paymentDateStr = "N/A";
              if (data['payment_date'] is Timestamp) {
                final date = (data['payment_date'] as Timestamp).toDate();
                paymentDateStr = DateFormat('dd/MM/yyyy HH:mm').format(date);
              }

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Mã đơn: $txlogisticId',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: txlogisticId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã copy mã đơn')),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Mã vận đơn: $billCode'),
                      Text('Ngày thanh toán: $paymentDateStr'),
                      Text('Trạng thái: $status'),
                      Text('Tổng tiền: ${message.formatCurrency(totalAmount)}'),
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