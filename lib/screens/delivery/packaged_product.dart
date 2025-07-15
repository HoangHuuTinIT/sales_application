import 'package:ban_hang/utils/message.dart';
import 'package:flutter/material.dart';
import 'package:ban_hang/services/delivery/packaged_product_services.dart';

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
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text('Tên KH: ${product['name']}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Địa chỉ: ${product['address']}'),
                      Text('SĐT: ${product['phone']}'),
                      Text('Sản phẩm: ${product['productName']}'),
                      Text('Số lượng: ${product['quantity']}'),
                      Text('Thanh toán: ${product['paymentMethod']}'),
                      Text('Trạng thái: ${product['status']}'),
                      Text('Tổng: ${product['total']}'),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      await _services.acceptProduct(product);
                      message.showSnackbartrue(context, 'Bạn đã nhận hàng thành công');
                    },
                    child: const Text('Nhận hàng'),
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
