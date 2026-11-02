import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_scope.dart';
import '../../core/config/env.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/ui/widgets.dart';
import '../auth/auth_cubit.dart';
import '../catalog/catalog_cubit.dart';
import '../collection/collection_cubit.dart';
import '../collection/collection_page.dart';
import '../deck/deck_page.dart';
import '../gacha/gacha_page.dart';
import '../home/home_page.dart';
import '../profile/profile_cubit.dart';
import '../profile/profile_page.dart';

/// Navigasi tab dari dalam halaman (tanpa BuildContext milik shell).
class ShellNavigator extends InheritedWidget {
  const ShellNavigator({
    super.key,
    required this.select,
    required super.child,
  });

  final ValueChanged<int> select;

  static ShellNavigator of(BuildContext context) {
    final navigator = context
        .dependOnInheritedWidgetOfExactType<ShellNavigator>();
    assert(navigator != null, 'ShellNavigator tidak ditemukan');
    return navigator!;
  }

  @override
  bool updateShouldNotify(ShellNavigator oldWidget) =>
      select != oldWidget.select;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  DateTime _lastCatalogSync = DateTime.now();

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    final elapsed = DateTime.now().difference(_lastCatalogSync);
    if (elapsed >= Env.catalogRefreshInterval) {
      _lastCatalogSync = DateTime.now();
      context.read<CatalogCubit>().load();
    }
    context.read<ProfileCubit>().refresh();

    final scope = AppScope.of(context);
    scope.repositories.telemetry.track('app_open', <String, dynamic>{
      'screen': 'resume',
    });
    scope.repositories.telemetry.flush();
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final auth = context.read<AuthCubit>();

    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<ProfileCubit>(
          create: (_) => ProfileCubit(scope.repositories.user, auth)..load(),
        ),
        BlocProvider<CollectionCubit>(
          create: (_) => CollectionCubit(scope.repositories.inventory)..load(),
        ),
      ],
      child: Builder(
        builder: (context) => _ShellScaffold(index: _index, onSelect: _select),
      ),
    );
  }
}

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ShellNavigator(
      select: onSelect,
      child: Scaffold(
        extendBody: true,
        body: AppBackground(
          child: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: index,
              children: const <Widget>[
                HomePage(),
                CollectionPage(),
                DeckPage(),
                GachaPage(),
                ProfilePage(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: onSelect,
          destinations: <NavigationDestination>[
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: strings.t('nav.home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.grid_view_outlined),
              selectedIcon: const Icon(Icons.grid_view_rounded),
              label: strings.t('nav.collection'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.style_outlined),
              selectedIcon: const Icon(Icons.style_rounded),
              label: strings.t('nav.deck'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.auto_awesome_outlined),
              selectedIcon: const Icon(Icons.auto_awesome_rounded),
              label: strings.t('nav.gacha'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: strings.t('nav.profile'),
            ),
          ],
        ),
      ),
    );
  }
}
