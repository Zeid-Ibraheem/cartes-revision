/// Fichiers de cartes reçus d'une autre appli (« Partager › Cartes »,
/// « Ouvrir avec › Cartes »).
library;

class IncomingFile {
  const IncomingFile(this.name, {this.bytes, this.error});

  /// Nom du fichier (ou du partage, pour un texte partagé).
  final String name;

  /// Contenu, ou `null` si la lecture a échoué.
  final List<int>? bytes;

  /// Pourquoi le fichier n'a pas pu être lu.
  final String? error;
}

/// Ce qui apporte les fichiers reçus : Android dans l'appli, un faux dans les
/// tests. Seul lib/data/android_shared_files.dart connaît Android.
abstract interface class SharedFiles {
  /// Ce qui a lancé l'appli (vide si elle a été ouverte normalement).
  Future<List<IncomingFile>> initial();

  /// Ce qui arrive pendant que l'appli est ouverte.
  void listen(void Function(List<IncomingFile> files) onFiles);
}
