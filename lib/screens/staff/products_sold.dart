import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:ban_hang/services/staff_services/products_sold_services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductsSoldScreen extends StatefulWidget {
  const ProductsSoldScreen({super.key});

  @override
  State<ProductsSoldScreen> createState() => _ProductsSoldScreenState();
}

class _ProductsSoldScreenState extends State<ProductsSoldScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  List<Map<String, dynamic>> _soldList = [];
  List<Map<String, dynamic>> _summary = [];
  bool _loading = false;

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chọn ngày';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _fetchData() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy chọn ngày bắt đầu & kết thúc')),
      );
      return;
    }

    setState(() => _loading = true);

    _soldList = await ProductsSoldServices.getProductsSold(
      startDate: _startDate,
      endDate: _endDate,
    );

    _summary = _groupByDay(_soldList);

    setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _groupByDay(List<Map<String, dynamic>> list) {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (var sold in list) {
      final DateTime deliveryTime = (sold['delivery_end_time'] as Timestamp).toDate();
      String key = DateFormat('yyyy-MM-dd').format(deliveryTime);

      if (!grouped.containsKey(key)) {
        grouped[key] = {
          'key': key,
          'quantity': 0,
          'total': 0.0,
        };
      }

      grouped[key]!['quantity'] += sold['quantity'] as int;
      grouped[key]!['total'] += sold['total'] as num;
    }

    final sorted = grouped.values.toList();
    sorted.sort((a, b) => a['key'].compareTo(b['key']));
    return sorted;
  }

  Widget _buildQuantityLineChart() {
    if (_summary.isEmpty) {
      return const Center(child: Text('Không có dữ liệu'));
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < _summary.length; i++) {
      spots.add(FlSpot(i.toDouble(), (_summary[i]['quantity'] as int).toDouble()));
    }

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            dotData: FlDotData(show: true),
            barWidth: 2,
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _summary.length) {
                  return Text(_summary[index]['key'], style: const TextStyle(fontSize: 10));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueLineChart() {
    if (_summary.isEmpty) {
      return const Center(child: Text('Không có dữ liệu'));
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < _summary.length; i++) {
      spots.add(FlSpot(i.toDouble(), (_summary[i]['total'] as num).toDouble()));
    }

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.orange,
            dotData: FlDotData(show: true),
            barWidth: 2,
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _summary.length) {
                  return Text(_summary[index]['key'], style: const TextStyle(fontSize: 10));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportExcel() async {
    if (_summary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có dữ liệu để xuất!')),
      );
      return;
    }

    final path = await ProductsSoldServices.exportToExcelLineChart(
      summarized: _summary,
      startDate: _startDate,
      endDate: _endDate,
    );

    await Share.shareXFiles([XFile(path)], text: 'Biểu đồ thống kê');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Đã chia sẻ file Excel!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biểu đồ đường: Số lượng & Doanh thu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportExcel,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickStartDate,
                    icon: const Icon(Icons.date_range),
                    label: Text('Bắt đầu: ${_formatDate(_startDate)}'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickEndDate,
                    icon: const Icon(Icons.date_range),
                    label: Text('Kết thúc: ${_formatDate(_endDate)}'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _fetchData,
                    icon: const Icon(Icons.search),
                    label: const Text('Lọc'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('🔵 Số lượng', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              SizedBox(height: 300, child: _buildQuantityLineChart()),
              const SizedBox(height: 16),
              const Text('🟠 Doanh thu', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              SizedBox(height: 300, child: _buildRevenueLineChart()),
            ],
          ),
        ),
      ),

    );
  }
}
