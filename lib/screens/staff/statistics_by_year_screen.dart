import 'package:ban_hang/services/staff_services/statistics_by_year_service.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';


class StatisticsYearScreen extends StatefulWidget {
  const StatisticsYearScreen({super.key});

  @override
  State<StatisticsYearScreen> createState() => _StatisticsYearScreenState();
}

class _StatisticsYearScreenState extends State<StatisticsYearScreen> {
  int? _selectedYear;
  List<Map<String, dynamic>> _data = [];
  bool _loading = false;

  Future<void> _fetchData() async {
    if (_selectedYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn năm!')),
      );
      return;
    }

    setState(() => _loading = true);
    _data = await StatisticsYearService.getSummaryForYear(_selectedYear!);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê theo năm'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
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
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 50),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          if (_selectedYear != null && _data.isNotEmpty) {
                            try {
                              await StatisticsYearService.exportToExcelAndShare(_data, _selectedYear!);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã xuất file Excel!')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Lỗi: $e')),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vui lòng lọc theo năm')),
                            );
                          }
                        },
                        child: const Text('Xuất Excel'),
                      ),
                      SizedBox(
                        height: 300,
                        child: BarChart(
                          StatisticsYearService.buildQuantityChart(_data),
                        ),
                      ),
                      const SizedBox(height: 50),
                      SizedBox(
                        height: 300,
                        child: BarChart(
                          StatisticsYearService.buildRevenueChart(_data),
                        ),
                      ),
                    ],
                  ),
                ),
              ),


            ),
          ],
        ),
      ),
    );
  }
}
