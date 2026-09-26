import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/api/api_exception.dart';
import '../models/verification_task.dart';
import '../verification_providers.dart';

/// Verification task list screen.
class VerificationTaskListScreen extends ConsumerWidget {
  const VerificationTaskListScreen({super.key});

  static const Color orange = Color(0xFFFF5A00);
  static const Color lightOrange = Color(0xFFFFF0E8);
  static const Color cardFill = Color(0xFFFFFBF9);
  static const Color cardBorder = Color(0xFFFFE2D3);
  static const Color darkText = Color(0xFF202625);
  static const Color secondaryText = Color(0xFF59635F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(myVerificationTasksProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'Verification Tasks',
          style: TextStyle(
            color: darkText,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: darkText),
      ),
      body: RefreshIndicator(
        color: orange,
        onRefresh: () => ref.refresh(myVerificationTasksProvider.future),
        child: switch (tasks) {
          AsyncData(:final value) when value.isEmpty => const _EmptyState(),
          AsyncData(:final value) => _TaskList(tasks: value),
          AsyncError(:final error) => _ErrorState(
            error: error,
            onRetry: () => ref.invalidate(myVerificationTasksProvider),
          ),
          _ => const Center(child: CircularProgressIndicator(color: orange)),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
      children: [
        const _ScreenHeader(),
        const SizedBox(height: 24),
        _TaskCardSection(tasks: tasks),
        const SizedBox(height: 20),
        const _InfoBanner(),
      ],
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: VerificationTaskListScreen.lightOrange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.fact_check_rounded,
                size: 32,
                color: VerificationTaskListScreen.orange,
              ),
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: Text(
                'My Tasks',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: VerificationTaskListScreen.darkText,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Review and complete physical asset verification tasks assigned to you.',
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: VerificationTaskListScreen.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _TaskCardSection extends StatelessWidget {
  const _TaskCardSection({required this.tasks});

  final List<VerificationTask> tasks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VerificationTaskListScreen.cardFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: VerificationTaskListScreen.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Assigned Tasks',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: VerificationTaskListScreen.darkText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: VerificationTaskListScreen.lightOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${tasks.length} total',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: VerificationTaskListScreen.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < tasks.length; i++) ...[
            _TaskTile(task: tasks[i]),
            if (i < tasks.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final VerificationTask task;

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = task.status == VerificationTaskStatus.completed;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7E6)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/verification/${task.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFFE0F2F1)
                        : VerificationTaskListScreen.lightOrange,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.assignment_outlined,
                    color: isCompleted
                        ? const Color(0xFF00897B)
                        : VerificationTaskListScreen.orange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${task.assetCode}: ${task.assetName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: VerificationTaskListScreen.darkText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Due ${_formatDate(task.dueDate)} · ${task.campaignName}'
                        '${task.isOverdue ? ' (overdue)' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: VerificationTaskListScreen.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(task: task),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9AA19E),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.task});

  final VerificationTask task;

  @override
  Widget build(BuildContext context) {
    final isOverdue = task.isPending && task.isOverdue;

    final (Color bg, Color fg, String text) = switch (task.status) {
      VerificationTaskStatus.completed => (
        const Color(0xFFE0F2F1),
        const Color(0xFF00796B),
        'Completed',
      ),
      VerificationTaskStatus.pending when isOverdue => (
        const Color(0xFFFFEBEE),
        const Color(0xFFC62828),
        'Overdue',
      ),
      VerificationTaskStatus.pending => (
        const Color(0xFFFFF3E0),
        const Color(0xFFE65100),
        'Pending',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VerificationTaskListScreen.lightOrange,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.qr_code_scanner_rounded,
            color: VerificationTaskListScreen.orange,
            size: 22,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'You can also scan asset QR codes from the officer dashboard.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: VerificationTaskListScreen.darkText,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
      children: [
        const _ScreenHeader(),
        const SizedBox(height: 48),
        Center(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: VerificationTaskListScreen.lightOrange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  size: 32,
                  color: VerificationTaskListScreen.orange,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No verification tasks',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: VerificationTaskListScreen.darkText,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'No verification tasks assigned to you.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: VerificationTaskListScreen.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load tasks',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: VerificationTaskListScreen.darkText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: VerificationTaskListScreen.secondaryText,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
