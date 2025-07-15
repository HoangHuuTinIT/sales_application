import 'package:ban_hang/screens/staff/order_cancelled.dart';
import 'package:flutter/material.dart';
import 'package:ban_hang/screens/staff/statistics_by_day_screen.dart';
import 'package:ban_hang/screens/staff/statistics_by_month_screen.dart';
import 'package:ban_hang/screens/staff/statistics_by_year_screen.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatisticsDayScreen()),
                );
              },
              child: const Text('Thống kê theo ngày ' ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatisticsMonthScreen()),
                );
              },
              child: const Text('Thống kê theo tháng'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatisticsYearScreen()),
                );
              },
              child: const Text('Thống kê theo năm'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrderCancelledScreen()),
                );
              },
              child: const Text('Đơn hàng bị hủy'),
            ),
          ],
        ),
      ),
    );
  }
}
