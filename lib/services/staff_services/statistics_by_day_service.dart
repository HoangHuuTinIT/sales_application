import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class StatisticsDayService {
  /// ✅ Lấy & gộp dữ liệu
  static Future<List<Map<String, dynamic>>> getSummaryForDay(DateTime day) async {
    final firestore = FirebaseFirestore.instance;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    // 1️⃣ Lấy tất cả Products_sold
    final soldSnap = await firestore.collection('Products_sold').get();

    final List<Map<String, dynamic>> temp = [];

    for (var soldDoc in soldSnap.docs) {
      final sold = soldDoc.data();
      final deliveryProductsId = sold['deliveryProductsId'] as String?;
      final orderedProductsId = sold['orderedProductsId'] as String?;

      if (deliveryProductsId == null || orderedProductsId == null) continue;

      // 2️⃣ JOIN sang delivery_products
      final deliveryDoc = await firestore.collection('delivery_products').doc(deliveryProductsId).get();
      if (!deliveryDoc.exists) continue;

      final deliveryEndTime = (deliveryDoc['delivery_end_time'] as Timestamp?)?.toDate();
      if (deliveryEndTime == null) continue;

      if (deliveryEndTime.isBefore(start) || deliveryEndTime.isAfter(end)) continue;

      // 3️⃣ JOIN sang OrderedProducts
      final orderedDoc = await firestore.collection('OrderedProducts').doc(orderedProductsId).get();
      if (!orderedDoc.exists) continue;

      final ordered = orderedDoc.data();
      final productId = ordered?['productId'] as String?;
      final quantity = ordered?['quantity'] as int? ?? 0;
      final total = ordered?['total'] as num? ?? 0;

      if (productId == null) continue;

      // 4️⃣ JOIN sang Products để lấy tên
      final productDoc = await firestore.collection('Products').doc(productId).get();
      final productName = productDoc.exists ? (productDoc['name'] ?? '') : '';

      temp.add({
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'total': total,
      });
    }

    // 5️⃣ Gom nhóm
    final Map<String, Map<String, dynamic>> grouped = {};
    for (var item in temp) {
      final pid = item['productId'] as String;
      final pname = item['productName'] as String;
      final qty = item['quantity'] as int;
      final tot = item['total'] as num;

      grouped.putIfAbsent(pid, () => {
        'productId': pid,
        'productName': pname,
        'quantity': 0,
        'total': 0,
      });

      grouped[pid]!['quantity'] += qty;
      grouped[pid]!['total'] += tot;
    }

    return grouped.values.toList();
  }
  /// ✅ Xuất file Excel + chia sẻ
  static Future<void> exportToExcelAndShare(List<Map<String, dynamic>> data, DateTime day) async {
    final status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      throw Exception('Chưa được cấp quyền lưu file!');
    }

    final excel = Excel.createExcel();
    final sheet = excel['Thống kê'];
    sheet.appendRow(['Mã SP', 'Tên SP', 'Số lượng', 'Doanh thu']);

    for (var item in data) {
      sheet.appendRow([
        item['productId'],
        item['productName'],
        item['quantity'],
        item['total'],
      ]);
    }

    final fileBytes = excel.encode();
    final dir = Directory('/storage/emulated/0/Download');
    final fileName = 'Thong_ke_${day.day}_${day.month}_${day.year}.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(fileBytes!);

    // Chia sẻ
    await Share.shareXFiles([XFile(file.path)], text: 'Thống kê ngày ${day.day}/${day.month}/${day.year}');
  }

  static BarChartData buildQuantityChart(List<Map<String, dynamic>> data) {
    final maxY = data.map((e) => e['quantity'] as int).reduce((a, b) => a > b ? a : b) * 1.2;

    return BarChartData(
      maxY: maxY,
      barGroups: data.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: (item['quantity'] as int).toDouble(),
              width: 20,
              color: const Color(0xFF2196F3),
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      }).toList(),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          axisNameWidget: const Text('Tên SP'),
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value.toInt() < data.length) {
                final m = data[value.toInt()];
                return Text(
                  m['productName'],
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        leftTitles: AxisTitles(
          axisNameWidget: const Text('Số lượng'),
        ),
      ),
      borderData: FlBorderData(show: false),
    );
  }

  static BarChartData buildRevenueChart(List<Map<String, dynamic>> data) {
    final maxY = data.map((e) => e['total'] as num).reduce((a, b) => a > b ? a : b) * 1.2;

    return BarChartData(
      maxY: maxY,
      barGroups: data.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: (item['total'] as num).toDouble(),
              width: 20,
              color: const Color(0xFFFF9800),
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      }).toList(),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          axisNameWidget: const Text('Tên SP'),
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value.toInt() < data.length) {
                final m = data[value.toInt()];
                return Text(
                  m['productName'],
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        leftTitles: AxisTitles(
          axisNameWidget: const Text('Doanh thu'),
        ),
      ),
      borderData: FlBorderData(show: false),
    );
  }
}
