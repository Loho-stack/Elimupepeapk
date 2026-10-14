import 'package:flutter/material.dart';

import '../../../core/design/clay.dart';
import '../../../data/api_error.dart';
import '../load_controller.dart';

/// The states every data screen shares: skeleton on the first load, a friendly
/// error with a retry when there is nothing to show, and the data (with an
/// offline banner when the last refresh failed) otherwise. Pull to refresh works in
/// every state, including the error page.
class LoadView<T> extends StatelessWidget {
  const LoadView({
    super.key,
    required this.controller,
    required this.skeleton,
    required this.builder,
    this.loadingLabel = 'Loading',
  });

  final LoadController<T> controller;
  final Widget skeleton;
  final String loadingLabel;

  /// Builds the content for loaded data; [banner] is null or the offline banner to put at the top.
  final Widget Function(BuildContext context, T data, Widget? banner) builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final data = controller.data;
        final Widget child;
        if (data != null) {
          child = builder(
            context,
            data,
            controller.stale
                ? OfflineBanner(
                    error: controller.error!,
                    onRetry: controller.load,
                  )
                : null,
          );
        } else if (controller.error != null) {
          child = _Scrollable(
            child: ErrorView(
              error: controller.error!,
              onRetry: controller.load,
              busy: controller.loading,
            ),
          );
        } else {
          child = Semantics(
            label: loadingLabel,
            liveRegion: true,
            child: skeleton,
          );
        }
        return RefreshIndicator(onRefresh: controller.refresh, child: child);
      },
    );
  }
}

/// A scroll view that is always scrollable, so pull to refresh works on short content.
class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(ClaySpace.s4),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: c.maxHeight - 2 * ClaySpace.s4),
        child: Center(child: child),
      ),
    ),
  );
}

/// A friendly message for an [AppApiError], never the server text.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    this.busy = false,
  });
  final AppApiError error;
  final VoidCallback onRetry;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final offline = error is OfflineError;
    final locked =
        error is SubscriptionRequiredError || error is AccessExpiredError;
    return ClayEmptyState(
      title: switch (error) {
        OfflineError() => 'You are offline',
        SubscriptionRequiredError() => 'A subscription is needed',
        AccessExpiredError() => 'Your time here has ended',
        NotFoundError() => 'We could not find that',
        _ => 'Something went wrong',
      },
      message: error.message,
      icon: offline
          ? ClayIcons.offline
          : (locked ? ClayIcons.lock : ClayIcons.warning),
      locked: locked,
      actionLabel: error is SessionExpiredError || busy ? null : 'Try again',
      onAction: error is SessionExpiredError || busy ? null : onRetry,
    );
  }
}

/// Shown above old data when a refresh failed.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.error, required this.onRetry});
  final AppApiError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final offline = error is OfflineError;
    final text = offline
        ? 'You are offline. Showing what you saw last.'
        : 'Could not refresh. Showing what you saw last.';
    return Semantics(
      container: true,
      liveRegion: true,
      label: text,
      child: ClayCard(
        tone: ClayCardTone.soft,
        tight: true,
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                offline ? ClayIcons.offline : ClayIcons.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: ClaySpace.s2),
            Expanded(
              child: ExcludeSemantics(
                child: Text(text, style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
            ClayIconButton(
              icon: ClayIcons.refresh,
              label: 'Try again',
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// A screen heading inside a list.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: ClaySpace.s5, bottom: ClaySpace.s2),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}
