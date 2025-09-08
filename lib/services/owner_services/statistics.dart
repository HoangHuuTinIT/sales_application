// lib/services/owner_services/statistics.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Enum để quản lý bộ lọc thời gian
enum DateFilter { today, thisWeek, thisMonth, thisQuarter, thisYear }

// Enum để quản lý bộ lọc của top sản phẩm
enum TopProductsFilter { sales, revenue, quantity }

class StatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Lấy shopId của người dùng hiện tại
  Future<String?> _getShopId() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final userDoc = await _firestore.collection("users").doc(user.uid).get();
    return userDoc.data()?["shopid"];
  }

  // Helper để lấy khoảng thời gian dựa vào bộ lọc
  Map<String, DateTime> _getDateRange(DateFilter filter) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (filter) {
      case DateFilter.today:
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1));
        break;
      case DateFilter.thisWeek:
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = start.add(const Duration(days: 7));
        break;
      case DateFilter.thisMonth:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 1);
        break;
      case DateFilter.thisQuarter:
        int quarter = ((now.month - 1) / 3).floor() + 1;
        start = DateTime(now.year, (quarter - 1) * 3 + 1, 1);
        end = DateTime(now.year, start.month + 3, 1);
        break;
      case DateFilter.thisYear:
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year + 1, 1, 1);
        break;
    }
    return {'start': start, 'end': end};
  }

  // Lấy dữ liệu thô từ Firestore theo khoảng thời gian
  Future<List<QueryDocumentSnapshot>> getSalesData(DateFilter filter) async {
    final shopId = await _getShopId();
    if (shopId == null) return [];

    final dateRange = _getDateRange(filter);
    final startDate = dateRange['start']!;
    final endDate = dateRange['end']!;

    final querySnapshot = await _firestore
        .collection('Products_sold')
        .doc(shopId)
        .collection('sales')
        .where('payment_date', isGreaterThanOrEqualTo: startDate)
        .where('payment_date', isLessThan: endDate)
        .get();

    return querySnapshot.docs;
  }

  // 1. Xử lý dữ liệu cho "Kết quả bán hàng"
  Map<String, dynamic> processSalesResults(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return {'totalRevenue': 0.0, 'orderCount': 0, 'returnCount': 0, 'returnAmount': 0.0};
    }

    double totalRevenue = 0;
    // Tạm thời chưa có logic trả hàng, nên để là 0
    int returnCount = 0;
    double returnAmount = 0.0;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalRevenue += (data['totalAmount'] ?? 0).toDouble();
    }

    return {
      'totalRevenue': totalRevenue,
      'orderCount': docs.length,
      'returnCount': returnCount,
      'returnAmount': returnAmount,
    };
  }

  // 2. Xử lý dữ liệu cho biểu đồ "Doanh thu"
  Map<String, double> processRevenueChartData(List<QueryDocumentSnapshot> docs, DateFilter filter) {
    Map<String, double> revenueData = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final paymentDate = (data['payment_date'] as Timestamp).toDate();
      final totalAmount = (data['totalAmount'] ?? 0).toDouble();

      String key;

      // Nhóm dữ liệu theo ngày/tháng/quý...
      switch (filter) {
        case DateFilter.today:
        case DateFilter.thisWeek:
          key = 'T${paymentDate.weekday + 1}'; // T2, T3...
          break;
        case DateFilter.thisMonth:
          key = '${paymentDate.day}';
          break;
        case DateFilter.thisQuarter:
        case DateFilter.thisYear:
          key = 'T${paymentDate.month}'; // Tháng 1, Tháng 2...
          break;
      }

      revenueData.update(key, (value) => value + totalAmount, ifAbsent: () => totalAmount);
    }
    return revenueData;
  }

  // 3. Xử lý dữ liệu cho "Top bán chạy"
  List<Map<String, dynamic>> processTopSellingProducts(
      List<QueryDocumentSnapshot> docs, TopProductsFilter filter) {
    Map<String, Map<String, dynamic>> productStats = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final List<dynamic> items = data['items'] ?? [];

      for (var item in items) {
        final productId = item['productId']?.toString() ?? item['name']; // Dùng name nếu productId null
        final productName = item['name'] ?? 'Sản phẩm không tên';
        final quantity = (item['quantity'] ?? 0);
        final total = (item['total'] ?? 0.0).toDouble();

        productStats.update(
          productId,
              (value) {
            value['quantity'] += quantity;
            value['revenue'] += total;
            value['sales'] += 1; // Mỗi lần xuất hiện trong 1 đơn là 1 lần bán
            return value;
          },
          ifAbsent: () => {
            'name': productName,
            'quantity': quantity,
            'revenue': total,
            'sales': 1,
          },
        );
      }
    }

    var sortedList = productStats.values.toList();

    // Sắp xếp danh sách dựa trên bộ lọc
    switch (filter) {
      case TopProductsFilter.quantity:
        sortedList.sort((a, b) => b['quantity'].compareTo(a['quantity']));
        break;
      case TopProductsFilter.revenue:
        sortedList.sort((a, b) => b['revenue'].compareTo(a['revenue']));
        break;
      case TopProductsFilter.sales:
        sortedList.sort((a, b) => b['sales'].compareTo(a['sales']));
        break;
    }

    return sortedList.take(10).toList(); // Lấy top 10
  }
}