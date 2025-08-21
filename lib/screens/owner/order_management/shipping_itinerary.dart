import 'package:flutter/material.dart';
import 'package:ban_hang/services/owner_services/shipping_itinerary_services.dart';

class ShippingItineraryScreen extends StatelessWidget {
  final String response;

  const ShippingItineraryScreen({super.key, required this.response});

  @override
  Widget build(BuildContext context) {
    final parsed = ShippingItineraryServices.parseTraceResponse(response);
    if (parsed == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Hành trình giao hàng")),
        body: const Center(child: Text("Không có dữ liệu hợp lệ")),
      );
    }

    final data = parsed["data"] as List<dynamic>;
    if (data.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Hành trình giao hàng")),
        body: const Center(child: Text("Chưa có thông tin hành trình")),
      );
    }

    final order = data.first;
    final billCode = order["billCode"];
    final details = (order["details"] ?? []) as List<dynamic>;

    if (details.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Hành trình giao hàng")),
        body: Center(
          child: Text(
            "Đơn $billCode hiện đang chờ xác nhận",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Hành trình giao hàng")),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Text(
              "Mã vận đơn: $billCode",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          const Divider(height: 1),

          // 🔹 Timeline list
          Expanded(
            child: ListView.builder(
              itemCount: details.length,
              itemBuilder: (context, index) {
                final d = details[index];
                final isLatest = index == 0;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cột icon timeline
                    Container(
                      width: 40,
                      alignment: Alignment.topCenter,
                      child: Column(
                        children: [
                          // chấm tròn
                          Icon(
                            isLatest ? Icons.check_circle : Icons.circle,
                            size: isLatest ? 22 : 14,
                            color: isLatest ? Colors.green : Colors.grey,
                          ),
                          if (index != details.length - 1)
                            Container(
                              height: 60,
                              width: 2,
                              color: Colors.grey.shade300,
                            ),
                        ],
                      ),
                    ),

                    // Nội dung
                    Expanded(
                      child: Card(
                        margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d["desc"] ?? "",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isLatest ? Colors.green : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text("⏰ ${d["scanTime"] ?? ""}",
                                  style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 8),
                              Text("🔖 ${d["scanTypeName"] ?? ""}"),
                              if (d["scanNetworkName"] != null)
                                Text("🏢 ${d["scanNetworkName"]}"),
                              if (d["scanNetworkArea"] != null)
                                Text(
                                    "📍 ${d["scanNetworkArea"]}, ${d["scanNetworkCity"]}, ${d["scanNetworkProvince"]}"),
                              if (d["nextStopName"] != null &&
                                  d["nextStopName"].toString().isNotEmpty)
                                Text("➡️ Chuyển tiếp: ${d["nextStopName"]}"),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
