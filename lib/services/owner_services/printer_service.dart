import 'package:cloud_firestore/cloud_firestore.dart';

class PrinterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String shopid;

  PrinterService(this.shopid);

  CollectionReference<Map<String, dynamic>> get _printer =>
      _firestore.collection('printer');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamPrinters() {
    return _printer.where('shopid', isEqualTo: shopid).snapshots();
  }

  Future<void> addPrinter({
    required String namePrinter,
    required String ip,
    required int port,
    String? note,
  }) async {
    final doc = _printer.doc();
    await doc.set({
      'name': namePrinter,
      'IP': ip,
      'Port': port,
      'note': note ?? '',
      'connectionType': 'wifi',
      'shopid': shopid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePrinter({
    required String id,
    required String namePrinter,
    required String ip,
    required int port,
    String? note,
  }) async {
    await _printer.doc(id).update({
      'name': namePrinter,
      'IP': ip,
      'Port': port,
      'note': note ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePrinter(String id) async {
    await _printer.doc(id).delete();
  }
}
