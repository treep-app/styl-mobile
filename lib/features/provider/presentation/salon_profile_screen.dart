import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/session_store.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../widgets/phone_number_field.dart';

/// Owner salon profile editor — cover, logo, name, description, contact.
///
/// Image convention: `imageUrls[0]` = cover, `imageUrls[1]` = logo.
class SalonProfileScreen extends StatefulWidget {
  const SalonProfileScreen({
    super.key,
    this.shopId,
    this.fromOnboarding = false,
  });

  final String? shopId;
  final bool fromOnboarding;

  @override
  State<SalonProfileScreen> createState() => _SalonProfileScreenState();
}

class _SalonProfileScreenState extends State<SalonProfileScreen> {
  static const _maxDescription = 300;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneFieldKey = GlobalKey<PhoneNumberFieldState>();

  ShopDto? _shop;
  String? _coverUrl;
  String? _logoUrl;
  String _addressLine = 'Address to be added';
  var _phoneCountryCode = 'GB';
  var _loading = true;
  var _saving = false;
  var _uploadingCover = false;
  var _uploadingLogo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String get _initials {
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'S';
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final chars = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return chars.isEmpty ? 'S' : chars;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthController>();
      final mine = await auth.catalogApi.listMyShops();
      if (!mounted) return;

      ShopDto? shop;
      if (widget.shopId != null) {
        for (final s in mine) {
          if (s.id == widget.shopId) {
            shop = s;
            break;
          }
        }
        shop ??= await auth.catalogApi.getShop(widget.shopId!);
      } else {
        shop = mine.where((s) => s.isOwner == true).firstOrNull ??
            (mine.isNotEmpty ? mine.first : null);
      }

      if (shop != null) {
        _applyShop(shop, fallbackPhone: auth.user?.phone);
      } else {
        final user = auth.user;
        final fallback = user?.fullName?.trim();
        if (_nameController.text.isEmpty) {
          _nameController.text =
              (fallback != null && fallback.isNotEmpty)
                  ? "$fallback's Salon"
                  : 'My Salon';
        }
        _seedPhone(user?.phone ?? '');
      }

      setState(() {
        _shop = shop;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load salon profile.';
      });
    }
  }

  void _applyShop(ShopDto shop, {String? fallbackPhone}) {
    _nameController.text = shop.name;
    _descriptionController.text = shop.description ?? '';
    _addressLine =
        shop.addressLine.trim().isEmpty ? 'Address to be added' : shop.addressLine;
    _coverUrl = shop.imageUrls.isNotEmpty ? shop.imageUrls[0] : null;
    _logoUrl = shop.imageUrls.length > 1 ? shop.imageUrls[1] : null;
    final shopPhone = (shop.phone ?? '').trim();
    final userPhone = (fallbackPhone ?? '').trim();
    _seedPhone(shopPhone.isNotEmpty ? shopPhone : userPhone);
  }

  void _seedPhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      _phoneController.clear();
      _phoneCountryCode = 'GB';
      return;
    }

    final e164 = toE164(trimmed);
    final digits = e164.replaceAll(RegExp(r'\D'), '');

    // Prefer UK (onboarding default), then other common dial codes.
    if (digits.startsWith('44') && digits.length > 2) {
      _phoneCountryCode = 'GB';
      final nsn = digits.substring(2);
      _phoneController.text = nsn.startsWith('0') ? nsn : '0$nsn';
      return;
    }
    if (digits.startsWith('1') && digits.length >= 11) {
      _phoneCountryCode = 'US';
      _phoneController.text = digits.substring(1);
      return;
    }
    if (digits.startsWith('353') && digits.length > 3) {
      _phoneCountryCode = 'IE';
      _phoneController.text = digits.substring(3);
      return;
    }
    if (digits.startsWith('971') && digits.length > 3) {
      _phoneCountryCode = 'AE';
      _phoneController.text = digits.substring(3);
      return;
    }
    if (digits.startsWith('27') && digits.length > 2) {
      _phoneCountryCode = 'ZA';
      _phoneController.text = digits.substring(2);
      return;
    }
    if (digits.startsWith('91') && digits.length > 2) {
      _phoneCountryCode = 'IN';
      _phoneController.text = digits.substring(2);
      return;
    }

    _phoneCountryCode = 'GB';
    _phoneController.text = digits;
  }

  String _resolvedPhone() {
    final fromField = _phoneFieldKey.currentState?.fullNumber;
    if (fromField != null && fromField.trim().length > 4) {
      return toE164(fromField);
    }
    final raw = _phoneController.text.trim();
    if (raw.isEmpty) return '';
    return toE164(raw.startsWith('+') ? raw : '+44$raw');
  }

  List<String> _composeImageUrls({String? cover, String? logo}) {
    final coverUrl = cover ?? _coverUrl;
    final logoUrl = logo ?? _logoUrl;
    final extras = <String>[];
    final existing = _shop?.imageUrls ?? const <String>[];
    for (var i = 2; i < existing.length; i++) {
      final u = existing[i];
      if (u != coverUrl && u != logoUrl) extras.add(u);
    }

    final out = <String>[];
    if (coverUrl != null && coverUrl.isNotEmpty) {
      out.add(coverUrl);
    }
    if (logoUrl != null && logoUrl.isNotEmpty) {
      if (out.isEmpty || out.first != logoUrl) out.add(logoUrl);
    }
    out.addAll(extras);
    return out;
  }

  Future<String?> _pickAndUpload({required bool forCover}) async {
    late final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: forCover ? 2400 : 1200,
        maxHeight: forCover ? 2400 : 1200,
        imageQuality: 88,
      );
    } on PlatformException catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'channel-error'
                ? 'Photo picker needs a full app restart. Stop the app and run again.'
                : (e.message ?? 'Could not open photo library.'),
          ),
        ),
      );
      return null;
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open photo library.')),
      );
      return null;
    }
    if (picked == null || !mounted) return null;

    setState(() {
      if (forCover) {
        _uploadingCover = true;
      } else {
        _uploadingLogo = true;
      }
    });
    final auth = context.read<AuthController>();
    try {
      final bytes = await picked.readAsBytes();
      final uploaded = await auth.uploadsApi.uploadImage(
            bytes: bytes,
            filename: picked.name.isNotEmpty
                ? picked.name
                : (forCover ? 'cover.jpg' : 'logo.jpg'),
            purpose: 'shop',
          );
      return uploaded.url;
    } on ApiException catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return null;
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            forCover ? 'Could not upload cover photo.' : 'Could not upload logo.',
          ),
        ),
      );
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _uploadingCover = false;
          _uploadingLogo = false;
        });
      }
    }
  }

  Future<void> _changeCover() async {
    final url = await _pickAndUpload(forCover: true);
    if (url == null || !mounted) return;
    setState(() => _coverUrl = url);
  }

  Future<void> _changeLogo() async {
    final url = await _pickAndUpload(forCover: false);
    if (url == null || !mounted) return;
    setState(() => _logoUrl = url);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a salon name.')),
      );
      return;
    }
    final description = _descriptionController.text.trim();
    if (description.length > _maxDescription) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Description must be 300 characters or less.')),
      );
      return;
    }

    setState(() => _saving = true);
    final auth = context.read<AuthController>();
    final phone = _resolvedPhone();
    final imageUrls = _composeImageUrls();

    try {
      ShopDto saved;
      final existing = _shop;
      final knownId = existing?.id ?? widget.shopId;
      if (knownId == null) {
        // Prefer updating an already-owned shop over creating another.
        final mine = await auth.catalogApi.listMyShops();
        final owned = mine.where((s) => s.isOwner == true).toList();
        if (owned.isNotEmpty) {
          saved = await auth.catalogApi.updateShop(owned.first.id, {
            'name': name,
            'addressLine': _addressLine,
            'description': description,
            if (phone.isNotEmpty) 'phone': phone,
            'imageUrls': imageUrls,
          });
        } else {
          saved = await auth.catalogApi.createShop({
            'name': name,
            'addressLine': _addressLine,
            if (description.isNotEmpty) 'description': description,
            if (phone.isNotEmpty) 'phone': phone,
            if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
          });
        }
      } else {
        saved = await auth.catalogApi.updateShop(knownId, {
          'name': name,
          'addressLine': _addressLine,
          'description': description,
          if (phone.isNotEmpty) 'phone': phone,
          'imageUrls': imageUrls,
        });
      }

      if (!mounted) return;
      setState(() {
        _shop = saved;
        _applyShop(saved);
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salon profile saved.')),
      );

      if (widget.fromOnboarding) {
        await SessionStore().setProviderSetupStage('services');
        await SessionStore().setProviderSetupShopId(saved.id);
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.providerServices,
          (route) => false,
          arguments: ProviderServicesArgs(
            shopId: saved.id,
            fromOnboarding: true,
          ),
        );
      } else {
        Navigator.of(context).maybePop(true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(_error!, textAlign: TextAlign.center),
                        ),
                        TextButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () async {
                                if (widget.fromOnboarding) {
                                  await SessionStore()
                                      .setProviderSetupStage('provider_type');
                                  if (!context.mounted) return;
                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    AppRoutes.providerType,
                                    (route) => false,
                                  );
                                } else {
                                  Navigator.of(context).maybePop();
                                }
                              },
                              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                              color: AppColors.brandPrimary,
                            ),
                            const Expanded(
                              child: Text(
                                'Salon Profile',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _saving ? null : _save,
                              child: Text(
                                _saving ? 'Saving…' : 'Save',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _saving
                                      ? AppColors.brandPrimary.withValues(alpha: 0.4)
                                      : const Color(0xFF6B5CE7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.lightOutlineVariant,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        10,
                                        12,
                                        0,
                                      ),
                                      child: _CoverPhoto(
                                        url: _coverUrl,
                                        uploading: _uploadingCover,
                                        onChange: _changeCover,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        10,
                                        16,
                                        0,
                                      ),
                                      child: Row(
                                        children: [
                                          _LogoBox(
                                            url: _logoUrl,
                                            initials: _initials,
                                            uploading: _uploadingLogo,
                                          ),
                                          const SizedBox(width: 12),
                                          Material(
                                            color: const Color(0xFFEDE9FE),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: InkWell(
                                              onTap: _uploadingLogo
                                                  ? null
                                                  : _changeLogo,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 10,
                                                ),
                                                child: Text(
                                                  'Change logo',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.brandPrimary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        12,
                                        16,
                                        12,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Salon name',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.brandPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          TextField(
                                            controller: _nameController,
                                            textInputAction:
                                                TextInputAction.next,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: Color(0xFF111827),
                                            ),
                                            decoration: _fieldDecoration(
                                              hint: 'Salon name',
                                            ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                          const SizedBox(height: 10),
                                          const Text(
                                            'Description',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.brandPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          TextField(
                                            controller: _descriptionController,
                                            maxLines: 3,
                                            minLines: 3,
                                            maxLength: _maxDescription,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              height: 1.35,
                                              color: Color(0xFF111827),
                                            ),
                                            decoration: _fieldDecoration(
                                              hint:
                                                  'Tell clients about your salon',
                                            ).copyWith(counterText: ''),
                                          ),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              '${_descriptionController.text.length}/$_maxDescription',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF9CA3AF),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          PhoneNumberField(
                                            key: _phoneFieldKey,
                                            controller: _phoneController,
                                            label: 'Contact number',
                                            hintText: 'Phone number',
                                            initialCountryCode:
                                                _phoneCountryCode,
                                            onCountryChanged: (c) {
                                              _phoneCountryCode =
                                                  c.countryCode;
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 50,
                                            child: FilledButton(
                                              onPressed:
                                                  _saving ? null : _save,
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF6B5CE7),
                                                disabledBackgroundColor:
                                                    const Color(0xFFD9D3F5),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: Text(
                                                _saving ? 'Saving…' : 'Save',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  InputDecoration _fieldDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brandPrimary, width: 1.4),
      ),
    );
  }
}

class _CoverPhoto extends StatelessWidget {
  const _CoverPhoto({
    required this.url,
    required this.uploading,
    required this.onChange,
  });

  final String? url;
  final bool uploading;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 2.05,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null && url!.isNotEmpty)
              Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(),
              )
            else
              _placeholder(),
            if (uploading)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                elevation: 1,
                child: InkWell(
                  onTap: uploading ? null : onChange,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_camera_outlined, size: 16, color: Color(0xFF374151)),
                        SizedBox(width: 6),
                        Text(
                          'Change cover photo',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: const Center(
        child: Icon(Icons.storefront_outlined, size: 40, color: Color(0xFF9CA3AF)),
      ),
    );
  }
}

class _LogoBox extends StatelessWidget {
  const _LogoBox({
    required this.url,
    required this.initials,
    required this.uploading,
  });

  final String? url;
  final String initials;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.brandPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: url != null && url!.isNotEmpty
                  ? Image.network(
                      url!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _initials(),
                    )
                  : _initials(),
            ),
          ),
          if (uploading)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.4),
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initials() {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
    );
  }
}
