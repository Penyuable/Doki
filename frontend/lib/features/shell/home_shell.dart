import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_scope.dart';
import '../../core/config/env.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../auth/auth_cubit.dart';
import '../catalog/catalog_cubit.dart';
import '../collection/collection_cubit.dart';
import '../collection/collection_page.dart';
import '../deck/deck_page.dart';
import '../gacha/gacha_page.dart';
import '../home/home_page.dart';
import '../onboarding/how_to_play.dart';
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
    final navigator =
        context.dependOnInheritedWidgetOfExactType<ShellNavigator>();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowHowToPlay(context);
    });
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
        bottomNavigationBar: _ModernNavBar(
          index: index,
          onSelect: onSelect,
          items: <_NavItem>[
            _NavItem(Icons.home_rounded, strings.t('nav.home')),
            _NavItem(Icons.grid_view_rounded, strings.t('nav.collection')),
            _NavItem(Icons.style_rounded, strings.t('nav.deck')),
            _NavItem(Icons.auto_awesome_rounded, strings.t('nav.gacha')),
            _NavItem(Icons.person_rounded, strings.t('nav.profile')),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// Navigasi mengambang gelap: tab aktif melebar menjadi pil terang berikon +
/// label, tab lain hanya ikon.
class _ModernNavBar extends StatelessWidget {
  const _ModernNavBar({
    required this.index,
    required this.onSelect,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Clay(
        color: AppTheme.ink,
        radius: 999,
        depth: 0.8,
        padding: const EdgeInsets.all(7),
        child: Row(
          children: <Widget>[
            for (var i = 0; i < items.length; i++)
              Expanded(
                flex: i == index ? 5 : 3,
                child: _NavButton(
                  item: items[i],
                  selected: i == index,
                  onTap: () => onSelect(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: 50,
          decoration: BoxDecoration(
            color: selected ? AppTheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                item.icon,
                size: 22,
                color: selected
                    ? AppTheme.primary
                    : Colors.white.withValues(alpha: 0.6),
              ),
              if (selected) ...<Widget>[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
