import 'package:ban_hang/services/owner_services/customer_order_service.dart';
import 'package:flutter/material.dart';
import 'chose_shipping_company_for_order.dart';

class SettingShippingCompanyForOrderScreen extends StatefulWidget {
  final double totalPrice; // nhận từ CreateOrderForCustomerScreen
  final double totalWeight;
  final Map<String, dynamic>? initialData;
  final String? receiverAddress;

  const SettingShippingCompanyForOrderScreen({  super.key,
    required this.totalPrice,
    required this.totalWeight,
    this.initialData,
    this.receiverAddress, });

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
  String goodsType ='';
  String productType ='';
  String area ='';
  String prov ='';
  String city ='';
  String addressrecervei ='';
  String customerCode='';
  String key ='';
  Map<String, dynamic>? partnerInfo;
  double partnerShippingFee=0;
  bool isRecalculating = false;
  bool isWeightChanged = false; // theo dõi thay đổi khối lượng

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
      prePaid = data['prePaid'] ?? 0;// 👈 thêm nếu bạn có trả trước
      partnerShippingFee = data['partnerShippingFee'] ?? 0;
      goodsType = partnerInfo?['goodsType'] ?? '';
      productType = partnerInfo?['productType'] ?? '';
      prov = partnerInfo?['prov']??'';
      area = partnerInfo?['area']??'';
      city = partnerInfo?['city']??'';
      customerCode =partnerInfo?['customerCode']??'';
      key = partnerInfo?['key']??'';
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
    return WillPopScope(
      onWillPop: () async {
        // Khi người dùng nhấn back
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) =>
              AlertDialog(
                title: const Text('Xác nhận'),
                content: const Text(
                    'Bạn có muốn hủy quá trình cấu hình đơn vị giao hàng?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Không')),
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Có')),
                ],
              ),
        );

        if (confirm == true) {
          // ✅ Check phí giao hàng đối tác trước khi thoát
          if (partnerShippingFee == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Hãy tính lại phí ship!"),
                backgroundColor: Colors.red,
              ),
            );
            return false; // không cho pop
          }
          return true; // cho phép pop
        }
        return false; // nếu không confirm
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cấu hình đơn vị giao hàng'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _handleBack();
              if (shouldPop && mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
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
              decoration: const InputDecoration(
                labelText: 'Khối lượng (kg)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                setState(() {
                  weight = double.tryParse(v) ?? 0;
                  isWeightChanged = true; // ✅ có thay đổi khối lượng
                });
              },
            ),

            const SizedBox(height: 16),
            // --- Phí giao hàng của đối tác ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Phí giao hàng của đối tác',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Text(
                    '${partnerShippingFee.toStringAsFixed(0)} đ',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.green),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    if (selectedPartner == null || selectedPartner!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Vui lòng chọn đối tác giao hàng trước khi tính phí."),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setState(() {
                      isRecalculating = true; // ✅ Bật loading
                    });
                    try {
                      if (selectedPartner == "J&T") {
                        if (weight <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Vui lòng nhập khối lượng hợp lệ")),
                          );
                          return;
                        }
                        final feeData = await CustomerOrderServiceLive.checkJTShippingFee(
                          context: context,
                          weight: weight,
                          receiverAddress: widget.receiverAddress,
                          partnerInfo: partnerInfo,
                          codMoney: codAmount,
                          goodsValue: widget.totalPrice,
                        );
                        if (feeData != null) {
                          setState(() {
                            partnerShippingFee = feeData['standardTotalFee'];
                            codAmount = widget.totalPrice + shippingFee - prePaid;
                            isWeightChanged = false; // ✅ đã tính lại → reset flag
                          });
                        }
                      }
                    } finally {
                      setState(() {
                        isRecalculating = false; // ✅ Tắt loading
                      });
                    }
                  },
                  child: isRecalculating
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text("Tính lại"),
                ),


              ],
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

                  // ✅ Nếu chưa tính phí đối tác (partnerShippingFee = 0) thì báo lỗi
                  if (partnerShippingFee == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Vui lòng tính phí giao hàng trước khi xác nhận."),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // ✅ Nếu khối lượng đã thay đổi mà chưa tính lại phí
                  if (isWeightChanged) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Khối lượng đã thay đổi, hãy tính lại phí ship!"),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Nếu ok thì pop về màn hình trước
                  Navigator.pop(context, {
                    'partnerName': selectedPartner,
                    'codAmount': codAmount,
                    'note': note,
                    'partnerInfo': partnerInfo,
                    'weight': weight,
                    'shippingFee': shippingFee,
                    'prePaid': prePaid,
                    'partnerShippingFee': partnerShippingFee,
                  });
                },


                child: const Text("Xác nhận"),
              ),

            ),

          ],
        ),
      ),
    ),
    );
  }
  Future<bool> _handleBack() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text(
            'Bạn có muốn hủy quá trình cấu hình đơn vị giao hàng?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Không')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Có')),
        ],
      ),
    );

    if (confirm == true) {
      // if (partnerShippingFee == 0) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(
      //       content: Text("Hãy tính lại phí ship!"),
      //       backgroundColor: Colors.red,
      //     ),
      //   );
      //   return false;
      // }
      return true;
    }
    return false;
  }
}
