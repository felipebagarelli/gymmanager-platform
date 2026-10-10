import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../errors/app_exception.dart';

/// Limites da foto do aparelho (o servidor valida de novo).
const maxPhotoBytes = 10 * 1024 * 1024;

/// Lado maior da foto enviada: reduz o tamanho (dados móveis) sem perder o que a IA precisa ver.
const photoMaxSide = 1568.0;

enum PhotoSource { camera, gallery }

class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;

  String get mimeType => photoMimeType(bytes);
}

/// Tipo da imagem pelos primeiros bytes (não confia na extensão). Aceita JPEG, PNG e WebP.
String photoMimeType(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
  if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47 && b[4] == 0x0D && b[5] == 0x0A && b[6] == 0x1A && b[7] == 0x0A) {
    return 'image/png';
  }
  if (b.length >= 12 && String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' && String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  throw AppException('Formato de imagem não suportado. Use uma foto JPG, PNG ou WebP.');
}

/// Lança [AppException] se a foto estiver vazia, grande demais ou em formato não suportado.
void validatePhoto(Uint8List bytes) {
  if (bytes.isEmpty) throw AppException('A foto está vazia.');
  if (bytes.length > maxPhotoBytes) throw AppException('A foto é grande demais (máximo de 10 MB).');
  photoMimeType(bytes);
}

/// Abre a câmera ou a galeria. Fica atrás de uma interface para os testes não dependerem do aparelho.
abstract class PhotoPicker {
  /// Null quando o aluno cancela.
  Future<PickedPhoto?> pick(PhotoSource source);
}

class ImagePickerPhotoPicker implements PhotoPicker {
  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: photoMaxSide,
        maxHeight: photoMaxSide,
        imageQuality: 85, // reencoda em JPEG (inclusive HEIC do iPhone)
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      validatePhoto(bytes);
      return PickedPhoto(bytes: bytes, name: file.name);
    } on PlatformException {
      throw AppException(source == PhotoSource.camera
          ? 'Não foi possível abrir a câmera. Permita o acesso nas configurações do aparelho.'
          : 'Não foi possível abrir a galeria. Permita o acesso nas configurações do aparelho.');
    }
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => ImagePickerPhotoPicker());
