import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/auth/me_provider.dart';
import '../../../shared/widgets/ui.dart';
import '../maintenance_providers.dart';
import '../models/fault_report.dart';

/// One maintenance record — a fault report and where it is in the repair
/// lifecycle — plus, for the assigned officer, FR-037's progress update.
/// Route: `/maintenance/:id`, with the list's copy passed as extra so the
/// screen renders at once; the record is then re-read by id so the status
/// is current.
class FaultDetailScreen extends ConsumerWidget {
  const FaultDetailScreen({super.key, required this.id, this.report});

  final String id;
  final FaultReport? report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(maintenanceRecordProvider(id));
    // A Staff reporter may not be able to re-read a record outside their
    // department (the API scopes by asset department) — keep showing the
    // copy they opened rather than an error.
    final initial = report;
    final AsyncValue<FaultReport> value = live.hasValue
        ? AsyncData(live.requireValue)
        : initial != null
        ? AsyncData(initial)
        : live;

    return Scaffold(
      appBar: AppBar(title: const Text('Fault report')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(maintenanceRecordProvider(id).future),
        child: AsyncView(
          value: value,
          errorTitle: 'Couldn\'t load this record',
          onRetry: () => ref.invalidate(maintenanceRecordProvider(id)),
          data: (record) => _RecordBody(record: record),
        ),
      ),
    );
  }
}

class _RecordBody extends StatelessWidget {
  const _RecordBody({required this.record});

  final FaultReport record;

  @override
  Widget build(BuildContext context) {
    final tone = StatusTone.of(record.statusLabel);
    String human(String? raw) =>
        raw == null || raw.isEmpty ? 'Not provided' : humanizeStatus(raw);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.pageInsets,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconTile(
                      record.isPreventive
                          ? Icons.event_repeat_outlined
                          : Icons.build_circle_outlined,
                      tone: tone,
                      size: 48,
                    ),
                    const Spacer(),
                    if (record.priority != null) ...[
                      StatusPill(humanizeStatus(record.priority!)),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Semantics(
                      label: 'Status: ${record.statusLabel}',
                      child: StatusPill(record.statusLabel, tone: tone),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(record.description, style: context.text.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                if (record.isCancelled)
                  Notice(
                    tone: StatusTone.danger,
                    title: 'Cancelled',
                    message:
                        record.cancellationReason ??
                        'This request was cancelled.',
                  )
                else
                  _Progress(stage: _stageOf(record)),
              ],
            ),
          ),
        ),
        _ProgressUpdate(record: record),
        const SectionHeader('Details'),
        ListCard(
          children: [
            InfoRow(
              icon: Icons.qr_code_2,
              label: 'Asset',
              value: record.assetLabel.isNotEmpty
                  ? record.assetLabel
                  : 'Not provided',
            ),
            if (record.type != null)
              InfoRow(
                icon: Icons.category_outlined,
                label: 'Type',
                value: humanizeStatus(record.type!),
              ),
            InfoRow(
              icon: Icons.health_and_safety_outlined,
              label: 'Condition',
              value: human(record.observedCondition),
            ),
            InfoRow(
              icon: Icons.event_outlined,
              label: 'Reported',
              value: formatDate(record.reportedAt),
            ),
            if (record.reportedByName?.isNotEmpty ?? false)
              InfoRow(
                icon: Icons.person_outline,
                label: 'Reported by',
                value: record.reportedByName!,
              ),
            if (record.reportedByEmail?.isNotEmpty ?? false)
              InfoRow(
                icon: Icons.alternate_email,
                label: 'Email',
                value: record.reportedByEmail!,
              ),
            if (record.assigneeEmail != null)
              InfoRow(
                icon: Icons.engineering_outlined,
                label: 'Assigned to',
                value: record.assigneeEmail!,
              ),
            if (record.estimatedCost != null)
              InfoRow(
                icon: Icons.request_quote_outlined,
                label: 'Estimated cost',
                value: formatMoney(record.estimatedCost!),
              ),
          ],
        ),
        if (record.workPerformed != null || record.completionDate != null) ...[
          const SectionHeader('Outcome'),
          ListCard(
            children: [
              if (record.workPerformed != null)
                InfoRow(
                  icon: Icons.handyman_outlined,
                  label: 'Work performed',
                  value: record.workPerformed!,
                ),
              if (record.completionDate != null)
                InfoRow(
                  icon: Icons.event_available_outlined,
                  label: 'Completed',
                  value: formatDate(record.completionDate!),
                ),
              if (record.actualCost != null)
                InfoRow(
                  icon: Icons.payments_outlined,
                  label: 'Actual cost',
                  value: formatMoney(record.actualCost!),
                ),
              if (record.resultingCondition != null)
                InfoRow(
                  icon: Icons.health_and_safety_outlined,
                  label: 'Resulting condition',
                  value: human(record.resultingCondition),
                ),
            ],
          ),
        ],
        if (record.photoUrl?.isNotEmpty ?? false) ...[
          const SectionHeader('Photo evidence'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              record.photoUrl!,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                height: 120,
                child: Center(child: Text('Photo could not be loaded')),
              ),
            ),
          ),
        ],
        if (record.assetId.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: () => context.push('/assets/${record.assetId}'),
            icon: const Icon(Icons.description_outlined, size: 20),
            label: const Text('Open asset record'),
          ),
        ],
      ],
    );
  }

  /// 0 requested · 1 approved · 2 in progress · 3 completed.
  static int _stageOf(FaultReport r) => r.isOpen
      ? 0
      : r.isApproved
      ? 1
      : r.isUnderWay
      ? 2
      : 3;
}

/// FR-037, mobile side (SRS §3.4: "Progress update only"). The only
/// transition the field client makes is APPROVED → IN_PROGRESS, by the
/// assigned officer; approval/assignment/costing and completion stay on the
/// web console. Everyone else sees what the record is waiting for.
class _ProgressUpdate extends ConsumerWidget {
  const _ProgressUpdate({required this.record});

  final FaultReport record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canManageMaintenanceProvider)) return const SizedBox();
    final me = ref.watch(meProvider).asData?.value;
    final isAssignee =
        me != null &&
        ((record.assigneeId != null && record.assigneeId == me.id) ||
            (record.assigneeEmail != null &&
                record.assigneeEmail!.toLowerCase() == me.email.toLowerCase()));
    final state = ref.watch(startMaintenanceControllerProvider);

    final Widget child;
    if (record.isApproved && isAssignee) {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Approved and assigned to you. Start work when you begin the '
            'repair — the asset is marked under maintenance until it\'s '
            'completed.',
            style: context.mutedBody,
          ),
          if (state.hasError) ...[
            const SizedBox(height: AppSpacing.md),
            Notice(
              tone: StatusTone.danger,
              message: errorMessageFor(
                state.error!,
                fallback: 'Couldn\'t start this work. Try again.',
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SubmitButton(
            label: 'Start work',
            busyLabel: 'Starting…',
            icon: Icons.play_arrow_rounded,
            busy: state.isLoading,
            onPressed: () => _start(context, ref),
          ),
        ],
      );
    } else if (record.isApproved) {
      child = Notice(
        message:
            'Approved — waiting for '
            '${record.assigneeEmail ?? 'the assigned officer'} to start work.',
      );
    } else if (record.isOpen) {
      child = const Notice(
        message: 'Waiting for approval and assignment on the web console.',
      );
    } else if (record.isUnderWay) {
      child = Notice(
        message: isAssignee
            ? 'Work under way. Record the outcome — work performed, actual '
                  'cost and resulting condition — on the web console to '
                  'complete it.'
            : 'Work under way.',
      );
    } else {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: child,
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.play_arrow_rounded),
        title: const Text('Start work?'),
        content: Text(
          '${record.assetCode.isNotEmpty ? record.assetCode : 'The asset'} '
          'will be marked under maintenance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start work'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(startMaintenanceControllerProvider.notifier)
        .start(record.id);
    if (ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Work started.')));
    }
  }
}

/// Requested → Approved → In progress → Completed (SRS Fig. 7).
class _Progress extends StatelessWidget {
  const _Progress({required this.stage});

  final int stage;

  static const _labels = ['Requested', 'Approved', 'In progress', 'Completed'];

  @override
  Widget build(BuildContext context) {
    final active = context.colors.primary;
    final idle = context.colors.outlineVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(top: 10),
                color: i <= stage ? active : idle,
              ),
            ),
          Column(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: i <= stage ? active : idle,
                child: i < stage || (i == stage && stage == 3)
                    ? Icon(
                        Icons.check,
                        size: 14,
                        color: context.colors.onPrimary,
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _labels[i],
                style: context.text.labelSmall?.copyWith(
                  color: i <= stage
                      ? context.colors.onSurface
                      : context.colors.onSurfaceVariant,
                  fontWeight: i == stage ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
