import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../maintenance/maintenance_providers.dart';
import '../../maintenance/widgets/fault_tile.dart';
import '../widgets/dashboard_section.dart';
import '../widgets/find_asset_card.dart';

/// Staff home: find an asset, report a fault, and track reported faults.
class StaffDashboardBody extends ConsumerWidget {
  const StaffDashboardBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faults = ref.watch(myFaultReportsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FindAssetCard(),
        DashboardPreview(
          title: 'My fault reports',
          data: faults,
          emptyLabel: 'You haven\'t reported any faults.',
          onSeeAll: () => context.go('/faults'),
          itemBuilder: FaultTile.new,
        ),
      ],
    );
  }
}
