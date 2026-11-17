import 'package:material_ui/material_ui.dart';

import 'app_info.dart';
import 'data/notification_reminders.dart';
import 'data/store.dart';
import 'domain/settings.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // En version release, une erreur d'affichage donne un simple écran gris.
  // On affiche plutôt le message, pour pouvoir le signaler et le corriger.
  ErrorWidget.builder = (details) => Material(
        color: const Color(0xFFFFF4F4),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Erreur d’affichage (fais une capture d’écran pour la '
              'signaler) :\n\n${details.exception}\n\n${details.stack ?? ''}',
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: Color(0xFF8B0000), fontSize: 12),
            ),
          ),
        ),
      );
  final store = await AppStore.open(reminders: NotificationReminders());
  runApp(CartesApp(store: store));
  await store.askReminderPermissionOnce();
}

class CartesApp extends StatefulWidget {
  const CartesApp({super.key, required this.store});

  final AppStore store;

  @override
  State<CartesApp> createState() => _CartesAppState();
}

class _CartesAppState extends State<CartesApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Retour dans l'appli (le lendemain, par exemple) : compteurs à jour.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.store.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final theme = widget.store.settings.theme;
        return MaterialApp(
          title: appName,
          debugShowCheckedModeBanner: false,
          themeMode: switch (theme) {
            AppTheme.system => ThemeMode.system,
            AppTheme.light => ThemeMode.light,
            AppTheme.dark || AppTheme.black => ThemeMode.dark,
          },
          theme: buildTheme(brightness: Brightness.light),
          // « Auto » suit le téléphone : clair le jour, noir en mode sombre.
          darkTheme: buildTheme(
            brightness: Brightness.dark,
            black: theme != AppTheme.dark,
          ),
          home: HomeScreen(store: widget.store),
        );
      },
    );
  }
}
