import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ban_hang/services/staff_services/order_cancelled_services.dart';
import 'package:share_plus/share_plus.dart';

class OrderCancelledScreen extends StatefulWidget {
  const OrderCancelledScreen({super.key});

  @override
  State<OrderCancelledScreen> createState() =>
      _OrderCancelledScreenState();
}

class _OrderCancelledScreenState extends State<OrderCancelledScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _orders = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _loading = true);
    _orders = await OrderCancelledServices.getOrders(
        startDate: _startDate, endDate: _endDate);
    setState(() => _loading = false);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _exportAndShare() async {
    if (_orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có dữ liệu để xuất!')),
      );
      return;
    }

    try {
      final path = await OrderCancelledServices.exportOrdersToExcel(
        orders: _orders,
        startDate: _startDate,
        endDate: _endDate,
      );
      await Share.shareXFiles([XFile(path)],
          text: 'Đơn hàng bị hủy trong khoảng đã lọc');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Đã chia sẻ file Excel!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _startDate != null && _endDate != null
        ? 'Từ ${_startDate!.day}/${_startDate!.month}/${_startDate!.year} '
        'đến ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
        : 'Toàn bộ';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn hàng bị hủy'),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Xuất & Chia sẻ Excel',
            onPressed: _exportAndShare,
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _pickStartDate,
                  child: const Text('Từ ngày'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _pickEndDate,
                  child: const Text('Đến ngày'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _fetchOrders,
                  child: const Text('Lọc'),
                ),
                const SizedBox(width: 12),
                Text(dateLabel),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                final DateTime cancelledAt =
                (order['cancelledAt'] as Timestamp).toDate();
                return Card(
                  child: ListTile(
                    title: Text('Khách: ${order['customerName']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SĐT: ${order['phone']}'),
                        Text('Địa chỉ: ${order['address']}'),
                        Text('Sản phẩm: ${order['productName']}'),
                        Text('Số lượng: ${order['quantity']}'),
                        Text(
                            'Ngày hủy: ${cancelledAt.day}/${cancelledAt.month}/${cancelledAt.year}'),
                      ],
                    ),
                    trailing:
                    Text('Tổng: ${order['total']} đ'),
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
