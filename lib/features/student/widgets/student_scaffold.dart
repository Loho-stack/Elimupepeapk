import 'package:flutter/material.dart';

import '../../../app/shell/student_shell.dart' show ShellActions;
import '../../../core/design/clay.dart';

/// Page frame for the student's tab screens: Clay app bar with the drawer button
/// (when inside the shell) and the page background.
class StudentScaffold extends StatelessWidget {
  const StudentScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  });
  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final openMenu = ShellActions.maybeOf(context)?.openMenu;
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    return Scaffold(
      backgroundColor: ClayTokens.of(context).palette.page,
      appBar: ClayAppBar(
        title: title,
        actions: actions,
        leading: !canPop && openMenu != null
            ? ClayIconButton(
                icon: ClayIcons.menu,
                label: 'Menu',
                onPressed: openMenu,
              )
            : null,
      ),
      body: body,
    );
  }
}
