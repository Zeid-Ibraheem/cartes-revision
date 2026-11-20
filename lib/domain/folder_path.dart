/// Les dossiers imbriqués, sous forme de chemins : « Cours/R3.07 » est le
/// dossier R3.07 rangé dans le dossier Cours.
///
/// Un paquet enregistre le chemin de son dossier. Les dossiers n'existent pas
/// seuls : ils apparaissent dès qu'un paquet est rangé dedans (ou plus bas).
library;

/// Séparateur des niveaux dans un chemin.
const folderSeparator = '/';

/// Séparateur affiché à l'écran.
const folderDisplaySeparator = ' › ';

/// Met un chemin saisi au propre : « Cours / R3.07 » ou « Cours › R3.07 »
/// donnent « Cours/R3.07 ». Les espaces sont resserrés, les niveaux vides
/// retirés. Renvoie une chaîne vide si rien ne reste.
String normalizeFolder(String text) => folderSegments(text).join(folderSeparator);

/// Les niveaux d'un chemin, du plus haut au plus bas.
List<String> folderSegments(String text) => text
    .replaceAll('›', folderSeparator)
    .split(folderSeparator)
    .map((segment) => segment.trim().replaceAll(RegExp(r'\s+'), ' '))
    .where((segment) => segment.isNotEmpty)
    .toList();

/// Nom du dernier niveau : « R3.07 » pour « Cours/R3.07 ».
String folderLeaf(String path) {
  final index = path.lastIndexOf(folderSeparator);
  return index < 0 ? path : path.substring(index + 1);
}

/// Chemin du dossier parent, ou chaîne vide pour un dossier du haut.
String folderParent(String path) {
  final index = path.lastIndexOf(folderSeparator);
  return index < 0 ? '' : path.substring(0, index);
}

/// Profondeur : 0 pour un dossier du haut.
int folderDepth(String path) => folderSeparator.allMatches(path).length;

/// Chemin d'un sous-dossier [leaf] dans [parent] (vide = en haut).
String joinFolder(String parent, String leaf) =>
    parent.isEmpty ? leaf : '$parent$folderSeparator$leaf';

/// [path] est [folder] lui-même, ou un de ses sous-dossiers (à tout niveau).
bool isInFolder(String path, String folder) =>
    path == folder || path.startsWith('$folder$folderSeparator');

/// Le dossier [folder] peut-il être rangé dans [target] (vide = tout en
/// haut) ? Pas dans lui-même, ni dans un de ses sous-dossiers, ni là où il
/// est déjà.
bool canMoveFolderInto(String folder, String target) =>
    !isInFolder(target, folder) && target != folderParent(folder);

/// Un paquet rangé dans [current] peut-il aller dans [target] ? Un paquet est
/// toujours dans un dossier, et ce doit être un autre que le sien.
bool canMoveDeckInto(String current, String target) =>
    target.isNotEmpty && target != current;

/// Tous les dossiers d'un chemin, du haut vers le bas :
/// « Cours/S3/R3.07 » donne Cours, Cours/S3, Cours/S3/R3.07.
List<String> folderAncestry(String path) {
  final segments = folderSegments(path);
  return [
    for (var i = 1; i <= segments.length; i++)
      segments.take(i).join(folderSeparator),
  ];
}

/// Chemin tel qu'affiché : « Cours › R3.07 ».
String displayFolder(String path) =>
    path.split(folderSeparator).join(folderDisplaySeparator);
