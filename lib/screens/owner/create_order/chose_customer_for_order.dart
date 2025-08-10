import 'package:ban_hang/screens/owner/create_order/create_order_for_customer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChoseCustomerForOrderScreen extends StatefulWidget {
  const ChoseCustomerForOrderScreen({super.key});

  @override
  State<ChoseCustomerForOrderScreen> createState() => _ChoseCustomerForOrderScreenState();
}

class _ChoseCustomerForOrderScreenState extends State<ChoseCustomerForOrderScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _customersStream;

  // Dữ liệu danh sách khách hàng lấy từ Firestore
  List<QueryDocumentSnapshot<Map<String, dynamic>>> allCustomers = [];
  // Danh sách khách hàng sau khi lọc theo tìm kiếm
  List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredCustomers = [];

  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final userId = currentUser?.uid;

    _customersStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'customer')
        .where('creatorId', isEqualTo: userId) // Lọc theo creatorId
        .snapshots();

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredCustomers = allCustomers;
      } else {
        filteredCustomers = allCustomers.where((doc) {
          final name = (doc.data()['name'] as String?)?.toLowerCase() ?? '';
          return name.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn khách hàng')),
      body: Column(
        children: [
          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm khách hàng theo tên...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
            ),
          ),

          // Danh sách khách hàng
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _customersStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                allCustomers = snapshot.data?.docs ?? [];

                // Nếu chưa tìm kiếm hoặc tìm kiếm rỗng, dùng danh sách đầy đủ
                if (_searchController.text.isEmpty) {
                  filteredCustomers = allCustomers;
                }

                if (filteredCustomers.isEmpty) {
                  return const Center(child: Text('Không tìm thấy khách hàng phù hợp'));
                }

                return ListView.builder(
                  itemCount: filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final doc = filteredCustomers[index];
                    final data = doc.data();

                    final avatarUrl = data['avatarUrl'] as String?;
                    final name = (data['name'] as String?)?.isNotEmpty == true ? data['name'] : 'Chưa có tên';
                    final phone = (data['phone'] as String?)?.isNotEmpty == true ? data['phone'] : 'Chưa có số điện thoại';
                    final address = (data['address'] as String?)?.isNotEmpty == true ? data['address'] : 'Chưa có địa chỉ';

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateOrderForCustomerScreen(customerDoc: doc),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade300, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 28,
                                backgroundImage:
                                avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl == null
                                    ? const Icon(Icons.person, size: 28)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 0),
                                    child: Text(
                                      phone,
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text(
                                      address,
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
