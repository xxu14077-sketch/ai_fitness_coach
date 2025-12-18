import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageHelper {
  static Future<String?> pickAndUploadImage({String bucket = 'uploads'}) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return null;
    final uid = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}-${f.name}';
    try {
      await Supabase.instance.client.storage.from(bucket).uploadBinary(path, Uint8List.fromList(bytes),
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
      final pub = Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
      return pub;
    } catch (_) {
      return null;
    }
  }
}
