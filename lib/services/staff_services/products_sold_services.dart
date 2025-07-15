import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

class ProductsSoldServices {
  /// Lấy danh sách sản phẩm đã bán theo khoảng ngày
  static Future<List<Map<String, dynamic>>> getProductsSold({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final firestore = FirebaseFirestore.instance;

    Query query = firestore.collection('Products_sold');

    if (startDate != null && endDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day)
          .add(const Duration(days: 1));
      query = query
          .where('delivery_end_time', isGreaterThanOrEqualTo: start)
          .where('delivery_end_time', isLessThan: end);
    }

    final snapshot = await query.get();

    return snapshot.docs.map((doc) {
      final data = doc.data()! as Map<String, dynamic>;
      return {
        'productId': data['productId'],
        'productName': data['productName'],
        'quantity': data['quantity'],
        'total': data['total'],
        'delivery_end_time': data['delivery_end_time'],
      };
    }).toList();
  }

  /// Gom nhóm thống kê: tổng số lượng & doanh thu theo sản phẩm
  static List<Map<String, dynamic>> summarizeByProduct(
      List<Map<String, dynamic>> soldList) {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (var sold in soldList) {
      final id = sold['productId'];
      if (!grouped.containsKey(id)) {
        grouped[id] = {
          'productId': id,
          'productName': sold['productName'],
          'quantity': 0,
          'total': 0.0,
        };
      }
      grouped[id]!['quantity'] += sold['quantity'] as int;
      grouped[id]!['total'] += sold['total'] as num;
    }

    return grouped.values.toList();
  }

  static List<Map<String, dynamic>> applyFilter(
      List<Map<String, dynamic>> data,
      String filterType,
      ) {
    final sorted = List<Map<String, dynamic>>.from(data);

    if (filterType == 'quantity_highest') {
      sorted.sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));
    } else if (filterType == 'quantity_lowest') {
      sorted.sort((a, b) => (a['quantity'] as int).compareTo(b['quantity'] as int));
    } else if (filterType == 'revenue_highest') {
      sorted.sort((a, b) => (b['total'] as num).compareTo(a['total'] as num));
    } else if (filterType == 'revenue_lowest') {
      sorted.sort((a, b) => (a['total'] as num).compareTo(b['total'] as num));
    }
    // Nếu filterType là "all" thì không sắp xếp
    return sorted;
  }


  /// Xuất Excel: Tên file + Sheet + Cột tiếng Việt
  static Future<String> exportToExcel({
    required List<Map<String, dynamic>> summarized,
    required DateTime? startDate,
    required DateTime? endDate,
    required String filterType,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Đơn hàng đã bán']; // Sheet tiếng Việt

    // Header cột tiếng Việt
    sheet.appendRow([
      'Tên sản phẩm',
      'Tổng số lượng bán',
      'Tổng doanh thu',
    ]);

    for (var item in summarized) {
      sheet.appendRow([
        item['productName'],
        item['quantity'].toString(),
        item['total'].toString(),
      ]);
    }

    // Tạo phần ngày lọc
    String datePart = '';
    if (startDate != null && endDate != null) {
      if (startDate.year == endDate.year &&
          startDate.month == endDate.month &&
          startDate.day == endDate.day) {
        datePart = '_${startDate.year}-${startDate.month}-${startDate.day}';
      } else {
        datePart =
        'Từ_ngày_${startDate.year}-${startDate.month}-${startDate.day}_đến_ngày_${endDate.year}-${endDate.month}-${endDate.day}';
      }
    } else {
      final now = DateTime.now();
      datePart = '_${now.year}-${now.month}-${now.day}';
    }

    // Bộ lọc tiếng Việt
    final filterLabel = _getFilterLabel(filterType);

    // Tên file tiếng Việt
    final fileName = 'Đơn_hàng_đã_bán_${datePart}_$filterLabel.xlsx';

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$fileName';

    final fileBytes = excel.save();
    final file = File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);

    return path;
  }

  /// Hàm dịch filterType sang tiếng Việt cho tên file
  static String _getFilterLabel(String filterType) {
    switch (filterType) {
      case 'quantity_highest':
        return 'Bán_ra_nhiều_nhất';
      case 'quantity_lowest':
        return 'Bán_ra_ít_nhất';
      case 'revenue_highest':
        return 'Doanh_thu_cao_nhất';
      case 'revenue_lowest':
        return 'Doanh_thu_thấp_nhất';
      default:
        return 'Tat_ca'; // filterType == 'all'
    }
  }
  static Future<String> exportToExcelLineChart({
    required List<Map<String, dynamic>> summarized,
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Thống kê'];

    sheet.appendRow(['Ngày', 'Tổng số lượng', 'Tổng doanh thu']);

    for (var item in summarized) {
      sheet.appendRow([
        item['key'],
        item['quantity'].toString(),
        item['total'].toString(),
      ]);
    }

    final now = DateTime.now();
    final fileName = 'Thong_ke_${now.year}-${now.month}-${now.day}.xlsx';

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$fileName';

    final fileBytes = excel.save();
    final file = File(path)..createSync(recursive: true)..writeAsBytesSync(fileBytes!);

    return path;
  }



}
