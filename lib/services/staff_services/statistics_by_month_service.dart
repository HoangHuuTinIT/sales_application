import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class StatisticsMonthService {
  /// Lấy & gộp dữ liệu theo ngày + productId
  static Future<List<Map<String, dynamic>>> getSummaryForMonth(
      int year, int month) async {
    final firestore = FirebaseFirestore.instance;
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    final snapshot = await firestore
        .collection('delivery_products')
        .where('status', isEqualTo: 'Hoàn tất thanh toán')
        .where('delivery_end_time', isGreaterThanOrEqualTo: start)
        .where('delivery_end_time', isLessThan: end)
        .get();

    final Map<String, Map<int, Map<String, dynamic>>> grouped = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final productId = data['productId'];
      final productName = data['productName'] ?? '';
      final quantity = data['quantity'] ?? 0;
      final total = data['total'] ?? 0;

      final date = (data['delivery_end_time'] as Timestamp).toDate();
      final day = date.day;

      grouped.putIfAbsent(productId, () => {});
      grouped[productId]!.putIfAbsent(day, () => {
        'productId': productId,
        'productName': productName,
        'day': day,
        'quantity': 0,
        'total': 0.0,
      });

      grouped[productId]![day]!['quantity'] += quantity;
      grouped[productId]![day]!['total'] += total;
    }

    final result = <Map<String, dynamic>>[];
    for (var productEntry in grouped.entries) {
      for (var dayEntry in productEntry.value.entries) {
        result.add(dayEntry.value);
      }
    }

    return result;
  }

  /// ✅ Xuất file Excel ra thư mục Download
  static Future<void> exportToExcel(
      List<Map<String, dynamic>> data, int year, int month) async {
    // ✅ Xin quyền
    final status = await Permission.manageExternalStorage.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      await openAppSettings();
      throw Exception('Cần cấp quyền lưu file trong Cài đặt!');
    }

    // ✅ Tạo Excel
    final excel = Excel.createExcel();
    final sheet = excel['Thống kê'];
    sheet.appendRow(['Ngày', 'Mã SP', 'Tên SP', 'Số lượng', 'Doanh thu']);

    for (var item in data) {
      sheet.appendRow([
        item['day'],
        item['productId'],
        item['productName'],
        item['quantity'],
        item['total'],
      ]);
    }

    final fileBytes = excel.encode();
    final dir = Directory('/storage/emulated/0/Download');
    final fileName = 'Thống_kê_${month}_$year.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(fileBytes!);

    print('✅ Đã lưu: ${file.path}');

    // ✅ Mở share luôn
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Thống kê tháng $month/$year',
    );
  }



  /// Chart Quantity
  static BarChartData buildQuantityChart(List<Map<String, dynamic>> data) {
    final maxY =
        data.map((e) => e['quantity'] as int).reduce((a, b) => a > b ? a : b) *
            1.2;

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
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
          axisNameWidget: const Text('Ngày'),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              if (value.toInt() < data.length) {
                final m = data[value.toInt()];
                return Text(
                  '${m['day']}\n${m['productName']}',
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        leftTitles: AxisTitles(
          axisNameWidget: const Text('Số lượng'),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text('${value.toInt()}'),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Chart Revenue
  static BarChartData buildRevenueChart(List<Map<String, dynamic>> data) {
    final maxY = data
        .map((e) => e['total'] as num)
        .reduce((a, b) => a > b ? a : b) *
        1.2;

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
          axisNameWidget: const Text('Ngày'),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              if (value.toInt() < data.length) {
                final m = data[value.toInt()];
                return Text(
                  '${m['day']}\n${m['productName']}',
                  style: const TextStyle(fontSize: 10),
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
    );
  }
}
