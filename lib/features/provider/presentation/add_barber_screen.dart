import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../widgets/phone_number_field.dart';
import '../../../widgets/styl_primary_button.dart';
import '../../../widgets/styl_text_field.dart';

/// Salon owner form to add a barber who may not have a STYL account yet.
class AddBarberScreen extends StatefulWidget {
  const AddBarberScreen({super.key, required this.args});

  final ProviderAddBarberArgs args;

  @override
  State<AddBarberScreen> createState() => _AddBarberScreenState();
}

class _AddBarberScreenState extends State<AddBarberScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _commissionController = TextEditingController();
  final _phoneKey = GlobalKey<PhoneNumberFieldState>();

  var _memberRole = 'STAFF';
  var _saving = false;
  var _uploadingPhoto = false;
  XFile? _pickedPhoto;
  String? _avatarUrl;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specialtyController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Barber photo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    late final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
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
                : (e.message ?? 'Could not open camera or gallery.'),
          ),
        ),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open camera or gallery.')),
      );
      return;
    }
    if (picked == null || !mounted) return;

    final uploadsApi = context.read<AuthController>().uploadsApi;
    setState(() {
      _pickedPhoto = picked;
      _uploadingPhoto = true;
    });
    try {
      final bytes = await picked.readAsBytes();
      final uploaded = await uploadsApi.uploadImage(
            bytes: bytes,
            filename: picked.name.isNotEmpty ? picked.name : 'barber.jpg',
            purpose: 'avatar',
          );
      if (!mounted) return;
      setState(() {
        _avatarUrl = uploaded.url;
        _uploadingPhoto = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _pickedPhoto = null;
        _uploadingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pickedPhoto = null;
        _uploadingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not upload photo.')),
      );
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the barber’s name.')),
      );
      return;
    }
    final local = _phoneController.text.trim();
    if (local.length < 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid mobile number.')),
      );
      return;
    }
    final email = _emailController.text.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email, or leave it blank.')),
      );
      return;
    }
    double? commission;
    final commissionRaw = _commissionController.text.trim();
    if (commissionRaw.isNotEmpty) {
      commission = double.tryParse(commissionRaw);
      if (commission == null || commission < 0 || commission > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commission must be between 0 and 100.')),
        );
        return;
      }
    }

    final phone = _phoneKey.currentState?.fullNumber ??
        composeE164(dialCode: '+44', national: local, isoCountry: 'GB');

    setState(() => _saving = true);
    try {
      await context.read<AuthController>().catalogApi.addShopMember(
            shopId: widget.args.shopId,
            phone: phone,
            fullName: name,
            email: email.isEmpty ? null : email,
            avatarUrl: _avatarUrl,
            memberRole: _memberRole,
            specialty: _specialtyController.text.trim().isEmpty
                ? null
                : _specialtyController.text.trim(),
            commissionPercent: commission,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barber added. Default hours are live on the schedule.'),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add barber.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _uploadingPhoto;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Add barber',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111111),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.brandPrimary,
          onPressed: busy ? null : () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text(
            'Create a salon profile even if they have not signed up yet. They’ll be bookable as soon as you save.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: Color(0xFF8A8A8A),
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: GestureDetector(
              onTap: busy ? null : _pickPhoto,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.lightSurfaceVariant,
                    backgroundImage: _pickedPhoto != null
                        ? FileImage(File(_pickedPhoto!.path))
                        : (_avatarUrl != null ? NetworkImage(_avatarUrl!) : null)
                            as ImageProvider?,
                    child: _pickedPhoto == null && _avatarUrl == null
                        ? const Icon(
                            Icons.person_outline,
                            size: 40,
                            color: AppColors.brandPrimary,
                          )
                        : null,
                  ),
                  if (_uploadingPhoto)
                    const Positioned.fill(
                      child: CircleAvatar(
                        backgroundColor: Color(0x88000000),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.photo_camera_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Photo (camera or gallery)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF8A8A8A)),
          ),
          const SizedBox(height: 22),
          StylTextField(
            controller: _nameController,
            label: 'Barber name',
            hintText: 'Full name',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          PhoneNumberField(
            key: _phoneKey,
            controller: _phoneController,
          ),
          const SizedBox(height: 14),
          StylTextField(
            controller: _emailController,
            label: 'Email (optional)',
            hintText: 'barber@salon.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),
          const Text(
            'Role',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _RoleChip(
                  label: 'Salon barber',
                  selected: _memberRole == 'STAFF',
                  onTap: () => setState(() => _memberRole = 'STAFF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RoleChip(
                  label: 'Mobile Barber',
                  selected: _memberRole == 'FREELANCER',
                  onTap: () => setState(() => _memberRole = 'FREELANCER'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          StylTextField(
            controller: _specialtyController,
            label: 'Specialty (optional)',
            hintText: 'Fades, colour, beard…',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          StylTextField(
            controller: _commissionController,
            label: 'Commission % (optional)',
            hintText: 'e.g. 40',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),
          StylPrimaryButton(
            label: _saving ? 'Adding…' : 'Save barber',
            onPressed: busy ? null : _save,
            isLoading: _saving,
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brandPrimary : AppColors.lightSurfaceVariant,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: selected ? Colors.white : const Color(0xFF111111),
            ),
          ),
        ),
      ),
    );
  }
}
