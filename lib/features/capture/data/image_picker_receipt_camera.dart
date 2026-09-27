import 'package:image_picker/image_picker.dart';

import 'package:el_ahorrador/features/capture/domain/capture_ports.dart';

/// The system camera. The photo is read and then kept encrypted like any
/// capture (see `EncryptedCaptureImageStore`).
class ImagePickerReceiptCamera implements ReceiptCamera {
  ImagePickerReceiptCamera({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> takePhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2000,
      imageQuality: 90,
    );
    return photo?.path;
  }
}
