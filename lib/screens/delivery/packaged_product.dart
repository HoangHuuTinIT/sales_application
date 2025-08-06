import 'package:ban_hang/utils/message.dart';
import 'package:flutter/material.dart';
import 'package:ban_hang/services/delivery/packaged_product_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PackagedProductScreen extends StatefulWidget {
  const PackagedProductScreen({super.key});

  @override
  State<PackagedProductScreen> createState() => _PackagedProductScreenState();
}

class _PackagedProductScreenState extends State<PackagedProductScreen> {
  final PackagedProductServices _services = PackagedProductServices();

  @override
  void initState() {
    super.initState();
    _services.loadPackagedProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách hàng đã đóng gói'),
      ),
      body: StreamBuilder(
        stream: _services.packagedProductsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Không có sản phẩm nào.'));
          }

          final products = snapshot.data!;

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];

              return FutureBuilder(
                future: Future.wait([
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(product['userId'])
                      .get(),
                  FirebaseFirestore.instance
                      .collection('Products')
                      .doc(product['productId'])
                      .get(),
                ]),
                builder: (context, AsyncSnapshot<List<DocumentSnapshot>> snap) {
                  if (!snap.hasData) {
                    return const ListTile(
                      title: Text('Đang tải...'),
                    );
                  }

                  final userDoc = snap.data![0];
                  final productDoc = snap.data![1];

                  final customerName =
                  userDoc.exists ? userDoc['name'] ?? '---' : '---';
                  final address =
                  userDoc.exists ? userDoc['address'] ?? '---' : '---';
                  final phone =
                  userDoc.exists ? userDoc['phone'] ?? '---' : '---';

                  final productName =
                  productDoc.exists ? productDoc['name'] ?? '---' : '---';

                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      title: Text('Tên KH: $customerName'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Địa chỉ: $address'),
                          Text('SĐT: $phone'),
                          Text('Sản phẩm: $productName'),
                          Text('Số lượng: ${product['quantity']}'),
                          Text('Thanh toán: ${product['paymentMethod']}'),
                          Text('Trạng thái: ${product['status']}'),
                          Text(
                              'Tổng: ${message.formatCurrency(product['total'])}'),
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          await _services.acceptProduct(product);
                          message.showSnackbartrue(
                              context, 'Bạn đã nhận hàng thành công');
                        },
                        child: const Text('Nhận hàng'),
                      ),
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
