import 'package:ban_hang/screens/customer/cartitems_screen.dart';
import 'package:ban_hang/screens/customer/customer_order.dart';
import 'package:ban_hang/screens/customer/my_customer.dart';
import 'package:ban_hang/screens/customer/product_customer_chose.dart';
import 'package:ban_hang/services/staff_services/product_service.dart';
import 'package:ban_hang/utils/message.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ban_hang/screens/auth/signin.dart';

class HomeCustomer extends StatefulWidget {
  const HomeCustomer({super.key});

  @override
  State<HomeCustomer> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeCustomer> {
  int _currentIndex = 0;
  String searchQuery = '';
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() async {
    final service = ProductService();
    final products = await service.fetchAllProducts();
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  void _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _products
        .where((p) => p['name'].toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: Colors.deepOrange,
          elevation: 0,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  if (_currentIndex == 0) // 🔑 Chỉ hiển thị search khi ở Trang chủ
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                          });
                        },
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          hintText: 'Tìm kiếm sản phẩm...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    )
                  else
                    const Expanded(child: SizedBox()), // chiếm chỗ
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                    onPressed: () {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignInScreen(
                              redirectRoute: '/cart',
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CartItemsScreen()),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () => _signOut(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentIndex == 0
          ? Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
            itemCount: filteredProducts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.7,
            ),
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              return ProductCard(
                name: product['name'],
                imageUrl: product['image'],
                price: product['price'],
                sold: product['sold'],
                discount: product['discount'],
                discountEndDate: product['discountEndDate'], // ✅ mới
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductCustomerChoseScreen(productId: product['id']),
                    ),
                  );
                },
              );
            }),
      )
          : _currentIndex == 1
          ? const Center(child: Text('Chức năng thông báo'))
          : AccountTab(
        onSignOut: () => _signOut(context),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.deepOrange,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Thông báo'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Tôi'),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final dynamic price;
  final dynamic sold;
  final dynamic discount;
  final DateTime? discountEndDate; // ✅
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.name,
    this.imageUrl,
    required this.price,
    required this.sold,
    required this.discount,
    this.discountEndDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayPrice = price is int ? price : (price as double).toInt();
    final displayDiscount = discount is int ? discount : (discount as double).toDouble();

    // ✅ Thêm kiểm tra hạn
    final now = DateTime.now();
    final isDiscountExpired = discountEndDate != null && now.isAfter(discountEndDate!);

    final hasDiscount = displayDiscount > 0 && !isDiscountExpired;

    final discountedPrice = hasDiscount
        ? displayPrice * (1 - displayDiscount / 100)
        : displayPrice;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: imageUrl != null
                  ? Image.network(
                imageUrl!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Image.asset('assets/images/background_no_image.png'),
              )
                  : Image.asset(
                'assets/images/background_no_image.png',
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  hasDiscount
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${message.formatCurrency(displayPrice)}',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${message.formatCurrency(discountedPrice)}',
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                      : Text(
                    '${message.formatCurrency(displayPrice)}',
                    style: const TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Đã bán: $sold',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

