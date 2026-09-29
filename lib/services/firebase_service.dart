import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize Firebase
  static Future<void> initialize() async {
    await Firebase.initializeApp();
  }

  // ==================== REGISTER ====================
  static Future<Map<String, dynamic>> registerWithEmail({
    required String nama,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'nama': nama,
        'email': email,
        'role': role,
        'registerDate': DateTime.now().toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _saveUserSession(
        uid: userCredential.user!.uid,
        email: email,
        role: role,
        nama: nama,
      );

      return {
        'success': true,
        'user': userCredential.user,
        'role': role,
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'error': _getAuthErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Terjadi kesalahan: $e',
      };
    }
  }

  // ==================== LOGIN ====================
  static Future<Map<String, dynamic>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      String role = 'user';
      String nama = '';
      if (userDoc.exists) {
        role = userDoc.get('role') ?? 'user';
        nama = userDoc.get('nama') ?? '';
      }

      await _saveUserSession(
        uid: userCredential.user!.uid,
        email: email,
        role: role,
        nama: nama,
      );

      return {
        'success': true,
        'user': userCredential.user,
        'role': role,
        'nama': nama,
      };
    } on FirebaseAuthException catch (e) {
      // PERBAIKAN: pesan error lebih ramah untuk user
      String msg = _getAuthErrorMessage(e.code);

      // Di firebase_auth v6, email salah & password salah
      // sama-sama mengembalikan 'invalid-credential'.
      // Kita tampilkan pesan generik demi keamanan.
      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        msg = 'Email atau password salah';
      }

      return {
        'success': false,
        'error': msg,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Terjadi kesalahan: $e',
      };
    }
  }

  // ==================== GET CURRENT USER ====================
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Check if user is logged in
  static bool isLoggedIn() {
    return _auth.currentUser != null;
  }

  // ==================== LOGOUT ====================
  static Future<void> logout() async {
    await _auth.signOut();
    await _clearUserSession();
  }

  // ==================== GET USER ROLE ====================
  static Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        return userDoc.get('role') ?? 'user';
      }
      return 'user';
    } catch (e) {
      return 'user';
    }
  }

  // ==================== GET USER DATA ====================
  static Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ==================== UPDATE PROFILE ====================
  /// Update nama & email user (Firestore + Firebase Auth + SharedPreferences)
  /// Catatan: di firebase_auth v6, updateEmail() dihapus.
  /// Digunakan verifyBeforeUpdateEmail() -> kirim link verifikasi ke email baru.
  static Future<Map<String, dynamic>> updateUserProfile({
    required String uid,
    required String nama,
    required String email,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'User tidak login'};
      }

      await user.reload();
      final freshUser = _auth.currentUser;
      if (freshUser == null) {
        return {'success': false, 'error': 'User tidak login'};
      }

      final emailChanged = freshUser.email != email;

      // 1. Update Firestore
      await _firestore.collection('users').doc(uid).update({
        'nama': nama,
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update email di Firebase Auth (jika berubah)
      if (emailChanged) {
        await freshUser.verifyBeforeUpdateEmail(email);
      }

      // 3. Update SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', nama);
      await prefs.setString('userEmail', email);

      return {
        'success': true,
        'emailChanged': emailChanged,
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Gagal update profil';
      if (e.code == 'email-already-in-use') {
        message = 'Email sudah digunakan akun lain';
      } else if (e.code == 'invalid-email') {
        message = 'Email tidak valid';
      } else if (e.code == 'requires-recent-login') {
        message = 'Sesi kadaluarsa, silakan login ulang';
      } else {
        message = _getAuthErrorMessage(e.code);
      }
      return {'success': false, 'error': message};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  // ==================== CHANGE PASSWORD ====================
  /// Ganti password dengan verifikasi password lama.
  static Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return {'success': false, 'error': 'User tidak ditemukan'};
      }

      // 1. Verifikasi password lama via re-authenticate
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: oldPassword,
      );

      try {
        await user.reauthenticateWithCredential(cred);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'wrong-password' ||
            e.code == 'invalid-credential') {
          return {'success': false, 'error': 'Password lama salah'};
        }
        rethrow;
      }

      // 2. Update ke password baru (dynamic untuk kompatibilitas v6)
      try {
        // ignore: avoid_dynamic_calls
        await (user as dynamic).updatePassword(newPassword);
        return {'success': true, 'method': 'direct'};
      } catch (e) {
        // Fallback: kirim email reset password
        await _auth.sendPasswordResetEmail(email: user.email!);
        return {
          'success': true,
          'method': 'email',
          'message':
              'Link reset password telah dikirim ke email Anda. Silakan cek inbox.',
        };
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Gagal mengubah password';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Password lama salah';
      } else if (e.code == 'weak-password') {
        message = 'Password baru terlalu lemah (min. 6 karakter)';
      } else if (e.code == 'requires-recent-login') {
        message = 'Sesi kadaluarsa, silakan login ulang';
      } else if (e.code == 'too-many-requests') {
        message = 'Terlalu banyak percobaan, coba lagi nanti';
      } else {
        message = _getAuthErrorMessage(e.code);
      }
      return {'success': false, 'error': message};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  // ==================== SESSION ====================
  static Future<void> _saveUserSession({
    required String uid,
    required String email,
    required String role,
    required String nama,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('uid', uid);
    await prefs.setString('userEmail', email);
    await prefs.setString('userRole', role);
    await prefs.setString('userName', nama);
  }

  static Future<void> _clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ==================== ERROR MESSAGES ====================
  static String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Email tidak terdaftar';
      case 'wrong-password':
        return 'Password salah';
      case 'invalid-credential':
        // Pesan generik demi keamanan (jangan bocorkan mana yang salah)
        return 'Email atau password salah';
      case 'invalid-email':
        return 'Format email tidak valid';
      case 'email-already-in-use':
        return 'Email sudah terdaftar';
      case 'weak-password':
        return 'Password terlalu lemah (min. 6 karakter)';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti';
      case 'requires-recent-login':
        return 'Sesi kadaluarsa, silakan login ulang';
      case 'user-disabled':
        return 'Akun dinonaktifkan';
      case 'operation-not-allowed':
        return 'Operasi tidak diizinkan';
      case 'network-request-failed':
        return 'Koneksi internet bermasalah';
      default:
        return 'Terjadi kesalahan: $code';
    }
  }
}