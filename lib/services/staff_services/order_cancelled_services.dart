import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

class OrderCancelledServices {
  /// Lấy đơn hàng bị hủy theo khoảng ngày
  static Future<List<Map<String, dynamic>>> getOrders({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final firestore = FirebaseFirestore.instance;

    Query query = firestore.collection('OrderCancelled');

    if (startDate != null && endDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day)
          .add(const Duration(days: 1));
      query = query
          .where('cancelledAt', isGreaterThanOrEqualTo: start)
          .where('cancelledAt', isLessThan: end);
    }

    final snapshot = await query.get();

    List<Map<String, dynamic>> results = [];

    for (var doc in snapshot.docs) {
      final data = doc.data()! as Map<String, dynamic>;

      final userId = data['userId'];
      final productId = data['productId'];

      final userDoc =
      await firestore.collection('users').doc(userId).get();
      final userData = userDoc.exists
          ? userDoc.data()! as Map<String, dynamic>
          : {};

      final productDoc =
      await firestore.collection('Products').doc(productId).get();
      final productData = productDoc.exists
          ? productDoc.data()! as Map<String, dynamic>
          : {};

      results.add({
        'orderId': doc.id,
        'cancelledAt': data['cancelledAt'],
        'quantity': data['quantity'],
        'total': data['total'],
        'userId': userId,
        'address': userData['address'] ?? '',
        'customerName': userData['name'] ?? '',
        'phone': userData['phone'] ?? '',
        'productName': productData['name'] ?? '',
      });
    }

    return results;
  }

  /// Tạo file Excel và trả về đường dẫn file
  static Future<String> exportOrdersToExcel({
    required List<Map<String, dynamic>> orders,
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['CancelledOrders'];

    // Header tiếng Việt
    sheet.appendRow([
      'ID Đặt hàng',
      'Tên khách hàng',
      'SDT',
      'Địa chỉ',
      'Tên sản phẩm',
      'Số lượng',
      'Tổng giá trị đơn hàng',
      'Ngày đơn hàng bị hủy'
    ]);

    for (var order in orders) {
      final cancelledAt = order['cancelledAt'] is Timestamp
          ? (order['cancelledAt'] as Timestamp).toDate()
          : order['cancelledAt'] as DateTime;

      sheet.appendRow([
        order['orderId'],
        order['customerName'],
        order['phone'],
        order['address'],
        order['productName'],
        order['quantity'].toString(),
        order['total'].toString(),
        '${cancelledAt.day}/${cancelledAt.month}/${cancelledAt.year}',
      ]);
    }

    // Tạo tên file theo ngày lọc
    String datePart = '';
    if (startDate != null && endDate != null) {
      if (startDate.year == endDate.year &&
          startDate.month == endDate.month &&
          startDate.day == endDate.day) {
        datePart =
        'Ngày_${startDate.year}-${startDate.month}-${startDate.day}';
      } else {
        datePart =
        '_Từ_ngày_${startDate.year}-${startDate.month}-${startDate.day}_đến_ngày_${endDate.year}-${endDate.month}-${endDate.day}';
      }
    } else {
      final now = DateTime.now();
      datePart = '_${now.year}-${now.month}-${now.day}';
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/Đơn_hàng_bị_hủy$datePart.xlsx';

    final fileBytes = excel.save();
    final file = File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);

    print('✅ File đã lưu: $path');
    return path;
  }
}
