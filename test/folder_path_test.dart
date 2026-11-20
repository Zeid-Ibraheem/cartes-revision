import 'package:cartes_revision/domain/folder_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chemins saisis mis au propre', () {
    expect(normalizeFolder('Cours/R3.07'), 'Cours/R3.07');
    expect(normalizeFolder('  Cours /  R3.07 / '), 'Cours/R3.07');
    expect(normalizeFolder('Cours › R3.07'), 'Cours/R3.07');
    expect(normalizeFolder('Mes   cours//S3'), 'Mes cours/S3');
    expect(normalizeFolder(' / '), '');
  });

  test('niveaux d’un chemin', () {
    expect(folderLeaf('Cours/S3/R3.07'), 'R3.07');
    expect(folderLeaf('Cours'), 'Cours');
    expect(folderParent('Cours/S3/R3.07'), 'Cours/S3');
    expect(folderParent('Cours'), '');
    expect(folderDepth('Cours'), 0);
    expect(folderDepth('Cours/S3/R3.07'), 2);
    expect(joinFolder('', 'Cours'), 'Cours');
    expect(joinFolder('Cours', 'R3.07'), 'Cours/R3.07');
    expect(folderAncestry('Cours/S3/R3.07'), ['Cours', 'Cours/S3', 'Cours/S3/R3.07']);
    expect(displayFolder('Cours/R3.07'), 'Cours › R3.07');
  });

  test('où peut-on glisser un dossier ou un paquet', () {
    // Dossier
    expect(canMoveFolderInto('Cours/R3.07', 'Connaissances'), isTrue);
    expect(canMoveFolderInto('Cours/R3.07', ''), isTrue, reason: 'tout en haut');
    expect(canMoveFolderInto('R3.07', ''), isFalse, reason: 'déjà en haut');
    expect(canMoveFolderInto('Cours/R3.07', 'Cours'), isFalse, reason: 'déjà là');
    expect(canMoveFolderInto('Cours', 'Cours'), isFalse, reason: 'lui-même');
    expect(canMoveFolderInto('Cours', 'Cours/R3.07'), isFalse,
        reason: 'un de ses sous-dossiers');
    expect(canMoveFolderInto('Cours', 'Coursier'), isTrue);
    // Paquet
    expect(canMoveDeckInto('Cours/R3.07', 'Connaissances'), isTrue);
    expect(canMoveDeckInto('Cours/R3.07', 'Cours/R3.07'), isFalse);
    expect(canMoveDeckInto('Cours/R3.07', ''), isFalse,
        reason: 'un paquet est toujours dans un dossier');
  });

  test('appartenance à un dossier', () {
    expect(isInFolder('Cours', 'Cours'), isTrue);
    expect(isInFolder('Cours/R3.07', 'Cours'), isTrue);
    expect(isInFolder('Cours/S3/R3.07', 'Cours'), isTrue);
    // Même début de nom, mais pas le même dossier.
    expect(isInFolder('Coursier', 'Cours'), isFalse);
    expect(isInFolder('Cours', 'Cours/R3.07'), isFalse);
  });
}
