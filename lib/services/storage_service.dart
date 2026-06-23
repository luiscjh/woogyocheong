import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  Future<String> uploadBannerImage(File file) async {
    final id = _uuid.v4();
    final ref = _storage.ref('banners/$id.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<String> uploadProfileImage(String uid, File file) async {
    final ref = _storage.ref('profiles/$uid.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<void> deleteFile(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }

  Future<File?> pickImageFromGallery() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    return picked != null ? File(picked.path) : null;
  }

  Future<File?> pickImageFromCamera() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
    return picked != null ? File(picked.path) : null;
  }
}
