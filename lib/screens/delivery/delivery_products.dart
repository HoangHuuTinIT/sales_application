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

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('OrderedProducts')
                    .doc(delivery['orderedProductsId'])
                    .get(),
                builder: (context, orderedSnap) {
                  if (!orderedSnap.hasData || !orderedSnap.data!.exists) {
                    return const ListTile(title: Text('Đang tải...'));
                  }

                  final orderedData =
                  orderedSnap.data!.data() as Map<String, dynamic>;

                  final productId = orderedData['productId'];
                  final customerId = orderedData['userId'];
                  final status = orderedData['status'] ?? '';

                  return FutureBuilder(
                    future: Future.wait([
                      FirebaseFirestore.instance
                          .collection('Products')
                          .doc(productId)
                          .get(),
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(customerId)
                          .get(),
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(delivery['deliveryId'])
                          .get(),
                    ]),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const ListTile(
                            title: Text('Đang tải chi tiết...'));
                      }

                      final productDoc = snap.data![0];
                      final customerDoc = snap.data![1];
                      final shipperDoc = snap.data![2];

                      final productName = productDoc['name'] ?? '';
                      final customerName = customerDoc['name'] ?? '';
                      final customerPhone = customerDoc['phone'] ?? '';
                      final customerAddress = customerDoc['address'] ?? '';
                      final shipperName = shipperDoc['name'] ?? '';

                      final quantity = orderedData['quantity'];
                      final total = orderedData['total'];
                      final paymentMethod = orderedData['paymentMethod'];

                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          title: Text('Sản phẩm: $productName'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Số lượng: $quantity'),
                              Text('Tổng: $total'),
                              Text('KH: $customerName'),
                              Text('Địa chỉ: $customerAddress'),
                              Text('SĐT: $customerPhone'),
                              Text('Thanh toán: $paymentMethod'),
                              Text('Shipper: $shipperName'),
                              Text('Trạng thái: $status'),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: status == 'Shipper nhận hàng'
                                        ? () async {
                                      await _services
                                          .updateToTransporting(
                                          delivery);
                                    }
                                        : null,
                                    child: const Text('Vận chuyển'),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: status == 'Đang vận chuyển'
                                        ? () async {
                                      await _services
                                          .completeDelivery(delivery);
                                    }
                                        : null,
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
              );
            },
          );
        },
      ),
    );
  }
}
