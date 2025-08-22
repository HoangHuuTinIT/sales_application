import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:ban_hang/screens/owner/order_management/shipping_itinerary.dart';
import 'package:path_provider/path_provider.dart';

class OrderCreatedServices {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<List<Map<String, dynamic>>> getCreatedOrders() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final userDoc = await _firestore.collection("users").doc(user.uid).get();
    final userData = userDoc.data();
    if (userData == null) return [];

    final shopId = userData["shopid"];
    if (shopId == null) return [];

    final query = await _firestore
        .collection("Order")
        .where("shopid", isEqualTo: shopId)
        .get();

    List<Map<String, dynamic>> orders = [];

    for (var doc in query.docs) {
      final data = doc.data();

      String createdByName = "";
      if (data["createdBy"] != null) {
        final userQuery = await _firestore
            .collection("users")
            .where("uid", isEqualTo: data["createdBy"])
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          createdByName = userQuery.docs.first.data()["name"] ?? "";
        }
      }

      DateTime? invoiceDateRaw;
      String invoiceDate = "";
      if (data["invoiceDate"] is Timestamp) {
        invoiceDateRaw = (data["invoiceDate"] as Timestamp).toDate();
        invoiceDate = DateFormat("dd/MM/yyyy HH:mm").format(invoiceDateRaw);
      }

      orders.add({
        "docId": doc.id,
        ...data,
        "createdByName": createdByName,
        "invoiceDate": invoiceDate,
        "invoiceDateRaw": invoiceDateRaw,
      });
    }

    orders.sort((a, b) {
      final da = a["invoiceDateRaw"] as DateTime?;
      final db = b["invoiceDateRaw"] as DateTime?;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    return orders;
  }

  // MỚI: Phương thức xử lý tìm kiếm và lọc
  List<Map<String, dynamic>> filterAndSearchOrders({
    required List<Map<String, dynamic>> allOrders,
    String? searchQuery,
    DateTime? selectedDate,
  }) {
    List<Map<String, dynamic>> filteredList = List.from(allOrders);

    // 1. Lọc theo từ khóa tìm kiếm
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lowerCaseQuery = searchQuery.toLowerCase();
      filteredList = filteredList.where((order) {
        final phone = order['customerPhone']?.toString().toLowerCase() ?? '';
        final logisticId = order['txlogisticId']?.toString().toLowerCase() ??
            '';
        return phone.contains(lowerCaseQuery) ||
            logisticId.contains(lowerCaseQuery);
      }).toList();
    }

    // 2. Lọc theo ngày
    if (selectedDate != null) {
      filteredList = filteredList.where((order) {
        final orderDate = order['invoiceDateRaw'] as DateTime?;
        if (orderDate == null) return false;
        // Chỉ so sánh Năm, Tháng, Ngày (bỏ qua giờ, phút, giây)
        return orderDate.year == selectedDate.year &&
            orderDate.month == selectedDate.month &&
            orderDate.day == selectedDate.day;
      }).toList();
    }

    return filteredList;
  }

  /// 🔹 Gọi API J&T để hủy đơn
  Future<bool> cancelOrder(Map<String, dynamic> order, String reason) async {
    try {
      final apiAccount = dotenv.env['API_ACCOUNT']!;
      final privateKey = dotenv.env['PRIVATE_KEY']!;
      final timestamp = DateTime
          .now()
          .millisecondsSinceEpoch;
      final customerCode = order["customerCode"];
      final txlogisticId = order["txlogisticId"];
      final key = order["key"];
      final passwordRaw = "$key${"jadada369t3"}";

      final password =
      md5.convert(utf8.encode(passwordRaw)).toString().toUpperCase();

      final bizContent = {
        "customerCode": customerCode,
        "password": password,
        "txlogisticId": txlogisticId,
        "reason": reason,
      };
      final bizContentStr = jsonEncode(bizContent);

      final digestMd5 = md5.convert(utf8.encode(bizContentStr + privateKey));
      final digest = base64.encode(digestMd5.bytes);

      final url = Uri.parse(
          "https://demoopenapi.jtexpress.vn/webopenplatformapi/api/order/cancelOrder");

      final response = await http.post(
        url,
        headers: {
          "digest": digest,
          "timestamp": "$timestamp",
          "apiAccount": apiAccount,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {
          "bizContent": bizContentStr,
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error cancelOrder: $e");
      return false;
    }
  }

  /// 🔹 Xóa đơn trong Firestore (copy sang OrderCancelled trước)
  Future<void> deleteOrder(Map<String, dynamic> order, String reason) async {
    try {
      final docId = order["docId"];
      final orderRef = _firestore.collection("Order").doc(docId);

      final orderSnap = await orderRef.get();
      if (orderSnap.exists) {
        final orderData = orderSnap.data()!;
        await _firestore.collection("OrderCancelled").doc(docId).set({
          ...orderData,
          "cancelReason": reason,
          "cancelledAt": FieldValue.serverTimestamp(),
          "status": "Hủy đơn"
        });

        await orderRef.delete();
      }
    } catch (e) {
      print("Error deleteOrder: $e");
    }
  }

  /// 🔹 Xóa đơn trực tiếp khỏi Firestore
  Future<void> deleteOrderOnly(Map<String, dynamic> order) async {
    try {
      final docId = order["docId"];
      await _firestore.collection("Order").doc(docId).delete();
    } catch (e) {
      print("Error deleteOrderOnly: $e");
    }
  }

  /// 🔹 Gọi API tra cứu hành trình J&T
  Future<String?> traceOrderJT(Map<String, dynamic> order) async {
    try {
      final apiAccount = dotenv.env['API_ACCOUNT']!;
      final privateKey = dotenv.env['PRIVATE_KEY']!;
      final timestamp = DateTime
          .now()
          .millisecondsSinceEpoch;

      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection("users").doc(user.uid).get();
      final userData = userDoc.data();
      if (userData == null) return null;

      final shopId = userData["shopid"];

      final jtQuery = await _firestore
          .collection("JT_setting")
          .where("shopid", isEqualTo: shopId)
          .limit(1)
          .get();

      if (jtQuery.docs.isEmpty) return null;

      final jtData = jtQuery.docs.first.data();
      final customerCode = jtData["customerCode"];
      final key = jtData["key"];

      final passwordRaw = "$key${"jadada369t3"}";
      final password =
      md5.convert(utf8.encode(passwordRaw)).toString().toUpperCase();

      final bizContent = {
        "billCodes": order["billCode"] ?? "",
        "txlogisticId": order["txlogisticId"] ?? "",
        "customerCode": customerCode,
        "password": password,
      };
      final bizContentStr = jsonEncode(bizContent);

      final digestMd5 = md5.convert(utf8.encode(bizContentStr + privateKey));
      final digest = base64.encode(digestMd5.bytes);

      final url = Uri.parse(
          "https://demoopenapi.jtexpress.vn/webopenplatformapi/api/logistics/trace");

      final response = await http.post(
        url,
        headers: {
          "apiAccount": apiAccount,
          "digest": digest,
          "timestamp": "$timestamp",
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {
          "bizContent": bizContentStr,
        },
      );
      print("thong tin van chuyen ve ne: ${response.body}");
      if (response.statusCode == 200) {
        return response.body;
      }
      else {
        return null;
      }
    } catch (e) {
      print("Error traceOrderJT: $e");
      return null;
    }
  }

  /// 🔹 Copy dữ liệu vào clipboard
  Future<void> copyToClipboard(BuildContext context, String text,
      String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)));
  }

  /// 🔹 Hiện dialog xác nhận hủy
  Future<void> showCancelDialog(BuildContext context,
      Map<String, dynamic> order) async {
    const defaultReason = "Hủy bởi người bán";
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text("Xác nhận hủy đơn"),
            content: const Text(
                "Bạn có chắc chắn muốn hủy và xóa đơn này không?"),
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
          ),
    );

    if (confirm == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final success = await cancelOrder(order, defaultReason);

      if (success) {
        await deleteOrder(order, defaultReason);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã hủy và xóa đơn thành công")),
        );
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Hủy đơn thất bại")),
        );
      }
    }
  }

  /// 🔹 Hiện dialog xác nhận xóa
  Future<void> showDeleteDialog(BuildContext context,
      Map<String, dynamic> order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text("Xác nhận xóa đơn"),
            content:
            const Text(
                "Bạn có chắc chắn muốn xóa đơn này khỏi hệ thống không?"),
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
          ),
    );

    if (confirm == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await deleteOrderOnly(order);

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã xóa đơn thành công")),
      );
    }
  }

  Future<String?> printOrderJT(Map<String, dynamic> order) async {
    try {
      final apiAccount = dotenv.env['API_ACCOUNT']!;
      final privateKey = dotenv.env['PRIVATE_KEY']!;
      final timestamp = DateTime
          .now()
          .millisecondsSinceEpoch;

      final customerCode = order["customerCode"];
      final key = order["key"];
      final txlogisticId = order["txlogisticId"];

      // 🔹 Tạo password
      final passwordRaw = "$key${"jadada369t3"}";
      final password = md5.convert(utf8.encode(passwordRaw))
          .toString()
          .toUpperCase();

      // 🔹 BizContent
      final bizContent = {
        "customerCode": customerCode,
        "password": password,
        "txlogisticId": txlogisticId,
      };
      final bizContentStr = jsonEncode(bizContent);

      // 🔹 Digest
      final digestMd5 = md5.convert(utf8.encode(bizContentStr + privateKey));
      final digest = base64.encode(digestMd5.bytes);

      final url = Uri.parse(
          "https://demoopenapi.jtexpress.vn/webopenplatformapi/api/order/printOrder");

      final response = await http.post(
        url,
        headers: {
          "apiAccount": apiAccount,
          "digest": digest,
          "timestamp": "$timestamp",
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {
          "bizContent": bizContentStr,
        },
      );

      print("Kết quả in vận đơn J&T: ${response.body}");

      if (response.statusCode == 200) {
        return response.body; // JSON trả về từ J&T
      } else {
        return null;
      }
    } catch (e) {
      print("Lỗi printOrderJT: $e");
      return null;
    }
  }

  Future<File?> savePdfFromBase64(String base64Str, String fileName) async {
    try {
      // Giải mã base64 -> bytes
      final bytes = base64.decode(base64Str);

      // Lấy thư mục tạm của app (trên Android/iOS)
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/$fileName.pdf");

      // Ghi bytes ra file
      await file.writeAsBytes(bytes);

      print("✅ File PDF đã được lưu: ${file.path}");
      return file;
    } catch (e) {
      print("❌ Lỗi khi decode base64 PDF: $e");
      return null;
    }
  }

}
