import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_exchange_egypt/core/file_utils.dart';

void main() {
  group('fileExtension', () {
    test('returns the extension for an ordinary path', () {
      expect(fileExtension('/data/user/0/cache/photo.jpg'), 'jpg');
      expect(fileExtension(r'C:\Users\x\Pictures\scan.PNG'), 'png');
      expect(fileExtension('licence.pdf'), 'pdf');
    });

    // This is the bug the helper exists for. Every upload site used
    // `path.split('.').last`, which for an extensionless file returns the
    // entire path — separators included — producing a storage key like
    // `<uid>/license./data/user/0/cache/img` that Storage rejects.
    test('falls back instead of returning the whole path when there is no extension', () {
      expect(fileExtension('/data/user/0/cache/image_picker_1234'), 'jpg');
      expect(fileExtension('/data/user/0/cache/image_picker_1234', fallback: 'png'), 'png');
    });

    test('is not fooled by a dot in a directory name', () {
      expect(fileExtension('/var/my.folder/photo'), 'jpg');
      expect(fileExtension('/var/my.folder/photo.webp'), 'webp');
    });

    test('rejects anything that is not a short alphanumeric extension', () {
      // A crafted filename must not be able to inject path segments into the
      // object key.
      expect(fileExtension('photo.jpg/../../etc/passwd'), 'jpg');
      expect(fileExtension('photo.reallylongextension'), 'jpg');
      expect(fileExtension('photo.'), 'jpg');
      expect(fileExtension('.bashrc'), 'jpg');
    });
  });
}
