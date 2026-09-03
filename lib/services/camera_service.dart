import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _deviceDocId = 'esp32cam';

  /// Mendapatkan IP kamera dari Firestore (sekali baca)
  Future<String?> getCameraIp() async {
    try {
      final doc = await _firestore
          .collection('devices')
          .doc(_deviceDocId)
          .get();

      if (doc.exists) {
        return doc.data()?['ip'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting camera IP: $e');
      return null;
    }
  }

  /// Stream untuk update IP kamera secara real-time
  Stream<String?> getCameraIpStream() {
    return _firestore
        .collection('devices')
        .doc(_deviceDocId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return doc.data()?['ip'] as String?;
      }
      return null;
    });
  }

  /// Update status kamera ke Firestore
  Future<void> updateCameraStatus({
    required String ip,
    required String status,
  }) async {
    try {
      await _firestore.collection('devices').doc(_deviceDocId).set({
        'ip': ip,
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ Camera status updated: $status');
    } catch (e) {
      debugPrint('❌ Error updating camera status: $e');
    }
  }
}