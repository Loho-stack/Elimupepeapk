import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/design/clay.dart';
import '../../data/idempotency.dart';
import '../../data/models/msafara_quests.dart';
import 'quest_session.dart';
import 'quest_widgets.dart';
import 'reading_controller.dart';
import 'reading_lock_bar.dart';

/// Lets the page move the PDF view ("Go to page N") without knowing which viewer is behind it.
class PdfNavigator {
  void Function(int page)? goTo;
}

/// Builds the PDF view for a local file, starting on [startPage]; calls [onPage] with 1-based pages.
typedef QuestPdfBuilder = Widget Function(
  BuildContext context,
  File file,
  int startPage,
  ValueChanged<int> onPage,
  PdfNavigator navigator,
);

/// The real viewer: pdfx, inside the app. The book never opens in another app.
Widget pdfxViewBuilder(BuildContext context, File file, int startPage, ValueChanged<int> onPage, PdfNavigator nav) =>
    _PdfPinchView(file: file, startPage: startPage, onPage: onPage, navigator: nav);

class _PdfPinchView extends StatefulWidget {
  const _PdfPinchView({required this.file, required this.startPage, required this.onPage, required this.navigator});
  final File file;
  final int startPage;
  final ValueChanged<int> onPage;
  final PdfNavigator navigator;

  @override
  State<_PdfPinchView> createState() => _PdfPinchViewState();
}

class _PdfPinchViewState extends State<_PdfPinchView> {
  late final PdfControllerPinch _controller = PdfControllerPinch(
    document: PdfDocument.openFile(widget.file.path),
    initialPage: widget.startPage,
  );

  @override
  void initState() {
    super.initState();
    widget.navigator.goTo = (page) => _controller.animateToPage(pageNumber: page);
  }

  @override
  void dispose() {
    widget.navigator.goTo = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PdfViewPinch(controller: _controller, onPageChanged: widget.onPage);
}

/// The reading screen of a book quest or a lesson quest. It pings the server every 20 seconds and on a
/// page change, only while it is on screen and the app is in the foreground, and shows the lock from
/// each reply.
class QuestReadPage extends StatefulWidget {
  const QuestReadPage({
    super.key,
    required this.session,
    required this.detail,
    required this.onAnswer,
    required this.onClose,
    this.fetchPdf,
    this.pdfBuilder = pdfxViewBuilder,
    this.pingInterval = const Duration(seconds: 20),
  });

  final MsafaraSession session;
  final QuestDetail detail;

  /// "Answer the questions".
  final VoidCallback onAnswer;

  /// Leave this screen (after a gate 409 the state screen is already routing).
  final VoidCallback onClose;

  /// Downloads the book into the cache. Null for a lesson.
  final Future<File> Function(String url)? fetchPdf;
  final QuestPdfBuilder pdfBuilder;
  final Duration pingInterval;

  @override
  State<QuestReadPage> createState() => _QuestReadPageState();
}

class _QuestReadPageState extends State<QuestReadPage> with WidgetsBindingObserver {
  late final ReadingController _reading;
  final PdfNavigator _nav = PdfNavigator();
  Future<File>? _pdf;
  ModalRoute<dynamic>? _route;

  QuestDetail get _d => widget.detail;
  bool get _isBook => _d.book != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reading = ReadingController(
      initial: _d.lock,
      initialPage: _d.book?.startPage,
      interval: widget.pingInterval,
      isVisible: () => mounted && (_route?.isCurrent ?? true),
      ping: (page) => widget.session.repo.ping(_d.no, page: page, key: newIdempotencyKey()),
      onError: (e) {
        widget.session.handleError(e);
        widget.onClose();
      },
    );
    _reading.addListener(_onLock);
    if (_isBook) {
      _startDownload();
    } else {
      // A lesson counts as read once it is on screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reading.start();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  void _startDownload() {
    final fetch = widget.fetchPdf;
    if (fetch == null) return;
    _pdf = fetch(_d.book!.pdfUrl);
    _pdf!.then((_) {
      // The book is on screen: the first ping goes out and the 20 second rhythm starts.
      if (mounted) _reading.start();
    }, onError: (_) {});
  }

  void _onLock() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _reading.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reading.removeListener(_onLock);
    _reading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session.strings;
    final bar = ReadingLockBar(
      strings: s,
      lock: _reading.lock,
      currentPage: _isBook ? _reading.page : null,
      pageCount: _d.book?.pageCount,
      onAnswer: widget.onAnswer,
      onGoToPage: _isBook ? (p) => _nav.goTo?.call(p) : null,
    );

    return QuestScaffold(
      title: _d.title,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(ClaySpace.s3),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
              child: SingleChildScrollView(child: bar),
            ),
          ),
          Expanded(child: _isBook ? _bookView(context) : _lessonView(context)),
        ],
      ),
    );
  }

  Widget _bookView(BuildContext context) {
    final s = widget.session.strings;
    final book = _d.book!;
    return FutureBuilder<File>(
      future: _pdf,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(ClaySpace.s4),
              child: ClayEmptyState(
                title: s.t('quest.download_failed'),
                icon: ClayIcons.offline,
                actionLabel: s.t('states.retry'),
                onAction: () => setState(_startDownload),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return Semantics(
            label: s.t('quest.downloading'),
            liveRegion: true,
            child: const Padding(
              padding: EdgeInsets.all(ClaySpace.s4),
              child: Column(children: [ClaySkeleton(height: 200)]),
            ),
          );
        }
        return widget.pdfBuilder(context, snap.data!, book.startPage, _reading.onPage, _nav);
      },
    );
  }

  Widget _lessonView(BuildContext context) {
    final lesson = _d.lesson!;
    final theme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(ClaySpace.s4),
      children: [
        Semantics(header: true, child: Text(lesson.title, style: theme.headlineSmall)),
        for (final p in lesson.paragraphs)
          Padding(
            padding: const EdgeInsets.only(top: ClaySpace.s3),
            child: Text(p, style: theme.bodyLarge?.copyWith(height: 1.5)),
          ),
        const SizedBox(height: ClaySpace.s6),
      ],
    );
  }
}
