import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ban_hang/services/staff_services/order_management_services.dart';
import 'package:ban_hang/utils/message.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  final OrderManagementService _orderService = OrderManagementService();

  String _searchName = '';
  DateTime? _selectedDate;
  String? _selectedStatus;

  final List<String> _statusOptions = [
    'Đang chờ xác nhận',
    'Đang tiến hành đóng gói',
    'Đóng gói hoàn tất',
    'Shipper nhận hàng',
    'Đang vận chuyển',
    'Hoàn tất thanh toán',
    'Đơn hàng bị hủy',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý đơn hàng'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 🔍 Tìm kiếm (nếu muốn, bạn cần xử lý lại phần nameSearch)
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Tìm kiếm theo tên',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchName = value.trim();
                });
              },
            ),
          ),
          // 📅 Lọc ngày
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDate == null
                        ? 'Chọn ngày lọc'
                        : 'Ngày: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Chọn ngày'),
                ),
                if (_selectedDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _selectedDate = null;
                      });
                    },
                  ),
              ],
            ),
          ),
          // ✅ Lọc trạng thái
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Text('Trạng thái:'),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    hint: const Text('Chọn trạng thái'),
                    isExpanded: true,
                    items: _statusOptions.map((status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value;
                      });
                    },
                  ),
                ),
                if (_selectedStatus != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _selectedStatus = null;
                      });
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 📦 Danh sách đơn hàng
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _orderService.getOrdersStream(
                nameQuery: _searchName,
                dateFilter: _selectedDate,
                statusFilter: _selectedStatus,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Không có đơn hàng nào.'));
                }

                final orders = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final doc = orders[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final userId = data['userId'] ?? '';
                    final productId = data['productId'] ?? '';
                    final status = (data['status'] ?? '').toString();
                    final isDisabled = status == 'Hoàn tất thanh toán' ||
                        status == 'Đang vận chuyển' ||
                        status == 'Shipper nhận hàng' ||
                        status == 'Đơn hàng bị hủy';

                    return FutureBuilder<List<Map<String, dynamic>?>>(
                      future: _orderService.getUserAndProduct(userId, productId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final userData = snapshot.data![0];
                        final productData = snapshot.data![1];
                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tên: ${userData?['name'] ?? ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text('Địa chỉ: ${userData?['address'] ?? ''}'),
                                Text('SĐT: ${userData?['phone'] ?? ''}'),
                                Text(
                                    'Hình thức thanh toán: ${data['paymentMethod'] ?? ''}'),
                                const SizedBox(height: 8),
                                Text('Sản phẩm: ${productData?['name'] ?? ''}'),
                                Text('Số lượng: ${data['quantity'] ?? ''}'),
                                Text(
                                    'Tổng tiền: ${message.formatCurrency(data['total'] ?? 0)}'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text(
                                      'Trạng thái:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      status,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: isDisabled
                                          ? null
                                          : () async {
                                        await _orderService
                                            .updateOrderStatus(
                                          doc.id,
                                          'Đang tiến hành đóng gói',
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  '✅ Đã xác nhận đơn hàng!')),
                                        );
                                      },
                                      child: const Text('Xác nhận đơn hàng'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: isDisabled
                                          ? null
                                          : () async {
                                        await _orderService
                                            .updateOrderStatus(
                                          doc.id,
                                          'Đóng gói hoàn tất',
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  '✅ Đã hoàn tất đóng gói!')),
                                        );
                                      },
                                      child: const Text('Hoàn tất đóng gói'),
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
            ),
          ),
        ],
      ),
    );
  }
}
