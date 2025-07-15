import 'package:flutter/material.dart';
import 'package:ban_hang/services/delivery/delivery_products_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryProductsScreen extends StatefulWidget {
  const DeliveryProductsScreen({super.key});

  @override
  State<DeliveryProductsScreen> createState() => _DeliveryProductsScreenState();
}

class _DeliveryProductsScreenState extends State<DeliveryProductsScreen> {
  final DeliveryProductsServices _services = DeliveryProductsServices();

  @override
  void initState() {
    super.initState();
    _services.loadDeliveryProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn hàng bạn đã nhận'),
      ),
      body: StreamBuilder(
        stream: _services.deliveryProductsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Chưa có đơn hàng nào.'));
          }

          final deliveries = snapshot.data!;

          return ListView.builder(
            itemCount: deliveries.length,
            itemBuilder: (context, index) {
              final delivery = deliveries[index];

              final status = delivery['status'] ?? '';

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text('Sản phẩm: ${delivery['productName']}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Số lượng: ${delivery['quantity']}'),
                      Text('Tổng: ${delivery['total']}'),
                      Text('Khách hàng: ${delivery['nameCustomer']}'),
                      Text('Trạng thái: $status'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: status == 'Shipper nhận hàng'
                                ? () async {
                              await _services.updateToTransporting(delivery);
                            }
                                : null, // Vô hiệu khi không ở trạng thái ban đầu
                            child: const Text('Vận chuyển'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: status == 'Đang vận chuyển'
                                ? () async {
                              await _services.completeDelivery(delivery);
                            }
                                : null, // Vô hiệu khi chưa Vận chuyển
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green),
                            child: const Text('Hoàn tất'),
                          ),
                        ],
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
