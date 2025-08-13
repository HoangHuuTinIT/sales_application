import 'package:flutter/material.dart';
import 'package:vietnam_provinces/vietnam_provinces.dart';
import 'package:ban_hang/services/customer_services/edit_information_for_order_services.dart';

class EditInformationForOrderScreen extends StatefulWidget {
  const EditInformationForOrderScreen({Key? key}) : super(key: key);

  @override
  State<EditInformationForOrderScreen> createState() => _EditInformationForOrderScreenState();
}

class _EditInformationForOrderScreenState extends State<EditInformationForOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _detailAddressController = TextEditingController();

  Province? selectedProvince;
  District? selectedDistrict;
  Ward? selectedWard;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userData = await EditInformationForOrderService().fetchUserData();

    if (userData != null) {
      _nameController.text = userData['name'] ?? '';
      _phoneController.text = userData['phone'] ?? '';

      if (userData['address'] != null) {
        final parts = userData['address'].split(' - ');
        if (parts.length == 4) {
          _detailAddressController.text = parts[0];

          final wardName = parts[1];
          final districtName = parts[2];
          final provinceName = parts[3];

          // Tìm province
          selectedProvince = VietnamProvinces.getProvinces()
              .firstWhere((p) => p.name == provinceName, orElse: () => VietnamProvinces.getProvinces().first);

          // Tìm district
          final districts = VietnamProvinces.getDistricts(provinceCode: selectedProvince!.code);
          selectedDistrict = districts.firstWhere((d) => d.name == districtName, orElse: () => districts.first);

          // Tìm ward
          final wards = VietnamProvinces.getWards(
            provinceCode: selectedProvince!.code,
            districtCode: selectedDistrict!.code,
          );
          selectedWard = wards.firstWhere((w) => w.name == wardName, orElse: () => wards.first);
        }
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    final address =
        "${_detailAddressController.text} - ${selectedWard?.name} - ${selectedDistrict?.name} - ${selectedProvince?.name}";

    await EditInformationForOrderService().updateUserData(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: address,
    );

    Navigator.pop(context); // Quay lại màn trước
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sửa thông tin nhận hàng')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập tên' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập SĐT' : null,
              ),
              const SizedBox(height: 12),

              // Province dropdown
              DropdownButtonFormField<Province>(
                value: selectedProvince,
                hint: const Text('Chọn tỉnh/thành'),
                items: VietnamProvinces.getProvinces().map((p) {
                  return DropdownMenuItem(value: p, child: Text(p.name));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedProvince = value;
                    selectedDistrict = null;
                    selectedWard = null;
                  });
                },
                validator: (value) => value == null ? 'Chọn tỉnh' : null,
              ),
              const SizedBox(height: 12),

              // District dropdown
              DropdownButtonFormField<District>(
                value: selectedDistrict,
                hint: const Text('Chọn quận/huyện'),
                items: selectedProvince == null
                    ? []
                    : VietnamProvinces.getDistricts(
                  provinceCode: selectedProvince!.code,
                ).map((d) {
                  return DropdownMenuItem(value: d, child: Text(d.name));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedDistrict = value;
                    selectedWard = null;
                  });
                },
                validator: (value) => value == null ? 'Chọn huyện' : null,
              ),
              const SizedBox(height: 12),

              // Ward dropdown
              DropdownButtonFormField<Ward>(
                value: selectedWard,
                hint: const Text('Chọn xã/phường'),
                items: selectedDistrict == null
                    ? []
                    : VietnamProvinces.getWards(
                  provinceCode: selectedProvince!.code,
                  districtCode: selectedDistrict!.code,
                ).map((w) {
                  return DropdownMenuItem(value: w, child: Text(w.name));
                }).toList(),
                onChanged: (value) {
                  setState(() => selectedWard = value);
                },
                validator: (value) => value == null ? 'Chọn xã' : null,
              ),
              const SizedBox(height: 12),

              // Detail address
              TextFormField(
                controller: _detailAddressController,
                decoration: const InputDecoration(labelText: 'Địa chỉ chi tiết'),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập địa chỉ chi tiết' : null,
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _saveData,
                child: const Text('Lưu thay đổi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
