import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._prefs, {required this.firebaseActive});

  final SharedPreferences _prefs;
  final bool firebaseActive;

  String? email;
  String? uid;
  bool restoring = true;
  bool busy = false;
  String? error;
  String? notice;

  bool get hasLocalAccount {
    final savedEmail = _prefs.getString('local_email');
    final savedLock = _prefs.getString('local_password');
    return savedEmail != null && savedEmail.isNotEmpty && savedLock != null && savedLock.isNotEmpty;
  }

  Future<void> restore() async {
    if (firebaseActive) {
      FirebaseAuth.instance.authStateChanges().listen((user) {
        email = user?.email;
        uid = user?.uid;
        restoring = false;
        notifyListeners();
      });
      return;
    }
    uid = _prefs.getString('local_uid');
    email = uid == null ? null : _prefs.getString('local_email');
    restoring = false;
    notifyListeners();
  }

  Future<bool> signIn(String rawEmail, String password) {
    return _submit(rawEmail, password, create: false);
  }

  Future<bool> signUp(String rawEmail, String password, {String secretKey = ''}) {
    return _submit(rawEmail, password, create: true, secretKey: secretKey);
  }

  Future<bool> _submit(
    String rawEmail,
    String password, {
    required bool create,
    String secretKey = '',
  }) async {
    final address = rawEmail.trim();
    final formError = _formError(address, password);
    if (formError != null) {
      error = formError;
      notice = null;
      notifyListeners();
      return false;
    }

    busy = true;
    error = null;
    notice = null;
    notifyListeners();
    try {
      if (firebaseActive) {
        if (create) {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: address,
            password: password,
          );
        } else {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: address,
            password: password,
          );
        }
      } else if (create) {
        final secretError = await _secretError(secretKey);
        if (secretError != null) {
          error = secretError;
          return false;
        }
        await _prefs.setString('local_email', address);
        await _prefs.setString('local_uid', address.toLowerCase());
        await _prefs.setString('local_password', _lock(password));
        email = address;
        uid = address.toLowerCase();
      } else {
        final savedEmail = _prefs.getString('local_email');
        final savedLock = _prefs.getString('local_password');
        if (savedEmail == null || savedEmail.toLowerCase() != address.toLowerCase()) {
          error = 'No saved account for that email on this device.';
          return false;
        }
        if (savedLock != _lock(password)) {
          error = 'Email or PIN is incorrect.';
          return false;
        }
        final id = savedEmail.toLowerCase();
        await _prefs.setString('local_uid', id);
        email = savedEmail;
        uid = id;
      }
      return error == null;
    } on FirebaseAuthException catch (exception) {
      error = _firebaseMessage(exception);
      return false;
    } catch (_) {
      error = 'Could not sign in. Check the connection and try again.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> sendReset(String rawEmail) async {
    final address = rawEmail.trim();
    if (!address.contains('@')) {
      error = 'Enter the email on the account.';
      notice = null;
      notifyListeners();
      return;
    }
    if (!firebaseActive) {
      error = 'Connect Firebase to send a reset email. The README has the steps.';
      notice = null;
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    notice = null;
    notifyListeners();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: address);
      notice = 'Reset email sent.';
    } on FirebaseAuthException catch (exception) {
      error = _firebaseMessage(exception);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (firebaseActive) {
      await FirebaseAuth.instance.signOut();
    }
    email = null;
    uid = null;
    if (!firebaseActive) {
      await _prefs.remove('local_uid');
    }
    notifyListeners();
  }

  String? _formError(String address, String password) {
    if (!address.contains('@') || !address.contains('.')) return 'Enter a valid email.';
    if (!firebaseActive) {
      if (!RegExp(r'^\d{4}$').hasMatch(password)) return 'Enter a 4 digit PIN.';
      return null;
    }
    if (password.length < 6) return 'Use at least 6 characters.';
    return null;
  }

  Future<String?> _secretError(String entered) async {
    try {
      final raw = await rootBundle.loadString('assets/data.json');
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return 'Insert the correct secret key.';
      final expected = decoded['secretKey'];
      if (expected is! String || expected.trim().isEmpty) {
        return 'Insert the correct secret key.';
      }
      if (entered.trim() != expected.trim()) return 'Insert the correct secret key.';
      return null;
    } catch (_) {
      return 'Insert the correct secret key.';
    }
  }

  String _lock(String password) {
    var hash = 17;
    for (final unit in password.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash.toString();
  }

  String _firebaseMessage(FirebaseAuthException exception) {
    return switch (exception.code) {
      'invalid-email' => 'That email does not look right.',
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        'Email or password is incorrect.',
      'email-already-in-use' => 'An account already exists for that email.',
      'weak-password' => 'Use at least 6 characters.',
      'network-request-failed' => 'No network. Check the connection and try again.',
      'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
      _ => exception.message ?? 'Could not complete that request.',
    };
  }
}
