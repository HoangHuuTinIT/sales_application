import 'package:ban_hang/services/staff_services/statistics_by_month_service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';


class StatisticsMonthScreen extends StatefulWidget {
  const StatisticsMonthScreen({super.key});

  @override
  State<StatisticsMonthScreen> createState() => _StatisticsMonthScreenState();
}

class _StatisticsMonthScreenState extends State<StatisticsMonthScreen> {
  int? _selectedMonth;
  int? _selectedYear;
  List<Map<String, dynamic>> _data = [];
  bool _loading = false;

  Future<void> _fetchData() async {
    if (_selectedMonth == null || _selectedYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn tháng & năm!')),
      );
      return;
    }

    setState(() => _loading = true);
    _data = await StatisticsMonthService.getSummaryForMonth(
      _selectedYear!,
      _selectedMonth!,
    );
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê theo tháng'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<int>(
                    value: _selectedMonth,
                    hint: const Text('Chọn tháng'),
                    items: List.generate(12, (i) => i + 1)
                        .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text('Tháng $m'),
                    ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedMonth = v),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<int>(
                    value: _selectedYear,
                    hint: const Text('Chọn năm'),
                    items: List.generate(5, (i) => now.year - i)
                        .map((y) => DropdownMenuItem(
                      value: y,
                      child: Text('$y'),
                    ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedYear = v),
                  ),
                ),
                IconButton(
                  onPressed: _fetchData,
                  icon: const Icon(Icons.search),
                )
              ],
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : Expanded(
              child: _data.isEmpty
                  ? const Center(child: Text('Không có dữ liệu'))
                  : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        if (_selectedMonth != null && _selectedYear != null && _data.isNotEmpty) {
                          await StatisticsMonthService.exportToExcel(
                            _data, _selectedYear!, _selectedMonth!,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã xuất Excel!')),
                          );
                        }
                      },
                      child: const Text('Xuất Excel'),
                    ),
                    Container(
                      height: 300,
                      margin: const EdgeInsets.only(bottom: 50),
                      child: BarChart(
                        StatisticsMonthService.buildQuantityChart(_data),
                      ),
                    ),
                    Container(
                      height: 300,
                      child: BarChart(
                        StatisticsMonthService.buildRevenueChart(_data),
                      ),
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
