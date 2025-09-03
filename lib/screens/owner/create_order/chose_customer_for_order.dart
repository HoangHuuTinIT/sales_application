import 'package:ban_hang/screens/owner/create_order/add_customer_for_order.dart';
import 'package:ban_hang/screens/owner/create_order/create_order_for_customer.dart';
import 'package:ban_hang/services/owner_services/customer_order_service.dart';
import 'package:flutter/material.dart';

class ChoseCustomerForOrderScreen extends StatefulWidget {
  const ChoseCustomerForOrderScreen({super.key});

  @override
  State<ChoseCustomerForOrderScreen> createState() => _ChoseCustomerForOrderScreenState();
}

class _ChoseCustomerForOrderScreenState extends State<ChoseCustomerForOrderScreen> {
  final CustomerOrderServiceLive _service = CustomerOrderServiceLive();
  List<Map<String, dynamic>> allCustomers = [];
  List<Map<String, dynamic>> filteredCustomers = [];
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadCustomers() async {
    try {
      final customers = await _service.fetchCustomersByShopIdFromRef();
      setState(() {
        allCustomers = customers;
        filteredCustomers = customers;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint("Lỗi load customers: $e");
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredCustomers = query.isEmpty
          ? allCustomers
          : allCustomers.where((c) {
        final name = (c['name'] as String?)?.toLowerCase() ?? '';
        return name.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn khách hàng'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'add_customer') {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddCustomerForOrderScreen(),
                  ),
                );

                if (result == true) {
                  _loadCustomers(); // refresh lại danh sách khách
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'add_customer',
                child: Text('Thêm khách hàng'),
              ),
            ],
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm khách hàng...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
            ),
          ),
          Expanded(
            child: filteredCustomers.isEmpty
                ? const Center(child: Text('Không tìm thấy khách hàng'))
                : ListView.builder(
              itemCount: filteredCustomers.length,
              itemBuilder: (context, index) {
                final data = filteredCustomers[index];
                final avatarUrl = data['avatarUrl'] as String?;
                final name = data['name'] ?? 'Chưa có tên';
                final phone = data['phone'] ?? 'Chưa có số điện thoại';
                final address = data['address'] ?? 'Chưa có địa chỉ';

                return InkWell(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateOrderForCustomerScreen(customerData: data),
                      ),
                    );

                    if (result != null && result is Map<String, dynamic>) {
                      setState(() {
                        final index = allCustomers.indexWhere((c) => c['id'] == result['id']);
                        if (index != -1) {
                          allCustomers[index] = result;
                        } else {
                          allCustomers.add(result);
                        }
                        filteredCustomers = allCustomers;
                      });
                    } else if (result == true) {
                      _loadCustomers(); // fallback đọc lại từ Firestore
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null ? const Icon(Icons.person) : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(phone, style: const TextStyle(color: Colors.grey)),
                              Text(address, style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

