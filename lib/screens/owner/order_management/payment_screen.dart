// lib/screens/owner/order_management/payment_screen.dart
import 'package:ban_hang/services/owner_services/order_created_services.dart';
import 'package:ban_hang/utils/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// Enum để quản lý các lựa chọn thanh toán, đặt ở đây vì nó thuộc về UI
enum PaymentOption { full, partial }

// Lớp định dạng tiền tệ, đặt ở đây vì nó thuộc về UI
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (newText.isEmpty) {
      return const TextEditingValue();
    }
    double value = double.parse(newText);
    final formatter = NumberFormat.decimalPattern('vi_VN');
    String formattedText = formatter.format(value);
    return newValue.copyWith(
        text: formattedText,
        selection: TextSelection.collapsed(offset: formattedText.length));
  }
}

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const PaymentScreen({super.key, required this.order});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // Tạo instance của service để gọi hàm xử lý
  final OrderCreatedServices _services = OrderCreatedServices();

  PaymentOption _selectedOption = PaymentOption.full;
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedOption == PaymentOption.partial) {
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }

    setState(() { _isLoading = true; });

    final reason = _reasonController.text;
    double? partialAmount;

    if (_selectedOption == PaymentOption.partial) {
      final amountString = _amountController.text.replaceAll('.', '');
      partialAmount = double.tryParse(amountString);
    }

    // Gọi hàm xử lý từ service
    await _services.processAndSavePayment(
      context: context,
      order: widget.order,
      paymentOption: _selectedOption,
      partialAmount: partialAmount,
      reason: reason,
    );

    setState(() { _isLoading = false; });

    // Quay lại màn hình danh sách đơn hàng sau khi xử lý xong
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Xác nhận thanh toán"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Mã đơn hàng:", style: Theme.of(context).textTheme.titleMedium),
              Text(widget.order['txlogisticId'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text("Tổng tiền:", style: Theme.of(context).textTheme.titleMedium),
              Text(message.formatCurrency(widget.order['totalAmount']) ?? '0',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)),
              const Divider(height: 32),

              RadioListTile<PaymentOption>(
                title: const Text("Đã thanh toán toàn bộ"),
                value: PaymentOption.full,
                groupValue: _selectedOption,
                onChanged: (value) {
                  setState(() { _selectedOption = value!; });
                },
              ),
              RadioListTile<PaymentOption>(
                title: const Text("Thanh toán một phần"),
                value: PaymentOption.partial,
                groupValue: _selectedOption,
                onChanged: (value) {
                  setState(() { _selectedOption = value!; });
                },
              ),

              if (_selectedOption == PaymentOption.partial)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: "Số tiền đã thanh toán",
                          hintText: 'Nhập số tiền',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          CurrencyInputFormatter(),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập số tiền';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _reasonController,
                        decoration: const InputDecoration(
                          labelText: "Lý do (không bắt buộc)",
                          prefixIcon: Icon(Icons.note_alt_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Xác nhận"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}