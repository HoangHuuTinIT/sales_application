import 'package:ban_hang/screens/owner/create_order_for_customer.dart';
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

  @override
  void initState() {
    super.initState();
    final userId = currentUser?.uid;

    _customersStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'customer')
        .where('creatorId', isEqualTo: userId) // Lọc theo creatorId
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn khách hàng')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _customersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final customers = snapshot.data?.docs ?? [];

          if (customers.isEmpty) {
            return const Center(child: Text('Chưa có khách hàng nào'));
          }

          return ListView.builder(
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final doc = customers[index];
              final data = doc.data();

              final avatarUrl = data['avatarUrl'] as String?;
              final name = (data['name'] as String?)?.isNotEmpty == true ? data['name'] : 'Chưa có tên';
              final phone = (data['phone'] as String?)?.isNotEmpty == true ? data['phone'] : 'Chưa có số điện thoại';
              final address = (data['address'] as String?)?.isNotEmpty == true ? data['address'] : 'Chưa có địa chỉ';

              return ListTile(
                leading: avatarUrl != null
                    ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl))
                    : const CircleAvatar(child: Icon(Icons.person)),
                title: Text(name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(phone),
                    Text(address),
                  ],
                ),
                onTap: () {
                  // Chuyển đến màn hình tạo đơn cho khách
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateOrderForCustomerScreen(customerDoc: doc),
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
