import 'package:ban_hang/services/staff_services/shipping_company_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vietnam_provinces/vietnam_provinces.dart';

import 'package:ban_hang/services/auth_services/auth_service.dart';

class ShippingCompanySettingsScreen extends StatefulWidget {
  const ShippingCompanySettingsScreen({super.key});

  @override
  State<ShippingCompanySettingsScreen> createState() => _ShippingCompanySettingsScreenState();
}

class _ShippingCompanySettingsScreenState extends State<ShippingCompanySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _senderNameController = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _defaultFeeController = TextEditingController();
  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _insuranceValueController = TextEditingController();
  final _manualInsuranceController = TextEditingController();
  final _detailAddressController = TextEditingController();
  bool _showConfigForm = true;
  bool _showDefaultValueForm = true;
  bool _isActive = true;
  bool _isDefaultTemplate = false;
  bool _applySenderAddress = false;

  String? _selectedService;
  String? _selectedPackageType;
  String? _selectedPaymentMethod;
  List<String> _shippingNotes = [];
  String? _selectedPostOffice;

  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedWard;
  int? _selectedProvinceCode;

  List<Province> _provinces = [];
  List<District> _districts = [];
  List<Ward> _wards = [];

  bool _isSaving = false;

  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initLocationData();
  }

  Future<void> _initLocationData() async {
    await _authService.initLocations();
    setState(() {
      _provinces = _authService.getProvinces();
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    await ShippingCompanyService.saveViettelPostSettings(
      formKey: _formKey,
      context: context,
      controllers: {
        'senderName': _senderNameController,
        'senderPhone': _senderPhoneController,
        'account': _accountController,
        'password': _passwordController,
        'defaultFee': _defaultFeeController,
        'defaultWeight': _weightController,
        'length': _lengthController,
        'width': _widthController,
        'height': _heightController,
        'insuranceTotalValue': _insuranceValueController,
        'manualInsuranceValue': _manualInsuranceController,
        'detailAddress': _detailAddressController,
      },
      dropdownValues: {
        'service': _selectedService,
        'packageType': _selectedPackageType,
        'paymentMethod': _selectedPaymentMethod,
        'shippingNotes': _shippingNotes,
        'postOffice': _selectedPostOffice,
        'province': _selectedProvince,
        'district': _selectedDistrict,
        'ward': _selectedWard,
      },
      switches: {
        'isActive': _isActive,
        'isDefaultTemplate': _isDefaultTemplate,
        'applySenderAddress': _applySenderAddress,
      },
    );

    setState(() => _isSaving = false);
  }


  Widget _buildAddressForm() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Áp dụng địa chỉ người gửi'),
          value: _applySenderAddress,
          onChanged: (val) => setState(() => _applySenderAddress = val ?? false),
        ),
        if (_applySenderAddress) ...[
          TextFormField(
            controller: _detailAddressController,
            decoration: const InputDecoration(labelText: 'Địa chỉ chi tiết'),
          ),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Tỉnh/Thành phố'),
            value: _selectedProvince,
            items: _provinces.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name))).toList(),
            onChanged: (val) {
              final selected = _provinces.firstWhere((p) => p.name == val);
              setState(() {
                _selectedProvince = val;
                _selectedProvinceCode = selected.code;
                _districts = _authService.getDistricts(selected.code);
                _selectedDistrict = null;
                _wards = [];
              });
            },
          ),
          if (_districts.isNotEmpty)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Quận/Huyện'),
              value: _selectedDistrict,
              items: _districts.map((d) => DropdownMenuItem(value: d.name, child: Text(d.name))).toList(),
              onChanged: (val) {
                final selected = _districts.firstWhere((d) => d.name == val);
                setState(() {
                  _selectedDistrict = val;
                  _wards = _authService.getWards(_selectedProvinceCode!, selected.code);
                  _selectedWard = null;
                });
              },
            ),
          if (_wards.isNotEmpty)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Phường/Xã'),
              value: _selectedWard,
              items: _wards.map((w) => DropdownMenuItem(value: w.name, child: Text(w.name))).toList(),
              onChanged: (val) => setState(() => _selectedWard = val),
            ),
        ]
      ],
    );
  }
  Widget _buildConfigurationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(controller: _senderNameController, decoration: const InputDecoration(labelText: 'Tên người gửi')),
        TextFormField(controller: _senderPhoneController, decoration: const InputDecoration(labelText: 'SĐT người gửi')),
        TextFormField(
          controller: _accountController,
          decoration: const InputDecoration(labelText: 'Tên tài khoản *'),
          validator: (val) => val!.isEmpty ? 'Bắt buộc' : null,
        ),
        TextFormField(
          controller: _passwordController,
          decoration: const InputDecoration(labelText: 'Mật khẩu *'),
          validator: (val) => val!.isEmpty ? 'Bắt buộc' : null,
        ),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Dịch vụ'),
          value: _selectedService,
          items: ['VCN', 'VHT', 'VEXP'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (val) => setState(() => _selectedService = val),
        ),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Loại hàng hóa *'),
          value: _selectedPackageType,
          items: ['Tài liệu', 'Bưu kiện'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (val) => setState(() => _selectedPackageType = val),
          validator: (val) => val == null ? 'Bắt buộc' : null,
        ),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Phương thức thanh toán *'),
          value: _selectedPaymentMethod,
          items: [
            'Không thu tiền',
            'Thu hộ tiền hàng',
            'Thu hộ tiền cước',
            'Thu hộ tiền cước và tiền hàng'
          ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (val) => setState(() => _selectedPaymentMethod = val),
          validator: (val) => val == null ? 'Bắt buộc' : null,
        ),
        InputDecorator(
          decoration: const InputDecoration(labelText: 'Lưu ý giao hàng'),
          child: Column(
            children: [
              CheckboxListTile(
                title: const Text('Giá trị cao'),
                value: _shippingNotes.contains('Giá trị cao'),
                onChanged: (val) => setState(() => val!
                    ? _shippingNotes.add('Giá trị cao')
                    : _shippingNotes.remove('Giá trị cao')),
              ),
              CheckboxListTile(
                title: const Text('Dễ vỡ'),
                value: _shippingNotes.contains('Dễ vỡ'),
                onChanged: (val) => setState(() => val!
                    ? _shippingNotes.add('Dễ vỡ')
                    : _shippingNotes.remove('Dễ vỡ')),
              ),
              CheckboxListTile(
                title: const Text('Nguyên khối'),
                value: _shippingNotes.contains('Nguyên khối'),
                onChanged: (val) => setState(() => val!
                    ? _shippingNotes.add('Nguyên khối')
                    : _shippingNotes.remove('Nguyên khối')),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildDefaultValueForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(controller: _defaultFeeController, decoration: const InputDecoration(labelText: 'Phí ship mặc định')),
        TextFormField(controller: _weightController, decoration: const InputDecoration(labelText: 'Khối lượng mặc định (g)')),
        TextFormField(controller: _lengthController, decoration: const InputDecoration(labelText: 'Chiều dài (cm)')),
        TextFormField(controller: _widthController, decoration: const InputDecoration(labelText: 'Chiều rộng (cm)')),
        TextFormField(controller: _heightController, decoration: const InputDecoration(labelText: 'Chiều cao (cm)')),
        TextFormField(controller: _insuranceValueController, decoration: const InputDecoration(labelText: 'Giá trị bảo hiểm bằng tổng tiền')),
        TextFormField(controller: _manualInsuranceController, decoration: const InputDecoration(labelText: 'Giá trị bảo hiểm mặc định')),
        const SizedBox(height: 10),
        _buildAddressForm(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cài đặt Viettel Post'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Cấu hình'),
              Tab(text: 'Giá trị mặc định'),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('Hiệu lực'),
                        value: _isActive,
                        onChanged: (val) => setState(() => _isActive = val ?? false),
                      ),
                    ),
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('Mẫu in mặc định'),
                        value: _isDefaultTemplate,
                        onChanged: (val) => setState(() => _isDefaultTemplate = val ?? false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(child: _buildConfigurationForm()),
                      SingleChildScrollView(child: _buildDefaultValueForm()),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveSettings,
                    child: _isSaving
                        ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                        : const Text('Lưu cấu hình'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



}
