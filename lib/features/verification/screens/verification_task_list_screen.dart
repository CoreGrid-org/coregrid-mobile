import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/api/api_exception.dart';
import '../models/verification_task.dart';
import '../verification_providers.dart';

/// FR-058 — the signed-in officer's outstanding verification tasks, ordered
/// by due date (server-side). Route: `/verification`.
class VerificationTaskListScreen extends ConsumerWidget {
  const VerificationTaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(myVerificationTasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verification Tasks')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myVerificationTasksProvider.future),
        child: switch (tasks) {
          AsyncData(:final value) when value.isEmpty => const _EmptyState(),
          AsyncData(:final value) => _TaskList(tasks: value),
          AsyncError(:final error) => _ErrorState(
            error: error,
            onRetry: () => ref.invalidate(myVerificationTasksProvider),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.tasks});

  final List<VerificationTask> tasks;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _TaskCard(task: task);
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final VerificationTask task;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = switch (task.status) {
      VerificationTaskStatus.completed => colors.primary,
      VerificationTaskStatus.pending when task.isOverdue => colors.error,
      VerificationTaskStatus.pending => colors.onSurfaceVariant,
    };

    return Card(
      child: ListTile(
        onTap: () => context.push('/verification/${task.id}'),
        leading: Icon(
          task.status == VerificationTaskStatus.completed
              ? Icons.check_circle_outline
              : Icons.fact_check_outlined,
          color: statusColor,
        ),
        title: Text('${task.assetCode} — ${task.assetName}'),
        subtitle: Text(
          '${task.campaignName} · Due ${_formatDate(task.dueDate)}'
          '${task.isOverdue ? ' (overdue)' : ''}',
        ),
        trailing: Chip(
          label: Text(task.status.apiValue),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: statusColor.withValues(alpha: 0.12),
          labelStyle: TextStyle(color: statusColor),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.task_alt,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  const Text('No verification tasks assigned to you.'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : 'Couldn\'t load verification tasks. Try again.';
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
