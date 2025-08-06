import 'package:ban_hang/screens/customer/verify_phone_number.dart';
import 'package:ban_hang/services/auth_services/auth_service.dart';
import 'package:ban_hang/utils/message.dart';
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

  List<Province> provinces = [];
  List<District> districts = [];
  List<Ward> wards = [];

  Province? selectedProvince;
  District? selectedDistrict;
  Ward? selectedWard;
  String? selectedGender;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    AuthService().initLocations().then((_) {
      provinces = AuthService().getProvinces();
      if (widget.initialData != null) {
        nameController.text = widget.initialData?['name'] ?? '';
      }
      setState(() {});
    });
  }

  void _handleSignUp() async {
    if (!_formKey.currentState!.validate() ||
        selectedProvince == null ||
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
        const SnackBar(content: Text('Không tìm thấy email Google')),
      );
      return;
    }

    setState(() => isLoading = true);

    final errorMessage = await AuthService().completeFacebookSignup(
      name: nameController.text.trim(),
      email: email,
      phone: message.formatVNPhone(verifiedPhone),
      province: selectedProvince!.name,
      district: selectedDistrict!.name,
      ward: selectedWard!.name,
      gender: selectedGender!,
      detailAddress: detailAddressController.text.trim(),
      avatarUrl: avatarUrl,
    );

    setState(() => isLoading = false);

    if (errorMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng ký thành công')),
      );
      await AuthService().navigateUserByRole(context);
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
                DropdownButtonFormField<Province>(
                  value: selectedProvince,
                  items: provinces
                      .map((p) =>
                      DropdownMenuItem(value: p, child: Text(p.name)))
                      .toList(),
                  decoration: const InputDecoration(labelText: 'Tỉnh/Thành phố'),
                  onChanged: (p) {
                    setState(() {
                      selectedProvince = p;
                      selectedDistrict = null;
                      selectedWard = null;
                      districts = AuthService().getDistricts(p!.code);
                      wards = [];
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<District>(
                  value: selectedDistrict,
                  items: districts
                      .map((d) =>
                      DropdownMenuItem(value: d, child: Text(d.name)))
                      .toList(),
                  decoration: const InputDecoration(labelText: 'Quận/Huyện'),
                  onChanged: (d) {
                    setState(() {
                      selectedDistrict = d;
                      selectedWard = null;
                      wards = AuthService()
                          .getWards(selectedProvince!.code, d!.code);
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Ward>(
                  value: selectedWard,
                  items: wards
                      .map((w) =>
                      DropdownMenuItem(value: w, child: Text(w.name)))
                      .toList(),
                  decoration: const InputDecoration(labelText: 'Phường/Xã'),
                  onChanged: (w) => setState(() => selectedWard = w),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: detailAddressController,
                  validator:
                  RequiredValidator(errorText: 'Không được để trống'),
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ chi tiết',
                    prefixIcon: Icon(Icons.home),
                  ),
                ),
                const SizedBox(height: 12),
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
