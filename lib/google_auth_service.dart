import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class GoogleAuthService {
  static Future<UserCredential?> signIn() async {
    if (kIsWeb) {
      // Web: popup simples do Firebase
      final googleProvider = GoogleAuthProvider();
      return await FirebaseAuth.instance.signInWithPopup(googleProvider);
    } else {
      // Mobile: signInWithProvider abre o fluxo nativo do Google
      // Não usa signInWithRedirect (que causa o erro de sessão)
      // Não depende do google_sign_in separado
      final googleProvider = GoogleAuthProvider();
      return await FirebaseAuth.instance.signInWithProvider(googleProvider);
    }
  }
}
