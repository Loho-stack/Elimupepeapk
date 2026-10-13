import 'package:flutter/material.dart';
import 'package:elimupepe/core/theme/app_theme.dart';
import 'package:elimupepe/core/services/parent_api_service.dart';

class ParentControlsScreen extends StatefulWidget {
  final List<ParentLinkedChild> children;

  const ParentControlsScreen({super.key, required this.children});

  @override
  State<ParentControlsScreen> createState() => _ParentControlsScreenState();
}

class _ParentControlsScreenState extends State<ParentControlsScreen> {
  late Map<String, int> _screenTime;
  late Map<String, bool> _accessEnabled;
  final Map<String, bool> _saving = {};

  @override
  void initState() {
    super.initState();
    _screenTime = {
      for (final c in widget.children) c.id: 60,
    };
    _accessEnabled = {
      for (final c in widget.children) c.id: true,
    };
  }

  Future<void> _saveScreenTime(String childId) async {
    setState(() => _saving['time_$childId'] = true);
    final ok = await ParentApiService.instance
        .setScreenTimeLimit(childId, _screenTime[childId] ?? 60);
    if (!mounted) return;
    setState(() => _saving['time_$childId'] = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Screen-time updated.'
            : 'Could not save right now. The student device will keep using current limits until sync.'),
      ),
    );
  }

  Future<void> _toggleAccess(String childId, bool enabled) async {
    setState(() => _saving['access_$childId'] = true);
    final ok =
        await ParentApiService.instance.toggleChildAccess(childId, enabled: enabled);
    if (!mounted) return;
    setState(() {
      _saving['access_$childId'] = false;
      if (ok) _accessEnabled[childId] = enabled;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? (enabled ? 'Access enabled.' : 'Access paused.')
            : 'Could not update right now. Please try again later.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      appBar: AppBar(
        title: const Text('Parental Controls'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: widget.children.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No children linked yet.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.children.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final child = widget.children[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                AppColors.primaryBlue.withValues(alpha: 0.12),
                            child: Text(
                              child.name.isNotEmpty
                                  ? child.name[0].toUpperCase()
                                  : 'S',
                              style: const TextStyle(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              child.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _accessRow(child),
                      const Divider(height: 24),
                      _screenTimeRow(child),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _accessRow(ParentLinkedChild child) {
    final enabled = _accessEnabled[child.id] ?? true;
    final saving = _saving['access_${child.id}'] ?? false;
    return Row(
      children: [
        const Icon(Icons.lock_outline, color: AppColors.primaryBlue),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'App Access',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2),
              Text(
                'Pause or allow learner access on this device.',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
            ],
          ),
        ),
        if (saving)
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Switch.adaptive(
            value: enabled,
            onChanged: (v) => _toggleAccess(child.id, v),
            activeThumbColor: AppColors.primaryBlue,
          ),
      ],
    );
  }

  Widget _screenTimeRow(ParentLinkedChild child) {
    final minutes = _screenTime[child.id] ?? 60;
    final saving = _saving['time_${child.id}'] ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.timer_outlined, color: AppColors.primaryBlue),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Daily Screen Time',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '$minutes min',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
        Slider(
          value: minutes.toDouble().clamp(15, 240),
          min: 15,
          max: 240,
          divisions: 15,
          activeColor: AppColors.primaryBlue,
          label: '$minutes min',
          onChanged: (v) {
            setState(() => _screenTime[child.id] = v.round());
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: saving ? null : () => _saveScreenTime(child.id),
            icon: saving
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Saving...' : 'Save'),
          ),
        ),
      ],
    );
  }
}