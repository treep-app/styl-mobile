import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/styl_avatar.dart';
import '../../../widgets/styl_primary_button.dart';
import '../../../widgets/styl_text_field.dart';
import '../../auth/presentation/account_created_screen.dart';

/// Personal Info — edit name & email; phone is read-only.
///
/// When [fromOnboarding] is true (post role-select), saving continues to
/// the “All set!” screen instead of popping back to settings.
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({
    super.key,
    this.isServiceProvider = false,
    this.fromOnboarding = false,
  });

  final bool isServiceProvider;
  final bool fromOnboarding;

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  static const _changeBlue = Color(0xFF1E8CF2);
  static const _label = Color(0xFF4A5568);
  static const _value = Color(0xFF111827);
  static const _fieldFill = Color(0xFFF2F3F7);

  late final TextEditingController _name;
  late final TextEditingController _email;
  var _uploading = false;
  var _saving = false;
  var _initialized = false;
  String? _nameError;
  String? _emailError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final user = context.read<AuthController>().user;
    _name = TextEditingController(text: user?.fullName ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _initialized = true;
  }

  @override
  void dispose() {
    if (_initialized) {
      _name.dispose();
      _email.dispose();
    }
    super.dispose();
  }

  Future<void> _changeAvatar() async {
    late final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'channel-error'
                ? 'Photo picker needs a full app restart. Stop the app and run again.'
                : (e.message ?? 'Could not open photo library.'),
          ),
        ),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open photo library.')),
      );
      return;
    }
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    final auth = context.read<AuthController>();
    try {
      final bytes = await picked.readAsBytes();
      final uploaded = await auth.uploadsApi.uploadImage(
        bytes: bytes,
        filename: picked.name.isNotEmpty ? picked.name : 'avatar.jpg',
        purpose: 'avatar',
      );
      await auth.authApi.updateMe(avatarUrl: uploaded.url);
      await auth.reloadMe();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not upload photo.')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  bool _validate() {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final emailLocked = context.read<AuthController>().user?.hasEmail == true;

    String? nameError;
    String? emailError;
    if (name.isEmpty) nameError = 'Name is required';
    if (!emailLocked) {
      if (email.isEmpty) {
        emailError = 'Email is required';
      } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
        emailError = 'Enter a valid email';
      }
    }

    setState(() {
      _nameError = nameError;
      _emailError = emailError;
    });
    return nameError == null && emailError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    final auth = context.read<AuthController>();
    final emailLocked = auth.user?.hasEmail == true;
    try {
      await auth.updateProfile(
        fullName: _name.text.trim(),
        email: emailLocked ? null : _email.text.trim(),
      );
      if (!mounted) return;
      if (widget.fromOnboarding) {
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.accountCreated,
          arguments: AccountCreatedArgs(
            isServiceProvider: widget.isServiceProvider,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      Navigator.of(context).maybePop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update profile.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final mobile = user?.phone ?? '—';
    final avatar = user?.avatarUrl;
    final displayName = user?.fullName?.trim().isNotEmpty == true
        ? user!.fullName!
        : 'You';
    final hasPhoto = avatar != null && avatar.trim().isNotEmpty;
    final onboarding = widget.fromOnboarding;
    final emailLocked = user?.hasEmail == true;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: onboarding
            ? const SizedBox.shrink()
            : IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: AppColors.brandPrimary,
              ),
        title: Text(
          onboarding ? 'Set up your profile' : 'Personal Info',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.brandPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (onboarding) ...[
                    const Text(
                      'Add your details so salons and professionals know who you are.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: _label,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        StylAvatar(
                          size: 96,
                          imageUrl: avatar,
                          name: displayName,
                          showAddBadge: !hasPhoto && !_uploading,
                          onTap: _uploading ? null : _changeAvatar,
                        ),
                        if (_uploading) ...[
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.45),
                            ),
                          ),
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: GestureDetector(
                      onTap: _uploading ? null : _changeAvatar,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _uploading
                                ? Icons.cloud_upload_outlined
                                : Icons.photo_camera_outlined,
                            size: 16,
                            color: _changeBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _uploading
                                ? 'Uploading…'
                                : hasPhoto
                                    ? 'Change photo'
                                    : 'Add photo',
                            style: const TextStyle(
                              color: _changeBlue,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  StylTextField(
                    controller: _name,
                    label: 'Name',
                    hintText: 'Your full name',
                    textInputAction: TextInputAction.next,
                  ),
                  if (_nameError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _nameError!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (emailLocked) ...[
                    const Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppColors.lightOnSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ReadOnlyField(value: user!.email!),
                    const SizedBox(height: 4),
                    const Text(
                      'Email can’t be changed once set',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _label,
                      ),
                    ),
                  ] else ...[
                    StylTextField(
                      controller: _email,
                      label: 'Email',
                      hintText: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                    ),
                    if (_emailError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _emailError!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Mobile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppColors.lightOnSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ReadOnlyField(value: mobile),
                  if (widget.isServiceProvider) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Address',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.lightOnSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _ReadOnlyField(value: 'On request'),
                    const SizedBox(height: 16),
                    const Text(
                      'Availability',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.lightOnSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _ReadOnlyField(
                      value: 'Managed from working hours',
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: StylPrimaryButton(
                label: onboarding
                    ? (_saving ? 'Saving…' : 'Continue')
                    : 'Update',
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Light gray field shell with dark, readable text (matches [StylTextField]).
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      decoration: BoxDecoration(
        color: _PersonalInfoScreenState._fieldFill,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _PersonalInfoScreenState._value,
          height: 1.35,
        ),
      ),
    );
  }
}
