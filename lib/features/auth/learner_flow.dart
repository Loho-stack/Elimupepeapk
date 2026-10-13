import 'package:elimupepe/core/theme/app_theme.dart';
import 'package:elimupepe/features/auth/login_screen.dart';
import 'package:flutter/material.dart';

class LearnerFlowScreen extends StatefulWidget {
  const LearnerFlowScreen({super.key});

  @override
  State<LearnerFlowScreen> createState() => _LearnerFlowScreenState();
}

class _LearnerFlowScreenState extends State<LearnerFlowScreen> {
  int _currentStep = 1;

  String schoolCode = '';
  String learnerId = '';
  String pinEntered = '';

  final Map<String, String> mockStudentData = {
    'school': 'Greenwood Primary School',
    'grade': 'Grade 5',
    'class': '5B',
    'name': 'Ava M.',
  };

  void _nextStep() => setState(() => _currentStep = (_currentStep + 1).clamp(1, 6));
  void _prevStep() => setState(() => _currentStep = (_currentStep - 1).clamp(1, 6));
  void _resetFlow() => setState(() => _currentStep = 1);

  bool _isCompact(BuildContext context) => MediaQuery.of(context).size.width < 380;
  bool _isLarge(BuildContext context) => MediaQuery.of(context).size.width >= 900;

  @override
  Widget build(BuildContext context) {
    final isCompact = _isCompact(context);
    final isLarge = _isLarge(context);
    final horizontalPadding = isCompact ? 16.0 : (isLarge ? 36.0 : 24.0);
    final maxContentWidth = isLarge ? 760.0 : 560.0;

    return Scaffold(
      backgroundColor: AppColors.brandGreen,
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 1
            ? Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppStyles.playfulShadow,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
                    onPressed: _prevStep,
                    iconSize: 20,
                  ),
                ),
              )
            : null,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppStyles.radiusPill,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            'Learner Setup • $_currentStep/6',
            style: const TextStyle(
              color: AppColors.brandGreen,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: _currentStep / 6,
                backgroundColor: AppColors.white.withValues(alpha: 0.5),
                color: AppColors.brandGreen,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/fam.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.brandGreen.withValues(alpha: 0.78),
                      AppColors.lightGreen.withValues(alpha: 0.88),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -50,
              right: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.lightGreen.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -70,
              left: -20,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: AppColors.secondaryBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: _buildCurrentStepView(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 1:
        return _buildStep1UniversalLanding();
      case 2:
        return _buildStep2LearnerContext();
      case 3:
        return _buildStep3SchoolConfirmation();
      case 4:
        return _buildStep4PinLogin();
      case 5:
        return _buildStep5Dashboard();
      case 6:
        return _buildStep6SessionEnd();
      default:
        return _buildStep1UniversalLanding();
    }
  }

  Widget _buildStep1UniversalLanding() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose Access Mode',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: _isCompact(context) ? 22 : 28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select how you want to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: _isCompact(context) ? 13 : 15,
                  ),
                ),
                const SizedBox(height: 20),
                _roleCard(
                  'Learner',
                  subtitle: 'Personal device access',
                  isSelected: true,
                  showOptions: false,
                  icon: Icons.face,
                ),
                _roleCard(
                  'Shared Tablet',
                  subtitle: 'Use one device for multiple learners',
                  icon: Icons.tablet_mac,
                  onTap: _nextStep,
                ),
                const SizedBox(height: 14),
                _entryOptionCard(
                  title: 'Sign in',
                  subtitle: 'For any learner with credentials (Learner ID and password/PIN).',
                  icon: Icons.login_rounded,
                  isPrimary: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleCard(
    String title, {
    String? subtitle,
    bool isSelected = false,
    bool showOptions = false,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final isCompact = _isCompact(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppColors.brandGreen : Colors.white.withValues(alpha: 0.6),
          width: isSelected ? 2 : 1.2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.brandGreen.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            InkWell(
              onTap: isSelected ? null : onTap,
              child: Padding(
                padding: EdgeInsets.all(isCompact ? 14 : 18),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isCompact ? 10 : 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.lightGreen.withValues(alpha: 0.2) : AppColors.surfaceGray,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: isSelected ? AppColors.brandGreen : AppColors.textMuted, size: isCompact ? 24 : 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: isCompact ? 16 : 18,
                              color: isSelected ? AppColors.brandGreen : AppColors.textMain,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: AppColors.textMuted.withValues(alpha: 0.9),
                                fontSize: isCompact ? 12 : 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle, color: AppColors.brandGreen, size: 20),
                      )
                    else
                      const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            if (showOptions)
              Container(
                color: const Color(0xFFF3FBF6),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        'Sign in',
                        Icons.login,
                        () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        ),
                        isPrimary: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _actionButton('Enter code', Icons.pin, _nextStep),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String title, IconData icon, VoidCallback onPressed, {bool isPrimary = false}) {
    final isCompact = _isCompact(context);
    return SizedBox(
      height: isCompact ? 44 : 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: isPrimary ? AppColors.brandGreen : AppColors.white,
          foregroundColor: isPrimary ? AppColors.white : AppColors.primaryBlue,
          side: isPrimary ? null : BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(icon, size: isCompact ? 18 : 20),
        label: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: isCompact ? 13 : 14),
        ),
      ),
    );
  }

  Widget _entryOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final isCompact = _isCompact(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimary ? AppColors.brandGreen.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isPrimary ? AppColors.lightGreen.withValues(alpha: 0.2) : AppColors.surfaceGray,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isPrimary ? AppColors.brandGreen : AppColors.primaryBlue,
            size: isCompact ? 22 : 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: isCompact ? 15 : 16,
            color: AppColors.textMain,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: isCompact ? 12 : 13,
              color: AppColors.textMuted,
            ),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }

  Widget _buildStep2LearnerContext() {
    final isCompact = _isCompact(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Join your school',
            style: TextStyle(
              fontSize: isCompact ? 22 : 28,
              fontWeight: FontWeight.w900,
              color: AppColors.brandGreen,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan your school QR code to continue.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 16),
          ),
          SizedBox(height: isCompact ? 28 : 40),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isCompact ? 18 : 22),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppStyles.playfulShadow,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, size: 34, color: AppColors.brandGreen),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Scan Learner QR',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Use camera to scan the QR code provided by your school.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 18),
                _primaryButton('Scan QR Code', Icons.qr_code_scanner, _nextStep),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3SchoolConfirmation() {
    final isCompact = _isCompact(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirm your school',
            style: TextStyle(fontSize: isCompact ? 22 : 28, fontWeight: FontWeight.w900, color: AppColors.brandGreen),
          ),
          const SizedBox(height: 8),
          const Text('Please confirm your details.', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
          SizedBox(height: isCompact ? 20 : 32),
          Container(
            padding: EdgeInsets.all(isCompact ? 16 : 24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: AppStyles.radiusLarge,
              boxShadow: AppStyles.playfulShadow,
              border: Border.all(color: AppColors.lightGreen.withValues(alpha: 0.3), width: 2),
            ),
            child: Column(
              children: [
                _infoRow(Icons.school, 'School name', mockStudentData['school']!),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: AppColors.surfaceGray, thickness: 2)),
                _infoRow(Icons.bar_chart, 'Grade', mockStudentData['grade']!),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: AppColors.surfaceGray, thickness: 2)),
                _infoRow(Icons.groups, 'Class', mockStudentData['class']!),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: AppColors.surfaceGray, thickness: 2)),
                _infoRow(Icons.face, 'Learner name', mockStudentData['name']!),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 20 : 28),
          _primaryButton('Continue', Icons.check_circle, _nextStep),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _prevStep,
              child: const Text(
                'Back to search',
                style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.surfaceGray, borderRadius: AppStyles.radiusSmall),
          child: Icon(icon, color: AppColors.brandGreen, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textMain)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep4PinLogin() {
    final isCompact = _isCompact(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(alignment: Alignment.topRight, child: _offlineCloudIndicator()),
        SizedBox(height: isCompact ? 12 : 16),
        Container(
          width: isCompact ? 84 : 100,
          height: isCompact ? 84 : 100,
          decoration: BoxDecoration(
            color: AppColors.lightGreen.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.brandGreen, width: 3),
          ),
          child: Icon(Icons.face_retouching_natural, size: isCompact ? 50 : 60, color: AppColors.brandGreen),
        ),
        SizedBox(height: isCompact ? 12 : 16),
        Text(
          mockStudentData['name']!,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: isCompact ? 20 : 24, color: AppColors.textMain),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppColors.surfaceGray, borderRadius: AppStyles.radiusPill),
          child: Text('${mockStudentData['grade']} • ${mockStudentData['class']}', style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
        ),
        SizedBox(height: isCompact ? 16 : 24),
        Text(
          'Enter your 6-digit PIN',
          style: TextStyle(fontSize: isCompact ? 14 : 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
        ),
        SizedBox(height: isCompact ? 12 : 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            final isFilled = pinEntered.length > index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: isCompact ? 5 : 8),
              width: isFilled ? (isCompact ? 16 : 20) : (isCompact ? 13 : 16),
              height: isFilled ? (isCompact ? 16 : 20) : (isCompact ? 13 : 16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isFilled ? AppColors.brandGreen : AppColors.darkGray, width: 2),
                color: isFilled ? AppColors.brandGreen : Colors.transparent,
              ),
            );
          }),
        ),
        SizedBox(height: isCompact ? 20 : 32),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 24),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: isCompact ? 1.05 : 1.2,
                mainAxisSpacing: isCompact ? 10 : 16,
                crossAxisSpacing: isCompact ? 10 : 16,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                if (index == 9) return const SizedBox.shrink();
                if (index == 11) {
                  return _keypadButton(
                    icon: Icons.backspace,
                    onTap: () {
                      if (pinEntered.isNotEmpty) {
                        setState(() => pinEntered = pinEntered.substring(0, pinEntered.length - 1));
                      }
                    },
                  );
                }
                final keyText = index == 10 ? '0' : '${index + 1}';
                return _keypadButton(
                  text: keyText,
                  onTap: () {
                    if (pinEntered.length < 6) {
                      setState(() => pinEntered += keyText);
                      if (pinEntered.length == 6) {
                        Future.delayed(const Duration(milliseconds: 300), _nextStep);
                      }
                    }
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _keypadButton({String? text, IconData? icon, required VoidCallback onTap}) {
    final isCompact = _isCompact(context);
    return Material(
      color: AppColors.white,
      borderRadius: AppStyles.radiusLarge,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppStyles.radiusLarge,
        child: Center(
          child: text != null
              ? Text(
                  text,
                  style: TextStyle(
                    fontSize: isCompact ? 24 : 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.brandGreen,
                  ),
                )
              : Icon(icon, color: AppColors.accentCoral, size: isCompact ? 24 : 28),
        ),
      ),
    );
  }

  Widget _buildStep5Dashboard() {
    final isCompact = _isCompact(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.white, shape: BoxShape.circle, boxShadow: AppStyles.playfulShadow),
              child: const Icon(Icons.menu, color: AppColors.textMain),
            ),
            Column(
              children: [
                const Text('Welcome back,', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                Text(
                  mockStudentData['name']!,
                  style: TextStyle(fontSize: isCompact ? 17 : 20, fontWeight: FontWeight.w900, color: AppColors.brandGreen),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.white, shape: BoxShape.circle, boxShadow: AppStyles.playfulShadow),
              child: const Icon(Icons.notifications_active, color: AppColors.accentOrange),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 20 : 32),
        Text('Continue learning', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isCompact ? 18 : 20, color: AppColors.textMain)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.white, borderRadius: AppStyles.radiusLarge, boxShadow: AppStyles.playfulShadow),
          child: Row(
            children: [
              Container(
                width: isCompact ? 56 : 70,
                height: isCompact ? 56 : 70,
                decoration: BoxDecoration(color: AppColors.secondaryBlue.withValues(alpha: 0.2), borderRadius: AppStyles.radiusMedium),
                child: Icon(Icons.menu_book, color: AppColors.primaryBlue, size: isCompact ? 26 : 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mathematics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: AppStyles.radiusPill,
                      child: LinearProgressIndicator(
                        value: 0.6,
                        color: AppColors.brandGreen,
                        backgroundColor: AppColors.surfaceGray,
                        minHeight: 8,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('60% complete', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isCompact ? 20 : 32),
        Text('Assigned activities', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isCompact ? 18 : 20, color: AppColors.textMain)),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              _activityTile('Fractions: Add & Subtract', 'Due tomorrow', Icons.calculate, AppColors.accentPurple),
              _activityTile('Reading Comprehension', 'Due Fri, May 23', Icons.book, AppColors.accentOrange),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.lightGreen.withValues(alpha: 0.1), borderRadius: AppStyles.radiusMedium),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_done, color: AppColors.brandGreen, size: 20),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Synced 9:45 AM today - All caught up!',
                  style: TextStyle(color: AppColors.brandGreen, fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _primaryButton('Logout / End Session', Icons.logout, _nextStep, isDanger: true),
      ],
    );
  }

  Widget _activityTile(String title, String dueDate, IconData icon, Color color) {
    final isCompact = _isCompact(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: AppStyles.radiusMedium, boxShadow: AppStyles.playfulShadow),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isCompact ? 14 : 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              const Icon(Icons.timer, size: 14, color: AppColors.accentCoral),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  dueDate,
                  style: const TextStyle(color: AppColors.accentCoral, fontWeight: FontWeight.bold, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(color: AppColors.surfaceGray, shape: BoxShape.circle),
          child: const Icon(Icons.chevron_right, color: AppColors.textMain),
        ),
        onTap: () {},
      ),
    );
  }

  Widget _buildStep6SessionEnd() {
    final isCompact = _isCompact(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: isCompact ? 12 : 24),
          Container(
            padding: EdgeInsets.all(isCompact ? 22 : 32),
            decoration: BoxDecoration(color: AppColors.brandGreen, shape: BoxShape.circle, boxShadow: AppStyles.playfulShadow),
            child: Icon(Icons.waving_hand, size: isCompact ? 62 : 80, color: AppColors.white),
          ),
          SizedBox(height: isCompact ? 20 : 32),
          Text('Great job today!', style: TextStyle(fontSize: isCompact ? 22 : 28, fontWeight: FontWeight.w900, color: AppColors.brandGreen)),
          const SizedBox(height: 8),
          const Text('Your progress is safely saved.', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
          SizedBox(height: isCompact ? 24 : 48),
          Container(
            padding: EdgeInsets.all(isCompact ? 16 : 20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: AppStyles.radiusLarge,
              boxShadow: AppStyles.playfulShadow,
              border: Border.all(color: AppColors.surfaceGray, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cloud_sync, color: AppColors.primaryBlue),
                    SizedBox(width: 12),
                    Text('Sync Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '3 items pending sync. They will automatically upload when you connect to Wi-Fi.',
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.5),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: AppColors.primaryBlue, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: AppStyles.radiusMedium),
                    foregroundColor: AppColors.primaryBlue,
                  ),
                  icon: const Icon(Icons.download),
                  label: const Text('Force Sync Now', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 20 : 28),
          _primaryButton('Return to welcome', Icons.home, _resetFlow),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => setState(() => _currentStep = 4),
            icon: const Icon(Icons.person_add, color: AppColors.textMain),
            label: const Text('Switch learner', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _primaryButton(String text, IconData icon, VoidCallback onPressed, {bool isDanger = false}) {
    final isCompact = _isCompact(context);
    final bgColor = isDanger ? AppColors.accentCoral : AppColors.brandGreen;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: bgColor.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Text(text, style: TextStyle(fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _offlineCloudIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppStyles.radiusPill,
        border: Border.all(color: AppColors.darkGray),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 16, color: AppColors.textMuted),
          SizedBox(width: 6),
          Text('Offline', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

}
