import 'package:ban_hang/screens/customer/verify_phone_number.dart';
import 'package:flutter/material.dart';
import 'package:vietnam_provinces/vietnam_provinces.dart';
import 'package:ban_hang/services/auth_services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

enum SignUpType { owner, customer }

class _SignUpScreenState extends State<SignUpScreen> {
  SignUpType _selectedType = SignUpType.owner;

  // Controller form bán hàng
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _detailAddressController = TextEditingController();

  // Địa chỉ tỉnh, huyện, xã chọn
  Province? _selectedProvince;
  District? _selectedDistrict;
  Ward? _selectedWard;

  @override
  void initState() {
    super.initState();
    AuthService().initLocations(); // Khởi tạo vietnam_provinces
  }

  void _onProvinceChanged(Province? p) {
    setState(() {
      _selectedProvince = p;
      _selectedDistrict = null;
      _selectedWard = null;
    });
  }

  void _onDistrictChanged(District? d) {
    setState(() {
      _selectedDistrict = d;
      _selectedWard = null;
    });
  }

  void _onWardChanged(Ward? w) {
    setState(() {
      _selectedWard = w;
    });
  }

  Future<void> _handleConfirmOwner() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProvince == null || _selectedDistrict == null || _selectedWard == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn đầy đủ địa chỉ')));
      return;
    }

    // Chuẩn bị dữ liệu
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final detailAddress = _detailAddressController.text.trim();

    // Địa chỉ lưu lên Firestore dạng "địa chỉ chi tiết - Xã - Huyện - Tỉnh"
    final address =
        '$detailAddress - ${_selectedWard!.name} - ${_selectedDistrict!.name} - ${_selectedProvince!.name}';

    // Chuyển sang màn VerifyPhoneNumber, đợi xác minh xong mới lưu Firestore
    final phoneNumber = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => const VerifyPhoneNumberScreen(),
      ),
    );

    if (phoneNumber != null) {
      // Lưu thông tin tài khoản bán hàng lên Firestore với role 'owner'
      final result = await AuthService().createOwnerAccount(
        name: name,
        email: email,
        password: password,
        address: address,
        phone: phoneNumber,
      );

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo tài khoản thành công')));
        // Có thể chuyển sang màn hình khác hoặc đóng
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $result')));
      }
    }
  }

  void _handleGoogleSignUp() async {
    await AuthService().signUpWithGoogleAndCheck(context: context);
  }

  void _handleFacebookSignUp() async {
    await AuthService().signUpWithFacebookAndCheck(context);
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tạo tài khoản")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Toggle chọn loại đăng ký
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Bán hàng'),
                  selected: _selectedType == SignUpType.owner,
                  onSelected: (_) {
                    setState(() => _selectedType = SignUpType.owner);
                  },
                ),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: const Text('Khách hàng'),
                  selected: _selectedType == SignUpType.customer,
                  onSelected: (_) {
                    setState(() => _selectedType = SignUpType.customer);
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            Expanded(
              child: _selectedType == SignUpType.owner
                  ? _buildOwnerSignUp()
                  : _buildCustomerSignUp(),
            ),

            // Bỏ 2 nút ở đây
            // Để 2 nút trong _buildCustomerSignUp()
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSignUp() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Nút đăng ký Google và Facebook chỉ hiện ở đây
        ElevatedButton.icon(
          onPressed: _handleGoogleSignUp,
          icon: const Icon(Icons.account_circle),
          label: const Text("Đăng ký bằng Google"),
        ),

        const SizedBox(height: 12),

        ElevatedButton.icon(
          onPressed: _handleFacebookSignUp,
          icon: const Icon(Icons.facebook, color: Colors.white),
          label: const Text("Đăng ký bằng Facebook"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[800],
          ),
        ),
      ],
    );
  }


  Widget _buildOwnerSignUp() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Tên
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Tên'),
              validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập tên' : null,
            ),

            // Email
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Vui lòng nhập email';
                if (!v.contains('@')) return 'Email không hợp lệ';
                return null;
              },
            ),

            // Mật khẩu
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Mật khẩu'),
              obscureText: true,
              validator: (v) => v == null || v.length < 6 ? 'Mật khẩu phải ít nhất 6 ký tự' : null,
            ),

            // Địa chỉ chọn tỉnh
            DropdownButtonFormField<Province>(
              value: _selectedProvince,
              hint: const Text('Chọn Tỉnh/Thành phố'),
              items: AuthService()
                  .getProvinces()
                  .map(
                    (p) => DropdownMenuItem(value: p, child: Text(p.name)),
              )
                  .toList(),
              onChanged: _onProvinceChanged,
              validator: (v) => v == null ? 'Vui lòng chọn tỉnh' : null,
            ),

            // Huyện
            DropdownButtonFormField<District>(
              value: _selectedDistrict,
              hint: const Text('Chọn Huyện/Quận'),
              items: _selectedProvince == null
                  ? []
                  : AuthService()
                  .getDistricts(_selectedProvince!.code)
                  .map(
                    (d) => DropdownMenuItem(value: d, child: Text(d.name)),
              )
                  .toList(),
              onChanged: _onDistrictChanged,
              validator: (v) => v == null ? 'Vui lòng chọn huyện' : null,
            ),

            // Xã
            DropdownButtonFormField<Ward>(
              value: _selectedWard,
              hint: const Text('Chọn Xã/Phường'),
              items: (_selectedProvince == null || _selectedDistrict == null)
                  ? []
                  : AuthService()
                  .getWards(_selectedProvince!.code, _selectedDistrict!.code)
                  .map(
                    (w) => DropdownMenuItem(value: w, child: Text(w.name)),
              )
                  .toList(),
              onChanged: _onWardChanged,
              validator: (v) => v == null ? 'Vui lòng chọn xã' : null,
            ),

            // Địa chỉ chi tiết
            TextFormField(
              controller: _detailAddressController,
              decoration: const InputDecoration(labelText: 'Địa chỉ chi tiết'),
              validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập địa chỉ chi tiết' : null,
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _handleConfirmOwner,
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
  }

}
