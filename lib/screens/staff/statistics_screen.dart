// lib/screens/staff/statistics_screen.dart

import 'package:ban_hang/services/owner_services/statistics.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê và Báo cáo'),
      ),
      // Mỗi phần thống kê giờ là một widget độc lập
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            SalesResultsWidget(),
            SizedBox(height: 24),
            RevenueChartWidget(),
            SizedBox(height: 24),
            TopSellingProductsWidget(),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// 1. WIDGET CHO PHẦN "KẾT QUẢ BÁN HÀNG"
// =================================================================
class SalesResultsWidget extends StatefulWidget {
  const SalesResultsWidget({super.key});

  @override
  State<SalesResultsWidget> createState() => _SalesResultsWidgetState();
}

class _SalesResultsWidgetState extends State<SalesResultsWidget> {
  final StatisticsService _service = StatisticsService();
  // Bộ lọc riêng cho widget này
  DateFilter _selectedDateFilter = DateFilter.today;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSectionHeader('KẾT QUẢ BÁN HÀNG', _selectedDateFilter, (newFilter) {
              // Khi thay đổi bộ lọc, chỉ widget này được build lại
              setState(() => _selectedDateFilter = newFilter);
            }),
            const SizedBox(height: 20),
            // FutureBuilder riêng cho widget này
            FutureBuilder<List<dynamic>>(
              key: ValueKey(_selectedDateFilter), // Key để FutureBuilder chạy lại khi filter đổi
              future: _service.getSalesData(_selectedDateFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return const SizedBox(height: 80, child: Center(child: Text('Lỗi tải dữ liệu')));
                }
                final results = _service.processSalesResults(snapshot.data?.cast() ?? []);
                final currencyFormatter = NumberFormat.decimalPattern('vi_VN');

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildResultItem(
                        Icons.receipt_long, Colors.blue,
                        '${results['orderCount']} Phiếu', 'bán hàng',
                        currencyFormatter.format(results['totalRevenue'])),
                    _buildResultItem(
                        Icons.undo, Colors.green,
                        '${results['returnCount']} phiếu', 'Trả hàng',
                        currencyFormatter.format(results['returnAmount'])),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// 2. WIDGET CHO PHẦN BIỂU ĐỒ "DOANH THU"
// =================================================================
class RevenueChartWidget extends StatefulWidget {
  const RevenueChartWidget({super.key});

  @override
  State<RevenueChartWidget> createState() => _RevenueChartWidgetState();
}

class _RevenueChartWidgetState extends State<RevenueChartWidget> {
  final StatisticsService _service = StatisticsService();
  // Bộ lọc riêng cho widget này
  DateFilter _selectedDateFilter = DateFilter.today;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('DOANH THU', _selectedDateFilter, (newFilter) {
              setState(() => _selectedDateFilter = newFilter);
            }),
            const SizedBox(height: 24),
            // FutureBuilder riêng cho widget này
            FutureBuilder<List<dynamic>>(
              key: ValueKey(_selectedDateFilter),
              future: _service.getSalesData(_selectedDateFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return const SizedBox(height: 200, child: Center(child: Text('Lỗi tải dữ liệu')));
                }

                final chartData = _service.processRevenueChartData(snapshot.data?.cast() ?? [], _selectedDateFilter);
                final sortedKeys = chartData.keys.toList()..sort((a, b) {
                  final numA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                  final numB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                  return numA.compareTo(numB);
                });

                List<FlSpot> spots = sortedKeys.map((key) {
                  final xValue = double.tryParse(key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                  final yValue = chartData[key]! / 1000000;
                  return FlSpot(xValue, yValue);
                }).toList();

                if (spots.isEmpty) {
                  return const SizedBox(height: 200, child: Center(child: Text("Chưa có dữ liệu cho khoảng thời gian này.")));
                }

                return SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBgColor: Colors.blueAccent,
                          getTooltipItems: (touchedSpots) => touchedSpots.map((spot) => LineTooltipItem(
                            '${NumberFormat.decimalPattern('vi_VN').format(spot.y * 1000000)} VNĐ',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          )).toList(),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        getDrawingHorizontalLine: (value) => const FlLine(color: Colors.grey, strokeWidth: 0.5),
                        getDrawingVerticalLine: (value) => const FlLine(color: Colors.grey, strokeWidth: 0.5),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40,
                            getTitlesWidget: (value, meta) => Text('${value.toInt()} tr', style: const TextStyle(fontSize: 12)))),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30,
                            getTitlesWidget: (value, meta) => Text(sortedKeys.isNotEmpty ? sortedKeys[value.toInt() % sortedKeys.length] : '', style: const TextStyle(fontSize: 12)))),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xff37434d), width: 1)),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          gradient: const LinearGradient(colors: [Colors.cyan, Colors.blue]),
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [Colors.cyan.withOpacity(0.3), Colors.blue.withOpacity(0.3)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// 3. WIDGET CHO PHẦN "TOP BÁN HÀNG CHẠY"
// =================================================================

// lib/screens/staff/statistics_screen.dart

// =================================================================
// 3. WIDGET CHO PHẦN "TOP BÁN HÀNG CHẠY"
// =================================================================
class TopSellingProductsWidget extends StatefulWidget {
  const TopSellingProductsWidget({super.key});

  @override
  State<TopSellingProductsWidget> createState() => _TopSellingProductsWidgetState();
}

class _TopSellingProductsWidgetState extends State<TopSellingProductsWidget> {
  final StatisticsService _service = StatisticsService();
  DateFilter _selectedDateFilter = DateFilter.today;
  TopProductsFilter _selectedTopProductsFilter = TopProductsFilter.quantity;
  // BỎ BIẾN NÀY: int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTopProductHeader(
              'TOP BÁN HÀNG CHẠY',
              _selectedDateFilter,
              _selectedTopProductsFilter,
                  (dateFilter) => setState(() => _selectedDateFilter = dateFilter),
                  (productFilter) => setState(() => _selectedTopProductsFilter = productFilter),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<dynamic>>(
              key: ValueKey('${_selectedDateFilter}_${_selectedTopProductsFilter}'),
              future: _service.getSalesData(_selectedDateFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return const SizedBox(height: 200, child: Center(child: Text('Lỗi tải dữ liệu')));
                }

                final topProducts = _service.processTopSellingProducts(snapshot.data?.cast() ?? [], _selectedTopProductsFilter);

                if (topProducts.isEmpty) {
                  return const SizedBox(height: 150, child: Center(child: Text("Chưa có sản phẩm nào được bán trong khoảng thời gian này.")));
                }

                // Tách riêng phần giao diện ra để code gọn gàng
                return _buildChartAndList(topProducts);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Widget chứa giao diện biểu đồ và danh sách
  Widget _buildChartAndList(List<Map<String, dynamic>> topProducts) {
    final currencyFormatter = NumberFormat.decimalPattern('vi_VN');
    final List<Color> pieColors = [
      Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple,
      Colors.teal, Colors.pink, Colors.amber, Colors.indigo, Colors.brown,
    ];

    double totalValue = topProducts.fold(0, (sum, item) {
      final value = _selectedTopProductsFilter == TopProductsFilter.revenue ? item['revenue'] : item['quantity'];
      return sum + value;
    });

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PieChart(
            PieChartData(
              // BỎ LUÔN CẢ KHỐI pieTouchData NÀY
              // pieTouchData: PieTouchData(
              //   touchCallback: (FlTouchEvent event, pieTouchResponse) {
              //     setState(() {
              //       touchedIndex = ...
              //     });
              //   },
              // ),
              sections: List.generate(topProducts.length, (index) {
                final product = topProducts[index];
                // BỎ LOGIC isTouched VÀ DÙNG BÁN KÍNH CỐ ĐỊNH
                final double radius = 50.0;
                final double value = _selectedTopProductsFilter == TopProductsFilter.revenue
                    ? product['revenue']
                    : product['quantity'].toDouble();
                final percentage = totalValue == 0 ? 0 : (value / totalValue) * 100;
                return PieChartSectionData(
                  color: pieColors[index % pieColors.length],
                  value: value,
                  title: '${percentage.toStringAsFixed(1)}%',
                  radius: radius,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }),
              centerSpaceRadius: 30,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: topProducts.length,
          itemBuilder: (context, index) {
            final product = topProducts[index];
            final double value = _selectedTopProductsFilter == TopProductsFilter.revenue
                ? product['revenue']
                : product['quantity'].toDouble();
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: pieColors[index % pieColors.length],
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(product['name']),
              trailing: Text(
                _selectedTopProductsFilter == TopProductsFilter.revenue
                    ? currencyFormatter.format(value)
                    : value.toInt().toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
      ],
    );
  }
}
// =================================================================
// CÁC WIDGET HELPER (DÙNG CHUNG)
// =================================================================

// Helper để lấy tên bộ lọc
String _getDateFilterText(DateFilter filter) {
  switch (filter) {
    case DateFilter.today: return "Hôm nay";
    case DateFilter.thisWeek: return "Tuần này";
    case DateFilter.thisMonth: return "Tháng này";
    case DateFilter.thisQuarter: return "Quý của năm nay";
    case DateFilter.thisYear: return "Năm nay";
  }
}

String _getTopProductsFilterText(TopProductsFilter filter) {
  switch (filter) {
    case TopProductsFilter.sales: return "Theo doanh số";
    case TopProductsFilter.revenue: return "Theo doanh thu";
    case TopProductsFilter.quantity: return "Theo số lượng";
  }
}

// Helper cho item kết quả bán hàng
Widget _buildResultItem(IconData icon, Color color, String count, String label, String amount) {
  return Column(
    children: [
      CircleAvatar(
        radius: 25,
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color, size: 28),
      ),
      const SizedBox(height: 8),
      Text(count, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      Text(label, style: const TextStyle(color: Colors.grey)),
    ],
  );
}

// Helper cho header chung
Widget _buildSectionHeader(String title, DateFilter selectedFilter, Function(DateFilter) onFilterChanged) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      PopupMenuButton<DateFilter>(
        initialValue: selectedFilter,
        onSelected: onFilterChanged,
        child: Row(
          children: [
            Text(_getDateFilterText(selectedFilter), style: const TextStyle(color: Colors.blue)),
            const Icon(Icons.arrow_drop_down, color: Colors.blue),
          ],
        ),
        itemBuilder: (context) => DateFilter.values.map((filter) => PopupMenuItem(
          value: filter,
          child: Text(_getDateFilterText(filter)),
        )).toList(),
      ),
    ],
  );
}

// Helper cho header của Top Products
Widget _buildTopProductHeader(
    String title,
    DateFilter selectedDateFilter,
    TopProductsFilter selectedProductFilter,
    Function(DateFilter) onDateFilterChanged,
    Function(TopProductsFilter) onProductFilterChanged,
    ) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      Row(
        children: [
          PopupMenuButton<TopProductsFilter>(
            initialValue: selectedProductFilter,
            onSelected: onProductFilterChanged,
            tooltip: "Lọc theo",
            child: const Icon(Icons.filter_list, color: Colors.blue),
            itemBuilder: (context) => TopProductsFilter.values.map((filter) => PopupMenuItem(
              value: filter,
              child: Text(_getTopProductsFilterText(filter)),
            )).toList(),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<DateFilter>(
            initialValue: selectedDateFilter,
            onSelected: onDateFilterChanged,
            child: Row(
              children: [
                Text(_getDateFilterText(selectedDateFilter), style: const TextStyle(color: Colors.blue)),
                const Icon(Icons.arrow_drop_down, color: Colors.blue),
              ],
            ),
            itemBuilder: (context) => DateFilter.values.map((filter) => PopupMenuItem(
              value: filter,
              child: Text(_getDateFilterText(filter)),
            )).toList(),
          ),
        ],
      ),
    ],
  );
}