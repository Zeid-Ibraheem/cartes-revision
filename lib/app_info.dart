/// Nom affiché de l'appli.
const appName = 'Cartes';

/// Version de l'appli. Elle n'est écrite qu'à un endroit, pubspec.yaml :
/// GitHub la transmet à la construction (--dart-define=APP_VERSION).
/// Une version construite à la main sur le PC affiche « dev ».
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
