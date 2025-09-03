import 'dart:io';
import 'package:ban_hang/services/owner_services/add_customer_for_order_services.dart';
import 'package:ban_hang/services/utilities/utilities_address.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';

class AddCustomerForOrderScreen extends StatefulWidget {
  const AddCustomerForOrderScreen({super.key});

  @override
  State<AddCustomerForOrderScreen> createState() => _AddCustomerForOrderScreenState();
}

class _AddCustomerForOrderScreenState extends State<AddCustomerForOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _facebookController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressDetailController = TextEditingController();

  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedWard;
  File? _avatarFile;
  bool _isLoading = false;
  @override
  void initState() {
    super.initState();
    AddressUtils.loadAddressJson();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _avatarFile = File(picked.path);
      });
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProvince == null || _selectedDistrict == null || _selectedWard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng chọn đủ địa chỉ")),
      );
      return;
    }

    setState(() {
      _isLoading = true; // Bật loading
    });

    try {
      final fullAddress = AddressUtils.buildFullAddress(
        addressDetail: _addressDetailController.text.trim(),
        ward: _selectedWard!,
        district: _selectedDistrict!,
        province: _selectedProvince!,
      );

      final shopId = FirebaseAuth.instance.currentUser?.uid ?? "";

      final data = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'facebook': _facebookController.text.trim(),
        'email': _emailController.text.trim(),
        'address': fullAddress,
        'shopid': shopId,
        'status': "Bình thường"
      };

      await AddCustomerForOrderServices().addCustomer(data, avatarFile: _avatarFile);

      if (mounted) {
        Navigator.pop(context, true); // trả về true để refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi khi lưu: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Tắt loading
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Thêm khách hàng")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _avatarFile != null ? FileImage(_avatarFile!) : null,
                      child: _avatarFile == null ? const Icon(Icons.person, size: 50) : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickAvatar,
                        child: const CircleAvatar(
                          radius: 18,
                          child: Icon(Icons.add),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Tên"),
                validator: (v) => v == null || v.isEmpty ? "Nhập tên" : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                keyboardType: TextInputType.number, // mở bàn phím số
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // chỉ cho nhập số
                ],
                controller: _phoneController,
                decoration: const InputDecoration(labelText: "Điện thoại"),
                validator: (v) => v == null || v.isEmpty ? "Nhập số điện thoại" : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _facebookController,
                decoration: const InputDecoration(labelText: "Facebook"),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email"),
              ),
              const SizedBox(height: 20),

              const Text("Địa chỉ"),
              const SizedBox(height: 8),

              // Province
              DropdownSearch<String>(
                selectedItem: _selectedProvince,
                popupProps: const PopupProps.menu(showSearchBox: true),
                items: AddressUtils.getProvinces(),
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(labelText: "Chọn Tỉnh/Thành phố"),
                ),
                onChanged: (v) {
                  setState(() {
                    _selectedProvince = v;
                    _selectedDistrict = null;
                    _selectedWard = null;
                  });
                },
              ),
              const SizedBox(height: 10),

              if (_selectedProvince != null)
                DropdownSearch<String>(
                  selectedItem: _selectedDistrict,
                  popupProps: const PopupProps.menu(showSearchBox: true),
                  items: AddressUtils.getDistricts(_selectedProvince!),
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(labelText: "Chọn Quận/Huyện"),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _selectedDistrict = v;
                      _selectedWard = null;
                    });
                  },
                ),
              const SizedBox(height: 10),

              if (_selectedProvince != null && _selectedDistrict != null)
                DropdownSearch<String>(
                  selectedItem: _selectedWard,
                  popupProps: const PopupProps.menu(showSearchBox: true),
                  items: AddressUtils.getWards(_selectedProvince!, _selectedDistrict!),
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(labelText: "Chọn Xã/Phường"),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _selectedWard = v;
                    });
                  },
                ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _addressDetailController,
                decoration: const InputDecoration(labelText: "Địa chỉ chi tiết"),
                validator: (v) => v == null || v.isEmpty ? "Nhập địa chỉ chi tiết" : null,
              ),
              const SizedBox(height: 30),

              Center(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveCustomer, // disable khi đang loading
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.save),
                      SizedBox(width: 8),
                      Text("Lưu"),
                    ],
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
