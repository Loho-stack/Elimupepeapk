import 'package:flutter/material.dart';

import '../../core/design/clay.dart';
import '../../data/models/msafara_quests.dart';
import '../student/widgets/adaptive.dart';
import 'quest_strings.dart';

/// The lock ring and its message, shown above the book or lesson. It only displays [lock], the last
/// server reply: running, paused (the page is outside the quest's pages) or unlocked.
class ReadingLockBar extends StatelessWidget {
  const ReadingLockBar({
    super.key,
    required this.strings,
    required this.lock,
    required this.onAnswer,
    this.onGoToPage,
    this.currentPage,
    this.pageCount,
  });

  final QuestStrings strings;
  final QuestLock lock;

  /// "Answer the questions", shown once unlocked.
  final VoidCallback onAnswer;

  /// "Go to page N", shown while paused (books only).
  final void Function(int page)? onGoToPage;
  final int? currentPage;
  final int? pageCount;

  static int minutesLeft(QuestLock l) => l.remaining <= 0 ? 0 : (l.remaining / 60).ceil();

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final theme = Theme.of(context).textTheme;
    final paused = !lock.unlocked && !lock.inRange;
    final from = lock.pageFrom;
    final to = lock.pageTo;

    final Widget message;
    if (lock.unlocked) {
      message = Semantics(
        liveRegion: true,
        container: true,
        child: Text(s.t('quest.unlocked'), style: theme.titleSmall),
      );
    } else if (paused) {
      message = Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('quest.lock_paused'), style: theme.titleSmall),
            if (from != null && to != null)
              Text(s.t('quest.off_pages', {'from': from, 'to': to}), style: theme.bodyMedium),
          ],
        ),
      );
    } else {
      message = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${s.t('quest.keep_reading')} ${minutesLeft(lock)} ${s.t('quest.minutes_to_go')}',
            style: theme.titleSmall,
          ),
          Text(s.t('quest.opens_after'), style: theme.bodySmall),
        ],
      );
    }

    final ring = ClayProgressRing(
      value: lock.unlocked ? 1 : lock.fraction,
      size: 56,
      semanticLabel: s.t('quest.lock_label'),
      child: lock.unlocked
          ? const Icon(ClayIcons.check, size: 24)
          : Padding(
              padding: const EdgeInsets.all(8),
              child: FittedBox(fit: BoxFit.scaleDown, child: Text('${minutesLeft(lock)}', style: theme.labelLarge)),
            ),
    );

    return ClayCard(
      tone: lock.unlocked ? ClayCardTone.green : (paused ? ClayCardTone.rose : ClayCardTone.soft),
      tight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LeadingAndText(leading: ring, text: message),
          if (currentPage != null && pageCount != null) ...[
            const SizedBox(height: ClaySpace.s2),
            Text(s.t('quest.page_of', {'page': currentPage!, 'total': pageCount!}), style: theme.bodySmall),
          ],
          if (from != null && to != null && !paused)
            Text(s.t('quest.pages', {'from': from, 'to': to}), style: theme.bodySmall),
          if (lock.unlocked) ...[
            const SizedBox(height: ClaySpace.s3),
            ClayButton(label: s.t('quest.answer_questions'), icon: ClayIcons.chevronRight, onPressed: onAnswer),
          ] else if (paused && from != null && onGoToPage != null) ...[
            const SizedBox(height: ClaySpace.s3),
            ClayButton(
              label: s.t('quest.back_to_pages', {'from': from}),
              variant: ClayButtonVariant.secondary,
              onPressed: () => onGoToPage!(from),
            ),
          ],
        ],
      ),
    );
  }
}
