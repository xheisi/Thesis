import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── REGISTER ──
  Future<String?> register({
    required String name,
    required String surname,
    required String email,
    required String password,
    String? gender,
    DateTime? birthdate,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _db.collection('users').doc(result.user!.uid).set({
        'name': name,
        'surname': surname,
        'email': email,
        'role': 'passenger',
        'status': 'active',
        'gender': gender ?? '',
        'birthdate': birthdate != null ? Timestamp.fromDate(birthdate) : null,
        'created_at': FieldValue.serverTimestamp(),
        'last_login': FieldValue.serverTimestamp(),
      });

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── LOGIN ──
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = result.user!.uid;

      // Get user doc safely
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();

      if (doc.exists) {
        // Safe read — use data() map instead of direct field access
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final status = data['status'] as String? ?? 'active';
        if (status == 'inactive') {
          await _auth.signOut();
          return 'inactive';
        }
      } else {
        // Doc doesn't exist yet (shouldn't happen but just in case)
        // Don't create a minimal doc — just proceed and let _AuthGate handle it
      }

      // Update last_login only — never overwrite other fields
      await _db.collection('users').doc(uid).update({
        'last_login': FieldValue.serverTimestamp(),
      });

      return null;
    } catch (e) {
      // If update fails because doc doesn't exist, ignore it
      // (staff accounts always have their doc created by createStaffAccount)
      final err = e.toString();
      if (err.contains('NOT_FOUND') || err.contains('not-found')) {
        return null; // login still succeeded
      }
      return err;
    }
  }

  // ── GET CURRENT USER ROLE ──
  Future<String> getUserRole() async {
    User? user = _auth.currentUser;
    if (user == null) return '';

    try {
      DocumentSnapshot doc =
          await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) return 'passenger';
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return data['role'] as String? ?? 'passenger';
    } catch (_) {
      return 'passenger';
    }
  }

  // ── LOGOUT ──
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ── CURRENT USER ──
  User? get currentUser => _auth.currentUser;
}