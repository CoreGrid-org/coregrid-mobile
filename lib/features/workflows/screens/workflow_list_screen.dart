import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/api/api_exception.dart';
import '../models/agent_workflow.dart';
import '../workflows_providers.dart';

/// Agent workflow list screen. Route: `/workflows`.
class WorkflowListScreen extends ConsumerWidget {
  const WorkflowListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflows = ref.watch(agentWorkflowsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Workflows'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Request Evaluation',
            onPressed: () => context.push('/workflows/new'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/workflows/new'),
        icon: const Icon(Icons.add),
        label: const Text('Request Evaluation'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(agentWorkflowsProvider.future),
        child: switch (workflows) {
          AsyncData(:final value) when value.isEmpty => const _EmptyState(),
          AsyncData(:final value) => _WorkflowList(workflows: value),
          AsyncError(:final error) => _ErrorState(
            error: error,
            onRetry: () => ref.invalidate(agentWorkflowsProvider),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _WorkflowList extends StatelessWidget {
  const _WorkflowList({required this.workflows});

  final List<AgentWorkflow> workflows;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: workflows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final workflow = workflows[index];
        return Card(
          child: ListTile(
            onTap: () => context.push('/workflows/${workflow.id}'),
            leading: Icon(_iconFor(workflow)),
            title: Text('${workflow.assetCode}: ${workflow.objective}'),
            subtitle: Text(_subtitleFor(workflow)),
            trailing: Chip(
              label: Text(workflow.status),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        );
      },
    );
  }

  IconData _iconFor(AgentWorkflow workflow) {
    if (workflow.isFailed) return Icons.error_outline;
    if (workflow.isResolved) return Icons.task_alt;
    return Icons.hourglass_top_outlined;
  }

  String _subtitleFor(AgentWorkflow workflow) {
    if (workflow.isFailed) return workflow.failureReason ?? 'Failed';
    if (workflow.isResolved) {
      return workflow.recommendation ?? 'Completed';
    }
    return 'In progress';
  }
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
                    Icons.smart_toy_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  const Text('No agent evaluations yet.'),
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
        : 'Couldn\'t load agent workflows. Try again.';
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
                  OutlinedButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
