import 'dart:convert';
import 'package:ban_hang/screens/owner/order_management/shipping_itinerary.dart';
import 'package:ban_hang/services/owner_services/order_created_services.dart';
import 'package:ban_hang/utils/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ban_hang/screens/owner/order_management/payment_screen.dart';
class OrderCreatedScreen extends StatefulWidget {
  const OrderCreatedScreen({super.key});

  @override
  State<OrderCreatedScreen> createState() => _OrderCreatedScreenState();
}

class _OrderCreatedScreenState extends State<OrderCreatedScreen> {
  final OrderCreatedServices _services = OrderCreatedServices();
  final TextEditingController _searchController = TextEditingController();
  late Future<void> _initFuture; // Dùng để fetch dữ liệu ban đầu
  List<Map<String, dynamic>> _allOrders = []; // Lưu trữ toàn bộ đơn hàng
  List<Map<String, dynamic>> _filteredOrders = []; // Lưu trữ đơn hàng đã được lọc
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _initFuture = _fetchOrders();

  }
// MỚI: Hàm fetch dữ liệu ban đầu
  Future<void> _fetchOrders() async {
    final data = await _services.getCreatedOrdersStream();
    setState(() {
      _allOrders = data as List<Map<String, dynamic>>;
      _filteredOrders = data as List<Map<String, dynamic>>;
    });
  }

  // MỚI: Hàm áp dụng bộ lọc và tìm kiếm
  void _applyFilters() {
    final filtered = _services.filterAndSearchOrders(
      allOrders: _allOrders,
      searchQuery: _searchController.text,
      selectedDate: _selectedDate,
    );
    setState(() {
      _filteredOrders = filtered;
    });
  }

  // MỚI: Hàm hiển thị Date Picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _applyFilters();
    }
  }

  // MỚI: Hàm xóa bộ lọc ngày
  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
    _applyFilters();
  }
  @override
  void dispose() {
    _searchController.dispose(); // MỚI: Hủy controller
    super.dispose();
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case "Hủy đơn":
        return Colors.red;
      case "Kết thúc":
      case "Đã thanh toán":
        return Colors.green;
      default:
        return Colors.blue;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Đơn đã tạo")),
      body: Column(
          children: [
      // Thanh tìm kiếm và bộ lọc (Phần này bạn đã làm đúng)
      Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Tìm theo SĐT hoặc Mã đơn hàng',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                },
              )
                  : null,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12.0)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.filter_list, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                _selectedDate == null
                    ? 'Lọc theo ngày'
                    : 'Đang lọc: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => _selectDate(context),
                child: const Text('Chọn ngày'),
              ),
              if (_selectedDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: _clearDateFilter,
                  tooltip: 'Xóa bộ lọc ngày',
                ),
              ]
            ],
          ),
        ],
      ),
    ),
    const Divider(),
            // THAY ĐỔI: Phần hiển thị danh sách
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _services.getCreatedOrdersStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(child: Text("Đã xảy ra lỗi khi tải dữ liệu"));
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("Không tìm thấy đơn hàng nào"));
                  }

                  // 🔹 Áp dụng bộ lọc (tìm kiếm + ngày)
                  final filteredOrders = _services.filterAndSearchOrders(
                    allOrders: snapshot.data!,
                    searchQuery: _searchController.text,
                    selectedDate: _selectedDate,
                  );

                  if (filteredOrders.isEmpty) {
                    return const Center(child: Text("Không tìm thấy đơn hàng nào"));
                  }

                  return ListView.builder(
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 🔹 Mã đơn + tổng tiền
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    order["txlogisticId"] ?? "",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    "  ${message.formatCurrency(order["totalAmount"]) ?? 0}",
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // 🔹 Mã vận đơn + copy
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "Mã vận đơn: ${order["billCode"] ?? ""}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy,
                                        size: 20, color: Colors.grey),
                                    onPressed: () {
                                      final billCode = order["billCode"] ?? "";
                                      if (billCode.isNotEmpty) {
                                        Clipboard.setData(ClipboardData(text: billCode));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                              content: Text("Đã copy mã vận đơn")),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // 🔹 Thông tin khách hàng
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.person, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(text: order["customerName"] ?? ""),
                                          const TextSpan(text: " | "),
                                          TextSpan(text: order["customerPhone"] ?? ""),
                                          const TextSpan(text: " | "),
                                          TextSpan(text: order["shippingAddress"] ?? ""),
                                        ],
                                      ),
                                      softWrap: true,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // 🔹 Đơn vị giao hàng + COD
                              Row(
                                children: [
                                  const Icon(Icons.local_shipping, size: 18),
                                  const SizedBox(width: 6),
                                  Text("${order["shippingPartner"] ?? ""} |"),
                                  const SizedBox(width: 12),
                                  Text(
                                      "COD: ${message.formatCurrency(order["codAmount"]) ?? 0}"),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // 🔹 Người tạo + ghi chú
                              Row(
                                children: [
                                  const Icon(Icons.warning, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      "Người tạo đơn: ${order["createdBy"] ?? ""} | ${order["shippingNote"] ?? ""}",
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // 🔹 Trạng thái + ngày + Popup
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Status badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _getStatusColor(order["status"]),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _getStatusColor(order["status"]),
                                          ),
                                        ),
                                        Text(
                                          order["status"] ?? "",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: _getStatusColor(order["status"]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    order["invoiceDate"] ?? "",
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                  // PopupMenu
                                  PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      _services.handleMenuSelection(context, value, order);
                                    },
                                    itemBuilder: (context) => _services.buildMenuItems(order['status'] ?? ''),
                                  )
                                ],
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

          ]
      )
    );
  }
}
