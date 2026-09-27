import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/api/api_exception.dart';
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
      body: switch (transfers) {
        AsyncData(:final value) when value.isEmpty => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No transfers yet.\nTap + to initiate a transfer request.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        AsyncData(:final value) => RefreshIndicator(
            onRefresh: () => ref.refresh(transferListProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              itemCount: value.length,
              itemBuilder: (context, index) =>
                  TransferSummaryCard(transfer: value[index]),
            ),
          ),
        AsyncError(:final error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    error is ApiException
                        ? error.message
                        : 'Could not load transfers.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => ref.invalidate(transferListProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
