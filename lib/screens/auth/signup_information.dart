import 'package:ban_hang/screens/customer/verify_phone_number.dart';
import 'package:ban_hang/services/auth_services/auth_service.dart';
import 'package:ban_hang/services/utilities/utilities_address.dart';
import 'package:ban_hang/utils/message.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:vietnam_provinces/vietnam_provinces.dart';

class SignUpInformationScreen extends StatefulWidget {
  final bool redirectToOrder;
  final Map<String, dynamic>? initialData;

  const SignUpInformationScreen({
    super.key,
    this.redirectToOrder = false,
    this.initialData,
  });

  @override
  State<SignUpInformationScreen> createState() =>
      _SignUpInformationScreenState();
}

class _SignUpInformationScreenState extends State<SignUpInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final detailAddressController = TextEditingController();

  List<String> provinces = [];
  List<String> districts = [];
  List<String> wards = [];

  String? selectedProvince;
  String? selectedDistrict;
  String? selectedWard;
  String? selectedGender;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Lấy danh sách tỉnh trực tiếp từ AddressUtils
    provinces = AddressUtils.getProvinces();
    if (widget.initialData != null) {
      nameController.text = widget.initialData?['name'] ?? '';
    }
  }

  void _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedProvince == null ||
        selectedDistrict == null ||
        selectedWard == null ||
        selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
      );
      return;
    }

    final verifiedPhone = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VerifyPhoneNumberScreen()),
    );

    if (verifiedPhone == null) return;
    final avatarUrl = widget.initialData?['avatarUrl'] ?? '';
    final email = widget.initialData?['email'] ?? FirebaseAuth.instance.currentUser?.email;

    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy email')),
      );
      return;
    }

    setState(() => isLoading = true);

    // Sử dụng các biến String trực tiếp, không cần .name
    final errorMessage = await AuthService().completeFacebookSignup(
      name: nameController.text.trim(),
      email: email,
      phone: message.formatVNPhone(verifiedPhone),
      province: selectedProvince!,
      district: selectedDistrict!,
      ward: selectedWard!,
      gender: selectedGender!,
      detailAddress: detailAddressController.text.trim(),
      avatarUrl: avatarUrl,
    );

    setState(() => isLoading = false);

    if (errorMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng ký thành công')),
      );
      if (mounted) {
        await AuthService().navigateUserByRole(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $errorMessage')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Thông tin tài khoản")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: nameController,
                  validator: RequiredValidator(errorText: 'Không được để trống'),
                  decoration: const InputDecoration(
                    labelText: 'Họ tên',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Giới tính:'),
                    const SizedBox(width: 16),
                    Radio<String>(
                      value: 'Nam',
                      groupValue: selectedGender,
                      onChanged: (value) => setState(() => selectedGender = value),
                    ),
                    const Text('Nam'),
                    const SizedBox(width: 16),
                    Radio<String>(
                      value: 'Nữ',
                      groupValue: selectedGender,
                      onChanged: (value) => setState(() => selectedGender = value),
                    ),
                    const Text('Nữ'),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownSearch<String>(
                  popupProps: const PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(decoration: InputDecoration(labelText: "Tìm kiếm tỉnh/thành"))
                  ),
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
                  validator: (value) => value == null ? 'Vui lòng chọn tỉnh/thành' : null,
                ),
                const SizedBox(height: 16),

                // Quận/Huyện
                DropdownSearch<String>(
                  popupProps: const PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(decoration: InputDecoration(labelText: "Tìm kiếm quận/huyện"))
                  ),
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
                  popupProps: const PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(decoration: InputDecoration(labelText: "Tìm kiếm phường/xã"))
                  ),
                  items: wards,
                  selectedItem: selectedWard,
                  enabled: selectedDistrict != null,
                  itemAsString: (item) => item?.split('-').first ?? '', // Chỉ hiển thị tên
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
                TextFormField(
                  controller: detailAddressController,
                  validator: RequiredValidator(errorText: 'Không được để trống'),
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ chi tiết (số nhà, tên đường...)',
                    prefixIcon: Icon(Icons.home),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : _handleSignUp,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Xác nhận'),
                ),
              ],
            ),
          ),
        ),
      ), 
    );
  }
}
