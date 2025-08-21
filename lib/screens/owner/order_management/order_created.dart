import 'package:ban_hang/screens/owner/order_management/shipping_itinerary.dart';
import 'package:ban_hang/services/owner_services/order_created_services.dart';
import 'package:ban_hang/utils/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OrderCreatedScreen extends StatefulWidget {
  const OrderCreatedScreen({super.key});

  @override
  State<OrderCreatedScreen> createState() => _OrderCreatedScreenState();
}

class _OrderCreatedScreenState extends State<OrderCreatedScreen> {
  late Future<List<Map<String, dynamic>>> _futureOrders;
  List<Map<String, dynamic>> _orders = [];

  String? _selectedReason; // ✅ lưu lý do hủy ngay trong State

  @override
  void initState() {
    super.initState();
    _futureOrders = OrderCreatedServices().getCreatedOrders().then((data) {
      _orders = data;
      return data;
    });
  }

  /// ✅ Hàm xóa order khỏi danh sách hiện tại
  void _removeOrder(String docId) {
    setState(() {
      _orders.removeWhere((order) => order["docId"] == docId);
    });
  }


  /// ✅ Hàm hiển thị dialog xác nhận hủy
  Future<void> _showCancelDialog(Map<String, dynamic> order) async {
    const defaultReason = "Hủy bởi người bán";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Xác nhận hủy đơn"),
          content: const Text("Bạn có chắc chắn muốn hủy và xóa đơn này không?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Không"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Có"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // 🔹 show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false, // không cho tắt khi nhấn ra ngoài
        builder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final services = OrderCreatedServices();
      final success = await services.cancelOrder(order, defaultReason);

      if (success) {
        await services.deleteOrder(order, defaultReason);

        final newOrders = await services.getCreatedOrders();

        if (!mounted) return;

        setState(() {
          _orders = newOrders;
          _futureOrders = Future.value(newOrders);
        });

        Navigator.pop(context); // 🔹 đóng loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã hủy và xóa đơn thành công")),
        );
      } else {
        Navigator.pop(context); // 🔹 đóng loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Hủy đơn thất bại")),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Đơn đã tạo")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureOrders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _orders.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_orders.isEmpty) {
            return const Center(child: Text("Chưa có đơn nào"));
          }
          return ListView.builder(
            itemCount: _orders.length,
            itemBuilder: (context, index) {
              final order = _orders[index];
              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔹 Hàng đầu tiên: mã đơn + totalAmount + menu
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
                          Row(
                            children: [
                              Text(
                                "  ${message.formatCurrency(order["totalAmount"]) ?? 0}",
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == "cancel") {
                                    await _showCancelDialog(order);
                                  }
                                  else if (value == "trace") {
                                    final services = OrderCreatedServices();
                                    if (order["shippingPartner"] == "J&T") {
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (_) => const Center(child: CircularProgressIndicator()),
                                      );

                                      final result = await services.traceOrderJT(order);
                                      Navigator.pop(context); // đóng loading

                                      if (!mounted) return;
                                      if (result != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ShippingItineraryScreen(response: result),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Không lấy được hành trình giao hàng")),
                                        );
                                      }
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Đơn vị này chưa hỗ trợ tra cứu")),
                                      );
                                    }
                                  }

                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: "cancel",
                                    child: Text("Hủy đơn"),
                                  ),
                                  PopupMenuItem(
                                    value: "trace",
                                    child: Text("Tra hành trình giao hàng"),
                                  ),
                                ],
                              ),


                            ],
                          ),
                        ],
                      ),
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
                            icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
                            onPressed: () {
                              final billCode = order["billCode"] ?? "";
                              if (billCode.isNotEmpty) {
                                Clipboard.setData(ClipboardData(text: billCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Đã copy mã vận đơn")),
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

                      // 🔹 Đơn vị giao hàng
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
                      // 🔹 Lưu ý + người tạo
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
                      // 🔹 Ngày tạo đơn
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          order["invoiceDate"] ?? "",
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
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
    );
  }
}
