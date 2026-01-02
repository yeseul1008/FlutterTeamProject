import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsign;
import 'firestore_service.dart';

class GoogleAuthService {
  static Future<UserCredential?> signInWithGoogle() async {
    final gsign.GoogleSignIn googleSignIn = gsign.GoogleSignIn(
      scopes: const ['email'],
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );

    final userCred =
    await FirebaseAuth.instance.signInWithCredential(credential);

    final user = userCred.user;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-null');
    }

    final fs = FirestoreService();
    final uid = user.uid;

    final userDoc = await fs.getUser(uid);

    final authEmail = (user.email ?? '').trim();
    final authPhone = (user.phoneNumber ?? '').trim();
    final authNickname = (user.displayName ?? '구글유저').trim();
    final authPhotoUrl = user.photoURL;

    if (!userDoc.exists) {
      final safeLoginId = authEmail.isNotEmpty ? authEmail : uid;

      await fs.createUser(
        userId: uid,
        loginId: safeLoginId,
        email: authEmail,
        phone: authPhone,
        provider: 'google',
        nickname: authNickname,
        profileImageUrl: authPhotoUrl,
        gender: 'U',
      );

      await fs.initFollowDoc(uid);
    } else {
      final data = userDoc.data() ?? {};
      final patch = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (authEmail.isNotEmpty && authEmail != data['email']) {
        patch['email'] = authEmail;
      }
      if (authNickname.isNotEmpty && authNickname != data['nickname']) {
        patch['nickname'] = authNickname;
      }
      if ((authPhotoUrl ?? '').isNotEmpty &&
          authPhotoUrl != data['profileImageUrl']) {
        patch['profileImageUrl'] = authPhotoUrl;
      }

      if (patch.length > 1) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update(patch);
      }

      await fs.initFollowDoc(uid);
    }

    return userCred;
  }
}
