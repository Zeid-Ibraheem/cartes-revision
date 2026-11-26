import 'package:flutter/services.dart';

import '../domain/shared_files.dart';

/// Fichiers reçus par MainActivity.kt (Android), par le canal
/// « cartes/fichiers_recus ». Sur une autre plateforme : rien.
class AndroidSharedFiles implements SharedFiles {
  static const _channel = MethodChannel('cartes/fichiers_recus');

  @override
  Future<List<IncomingFile>> initial() async {
    try {
      return _decode(await _channel.invokeMethod<List<Object?>>('initial'));
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  void listen(void Function(List<IncomingFile> files) onFiles) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'received') {
        final files = _decode(call.arguments as List<Object?>?);
        if (files.isNotEmpty) onFiles(files);
      }
    });
  }

  static List<IncomingFile> _decode(List<Object?>? raw) => [
        for (final item in raw ?? const [])
          if (item is Map)
            IncomingFile(
              item['name'] as String? ?? 'fichier.txt',
              bytes: item['bytes'] as Uint8List?,
              error: item['error'] as String?,
            ),
      ];
}
