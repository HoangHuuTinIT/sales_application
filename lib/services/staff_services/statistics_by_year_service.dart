import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class StatisticsYearService {
  /// Lấy dữ liệu theo năm
  static Future<List<Map<String, dynamic>>> getSummaryForYear(int year) async {
    final firestore = FirebaseFirestore.instance;

    final snapshot = await firestore
        .collection('delivery_products')
        .where('status', isEqualTo: 'Hoàn tất thanh toán')
        .get();

    final Map<int, Map<String, dynamic>> grouped = {
      for (var i = 1; i <= 12; i++) i: {'month': i, 'quantity': 0, 'total': 0.0},
    };

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final endTime = (data['delivery_end_time'] as Timestamp).toDate();
      if (endTime.year == year) {
        final month = endTime.month;
        grouped[month]!['quantity'] += data['quantity'] as int;
        grouped[month]!['total'] += (data['total'] as num).toDouble();
      }
    }

    return List.generate(12, (i) => grouped[i + 1]!);
  }

  /// ✅ Xuất & chia sẻ file Excel
  static Future<void> exportToExcelAndShare(List<Map<String, dynamic>> data, int year) async {
    final status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      throw Exception('Chưa được cấp quyền lưu file!');
    }

    final excel = Excel.createExcel();
    final sheet = excel['Thống kê'];
    sheet.appendRow(['Tháng', 'Số lượng', 'Doanh thu']);

    for (var item in data) {
      sheet.appendRow([
        item['month'],
        item['quantity'],
        item['total'],
      ]);
    }

    final fileBytes = excel.encode();
    final dir = Directory('/storage/emulated/0/Download');
    final fileName = 'Thong_ke_nam_$year.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(fileBytes!);

    await Share.shareXFiles([XFile(file.path)], text: 'Thống kê năm $year');
  }

  /// Biểu đồ số lượng
  static BarChartData buildQuantityChart(List<Map<String, dynamic>> data) {
    final maxY = data.map((e) => e['quantity'] as int).fold<int>(0, (prev, el) => el > prev ? el : prev);

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      barGroups: data.map((item) {
        return BarChartGroupData(
          x: item['month'],
          barRods: [
            BarChartRodData(
              toY: (item['quantity'] as int).toDouble(),
              color: const Color(0xff4CAF50),
              width: 12,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      }).toList(),
      maxY: maxY.toDouble() * 1.2,
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(axisNameWidget: const Text('Số lượng')),
        bottomTitles: AxisTitles(
          axisNameWidget: const Text('Tháng'),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              final month = value.toInt();
              if (month >= 1 && month <= 12) {
                return Text('T$month');
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  /// Biểu đồ doanh thu
  static BarChartData buildRevenueChart(List<Map<String, dynamic>> data) {
    final maxY = data.map((e) => e['total'] as num).fold<num>(0, (prev, el) => el > prev ? el : prev);

    return BarChartData(
      barGroups: data.map((item) {
        return BarChartGroupData(
          x: item['month'],
          barRods: [
            BarChartRodData(
              toY: (item['total'] as num).toDouble(),
              color: const Color(0xffFF9800),
              width: 12,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      }).toList(),
      maxY: maxY.toDouble() * 1.2,
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(axisNameWidget: const Text('Doanh thu')),
        bottomTitles: AxisTitles(
          axisNameWidget: const Text('Tháng'),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              final month = value.toInt();
              if (month >= 1 && month <= 12) {
                return Text('T$month');
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}
