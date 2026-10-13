import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:elimupepe/app/app_services.dart';
import 'package:elimupepe/core/theme/app_theme.dart';
import 'package:elimupepe/core/widgets/elimu_button.dart';
import 'package:elimupepe/core/services/auth_service.dart';
import 'package:elimupepe/features/auth/welcome_screen.dart';
import 'package:elimupepe/core/widgets/elimu_text_field.dart';
import 'package:elimupepe/core/utils/image_url_resolver.dart';
import 'package:elimupepe/core/services/user_data_service.dart';
import 'package:elimupepe/features/parental_control/parental_gate.dart';
import 'package:elimupepe/features/quiz/learner_dashboard_api_service.dart';
import 'package:elimupepe/core/utils/error_feedback.dart';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedAvatar =
      'https://api.dicebear.com/9.x/adventurer/png?seed=Felix';

  final List<String> _availableAvatars = [
    'https://api.dicebear.com/9.x/adventurer/png?seed=Felix',
    'https://api.dicebear.com/9.x/adventurer/png?seed=Aneka',
    'https://api.dicebear.com/9.x/adventurer/png?seed=Jasper',
    'https://api.dicebear.com/9.x/adventurer/png?seed=Destiny',
    'https://api.dicebear.com/9.x/adventurer/png?seed=Tinkerbell',
    'https://api.dicebear.com/9.x/adventurer/png?seed=Bandit',
    'https://api.dicebear.com/9.x/adventurer/png?seed=Jack',
    'https://api.dicebear.com/9.x/adventurer/png?seed=Cali',
  ];

  // Image upload state
  bool _isUploadingAvatar = false;
  bool _isSaving = false;

  // Form Controllers
  final _nameController = TextEditingController(text: 'Alex Learner');
  final _emailController = TextEditingController(
    text: 'alex.learner@example.com',
  );
  final _aboutController = TextEditingController(
    text: 'I love reading science and math books!',
  );
  final _extraController = TextEditingController(
    text: 'Favorite Subject: Astronomy',
  );

  @override
  void initState() {
    super.initState();
    _loadCachedProfile();
  }

  Future<void> _loadCachedProfile() async {
    // Only the display name and avatar are kept on the device; the email is
    // not stored locally, so that field starts empty.
    final profile = await AppServices.instance.profile.read();
    if (!mounted) return;
    setState(() {
      _selectedAvatar = profile.avatarUrl ?? _selectedAvatar;
      _nameController.text = profile.name ?? _nameController.text;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _aboutController.dispose();
    _extraController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final success = await UserDataService.instance.updateProfile({
      'avatar': _selectedAvatar,
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
    });

    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _isSaving = false;
    });

    if (success) {
      final profile = AppServices.instance.profile;
      final avatarCacheKey = DateTime.now().millisecondsSinceEpoch.toString();
      final refreshedAvatar = ImageUrlResolver.withCacheBuster(
        _selectedAvatar,
        cacheKey: avatarCacheKey,
      );

      await profile.update(
        name: _nameController.text,
        avatarUrl: refreshedAvatar ?? _selectedAvatar,
      );
      profile.avatarCacheKey = avatarCacheKey;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      navigator.pop();
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to update profile. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
    // This was a fire-and-forget call, which is not ideal.
    /* UserDataService.instance.updateProfile({
        'avatar': _selectedAvatar,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
      }); */
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() {
        _isUploadingAvatar = true;
      });

      // Upload the image using the API
      final result = await LearnerDashboardApiService.instance
          .uploadStudentAvatar(pickedFile.path);

      if (result != null && result['avatar_url'] != null) {
        final newAvatarUrl = result['avatar_url'] as String;
        final avatarCacheKey = DateTime.now().millisecondsSinceEpoch.toString();
        final refreshedAvatar = ImageUrlResolver.withCacheBuster(
          newAvatarUrl,
          cacheKey: avatarCacheKey,
        );

        setState(() {
          _selectedAvatar = refreshedAvatar ?? newAvatarUrl;
        });

        final profile = AppServices.instance.profile;
        await profile.update(avatarUrl: _selectedAvatar);
        profile.avatarCacheKey = avatarCacheKey;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          await ErrorFeedback.showErrorDialog(
            context,
            title: 'Avatar upload failed',
            error: 'Please check your network connection and try again.',
            fallback: 'Failed to upload avatar. Please try again.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await ErrorFeedback.showErrorDialog(
          context,
          title: 'Avatar upload failed',
          error: e,
          fallback: 'Failed to upload avatar. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose an Avatar',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandGreen,
                ),
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _availableAvatars.length,
                itemBuilder: (context, index) {
                  final avatarUrl = _availableAvatars[index];
                  final isSelected = _selectedAvatar == avatarUrl;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedAvatar = avatarUrl;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.lightGreen
                              : Colors.transparent,
                          width: 4,
                        ),
                      ),
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(avatarUrl),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // Upload Custom Avatar Option
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUploadingAvatar
                      ? null
                      : () {
                          Navigator.pop(context);
                          _showImageSourceDialog();
                        },
                  icon: _isUploadingAvatar
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.upload),
                  label: Text(
                    _isUploadingAvatar
                        ? 'Uploading...'
                        : 'Upload Custom Avatar',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation() async {
    final passed = await showParentalGate(context);
    if (!passed || !mounted) return;

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action is permanent and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      final success = await AuthService.instance.deleteAccount();

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account successfully deleted.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your session was cleared, but the remote account deletion request might not have completed. Please contact support.',
            ),
          ),
        );
      }

      // Navigate back to the pre-login welcome flow
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF0F8FF),
        iconTheme: const IconThemeData(color: AppColors.brandGreen),
        title: const Text(
          'Update Profile',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.brandGreen,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Image Section
              Center(
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.lightGreen,
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: NetworkImage(_selectedAvatar),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 4,
                      child: GestureDetector(
                        onTap: _showAvatarPicker,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.lightGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Basic Info Section
              _buildSectionTitle('Basic Information'),
              const SizedBox(height: 16),
              ElimuTextField(
                label: 'Full Name',
                hint: 'Enter your full name',
                controller: _nameController,
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 16),
              ElimuTextField(
                label: 'Email Address',
                hint: 'Enter your email',
                controller: _emailController,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 32),

              // About & Extra Details Section
              _buildSectionTitle('About Me'),
              const SizedBox(height: 16),
              ElimuTextField(
                label: 'Bio / About',
                hint: 'Tell us about yourself',
                controller: _aboutController,
                icon: Icons.info_outline_rounded,
              ),
              const SizedBox(height: 16),
              ElimuTextField(
                label: 'Extra Details',
                hint: 'Add any extra info',
                controller: _extraController,
                icon: Icons.star_border_rounded,
              ),
              const SizedBox(height: 40),

              // Save Changes Button
              ElimuButton(
                text: 'Save Changes',
                isLoading: _isSaving,
                onPressed: _saveProfile,
              ),
              const SizedBox(height: 48),

              // Security & Danger Zone
              _buildSectionTitle('Security & Account'),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.brandGreen,
                  ),
                ),
                title: const Text(
                  'Change Password',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  // TODO: Navigate to Change Password Screen or show dialog
                },
              ),
              const Divider(height: 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.lightGreen,
                  ),
                ),
                title: const Text(
                  'Delete Account',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightGreen,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.lightGreen,
                ),
                onTap: _showDeleteConfirmation,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.brandGreen,
      ),
    );
  }
}
