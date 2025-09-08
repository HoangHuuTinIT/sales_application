import 'package:ban_hang/services/owner_services/order_created_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // để dùng Clipboard
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
  final OrderCreatedServices _ownerOrderService = OrderCreatedServices();

  void _showOrderItems(String orderId) async {
    final items = await _orderService.getOrderItems(orderId);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text("Không có sản phẩm nào trong đơn này."),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: (item['imageUrls'] != null &&
                    (item['imageUrls'] as List).isNotEmpty)
                    ? Image.network(
                  item['imageUrls'][0],
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                )
                    : const Icon(Icons.image_not_supported, size: 40),
                title: Text(item['name'] ?? 'Sản phẩm'),
                subtitle: Text(
                  'SL: ${item['quantity']}  |  Giá: ${message.formatCurrency(item['price'] ?? 0)}',
                ),
                trailing: Text(
                  message.formatCurrency(item['total'] ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn hàng của tôi')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _orderService.getMyOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Đơn hàng của bạn sẽ hiện ở đây khi được đơn vị bán hàng xử lý'),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data();
              final Map<String, dynamic> orderDataForCancel = {
                ...data,
                'docId': doc.id, // Rất quan trọng: phải có docId
              };

              final txlogisticId = data['txlogisticId'] ?? '';
              final billCode = data['billCode'] ?? '';
              final status = data['status'] ?? '';
              final totalAmount = data['totalAmount'] ?? 0;

              String invoiceDate = "";
              if (data['invoiceDate'] is Timestamp) {
                final date = (data['invoiceDate'] as Timestamp).toDate();
                invoiceDate = DateFormat('dd/MM/yyyy HH:mm').format(date);
              }

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
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
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: txlogisticId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã copy mã đơn')),
                              );
                            },
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'items') {
                                _showOrderItems(doc.id);
                              } else if (value == 'cancel') {
                                // Dòng này đã đúng, nó sẽ gọi đến hàm showCancelDialog đã được cập nhật ở trên
                                _ownerOrderService.showCancelDialog(context, orderDataForCancel);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'items',
                                child: Text('Chi tiết sản phẩm'),
                              ),
                              if (status != "Hủy đơn")
                                const PopupMenuItem(
                                  value: 'cancel',
                                  child: Text('Hủy đơn'),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Mã vận đơn: $billCode'),
                      Text('Ngày: $invoiceDate'),
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
