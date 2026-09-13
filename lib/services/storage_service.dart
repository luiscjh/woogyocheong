import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'demo_data.dart';
import 'firestore_service.dart' show demoMode;

class StorageService {
  FirebaseStorage get _storage => FirebaseStorage.instance;
  final _uuid = const Uuid();

  Future<String> uploadBannerImage(XFile file) async {
    final bytes = await file.readAsBytes();
    if (demoMode) return DemoData.instance.cacheImage(bytes);
    final ref = _storage.ref('banners/${_uuid.v4()}.jpg');
    await ref.putData(bytes);
    return ref.getDownloadURL();
  }

  Future<String> uploadProfileImage(String uid, XFile file) async {
    if (demoMode) return '';
    final bytes = await file.readAsBytes();
    final ref = _storage.ref('profiles/$uid.jpg');
    await ref.putData(bytes);
    return ref.getDownloadURL();
  }

  Future<void> deleteFile(String url) async {
    if (demoMode) {
      // 데모 모드에서 업로드했던 이미지도 실제 삭제처럼 메모리에서 함께 해제
      DemoData.instance.removeImage(url);
      return;
    }
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }

  Future<XFile?> pickImageFromGallery() async {
    return await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
  }
}
