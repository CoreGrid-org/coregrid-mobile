import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/auth/auth_controller.dart';
import '../shared/auth/auth_state.dart';
import '../shared/widgets/ui.dart';

/// Branch order of the router's `StatefulShellRoute` — keep in sync with
/// `router.dart`.
abstract final class ShellBranch {
  static const home = 0;
  static const verify = 1;
  static const workflows = 2;
  static const faults = 3;
  static const account = 4;
}

class _Tab {
  const _Tab(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

const _tabs = {
  ShellBranch.home: _Tab(Icons.home_outlined, Icons.home_rounded, 'Home'),
  ShellBranch.verify: _Tab(
    Icons.fact_check_outlined,
    Icons.fact_check_rounded,
    'Verify',
  ),
  ShellBranch.workflows: _Tab(
    Icons.auto_awesome_outlined,
    Icons.auto_awesome_rounded,
    'Workflows',
  ),
  ShellBranch.faults: _Tab(
    Icons.handyman_outlined,
    Icons.handyman_rounded,
    'Faults',
  ),
  ShellBranch.account: _Tab(
    Icons.account_circle_outlined,
    Icons.account_circle_rounded,
    'Account',
  ),
};

/// Which tabs a role sees. Verification and workflows are Officer-only on
/// mobile (the router also guards them); a session whose role couldn't be
/// resolved gets just Home and Account.
List<int> shellBranchesFor(String? role) => switch (role) {
  'InventoryOfficer' => const [
    ShellBranch.home,
    ShellBranch.verify,
    ShellBranch.workflows,
    ShellBranch.faults,
    ShellBranch.account,
  ],
  'Staff' => const [ShellBranch.home, ShellBranch.faults, ShellBranch.account],
  _ => const [ShellBranch.home, ShellBranch.account],
};

/// The signed-in app frame: each tab keeps its own navigation stack
/// (go_router `StatefulShellRoute.indexedStack`), full-screen flows such as
/// scan, asset detail and forms push over it from the root navigator.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthUnauthenticated) context.go('/sign-in');
    });

    final auth = ref.watch(authControllerProvider);
    final role = auth is AuthAuthenticated ? auth.role : null;
    final branches = shellBranchesFor(role);
    final selected = branches.indexOf(navigationShell.currentIndex);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _DockedBar(
        child: NavigationBar(
          selectedIndex: selected < 0 ? 0 : selected,
          onDestinationSelected: (i) => navigationShell.goBranch(
            branches[i],
            // Re-tapping the current tab pops it back to its root.
            initialLocation: branches[i] == navigationShell.currentIndex,
          ),
          destinations: [
            for (final b in branches)
              NavigationDestination(
                icon: Icon(_tabs[b]!.icon),
                selectedIcon: Icon(_tabs[b]!.selectedIcon),
                label: _tabs[b]!.label,
                tooltip: '',
              ),
          ],
        ),
      ),
    );
  }
}

/// The tab bar's surface: full-width, docked to the bottom edge, with a
/// hairline top border (the theme keeps the bar itself transparent).
class _DockedBar extends StatelessWidget {
  const _DockedBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isLight = context.theme.brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : context.colors.surfaceContainer,
        border: Border(top: BorderSide(color: context.colors.outlineVariant)),
      ),
      child: child,
    );
  }
}
