import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
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
  // Future<void> printPdfFromBase64(String base64Str) async {
  //   try {
  //     // B1: Lấy thông tin IP và Port của máy in từ Firestore
  //     final printerInfo = await _getPrinterInfo();
  //     final String ip = printerInfo['ip'];
  //     final int port = printerInfo['port'];
  //
  //     // B2: Giải mã chuỗi base64 thành dữ liệu byte của PDF
  //     final Uint8List pdfBytes = base64Decode(base64Str);
  //
  //     // B3: Chuyển đổi dữ liệu PDF thành hình ảnh
  //     final img.Image image = await _convertPdfToImage(pdfBytes);
  //
  //     // B4: Gửi hình ảnh đến máy in qua mạng WiFi
  //     await _printImageOverNetwork(ip, port, image);
  //
  //   } catch (e) {
  //     // Ném lại lỗi để UI có thể bắt và hiển thị thông báo
  //     print("Lỗi trong quá trình in vận đơn: $e");
  //     throw Exception("In vận đơn thất bại. Chi tiết: ${e.toString()}");
  //   }
  // }

  /// [Hàm phụ 1] - Lấy thông tin máy in từ Firestore
  Future<Map<String, dynamic>> _getPrinterInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Người dùng chưa đăng nhập.');
    }

    // Lấy shopid của người dùng hiện tại từ bảng 'users'
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!userDoc.exists || userDoc.data()?['shopid'] == null) {
      throw Exception('Không tìm thấy thông tin shop của người dùng.');
    }
    final shopId = userDoc.data()!['shopid'];

    // Tìm máy in có shopid tương ứng trong bảng 'printer'
    final printerQuery = await FirebaseFirestore.instance
        .collection('printer')
        .where('shopid', isEqualTo: shopId)
        .limit(1)
        .get();

    if (printerQuery.docs.isEmpty) {
      throw Exception('Chưa cấu hình máy in cho shop này.');
    }

    final printerData = printerQuery.docs.first.data();
    final ip = printerData['IP'] as String?;
    final port = printerData['Port']; // Port có thể là String hoặc int

    if (ip == null || ip.isEmpty) {
      throw Exception('Địa chỉ IP của máy in không hợp lệ.');
    }

    final int? portNumber = (port is int) ? port : int.tryParse(port.toString());

    if (portNumber == null) {
      throw Exception('Cổng (Port) của máy in không hợp lệ.');
    }

    return {'ip': ip, 'port': portNumber};
  }

  /// [Hàm phụ 2] - Chuyển đổi PDF (dưới dạng bytes) thành đối tượng Image
  // Future<img.Image> _convertPdfToImage(Uint8List pdfBytes) async {
  //   // Mở tài liệu PDF từ dữ liệu byte
  //   final document = await pdf.PdfDocument.openData(pdfBytes);
  //   // Lấy trang đầu tiên (thường vận đơn chỉ có 1 trang)
  //   final page = await document.getPage(1);
  //
  //   // Render trang PDF thành hình ảnh.
  //   // Chiều rộng 512px là phổ biến cho máy in 80mm (khoảng 203 DPI)
  //   final pageImage = await page.render(
  //     width: 512,
  //     // Tính toán chiều cao tương ứng để giữ đúng tỷ lệ
  //     height: (page.height * 512 / page.width).round(),
  //   );
  //
  //   // Dọn dẹp tài nguyên
  //   await page.close();
  //   await document.close();
  //
  //   if (pageImage == null) {
  //     throw Exception("Không thể chuyển đổi PDF sang ảnh.");
  //   }
  //
  //   // Giải mã dữ liệu byte của ảnh thành đối tượng Image có thể in được
  //   final decodedImage = img.decodeImage(pageImage.bytes);
  //   if (decodedImage == null) {
  //     throw Exception('Không thể giải mã dữ liệu ảnh từ PDF.');
  //   }
  //
  //   return decodedImage;
  // }


  /// [Hàm phụ 3] - Kết nối và gửi lệnh in hình ảnh đến máy in
  Future<void> _printImageOverNetwork(String ip, int port, img.Image image) async {
    // Sử dụng khổ giấy 80mm như yêu cầu
    const PaperSize paper = PaperSize.mm80;
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(paper, profile);

    // Kết nối đến máy in với timeout 5 giây
    final PosPrintResult res = await printer.connect(ip, port: port, timeout: const Duration(seconds: 5));

    if (res == PosPrintResult.success) {
      // In hình ảnh đã được chuyển đổi
      printer.image(image, align: PosAlign.center);
      // Đẩy giấy lên vài dòng cho dễ xé
      printer.feed(2);
      // Cắt giấy
      printer.cut();
      // Ngắt kết nối
      printer.disconnect();
    } else {
      // Nếu kết nối thất bại, báo lỗi
      throw Exception('Không thể kết nối đến máy in: ${res.msg}');
    }
  }


}
