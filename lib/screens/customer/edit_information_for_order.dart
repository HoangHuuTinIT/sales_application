import 'package:ban_hang/services/utilities/utilities_address.dart';
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart'; // Import package mới
import 'package:ban_hang/services/customer_services/edit_information_for_order_services.dart';

// import 'package:vietnam_provinces/vietnam_provinces.dart'; // Xóa import cũ

class EditInformationForOrderScreen extends StatefulWidget {
  const EditInformationForOrderScreen({Key? key}) : super(key: key);

  @override
  State<EditInformationForOrderScreen> createState() =>
      _EditInformationForOrderScreenState();
}

class _EditInformationForOrderScreenState
    extends State<EditInformationForOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _detailAddressController = TextEditingController();

  // --- Thay đổi kiểu dữ liệu State Variables ---
  String? selectedProvince;
  String? selectedDistrict;
  String? selectedWard;

  List<String> provinces = [];
  List<String> districts = [];
  List<String> wards = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Lấy danh sách tỉnh từ AddressUtils
    provinces = AddressUtils.getProvinces();
    _loadData();
  }

  Future<void> _loadData() async {
    final userData = await EditInformationForOrderService().fetchUserData();

    if (userData != null) {
      _nameController.text = userData['name'] ?? '';
      _phoneController.text = userData['phone'] ?? '';

      if (userData['address'] != null) {
        // Sử dụng helper từ AddressUtils để phân tích địa chỉ
        final parsedAddress = AddressUtils.parseFullAddress(userData['address']);

        if (parsedAddress.isNotEmpty) {
          _detailAddressController.text = parsedAddress['addressDetail'] ?? '';
          selectedProvince = parsedAddress['province'];

          if (selectedProvince != null) {
            districts = AddressUtils.getDistricts(selectedProvince!);
            selectedDistrict = parsedAddress['district'];
          }

          if (selectedProvince != null && selectedDistrict != null) {
            wards = AddressUtils.getWards(selectedProvince!, selectedDistrict!);
            // Vì địa chỉ lưu tên phường, cần tìm lại item đầy đủ (có mã) trong list wards
            selectedWard = AddressUtils.findWardByName(
              province: selectedProvince!,
              district: selectedDistrict!,
              wardName: parsedAddress['ward'] ?? '',
            );
          }
        }
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Sử dụng helper từ AddressUtils để tạo chuỗi địa chỉ hoàn chỉnh
    final address = AddressUtils.buildFullAddress(
      addressDetail: _detailAddressController.text.trim(),
      ward: selectedWard ?? '',
      district: selectedDistrict ?? '',
      province: selectedProvince ?? '',
    );

    await EditInformationForOrderService().updateUserData(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: address,
    );

    // Hiển thị thông báo thành công (tùy chọn)
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật thông tin thành công!')),
      );
      Navigator.pop(context); // Quay lại màn trước
    }
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
                decoration: const InputDecoration(labelText: 'Họ và tên', border: OutlineInputBorder()),
                validator: (value) =>
                value!.isEmpty ? 'Vui lòng nhập tên' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Số điện thoại', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                value!.isEmpty ? 'Vui lòng nhập SĐT' : null,
              ),
              const SizedBox(height: 16),

              // --- Thay thế bằng DropdownSearch ---

              // Tỉnh/Thành phố
              DropdownSearch<String>(
                popupProps: const PopupProps.menu(showSearchBox: true, searchFieldProps: TextFieldProps(decoration: InputDecoration(labelText: "Tìm kiếm"))),
                items: provinces,
                selectedItem: selectedProvince,
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: "Tỉnh/Thành phố",
                    border: OutlineInputBorder(),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    selectedProvince = value;
                    selectedDistrict = null;
                    selectedWard = null;
                    districts = value != null ? AddressUtils.getDistricts(value) : [];
                    wards = [];
                  });
                },
                validator: (value) => value == null ? 'Vui lòng chọn tỉnh/thành phố' : null,
              ),
              const SizedBox(height: 16),

              // Quận/Huyện
              DropdownSearch<String>(
                popupProps: const PopupProps.menu(showSearchBox: true, searchFieldProps: TextFieldProps(decoration: InputDecoration(labelText: "Tìm kiếm"))),
                items: districts,
                selectedItem: selectedDistrict,
                enabled: selectedProvince != null,
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: "Quận/Huyện",
                    border: OutlineInputBorder(),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    selectedDistrict = value;
                    selectedWard = null;
                    wards = (selectedProvince != null && value != null)
                        ? AddressUtils.getWards(selectedProvince!, value)
                        : [];
                  });
                },
                validator: (value) => value == null ? 'Vui lòng chọn quận/huyện' : null,
              ),
              const SizedBox(height: 16),

              // Phường/Xã
              DropdownSearch<String>(
                popupProps: const PopupProps.menu(showSearchBox: true, searchFieldProps: TextFieldProps(decoration: InputDecoration(labelText: "Tìm kiếm"))),
                items: wards,
                selectedItem: selectedWard,
                enabled: selectedDistrict != null,
                itemAsString: (item) => item?.split('-').first ?? '', // Chỉ hiển thị tên phường/xã
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: "Phường/Xã",
                    border: OutlineInputBorder(),
                  ),
                ),
                onChanged: (value) {
                  setState(() => selectedWard = value);
                },
                validator: (value) => value == null ? 'Vui lòng chọn phường/xã' : null,
              ),
              const SizedBox(height: 16),

              // Địa chỉ chi tiết
              TextFormField(
                controller: _detailAddressController,
                decoration: const InputDecoration(labelText: 'Địa chỉ chi tiết (số nhà, tên đường...)', border: OutlineInputBorder()),
                validator: (value) =>
                value!.isEmpty ? 'Vui lòng nhập địa chỉ chi tiết' : null,
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
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