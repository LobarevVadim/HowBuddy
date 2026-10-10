import 'package:flutter/material.dart';

import '../../app_style.dart';
import '../../models/app_models.dart';
import '../../shared/app_widgets.dart';
import '../learning/lesson_tree.dart';
import '../notepad/notepad_tree_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.account,
    required this.onLogout,
    this.initialIndex = 0,
    this.topicId = 'immortal',
    super.key,
  });

  final Account account;
  final VoidCallback onLogout;
  final int initialIndex;
  final String topicId;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _selectedIndex = widget.initialIndex;
  late String _topicId = widget.topicId;
  int _notepadRefreshKey = 0;

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
  }

  void _openTopicFromNotepad(String topicId) {
    setState(() {
      _topicId = topicId;
      _selectedIndex = 0;
    });
  }

  void _refreshNotepadProgress() {
    setState(() => _notepadRefreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TreeLessonsPage(
        key: ValueKey(_topicId),
        topicId: _topicId,
        onTopicSelected: _openTopicFromNotepad,
        onTopicCompleted: _refreshNotepadProgress,
      ),
      NotepadTreePage(
        key: ValueKey(_notepadRefreshKey),
        onTopicSelected: _openTopicFromNotepad,
      ),
      const SignedInTabPage(
        icon: Icons.workspace_premium_outlined,
        title: 'XP',
        subtitle: 'Track progress and keep building momentum.',
      ),
      ProfileTabPage(account: widget.account, onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.park_outlined),
            selectedIcon: Icon(Icons.park_rounded),
            label: 'Tree',
          ),
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            selectedIcon: Icon(Icons.note_alt_rounded),
            label: 'Notepad',
          ),
          NavigationDestination(
            icon: Icon(Icons.workspace_premium_outlined),
            selectedIcon: Icon(Icons.workspace_premium_rounded),
            label: 'XP',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class SignedInTabPage extends StatelessWidget {
  const SignedInTabPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: AppSizes.tabHeroIcon),
            const SizedBox(height: AppSpacing.tabIconGap),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.tabTextGap),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTabPage extends StatelessWidget {
  const ProfileTabPage({
    required this.account,
    required this.onLogout,
    super.key,
  });

  final Account account;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.tabPagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_rounded,
              color: AppColors.success,
              size: AppSizes.tabHeroIcon,
            ),
            const SizedBox(height: AppSpacing.tabIconGap),
            Text(
              'Hi, ${account.fullName}',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.tabTextGap),
            Text(
              account.email,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.mutedText),
            ),
            const SizedBox(height: AppSpacing.profileLogoutGap),
            PrimaryButton(text: 'Logout', onPressed: onLogout),
          ],
        ),
      ),
    );
  }
}
