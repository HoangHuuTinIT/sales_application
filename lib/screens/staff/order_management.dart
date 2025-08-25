import 'package:ban_hang/screens/owner/create_order/create_order_for_customer.dart';
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

                    final createdAt = (data['createdAt'] as Timestamp).toDate();
                    final orderCode = data['orderCode'] ?? '';
                    final paymentMethod = data['paymentMethod'] ?? '';
                    final status = data['status'] ?? '';
                    final totalAmount = data['totalAmount'] ?? 0;

                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        title: Text('Mã đơn: $orderCode', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}'),
                            Text('Phương thức: $paymentMethod'),
                            Text('Trạng thái: $status'),
                            Text('Tổng tiền: ${message.formatCurrency(totalAmount)}'),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'details') {
                              Navigator.pushNamed(
                                context,
                                '/orderDetails',
                                arguments: {
                                  'orderId': doc.id,
                                  'orderData': data,
                                },
                              );
                            } else if (value == 'create_order') {
                              // ✅ Gọi service lấy đủ dữ liệu đơn hàng + user
                              final customerData = await _orderService.prepareOrderData(doc.id);

                              if (customerData != null && mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CreateOrderForCustomerScreen(
                                      customerData: customerData,
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'details',
                              child: Text('Chi tiết đơn hàng'),
                            ),
                            const PopupMenuItem(
                              value: 'create_order',
                              child: Text('Tạo đơn'),
                            ),
                          ],
                        ),

                      ),
                    );

                  },

                );
              },
            ),
          )

        ],
      ),
    );
  }
}
