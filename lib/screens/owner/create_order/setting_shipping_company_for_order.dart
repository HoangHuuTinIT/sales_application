import 'package:flutter/material.dart';
import 'chose_shipping_company_for_order.dart';

class SettingShippingCompanyForOrderScreen extends StatefulWidget {
  final double totalPrice; // nhận từ CreateOrderForCustomerScreen
  final double totalWeight;
  final Map<String, dynamic>? initialData;
  const SettingShippingCompanyForOrderScreen({super.key, required this.totalPrice, required this.totalWeight, this.initialData});

  @override
  State<SettingShippingCompanyForOrderScreen> createState() => _SettingShippingCompanyForOrderScreenState();
}

class _SettingShippingCompanyForOrderScreenState extends State<SettingShippingCompanyForOrderScreen> {
  String? selectedPartner;
  double weight = 0;
  double shippingFee = 0;
  double prePaid = 0;
  double codAmount = 0;
  String note = '';

  Map<String, dynamic>? partnerInfo;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      selectedPartner = data['partnerName'];
      codAmount = data['codAmount'] ?? 0;
      note = data['note'] ?? '';
      partnerInfo = data['partnerInfo'];
      weight = data['weight'] ?? widget.totalWeight;
      shippingFee = data['shippingFee'] ?? 0;   // 👈 thêm nếu bạn có phí ship
      prePaid = data['prePaid'] ?? 0;           // 👈 thêm nếu bạn có trả trước
    } else {
      weight = widget.totalWeight;
    }
    _calculateCOD();
  }

  void _calculateCOD() {
    setState(() {
      codAmount = widget.totalPrice + shippingFee - prePaid;
      if (codAmount < 0) codAmount = 0; // không cho âm
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cấu hình đơn vị giao hàng')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Đối tác giao hàng ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Đối tác giao hàng:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () async {
                    final partner = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChoseShippingCompanyForOrderScreen(),
                      ),
                    );
                    if (partner != null) {
                      setState(() {
                        selectedPartner = partner['nameCopany'];
                        partnerInfo = partner;
                      });
                    }
                  },
                  child: Text(
                    selectedPartner ?? 'Chạm để chọn',
                    style: const TextStyle(fontSize: 16, color: Colors.blue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- Nhập khối lượng ---
            TextFormField(
              initialValue: weight.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Khối lượng (kg)', border: OutlineInputBorder()),
              onChanged: (v) => setState(() => weight = double.tryParse(v) ?? 0),
            ),
            const SizedBox(height: 16),

            // --- Phí vận chuyển ---
            TextFormField(
              initialValue: shippingFee.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Phí vận chuyển', border: OutlineInputBorder()),
              onChanged: (v) {
                shippingFee = double.tryParse(v) ?? 0;
                _calculateCOD();
              },
            ),
            const SizedBox(height: 16),

            // --- Trả trước ---
            TextFormField(
              initialValue: prePaid.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Trả trước', border: OutlineInputBorder()),
              onChanged: (v) {
                prePaid = double.tryParse(v) ?? 0;
                _calculateCOD();
              },
            ),
            const SizedBox(height: 16),

            // --- Tiền thu hộ ---
            Text(
              'Tiền thu hộ: ${codAmount.toStringAsFixed(0)} đ',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 16),

            // --- Ghi chú giao hàng ---
            TextFormField(
              initialValue: note,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Ghi chú giao hàng',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => note = v,
            ),
            const SizedBox(height: 20),
            Container(
              alignment: Alignment.center,
              child: ElevatedButton(
                onPressed: () {
                  if (selectedPartner == null || selectedPartner!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng chọn đối tác giao hàng trước khi xác nhận.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'partnerName': selectedPartner,
                    'codAmount': codAmount,
                    'note': note,
                    'partnerInfo': partnerInfo,
                    'weight': weight,
                  });
                },
                child: const Text("Xác nhận"),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
