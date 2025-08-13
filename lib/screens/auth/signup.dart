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
  Province? _selectedProvinceCustomer;
  District? _selectedDistrictCustomer;
  Ward? _selectedWardCustomer;

  final _formKeyCustomer = GlobalKey<FormState>();
  final _nameControllerCustomer = TextEditingController();
  final _emailControllerCustomer = TextEditingController();
  final _passwordControllerCustomer = TextEditingController();
  final _detailAddressControllerCustomer = TextEditingController();

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
  List<Province> _provinces = [];
  @override
  void initState() {
    super.initState();
    AuthService().initLocations(); // Khởi tạo vietnam_provinces
    _provinces = AuthService().getProvinces();
  }

  void _onProvinceChangedCustomer(Province? p) {
    setState(() {
      _selectedProvinceCustomer = p;
      _selectedDistrictCustomer = null;
      _selectedWardCustomer = null;
    });
  }

  void _onDistrictChangedCustomer(District? d) {
    setState(() {
      _selectedDistrictCustomer = d;
      _selectedWardCustomer = null;
    });
  }

  void _onWardChangedCustomer(Ward? w) {
    setState(() {
      _selectedWardCustomer = w;
    });
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

  Future<void> _handleConfirmCustomer() async {
    if (!_formKeyCustomer.currentState!.validate()) return;

    if (_selectedProvinceCustomer == null ||
        _selectedDistrictCustomer == null ||
        _selectedWardCustomer == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vui lòng chọn đầy đủ địa chỉ')));
      return;
    }

    final name = _nameControllerCustomer.text.trim();
    final email = _emailControllerCustomer.text.trim();
    final password = _passwordControllerCustomer.text.trim();
    final detailAddress = _detailAddressControllerCustomer.text.trim();

    final verifiedPhone = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => const VerifyPhoneNumberScreen(),
      ),
    );

    if (verifiedPhone == null) return;

    final address =
        '$detailAddress - ${_selectedWardCustomer!.name} - ${_selectedDistrictCustomer!.name} - ${_selectedProvinceCustomer!.name}';

    final error = await AuthService().CreateCustomerAccount(
      name: name,
      email: email,
      password: password,
      phone: verifiedPhone,
      address: address,
    );
    if (error == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đăng ký thành công')));
      await AuthService().navigateUserByRole(context);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $error')));
    }
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

          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSignUp() {
    return SingleChildScrollView(
      child: Form(
        key: _formKeyCustomer,
        child: Column(
          children: [
            // Tên
            TextFormField(
              controller: _nameControllerCustomer,
              decoration: const InputDecoration(labelText: 'Tên'),
              validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập tên' : null,
            ),

            // Tỉnh/Thành phố
            DropdownButtonFormField<Province>(
              value: _selectedProvinceCustomer,
              hint: const Text('Chọn Tỉnh/Thành phố'),
              items: AuthService()
                  .getProvinces()
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                  .toList(),
              onChanged: _onProvinceChangedCustomer,
              validator: (v) => v == null ? 'Vui lòng chọn tỉnh' : null,
            ),

            const SizedBox(height: 12),

            // Huyện/Quận
            DropdownButtonFormField<District>(
              value: _selectedDistrictCustomer,
              hint: const Text('Chọn Huyện/Quận'),
              items: _selectedProvinceCustomer == null
                  ? []
                  : AuthService()
                  .getDistricts(_selectedProvinceCustomer!.code)
                  .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                  .toList(),
              onChanged: _onDistrictChangedCustomer,
              validator: (v) => v == null ? 'Vui lòng chọn huyện' : null,
            ),

            const SizedBox(height: 12),

            // Xã/Phường
            DropdownButtonFormField<Ward>(
              value: _selectedWardCustomer,
              hint: const Text('Chọn Xã/Phường'),
              items: (_selectedProvinceCustomer == null || _selectedDistrictCustomer == null)
                  ? []
                  : AuthService()
                  .getWards(_selectedProvinceCustomer!.code, _selectedDistrictCustomer!.code)
                  .map((w) => DropdownMenuItem(value: w, child: Text(w.name)))
                  .toList(),
              onChanged: _onWardChangedCustomer,
              validator: (v) => v == null ? 'Vui lòng chọn xã' : null,
            ),

            // Địa chỉ chi tiết
            TextFormField(
              controller: _detailAddressControllerCustomer,
              decoration: const InputDecoration(labelText: 'Địa chỉ chi tiết'),
              validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập địa chỉ chi tiết' : null,
            ),

            // Email
            TextFormField(
              controller: _emailControllerCustomer,
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
              controller: _passwordControllerCustomer,
              decoration: const InputDecoration(labelText: 'Mật khẩu'),
              obscureText: true,
              validator: (v) =>
              v == null || v.length < 6 ? 'Mật khẩu phải ít nhất 6 ký tự' : null,
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _handleConfirmCustomer,
              child: const Text('Xác nhận'),
            ),

            const SizedBox(height: 30),

            // Nút đăng ký Google
            ElevatedButton.icon(
              onPressed: _handleGoogleSignUp,
              icon: const Icon(Icons.account_circle),
              label: const Text("Đăng ký bằng Google"),
            ),

            const SizedBox(height: 12),

            // Nút đăng ký Facebook
            ElevatedButton.icon(
              onPressed: _handleFacebookSignUp,
              icon: const Icon(Icons.facebook, color: Colors.white),
              label: const Text("Đăng ký bằng Facebook"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
              ),
            ),
          ],
        ),
      ),
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
              items: _provinces
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
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
