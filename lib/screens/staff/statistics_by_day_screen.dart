import 'package:ban_hang/services/staff_services/statistics_by_day_service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';


class StatisticsDayScreen extends StatefulWidget {
  const StatisticsDayScreen({super.key});

  @override
  State<StatisticsDayScreen> createState() => _StatisticsDayScreenState();
}

class _StatisticsDayScreenState extends State<StatisticsDayScreen> {
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _summary = [];
  bool _loading = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    if (_selectedDate == null) return;
    setState(() => _loading = true);
    _summary = await StatisticsDayService.getSummaryForDay(_selectedDate!);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê theo ngày')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _pickDate,
              child: Text(
                _selectedDate == null
                    ? 'Chọn ngày'
                    : DateFormat('dd/MM/yyyy').format(_selectedDate!),
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const CircularProgressIndicator()
            else if (_summary.isEmpty)
              const Text('Không có dữ liệu')
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          if (_selectedDate != null && _summary.isNotEmpty) {
                            try {
                              await StatisticsDayService.exportToExcelAndShare(_summary, _selectedDate!);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã xuất file Excel!')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Lỗi: $e')),
                              );
                            }
                          }
                        },
                        child: const Text('Xuất Excel'),
                      ),
                      SizedBox(
                        height: 300,
                        child: BarChart(StatisticsDayService.buildQuantityChart(_summary)),
                      ),
                      const SizedBox(height: 50),
                      SizedBox(
                        height: 300,
                        child: BarChart(StatisticsDayService.buildRevenueChart(_summary)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
