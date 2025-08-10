import 'dart:async';

import 'package:ban_hang/services/owner_services/customer_order_service.dart';
import 'package:ban_hang/utils/message.dart';
import 'package:flutter/material.dart';



class ChoseProductForOrderScreen extends StatefulWidget {
  const ChoseProductForOrderScreen({Key? key}) : super(key: key);

  @override
  State<ChoseProductForOrderScreen> createState() => _ChoseProductForOrderScreenState();
}

class _ChoseProductForOrderScreenState extends State<ChoseProductForOrderScreen> {
  final CustomerOrderServiceLive _service = CustomerOrderServiceLive();
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> selectedProducts = [];
  bool loading = true;
  TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }
  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => loading = true);
    final list = await _service.loadProductsForCurrentUser();
    setState(() {
      products = list;
      filteredProducts = List.from(products);
      loading = false;
    });
  }


  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      setState(() {
        filteredProducts = _service.searchProducts(products, query);
      });
    });
  }



  void _toggleSelection(Map<String, dynamic> product, bool selected) {
    setState(() {
      selectedProducts =
          _service.toggleSelection(selectedProducts, product, selected);
    });
  }

  void _confirmSelection() {
    Navigator.pop(context, _service.confirmSelection(selectedProducts));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn sản phẩm'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'add_product') {
                Navigator.pushNamed(context, '/add_product_for_order').then((value) {
                  if (value == true) _loadProducts();
                });
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'add_product',
                child: Text('Thêm sản phẩm'),
              ),
            ],
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm sản phẩm...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(height: 8),

          // Danh sách sản phẩm
          Expanded(
            child: filteredProducts.isEmpty
                ? const Center(child: Text('Không tìm thấy sản phẩm'))
                : ListView.builder(
              itemCount: filteredProducts.length,
              itemBuilder: (context, i) {
                final p = filteredProducts[i];
                final isSelected =
                selectedProducts.any((sp) => sp['id'] == p['id']);
                final imageUrls = p['imageUrls'] as List<String>;
                return ListTile(
                  leading: Checkbox(
                    value: isSelected,
                    onChanged: (v) =>
                        _toggleSelection(p, v ?? false),
                  ),
                  title: Text(p['name']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tồn kho: ${p['stockQuantity'] ?? 0}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      Text(
                        'Giá: ${p['price'] != null ?message.formatCurrency(p['price']).toString() : '0'}',
                        style: const TextStyle(color: Colors.red , fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  trailing: imageUrls.isNotEmpty
                      ? CircleAvatar(
                      backgroundImage:
                      NetworkImage(imageUrls.first))
                      : CircleAvatar(
                    child: Text(
                      p['name'][0].toUpperCase(),
                    ),
                  ),
                  onTap: () => _toggleSelection(p, !isSelected),
                );
              },
            ),
          ),
        ],
      ),


      bottomNavigationBar: selectedProducts.isNotEmpty
          ? Container(
        padding: const EdgeInsets.all(8),
        child: ElevatedButton(
          onPressed: _confirmSelection,
          child: Text('Chọn (${selectedProducts.length}) sản phẩm'),
        ),
      )
          : null,
    );
  }
}
