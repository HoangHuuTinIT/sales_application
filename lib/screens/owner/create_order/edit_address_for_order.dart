import 'package:ban_hang/services/utilities/utilities_address.dart';
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';


class EditAddressForOrderScreen extends StatefulWidget {
  final Map<String, dynamic> initialData;
  const EditAddressForOrderScreen({super.key, required this.initialData});

  @override
  State<EditAddressForOrderScreen> createState() => _EditAddressForOrderScreenState();
}

class _EditAddressForOrderScreenState extends State<EditAddressForOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _detailAddressController;

  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedWard;

  @override
  void initState() {
    super.initState();
    // Load JSON
    AddressUtils.loadAddressJson().then((_) {
      setState(() {}); // refresh UI khi có dữ liệu
    });
    _nameController = TextEditingController(text: widget.initialData['name']);
    _phoneController = TextEditingController(text: widget.initialData['phone']);

    final fullAddress = widget.initialData['address'] ?? '';
    final parsed = AddressUtils.parseFullAddress(fullAddress);


    _detailAddressController = TextEditingController(
      text: parsed['addressDetail'] ?? '',
    );
    _selectedProvince = parsed['province'];
    _selectedDistrict = parsed['district'];
    _selectedWard = parsed['ward'];
  }

  @override
  Widget build(BuildContext context) {
    final provinces = AddressUtils.getProvinces();
    final districts = _selectedProvince != null
        ? AddressUtils.getDistricts(_selectedProvince!)
        : <String>[];
    final wards = (_selectedProvince != null && _selectedDistrict != null)
        ? AddressUtils.getWards(_selectedProvince!, _selectedDistrict!)
        : <String>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Sửa địa chỉ giao hàng')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              /// Province
              DropdownSearch<String>(
                items: provinces,
                selectedItem: _selectedProvince,
                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  title: Text('Chọn Tỉnh/Thành phố'),
                ),
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(labelText: 'Tỉnh/Thành phố'),
                ),
                validator: (v) => v == null ? 'Chọn tỉnh/thành phố' : null,
                onChanged: (value) {
                  setState(() {
                    _selectedProvince = value;
                    _selectedDistrict = null;
                    _selectedWard = null;
                  });
                },
              ),
              const SizedBox(height: 8),

              /// District
              DropdownSearch<String>(
                items: districts,
                selectedItem: _selectedDistrict,
                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  title: Text('Chọn Quận/Huyện'),
                ),
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(labelText: 'Quận/Huyện'),
                ),
                validator: (v) => v == null ? 'Chọn quận/huyện' : null,
                onChanged: (value) {
                  setState(() {
                    _selectedDistrict = value;
                    _selectedWard = null;
                  });
                },
                enabled: _selectedProvince != null,
              ),
              const SizedBox(height: 8),

              /// Ward
              DropdownSearch<String>(
                items: wards,
                selectedItem: _selectedWard,
                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  title: Text('Chọn Xã/Phường'),
                ),
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(labelText: 'Xã/Phường'),
                ),
                validator: (v) => v == null ? 'Chọn xã/phường' : null,
                onChanged: (value) {
                  setState(() {
                    _selectedWard = value;
                  });
                },
                enabled: _selectedDistrict != null,
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
                    final fullAddress = AddressUtils.buildFullAddress(
                      addressDetail: _detailAddressController.text,
                      ward: _selectedWard ?? '',
                      district: _selectedDistrict ?? '',
                      province: _selectedProvince ?? '',
                    );

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
