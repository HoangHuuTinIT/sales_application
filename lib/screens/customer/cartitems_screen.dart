import 'package:ban_hang/screens/customer/buy_products.dart';
import 'package:ban_hang/screens/customer/product_customer_chose.dart';
import 'package:ban_hang/services/customer_services/cartitems_services.dart';
import 'package:ban_hang/utils/message.dart';
import 'package:flutter/material.dart';

class CartItemsScreen extends StatefulWidget {
  const CartItemsScreen({super.key});

  @override
  State<CartItemsScreen> createState() => _CartItemsScreenState();
}

class _CartItemsScreenState extends State<CartItemsScreen> {
  List<Map<String, dynamic>> _cartItems = [];
  Set<String> _selectedProductIds = {};
  bool _selectAll = false;
  bool _isEditMode = false;
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _fetchCartItems();
  }

  Future<void> _fetchCartItems() async {
    setState(() => _isLoading = true);
    final items = await CartItemsService().fetchCartItemsWithProductInfo();
    setState(() {
      _cartItems = items;
      _isLoading=false;
    });
  }

  void _toggleSelectAll(bool? selected) {
    setState(() {
      _selectAll = selected ?? false;
      if (_selectAll) {
        _selectedProductIds =
            _cartItems.map((e) => e['productId'] as String).toSet();
      } else {
        _selectedProductIds.clear();
      }
    });
  }

  double _calculateTotal() {
    return _cartItems
        .where((item) => _selectedProductIds.contains(item['productId']))
        .fold(
        0.0, (sum, item) => sum + (item['totalAmount'] as num).toDouble());
  }

  void _toggleSelection(String productId, bool selected) {
    setState(() {
      if (selected) {
        _selectedProductIds.add(productId);
      } else {
        _selectedProductIds.remove(productId);
        _selectAll = false;
      }
    });
  }

  Future<void> _deleteSelectedItems() async {
    if (_selectedProductIds.isEmpty) {
      message.showSnackbarfalse(context, 'Hãy chọn sản phẩm');
      return;
    }
    await CartItemsService()
        .deleteCartItemsByProductIds(_selectedProductIds.toList());
    await _fetchCartItems();
    setState(() {
      _selectedProductIds.clear();
      _selectAll = false;
    });
    message.showSnackbartrue(context, 'Đã xóa sản phẩm đã chọn');
  }

  void _buyNow() {
    if (_selectedProductIds.isEmpty) {
      message.showSnackbarfalse(context, 'Hãy chọn sản phẩm để mua');
      return;
    }

    final selectedItems = _cartItems
        .where((item) => _selectedProductIds.contains(item['productId']))
        .toList();
    for (var item in selectedItems) {
      print('✅ selectedItem: $item');
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuyProductsScreen(selectedItems: selectedItems),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giỏ hàng'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _isEditMode = !_isEditMode),
            child: Text(_isEditMode ? 'Xong' : 'Sửa',
                style: const TextStyle(color: Colors.black)),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // 👈 Loading khi vào giao diện
          : Column(
        children: [
          Expanded(
            child: _cartItems.isEmpty
                ? const Center(child: Text('🛒 Giỏ hàng trống'))
                : ListView.builder(
              itemCount: _cartItems.length,
              itemBuilder: (context, index) {
                final item = _cartItems[index];
                final productId = item['productId'] as String;
                final selected = _selectedProductIds.contains(productId);
                return ListTile(
                  leading: Checkbox(
                    value: selected,
                    onChanged: (value) => _toggleSelection(productId, value ?? false),
                  ),
                  title: Text(item['productName'] ?? ''),
                  subtitle: Text(
                      'SL: ${item['quantity']} | Tổng: ${message.formatCurrency(item['totalAmount'])}'),
                  trailing: item['productImage'] != null
                      ? Image.network(item['productImage'], width: 60)
                      : const Icon(Icons.image_not_supported),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductCustomerChoseScreen(productId: productId),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_cartItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _selectAll,
                        onChanged: _toggleSelectAll,
                      ),
                      const Text('Tất cả'),
                      const Spacer(),
                      if (!_isEditMode)
                        Text(
                          'Tổng cộng: ${message.formatCurrency(_calculateTotal())}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isEditMode ? _deleteSelectedItems : _buyNow,
                      child: Text(_isEditMode ? 'Xóa sản phẩm đã chọn' : 'Mua ngay'),
                    ),
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }
}
