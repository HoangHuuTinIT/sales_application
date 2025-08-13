import 'package:ban_hang/screens/auth/signin.dart';
import 'package:ban_hang/screens/auth/signup_information.dart';
import 'package:ban_hang/screens/customer/home_customer.dart';
import 'package:ban_hang/screens/delivery/delivery_home.dart';
import 'package:ban_hang/screens/manager/home_manager.dart';
import 'package:ban_hang/screens/owner/home_owner.dart';
import 'package:ban_hang/screens/staff/home_staff.dart';
import 'package:ban_hang/utils/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:vietnam_provinces/vietnam_provinces.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initLocations() async => await VietnamProvinces.initialize();

  List<Province> getProvinces() => VietnamProvinces.getProvinces();

  List<District> getDistricts(int provinceCode) =>
      VietnamProvinces.getDistricts(provinceCode: provinceCode);

  List<Ward> getWards(int provinceCode, int districtCode) =>
      VietnamProvinces.getWards(
        provinceCode: provinceCode,
        districtCode: districtCode,
      );

  static User? googleUser;

  Future<String?> signInWithGoogleAndCheckUserExists() async {
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      await googleSignIn.signOut();
      final GoogleSignInAccount? gUser = await googleSignIn.signIn();
      if (gUser == null) return 'Bạn đã hủy đăng nhập';

      final GoogleSignInAuthentication gAuth = await gUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      googleUser = userCredential.user;

      final email = googleUser?.email;
      if (email == null) return 'Không lấy được email người dùng';

      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        await _auth.signOut();
        return 'Tài khoản Google này chưa được đăng ký';
      }

      return null;
    } catch (e) {
      print('Google sign-in error: $e');
      return 'Lỗi đăng nhập Google: $e';
    }
  }

  Future<String?> completeGoogleSignup({
    required String name,
    required String email,
    required String phone,
    required String ward,
    required String district,
    required String province,
    required String gender,
    required String detailAddress,
    required String googleUid,
  }) async {
    try {
      final fullAddress = "$detailAddress - $ward - $district - $province";

      await FirebaseFirestore.instance.collection('users').doc(googleUid).set({
        'name': name,
        'email': email,
        'phone': phone,
        'phone_verified': true,
        'address': fullAddress,
        'role': 'customer',
        'gender': gender,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null;
    } catch (e) {
      return 'Lỗi khi lưu thông tin người dùng: $e';
    }
  }

  Future<void> navigateUserByRole(BuildContext context) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await _firestore.collection('users').doc(uid).get();
    final role = doc.data()?['role'];

    Widget home;
    if (role == 'manager') {
      home = const HomeManager();
    } else if (role == 'staff') {
      home = const HomeStaff();
    } else if (role == 'delivery') {
      home = const DeliveryHomeScreen();
    } else if (role == 'owner') {
      home = const HomeOwnerScreen();
    } else {
      home = const HomeCustomer();
    }
    print('role người dùng: $role');

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => home),
          (route) => false,
    );
  }

  Future<String?> createStaffAndDeliveryAccount({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String address,
    required String role,
    required String creatorId,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'role': role,
        'creator': creatorId,
        'status': 'chờ duyệt',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null;
    } catch (e) {
      return 'Lỗi khi tạo tài khoản: $e';
    }
  }

  Future<void> signUpWithGoogleAndCheck({
    required BuildContext context,
  }) async {
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      await googleSignIn.signOut();

      final gUser = await googleSignIn.signIn();
      if (gUser == null) return;

      final gAuth = await gUser.authentication;

      // Lấy thông tin ID Google
      final idToken = gAuth.idToken;
      if (idToken == null) {
        message.showSnackbarfalse(context, "Không thể lấy ID Token Google");
        return;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: idToken,
      );

      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null || user.email == null) {
        message.showSnackbarfalse(
            context, "Không thể lấy thông tin tài khoản Google");
        return;
      }

      final email = user.email!;
      final googleUid = gUser.id; // <-- UID Google thật sự (khác Firebase UID)

      // Kiểm tra Firestore xem Google UID đã tồn tại chưa
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .doc(googleUid)
          .get();

      if (existing.exists) {
        message.showConfirmDialog(
          context: context,
          title: "Tài khoản đã tồn tại",
          content:
          "Tài khoản Google đã được đăng ký. Bạn có muốn chuyển đến đăng nhập?",
          confirmText: "Đăng nhập",
          cancelText: "Hủy",
          onConfirm: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SignInScreen()),
            );
          },
        );
        await FirebaseAuth.instance.signOut();
        return;
      }

      // Chuyển qua màn hình nhập thêm thông tin
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SignUpInformationScreen(
            initialData: {
              'email': email,
              'googleUid': googleUid, // truyền luôn Google UID
            },
          ),
        ),
      );
    } catch (e) {
      print('Lỗi đăng ký Google: $e');
      message.showSnackbarfalse(context, 'Lỗi đăng ký Google: $e');
    }
  }


  Future<void> signUpWithFacebookAndCheck(BuildContext context) async {
    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status != LoginStatus.success) {
        message.showSnackbarfalse(context, 'Hủy đăng nhập Facebook');
        return;
      }

      final OAuthCredential facebookAuthCredential =
      FacebookAuthProvider.credential(result.accessToken!.token);

      final userCredential = await FirebaseAuth.instance
          .signInWithCredential(facebookAuthCredential);
      final user = userCredential.user;

      final userData = await FacebookAuth.instance.getUserData(fields: "email,name,picture");
      final fbEmail = userData['email'] as String?;
      final fbName = userData['name'] as String? ?? user?.displayName ?? '';
      final fbPicture = userData['picture']['data']['url'] as String? ?? '';

      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: fbEmail)
          .limit(1)
          .get();


      if (existing.docs.isNotEmpty) {
        message.showConfirmDialog(
          context: context,
          title: "Tài khoản đã tồn tại",
          content: "Tài khoản Facebook đã được đăng ký. Bạn có muốn chuyển đến đăng nhập?",
          confirmText: "Đăng nhập",
          cancelText: "Hủy",
          onConfirm: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SignInScreen()),
            );
          },
        );
        await FirebaseAuth.instance.signOut();
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SignUpInformationScreen(
            initialData: {
              'email': fbEmail,
              'name': fbName,
              'avatarUrl': fbPicture,
            },
          ),
        ),
      );
    } catch (e) {
      print('Lỗi đăng ký Facebook: $e');
      message.showSnackbarfalse(context, 'Lỗi đăng ký Facebook: $e');
    }
  }
  Future<String?> completeFacebookSignup({
    required String name,
    required String email,
    required String phone,
    required String ward,
    required String district,
    required String province,
    required String gender,
    required String detailAddress,
    required String avatarUrl,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "Không tìm thấy người dùng";

      final fullAddress = "$detailAddress - $ward - $district - $province";

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'email': email,
        'phone': phone,
        'phone_verified': true,
        'address': fullAddress,
        'role': 'customer',
        'gender': gender,
        'avatarUrl': avatarUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null;
    } catch (e) {
      return 'Lỗi khi lưu thông tin người dùng: $e';
    }
  }

  Future<String?> signInWithFacebookAndCheckUserExists() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status != LoginStatus.success) {
        return 'Bạn đã hủy đăng nhập Facebook';
      }

      final OAuthCredential facebookAuthCredential =
      FacebookAuthProvider.credential(result.accessToken!.token);

      final userCredential = await FirebaseAuth.instance
          .signInWithCredential(facebookAuthCredential);

      final user = userCredential.user;
      final userData = await FacebookAuth.instance.getUserData(fields: "email,name");

      final fbEmail = userData['email'] as String?;
      if (fbEmail == null) return 'Không thể lấy email từ tài khoản Facebook';

      // Kiểm tra email có tồn tại trong firestore chưa
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: fbEmail)
          .limit(1)
          .get();
      print("Firebase UID: ${user?.uid}");
      print("Facebook email: $fbEmail");
      if (existing.docs.isEmpty) {
        await FirebaseAuth.instance.signOut();
        return 'Tài khoản Facebook này chưa được đăng ký';
      }

      return null;
    } catch (e) {
      print('Facebook sign-in error: $e');
      return 'Lỗi đăng nhập Facebook: $e';
    }
  }
  Future<String?> createOwnerAccount({
    required String name,
    required String email,
    required String password,
    required String address,
    required String phone,
  }) async {
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = userCredential.user!.uid;
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'shopid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'role': 'owner',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null;
    } catch (e) {
      return e.toString();
    }
  }
  Future<String?> CreateCustomerAccount({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String address,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = userCredential.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'shopid':uid,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'role': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null;
    } catch (e) {
      return 'Lỗi khi đăng ký tài khoản: $e';
    }
  }

}
