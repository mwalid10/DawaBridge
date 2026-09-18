import 'dart:io';

/// Safe file extension for building a Storage object key.
///
/// Every upload path in the app used `path.split('.').last`, which is wrong
/// for a file with no extension at all: `split` returns a single-element
/// list and `.last` hands back the *whole path*, separators included. The
/// resulting key (`<uid>/license./data/user/0/cache/img`) is rejected by
/// Storage, so the user just saw an upload failure with no explanation.
///
/// Returns [fallback] when there's no usable extension, and refuses
/// anything that isn't a short alphanumeric run so a crafted filename can't
/// inject path segments into the object key.
String fileExtension(String path, {String fallback = 'jpg'}) {
  final name = path.split(RegExp(r'[/\\]')).last;
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return fallback;

  final ext = name.substring(dot + 1).toLowerCase();
  if (ext.length > 5 || !RegExp(r'^[a-z0-9]+$').hasMatch(ext)) return fallback;
  return ext;
}

/// Size of [path] in bytes, or null if it can't be read.
Future<int?> fileSizeBytes(String path) async {
  try {
    return await File(path).length();
  } catch (_) {
    return null;
  }
}

/// Matches the per-bucket `file_size_limit` set in migration 0040. Checked
/// client-side too so the user gets a clear message instead of a Storage
/// 413 after waiting for a full upload over a mobile connection.
const maxMedicinePhotoBytes = 5 * 1024 * 1024;
const maxLicenseBytes = 10 * 1024 * 1024;
const maxChatAttachmentBytes = 15 * 1024 * 1024;
