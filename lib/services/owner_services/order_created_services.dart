import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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
        "invoiceDateRaw": invoiceDateRaw, // 🔹 thêm field gốc để sort
      });
    }

    // 🔹 Sort theo ngày tạo (mới nhất lên đầu)
    orders.sort((a, b) {
      final da = a["invoiceDateRaw"] as DateTime?;
      final db = b["invoiceDateRaw"] as DateTime?;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da); // db trước => mới hơn
    });

    return orders;
  }


  /// 🔹 Gọi API J&T để hủy đơn
  Future<bool> cancelOrder(Map<String, dynamic> order, String reason) async {
    try {
      final apiAccount = dotenv.env['API_ACCOUNT']!;
      final privateKey = dotenv.env['PRIVATE_KEY']!;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
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

      final digestMd5 =
      md5.convert(utf8.encode(bizContentStr + privateKey));
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

      print("trang thai tra ve : ${response.statusCode}");
      if (response.statusCode == 200) {
        print("Cancel success: ${response.body}");
        return true;
      } else {
        print("Cancel failed: ${response.body}");
        return false;
      }
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
        });

        await orderRef.delete();
      }
    } catch (e) {
      print("Error deleteOrder: $e");
    }
  }Future<String?> traceOrderJT(Map<String, dynamic> order) async {
    try {
      final apiAccount = dotenv.env['API_ACCOUNT']!;
      final privateKey = dotenv.env['PRIVATE_KEY']!;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // 🔹 Lấy user hiện tại
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection("users").doc(user.uid).get();
      final userData = userDoc.data();
      if (userData == null) return null;

      final shopId = userData["shopid"];

      // 🔹 Lấy JT_setting theo shopid
      final jtQuery = await _firestore
          .collection("JT_setting")
          .where("shopid", isEqualTo: shopId)
          .limit(1)
          .get();

      if (jtQuery.docs.isEmpty) return null;

      final jtData = jtQuery.docs.first.data();
      final customerCode = jtData["customerCode"];
      final key = jtData["key"];

      // 🔹 password
      final passwordRaw = "$key${"jadada369t3"}";
      final password =
      md5.convert(utf8.encode(passwordRaw)).toString().toUpperCase();

      // 🔹 bizContent
      final bizContent = {
        "billCodes": order["billCode"] ?? "",
        "txlogisticId": order["txlogisticId"] ?? "",
        "customerCode": customerCode,
        "password": password,
      };
      final bizContentStr = jsonEncode(bizContent);

      // 🔹 digest
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

      if (response.statusCode == 200) {
        print("Trace success: ${response.body}");
        return response.body; // 🔹 bạn có thể parse JSON để đẹp hơn
      } else {
        print("Trace failed: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error traceOrderJT: $e");
      return null;
    }
  }


}
