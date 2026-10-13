import 'package:flutter/material.dart';
import 'package:elimupepe/core/theme/app_theme.dart';
import 'package:elimupepe/core/services/parent_api_service.dart';
import 'package:elimupepe/features/parental_control/parent_child_detail_screen.dart';

class LinkedChildrenScreen extends StatefulWidget {
  final List<ParentLinkedChild> children;

  const LinkedChildrenScreen({super.key, required this.children});

  @override
  State<LinkedChildrenScreen> createState() => _LinkedChildrenScreenState();
}

class _LinkedChildrenScreenState extends State<LinkedChildrenScreen> {
  late List<ParentLinkedChild> _children;

  @override
  void initState() {
    super.initState();
    _children = List<ParentLinkedChild>.from(widget.children);
  }

  void _openChild(ParentLinkedChild child) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ParentChildDetailScreen(child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      appBar: AppBar(
        title: const Text('Linked Children'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _children.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.family_restroom,
                        size: 64,
                        color: AppColors.primaryBlue.withValues(alpha: 0.6)),
                    const SizedBox(height: 12),
                    const Text(
                      'No children linked yet',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Use the web dashboard to link learners to your parent account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blueGrey.shade600),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _children.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final child = _children[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor:
                          AppColors.primaryBlue.withValues(alpha: 0.12),
                      backgroundImage:
                          (child.avatarUrl != null && child.avatarUrl!.isNotEmpty)
                              ? NetworkImage(child.avatarUrl!)
                              : null,
                      child:
                          (child.avatarUrl == null || child.avatarUrl!.isEmpty)
                              ? Text(
                                  child.name.isNotEmpty
                                      ? child.name[0].toUpperCase()
                                      : 'S',
                                  style: const TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                )
                              : null,
                    ),
                    title: Text(
                      child.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          '${child.grade}${child.className != null ? ' • ${child.className}' : ''}',
                          style: TextStyle(
                            color: Colors.blueGrey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        if (child.schoolName != null &&
                            child.schoolName!.isNotEmpty)
                          Text(
                            child.schoolName!,
                            style: TextStyle(
                              color: Colors.blueGrey.shade500,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openChild(child),
                  ),
                );
              },
            ),
    );
  }
}