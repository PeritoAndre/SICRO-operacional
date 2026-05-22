import 'package:image_picker/image_picker.dart';

class PhotoCaptureService {
  PhotoCaptureService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<XFile?> capturePhoto() {
    return _picker.pickImage(source: ImageSource.camera);
  }
}
