import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/ui.dart';
import '../transfers_providers.dart';
import '../widgets/transfer_summary_card.dart';

/// Entry screen for eatures/transfers/ - shows the current user's
/// org-scoped transfer list (FR-043) and provides a FAB to initiate a new
/// transfer request. Also serves as the backing view for the dashboard
/// Transfer quick action.
class TransferListScreen extends ConsumerWidget {
  const TransferListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(transferListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transfers')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new_transfer_fab',
        onPressed: () => context.push('/transfers/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(transferListProvider.future),
        child: AsyncView(
          value: transfers,
          errorTitle: 'Couldn\'t load transfers',
          onRetry: () => ref.invalidate(transferListProvider),
          isEmpty: (value) => value.isEmpty,
          empty: const MessageView(
            icon: Icons.local_shipping_outlined,
            title: 'No transfers yet',
            message: 'Tap New Request to move an asset to another department.',
          ),
          data: (value) => ListView(
            padding: AppSpacing.pageInsetsFab,
            children: [
              ListCard(
                children: [
                  for (final t in value) TransferSummaryCard(transfer: t),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
