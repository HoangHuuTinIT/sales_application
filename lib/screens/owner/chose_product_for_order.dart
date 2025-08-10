import 'package:ban_hang/services/customer_services/customer_order_services.dart';
import 'package:ban_hang/services/owner_services/customer_order_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';


class ChoseProductForOrderScreen extends StatefulWidget {
  const ChoseProductForOrderScreen({super.key});

  @override
  State<ChoseProductForOrderScreen> createState() => _ChoseProductForOrderScreenState();
}

class _ChoseProductForOrderScreenState extends State<ChoseProductForOrderScreen> {
  final CustomerOrderServiceLive _service = CustomerOrderServiceLive();
  List<Map<String, dynamic>> products = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      loading = true;
    });
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final list = await _service.fetchProducts(uid);
    setState(() {
      products = list;
      loading = false;
    });
  }

  void _goToAddProduct({Map<String, dynamic>? product}) {
    Navigator.pushNamed(
      context,
      '/add_product_for_order',
      arguments: product, // truyền sản phẩm để sửa
    ).then((value) {
      if (value == true) {
        _loadProducts();
      }
    });
  }

  Future<void> _confirmDeleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa sản phẩm này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (confirm == true) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      try {
        await _service.deleteProduct(productId, uid);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Xóa sản phẩm thành công')));
        _loadProducts();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xóa sản phẩm: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn sản phẩm'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'add_product') _goToAddProduct();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'add_product', child: Text('Thêm sản phẩm')),
            ],
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : products.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Chưa có sản phẩm nào'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _goToAddProduct(),
              child: const Text('Thêm sản phẩm'),
            )
          ],
        ),
      )
          : ListView.builder(
        itemCount: products.length,
        itemBuilder: (context, i) {
          final p = products[i];
          return ListTile(
            leading: p['imageUrl'] != null && p['imageUrl'].isNotEmpty
                ? CircleAvatar(backgroundImage: NetworkImage(p['imageUrl']))
                : CircleAvatar(child: Text(p['name'][0].toUpperCase())),
            title: Text(p['name']),
            subtitle: Text('Tồn kho: ${p['stock'] ?? 0}', style: const TextStyle(color: Colors.grey)),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _goToAddProduct(product: p);
                } else if (value == 'delete') {
                  _confirmDeleteProduct(p['id']);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Sửa sản phẩm')),
                PopupMenuItem(value: 'delete', child: Text('Xóa sản phẩm')),
              ],
            ),
            onTap: () {
              Navigator.pop(context, p);
            },
          );
        },
      ),
    );
  }
}

