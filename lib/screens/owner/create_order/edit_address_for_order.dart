import 'package:ban_hang/services/auth_services/auth_service.dart';
import 'package:ban_hang/services/owner_services/customer_order_service.dart';
import 'package:flutter/material.dart';
import 'package:vietnam_provinces/vietnam_provinces.dart';


class EditAddressForOrderScreen extends StatefulWidget {
  final Map<String, dynamic> initialData;
  const EditAddressForOrderScreen({super.key, required this.initialData});

  @override
  State<EditAddressForOrderScreen> createState() => _EditAddressForOrderScreenState();
}

class _EditAddressForOrderScreenState extends State<EditAddressForOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _detailAddressController;

  Province? _selectedProvince;
  District? _selectedDistrict;
  Ward? _selectedWard;

  late List<Province> _provinces;
  List<District> _districts = [];
  List<Ward> _wards = [];

  final _orderService = CustomerOrderServiceLive();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData['name']);
    _phoneController = TextEditingController(text: widget.initialData['phone']);

    String fullAddress = widget.initialData['address'] ?? '';

    _orderService.initLocationData().then((provinces) {
      setState(() {
        _provinces = provinces;
        final parsed = _orderService.parseAddressParts(fullAddress, provinces);

        _detailAddressController = TextEditingController(
          text: parsed['detailAddress'],
        );
        _selectedProvince = parsed['province'];
        _districts = parsed['districts'];
        _selectedDistrict = parsed['district'];
        _wards = parsed['wards'];
        _selectedWard = parsed['ward'];
      });
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sửa địa chỉ giao hàng')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

              // Province Dropdown
              DropdownButtonFormField<Province>(
                value: _selectedProvince,
                decoration: const InputDecoration(labelText: 'Tỉnh/Thành phố'),
                items: _provinces
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: (province) {
                  setState(() {
                    _selectedProvince = province;
                    _selectedDistrict = null;
                    _selectedWard = null;
                    _districts = province != null
                        ? _authService.getDistricts(province.code)
                        : [];
                    _wards = [];
                  });
                },
                validator: (v) => v == null ? 'Chọn tỉnh/thành phố' : null,
              ),
              const SizedBox(height: 8),

              // District Dropdown
              if (_districts.isNotEmpty)
                DropdownButtonFormField<District>(
                  value: _selectedDistrict,
                  decoration: const InputDecoration(labelText: 'Quận/Huyện'),
                  items: _districts
                      .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                      .toList(),
                  onChanged: (district) {
                    setState(() {
                      _selectedDistrict = district;
                      _selectedWard = null;
                      _wards = district != null
                          ? _authService.getWards(
                          _selectedProvince!.code, district.code)
                          : [];
                    });
                  },
                  validator: (v) => v == null ? 'Chọn quận/huyện' : null,
                ),
              const SizedBox(height: 8),

              // Ward Dropdown
              if (_wards.isNotEmpty)
                DropdownButtonFormField<Ward>(
                  value: _selectedWard,
                  decoration: const InputDecoration(labelText: 'Xã/Phường'),
                  items: _wards
                      .map((w) => DropdownMenuItem(value: w, child: Text(w.name)))
                      .toList(),
                  onChanged: (ward) {
                    setState(() {
                      _selectedWard = ward;
                    });
                  },
                  validator: (v) => v == null ? 'Chọn xã/phường' : null,
                ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _detailAddressController,
                decoration: const InputDecoration(labelText: 'Địa chỉ chi tiết'),
                validator: (v) => v == null || v.isEmpty ? 'Nhập địa chỉ' : null,
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final fullAddress =
                        '${_detailAddressController.text} - ${_selectedWard?.name ?? ''} - ${_selectedDistrict?.name ?? ''} - ${_selectedProvince?.name ?? ''}';
                    Navigator.pop(context, {
                      'name': _nameController.text,
                      'phone': _phoneController.text,
                      'address': fullAddress,
                    });
                  }
                },
                child: const Text('Lưu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
