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
import 'package:ban_hang/screens/owner/order_management/payment_screen.dart';
class OrderCreatedServices {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Stream<List<Map<String, dynamic>>> getCreatedOrdersStream() async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield [];
      return;
    }

    final userDoc = await _firestore.collection("users").doc(user.uid).get();
    final userData = userDoc.data();
    if (userData == null) {
      yield [];
      return;
    }

    final shopId = userData["shopid"];
    if (shopId == null) {
      yield [];
      return;
    }

    // 🔹 Lấy map userId -> tên
    final usersQuery = await _firestore.collection("users").get();
    final Map<String, String> userNames = {
      for (var u in usersQuery.docs) u.id: (u.data()["name"] ?? "")
    };

    // 🔹 Lắng nghe đơn hàng realtime
    yield* _firestore
        .collection("Order")
        .where("shopid", isEqualTo: shopId)
        .orderBy("invoiceDate", descending: true) // đảm bảo invoiceDate là Timestamp
        .snapshots()
        .map((query) {
      return query.docs.map((doc) {
        final data = doc.data();

        final createdBy = data["createdBy"];
        final createdByName = createdBy != null ? userNames[createdBy] ?? "" : "";

        DateTime? invoiceDateRaw;
        String invoiceDate = "";
        if (data["invoiceDate"] is Timestamp) {
          invoiceDateRaw = (data["invoiceDate"] as Timestamp).toDate();
          invoiceDate = DateFormat("dd/MM/yyyy HH:mm").format(invoiceDateRaw);
        }

        return {
          "docId": doc.id,
          ...data,
          "createdByName": createdByName,
          "invoiceDate": invoiceDate,
          "invoiceDateRaw": invoiceDateRaw,
        };
      }).toList();
    });
  }

  Future<void> updateOrderStatusToCancelled(Map<String, dynamic> order, String reason) async {
    try {
      final docId = order["docId"];
      if (docId == null) {
        throw Exception("Lỗi: Không tìm thấy ID của đơn hàng để cập nhật.");
      }
      final orderRef = _firestore.collection("Order").doc(docId);

      // Chỉ cập nhật trạng thái và thêm lý do hủy
      await orderRef.update({
        "status": "Hủy đơn",
        "cancelReason": reason,
        "cancelledAt": FieldValue.serverTimestamp(),
      });

    } catch (e) {
      print("Lỗi khi cập nhật trạng thái hủy đơn: $e");
      rethrow; // Ném lại lỗi để UI có thể xử lý
    }
  }

  /// 🔹 Hiện dialog xác nhận hủy (đã được cập nhật)
  Future<void> showCancelDialog(BuildContext context, Map<String, dynamic> order) async {
    // Sửa lại lý do cho phù hợp với cả khách hàng và chủ shop
    const defaultReason = "Đơn hàng đã được hủy";
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận hủy đơn"),
        // Sửa lại nội dung dialog
        content: const Text("Bạn có chắc chắn muốn hủy đơn hàng này không?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Không"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Có, hủy đơn"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Bước 1: Gọi API của J&T để hủy
      final success = await cancelOrder(order, defaultReason);

      if (success) {
        // Bước 2: Nếu thành công, cập nhật status trong bảng Order
        await updateOrderStatusToCancelled(order, defaultReason);

        if (context.mounted) {
          Navigator.pop(context); // Tắt loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Đã hủy đơn thành công")),
          );
        }
      } else {
        if (context.mounted) {
          Navigator.pop(context); // Tắt loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Hủy đơn trên hệ thống giao hàng thất bại")),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Tắt loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Đã xảy ra lỗi: $e")),
        );
      }
    }
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
          "https://ylopenapi.jtexpress.vn/webopenplatformapi/api/order/cancelOrder");

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
          "https://ylopenapi.jtexpress.vn/webopenplatformapi/api/logistics/trace");

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
  // Future<void> showCancelDialog(BuildContext context, Map<String, dynamic> order) async {
  //   const defaultReason = "Hủy bởi người bán";
  //   final confirm = await showDialog<bool>(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       title: const Text("Xác nhận hủy đơn"),
  //       content: const Text("Bạn có chắc chắn muốn hủy và xóa đơn này không?"),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(ctx, false),
  //           child: const Text("Không"),
  //         ),
  //         ElevatedButton(
  //           onPressed: () => Navigator.pop(ctx, true),
  //           child: const Text("Có"),
  //         ),
  //       ],
  //     ),
  //   );
  //
  //   if (confirm == true) {
  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (_) => const Center(child: CircularProgressIndicator()),
  //     );
  //
  //     final success = await cancelOrder(order, defaultReason);
  //
  //     if (!context.mounted) return; // ⬅️ thêm dòng này
  //
  //     Navigator.pop(context); // tắt loading
  //
  //     if (success) {
  //       await deleteOrder(order, defaultReason);
  //       if (context.mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(content: Text("Đã hủy và xóa đơn thành công")),
  //         );
  //       }
  //     } else {
  //       if (context.mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(content: Text("Hủy đơn thất bại")),
  //         );
  //       }
  //     }
  //   }
  // }


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



  Future<void> processAndSavePayment({
    required BuildContext context,
    required Map<String, dynamic> order,
    required PaymentOption paymentOption,
    double? partialAmount,
    String? reason,
  }) async {
    final shopId = order['shopid'];
    if (shopId == null || shopId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lỗi: Không tìm thấy ID của shop!")),
      );
      return;
    }

    // Sử dụng Transaction để đảm bảo tính toàn vẹn dữ liệu
    await _firestore.runTransaction((transaction) async {
      // --- BƯỚC 1: Chuẩn bị dữ liệu cho bảng Products_sold ---
      Map<String, dynamic> dataToSave = Map.from(order);

      if (paymentOption == PaymentOption.partial) {
        dataToSave['totalAmount'] = partialAmount ?? 0;
      } else {
        dataToSave['totalAmount'] = order['totalAmount'];
      }

      dataToSave['reason'] = reason ?? "";
      dataToSave['payment_date'] = FieldValue.serverTimestamp();

      dataToSave.remove('docId');
      dataToSave.remove('createdByName');
      dataToSave.remove('invoiceDateRaw');

      // Tạo tham chiếu để lưu đơn hàng đã bán
      final soldOrderRef = _firestore
          .collection('Products_sold')
          .doc(shopId)
          .collection('sales')
          .doc(); // Tạo doc mới với ID tự động

      // Thêm thao tác lưu vào transaction
      transaction.set(soldOrderRef, dataToSave);

      // --- BƯỚC 2: Cập nhật trạng thái của đơn hàng gốc trong bảng Order ---
      final originalOrderRef = _firestore.collection('Order').doc(order['docId']);
      transaction.update(originalOrderRef, {'status': 'Đã thanh toán'});

      // --- BƯỚC 3: Cập nhật tồn kho và số lượng đã bán cho từng sản phẩm ---
      final List<dynamic> items = order['items'] ?? [];
      for (var item in items) {
        final productId = item['productId'];
        final quantitySold = item['quantity'];

        if (productId != null && quantitySold != null) {
          // Tạo tham chiếu đến sản phẩm trong bảng Products
          final productRef = _firestore.collection('Products').doc(productId);

          // Thêm thao tác cập nhật sản phẩm vào transaction
          transaction.update(productRef, {
            // Giảm tồn kho đi số lượng đã bán
            'stockQuantity': FieldValue.increment(-quantitySold),
            // Tăng số lượng đã bán lên
            'sold': FieldValue.increment(quantitySold),
          });
        }
      }
    }).then((_) {
      // Khi tất cả các thao tác trong transaction thành công
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Xác nhận thanh toán và cập nhật kho thành công!")),
        );
      }
    }).catchError((error) {
      // Khi có bất kỳ lỗi nào xảy ra, tất cả thao tác sẽ được hoàn tác
      print("Lỗi transaction khi thanh toán: $error");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Đã xảy ra lỗi: $error")),
        );
      }
    });
  }
  List<PopupMenuEntry<String>> buildMenuItems(String status) {
    // Kiểm tra xem đơn có bị hủy hay không
    final isCancelled = (status == 'Hủy đơn');

    return [
      // Mục "Thanh toán" - Bị vô hiệu hóa nếu đơn đã hủy
      PopupMenuItem(
        value: "payment",
        enabled: !isCancelled, // enabled = false sẽ làm mờ mục này
        child: Text(
          "Thanh toán",
          style: TextStyle(color: isCancelled ? Colors.grey : Colors.black),
        ),
      ),
      const PopupMenuDivider(),

      // Mục "Hủy đơn" - Bị vô hiệu hóa nếu đơn đã hủy
      PopupMenuItem(
        value: "cancel",
        enabled: !isCancelled,
        child: Text(
          "Hủy đơn",
          style: TextStyle(color: isCancelled ? Colors.grey : Colors.black),
        ),
      ),

      // Các mục còn lại luôn được bật
      const PopupMenuItem(
        value: "delete",
        child: Text("Xóa đơn"),
      ),
      const PopupMenuItem(
        value: "trace",
        child: Text("Tra hành trình"),
      ),
      const PopupMenuItem(
        value: "copy_customer",
        child: Text("Copy thông tin khách hàng"),
      ),
      const PopupMenuItem(
        value: "copy_cod",
        child: Text("Copy số tiền COD"),
      ),
      // const PopupMenuItem(
      //   value: "print",
      //   child: Text("In vận đơn"),
      // ),
    ];
  }
  Future<void> handleMenuSelection(BuildContext context, String value, Map<String, dynamic> order) async {
    // Di chuyển toàn bộ logic từ onSelected của UI vào đây
    if (value == "print") {
      if (order["shippingPartner"] == "J&T") {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
        try {
          final result = await printOrderJT(order);
          Navigator.pop(context); // tắt loading

          if (result != null) {
            final jsonResult = jsonDecode(result);
            if (jsonResult["code"] == "1") {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Đã gửi vận đơn đến máy in")),
                );
              }
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("In thất bại: ${jsonResult["msg"]}")),
                );
              }
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Không in được vận đơn J&T")),
              );
            }
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Lỗi in vận đơn: $e")),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đơn vị này chưa hỗ trợ in vận đơn")),
        );
      }
    } else if (value == "cancel") {
      await showCancelDialog(context, order);
    } else if (value == "delete") {
      await showDeleteDialog(context, order);
    } else if (value == "trace") {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      try {
        final result = await traceOrderJT(order);
        if (result != null && context.mounted) {
          Navigator.pop(context); // Tắt loading
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShippingItineraryScreen(response: result),
            ),
          );
        } else {
          if (context.mounted) {
            Navigator.pop(context); // Tắt loading
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Không tìm thấy hành trình")),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Tắt loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Lỗi tra hành trình: $e")),
          );
        }
      }
    } else if (value == "copy_customer") {
      final info =
          "${order["customerName"]} - ${order["customerPhone"]} - ${order["shippingAddress"]}";
      await copyToClipboard(context, info, "Đã copy thông tin khách hàng");
    } else if (value == "copy_cod") {
      await copyToClipboard(context, "${order["codAmount"] ?? "0"}", "Đã copy số tiền COD");
    } else if (value == "payment") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(order: order),
        ),
      );
    }
  }
}
