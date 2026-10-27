import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/session_store.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/styl_avatar.dart';
import '../../customer/presentation/looks_ui.dart';

enum ProviderWorkType { owner, staff, independent }

/// Looksy professional onboarding.
///
/// Owners: work type → salon setup (profile / services / hours / team / booking).
/// Staff / independent: work type → personal profile → find salon → …
class ProviderTypeScreen extends StatefulWidget {
  const ProviderTypeScreen({super.key});

  @override
  State<ProviderTypeScreen> createState() => _ProviderTypeScreenState();
}

class _ProviderTypeScreenState extends State<ProviderTypeScreen> {
  static const _professions = [
    'Barber',
    'Hair Stylist',
    'Colourist',
    'Nail Technician',
    'Lash Technician',
    'Beauty Therapist',
    'Braider',
  ];

  static const _experience = [
    'Less than 1 year',
    '1–2 years',
    '3–4 years',
    '5+ years',
    '10+ years',
  ];

  var _step = 0;
  var _type = ProviderWorkType.staff;
  var _busy = false;
  var _uploadingPhoto = false;
  var _loadingSalons = false;
  String? _salonsError;
  List<ShopDto> _salons = const [];
  String? _selectedShopId;
  var _salonNotListed = false;
  String? _avatarUrl;
  File? _localPhoto;

  late final TextEditingController _name;
  late final TextEditingController _search;
  Timer? _salonSearchDebounce;
  var _salonSearchGen = 0;
  var _profession = 'Barber';
  var _years = '5+ years';

  static const _catalogServices = [
    'Haircut',
    'Skin Fade',
    'Taper Fade',
    'Beard Trim',
    'Colour',
    'Haircut + Beard',
  ];

  static const _catalogSpecialties = [
    'Low Taper',
    'Skin Fade',
    'Afro Hair',
    'Beard Shaping',
    'Designs',
    'Kids Cuts',
  ];

  static const _servicePrices = <String, double>{
    'Haircut': 25,
    'Skin Fade': 30,
    'Taper Fade': 30,
    'Beard Trim': 15,
    'Colour': 45,
    'Haircut + Beard': 35,
  };

  List<String> _serviceOptions = List<String>.from(_catalogServices);
  var _selectedServices = <String>{
    'Haircut',
    'Skin Fade',
    'Taper Fade',
    'Beard Trim',
  };
  var _selectedSpecialties = <String>{'Low Taper'};
  final _portfolio = <_PortfolioShot>[];
  var _addingPortfolio = false;

  String get _providerTypeApi {
    return switch (_type) {
      ProviderWorkType.owner => 'OWNER',
      ProviderWorkType.staff => 'STAFF',
      ProviderWorkType.independent => 'INDEPENDENT',
    };
  }

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().user;
    _name = TextEditingController(text: user?.fullName ?? '');
    _search = TextEditingController();
    _search.addListener(_onSalonSearchChanged);
    _avatarUrl = user?.avatarUrl;
  }

  @override
  void dispose() {
    _salonSearchDebounce?.cancel();
    _search.removeListener(_onSalonSearchChanged);
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onSalonSearchChanged() {
    _salonSearchDebounce?.cancel();
    _salonSearchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted || _step != 2) return;
      final q = _search.text.trim();
      _loadSalons(q: q.isEmpty ? null : q, showSpinner: _salons.isEmpty);
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadSalons({String? q, bool showSpinner = true}) async {
    final gen = ++_salonSearchGen;
    setState(() {
      if (showSpinner) _loadingSalons = true;
      _salonsError = null;
    });
    try {
      final shops = await context.read<AuthController>().catalogApi.listShops(
        q: q,
      );
      if (!mounted || gen != _salonSearchGen) return;
      setState(() {
        _salons = shops;
        _loadingSalons = false;
      });
    } on ApiException catch (e) {
      if (!mounted || gen != _salonSearchGen) return;
      setState(() {
        _salonsError = friendlyErrorMessage(e);
        _loadingSalons = false;
      });
    } catch (e) {
      if (!mounted || gen != _salonSearchGen) return;
      setState(() {
        _salonsError = friendlyErrorMessage(e);
        _loadingSalons = false;
      });
    }
  }

  Future<void> _pickPhoto() async {
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
      _toast(
        e.code == 'channel-error'
            ? 'Photo picker needs a full app restart. Stop the app and run again.'
            : (e.message ?? 'Could not open photo library.'),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      _toast('Could not open photo library.');
      return;
    }
    if (picked == null || !mounted) return;
    final file = File(picked.path);

    setState(() {
      _localPhoto = file;
      _uploadingPhoto = true;
    });
    final auth = context.read<AuthController>();
    try {
      final bytes = await picked.readAsBytes();
      final uploaded = await auth.uploadsApi.uploadImage(
        bytes: bytes,
        filename: picked.name.isNotEmpty ? picked.name : 'avatar.jpg',
        purpose: 'avatar',
      );
      if (!mounted) return;
      setState(() {
        _avatarUrl = uploaded.url;
        _uploadingPhoto = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      _toast('Could not upload photo.');
    }
  }

  Future<void> _prepareServices() async {
    var names = [..._catalogServices];
    final shopId = _selectedShopId;
    if (shopId != null) {
      try {
        final existing = await context
            .read<AuthController>()
            .catalogApi
            .listServices(shopId);
        final fromSalon = existing.map((s) => s.name).toList();
        names = <String>{...fromSalon, ..._catalogServices}.toList();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _serviceOptions = names;
      _selectedServices = {
        for (final n in _catalogServices.take(4))
          if (names.contains(n)) n,
      };
    });
  }

  Future<void> _addPortfolioPhotos() async {
    late final List<XFile> picked;
    try {
      picked = await ImagePicker().pickMultiImage(
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 88,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      _toast(
        e.code == 'channel-error'
            ? 'Photo picker needs a full app restart. Stop the app and run again.'
            : (e.message ?? 'Could not open photo library.'),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      _toast('Could not open photo library.');
      return;
    }
    if (picked.isEmpty || !mounted) return;

    setState(() => _addingPortfolio = true);
    final auth = context.read<AuthController>();
    try {
      for (final file in picked) {
        final bytes = await file.readAsBytes();
        final uploaded = await auth.uploadsApi.uploadImage(
          bytes: bytes,
          filename: file.name.isNotEmpty ? file.name : 'work.jpg',
          purpose: 'shop',
        );
        _portfolio.add(
          _PortfolioShot(file: File(file.path), url: uploaded.url),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      _toast('Could not upload photo.');
    } finally {
      if (mounted) setState(() => _addingPortfolio = false);
    }
  }

  Future<void> _continue() async {
    if (_busy) return;

    if (_step == 0) {
      // Owners skip the personal “professional profile” wizard and go straight
      // into salon setup: profile → services → hours → team → booking.
      if (_type == ProviderWorkType.owner) {
        await _startOwnerSalonSetup();
        return;
      }
      setState(() => _step = 1);
      return;
    }

    if (_step == 1) {
      if (_name.text.trim().isEmpty) {
        _toast('Enter your display name.');
        return;
      }
      setState(() => _step = 2);
      await _loadSalons();
      return;
    }

    if (_step == 2) {
      if (!_salonNotListed && _selectedShopId == null) {
        _toast('Select a salon, or tap My salon isn’t listed.');
        return;
      }
      setState(() => _step = 3);
      await _prepareServices();
      return;
    }

    if (_step == 3) {
      if (_selectedServices.isEmpty) {
        _toast('Select at least one service.');
        return;
      }
      setState(() => _step = 4);
      return;
    }

    if (_step == 4) {
      if (_selectedSpecialties.isEmpty) {
        _toast('Pick at least one speciality.');
        return;
      }
      setState(() => _step = 5);
      return;
    }

    await _finish();
  }

  /// Create (or reuse) an owned shop and open Salon Profile onboarding.
  Future<void> _startOwnerSalonSetup() async {
    setState(() => _busy = true);
    final auth = context.read<AuthController>();
    final store = SessionStore();
    try {
      await auth.completeOnboarding(
        role: 'BARBER',
        providerType: 'OWNER',
      );

      String? shopId;
      try {
        final shops = await auth.catalogApi.listMyShops();
        final owned = shops.where((s) => s.isOwner == true).toList();
        if (owned.isNotEmpty) {
          shopId = owned.first.id;
        }
      } catch (_) {}

      if (shopId == null) {
        final display = (_name.text.trim().isNotEmpty
                ? _name.text.trim()
                : (auth.user?.fullName ?? '').trim())
            .trim();
        final salonName =
            display.isEmpty ? 'My Salon' : "$display's Salon";
        final onboardPhone = (auth.user?.phone ?? '').trim();
        final created = await auth.catalogApi.createShop({
          'name': salonName,
          'addressLine': 'Address to be added',
          if (onboardPhone.isNotEmpty) 'phone': onboardPhone,
        });
        shopId = created.id;
      }

      await store.setOwnerOnboardingComplete(false);
      await store.setProviderSetupStage('salon_profile');
      await store.setProviderSetupShopId(shopId);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.providerSalonProfile,
        (route) => false,
        arguments: SalonProfileArgs(
          shopId: shopId,
          fromOnboarding: true,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } catch (e) {
      if (!mounted) return;
      _toast(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    final auth = context.read<AuthController>();
    try {
      await auth.completeOnboarding(
        role: 'BARBER',
        providerType: _providerTypeApi,
      );
      await auth.updateProfile(fullName: _name.text.trim());
      if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
        await auth.authApi.updateMe(avatarUrl: _avatarUrl);
        await auth.reloadMe();
      }

      var shopId = _selectedShopId;
      var canManageShop = false;

      // Owners always get an owned shop (never only link as a freelancer).
      if (_type == ProviderWorkType.owner) {
        // Reuse an existing owned salon — never create duplicates that hide
        // services from customers in marketplace search.
        try {
          final shops = await auth.catalogApi.listMyShops();
          final owned = shops.where((s) => s.isOwner == true).toList();
          if (owned.isNotEmpty) {
            shopId = owned.first.id;
            canManageShop = true;
          }
        } catch (_) {}

        if (shopId == null || !canManageShop) {
          final onboardPhone = (auth.user?.phone ?? '').trim();
          final created = await auth.catalogApi.createShop({
            'name': '${_name.text.trim()}’s Salon',
            'addressLine': 'Address to be added',
            if (onboardPhone.isNotEmpty) 'phone': onboardPhone,
            if (_selectedSpecialties.isNotEmpty)
              'description': _selectedSpecialties.join(', '),
            'imageUrls': [
              for (final shot in _portfolio)
                if (shot.url != null) shot.url!,
            ],
          });
          shopId = created.id;
          canManageShop = true;
        } else {
          // Refresh owned shop media / description without creating a new one.
          final urls = [
            for (final shot in _portfolio)
              if (shot.url != null) shot.url!,
          ];
          if (urls.isNotEmpty || _selectedSpecialties.isNotEmpty) {
            await auth.catalogApi.updateShop(shopId, {
              if (urls.isNotEmpty) 'imageUrls': urls,
              if (_selectedSpecialties.isNotEmpty)
                'description': _selectedSpecialties.join(', '),
            });
          }
        }
      } else if (shopId != null && !_salonNotListed) {
        try {
          await auth.catalogApi.linkShop(shopId);
        } on ApiException catch (e) {
          if (e.statusCode != 409) rethrow;
        }
        // Persist selected services onto the salon for this professional.
        try {
          final existing = await auth.catalogApi.listServices(shopId);
          final have = existing.map((s) => s.name.toLowerCase()).toSet();
          for (final name in _selectedServices) {
            if (have.contains(name.toLowerCase())) continue;
            await auth.catalogApi.createService(
              shopId,
              name: name,
              priceAmount: _servicePrices[name] ?? 25,
            );
          }
        } catch (_) {
          // Pending approval may still allow create; ignore soft failures.
        }
      } else if (_type != ProviderWorkType.staff) {
        final created = await auth.catalogApi.createShop({
          'name': '${_name.text.trim()}’s Studio',
          'addressLine': 'Address to be added',
          'description': _selectedSpecialties.join(', '),
          'imageUrls': [
            for (final shot in _portfolio)
              if (shot.url != null) shot.url!,
          ],
        });
        shopId = created.id;
        canManageShop = true;
      }

      if (shopId != null && canManageShop) {
        final existing = await auth.catalogApi.listServices(shopId);
        final have = existing.map((s) => s.name.toLowerCase()).toSet();
        for (final name in _selectedServices) {
          if (have.contains(name.toLowerCase())) continue;
          await auth.catalogApi.createService(
            shopId,
            name: name,
            priceAmount: _servicePrices[name] ?? 25,
          );
        }
        final urls = [
          for (final shot in _portfolio)
            if (shot.url != null) shot.url!,
        ];
        if (urls.isNotEmpty) {
          await auth.catalogApi.updateShop(shopId, {
            'imageUrls': urls,
            if (_selectedSpecialties.isNotEmpty)
              'description': _selectedSpecialties.join(', '),
          });
        }
      }

      if (!mounted) return;
      final store = SessionStore();
      if (_type == ProviderWorkType.owner) {
        await store.setProviderSetupStage('salon_profile');
        await store.setProviderSetupShopId(shopId);
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.providerSalonProfile,
          (route) => false,
          arguments: SalonProfileArgs(
            shopId: shopId,
            fromOnboarding: true,
          ),
        );
      } else {
        await store.clearProviderSetup();
        if (!mounted) return;
        if (shopId != null && !_salonNotListed) {
          _toast('Join request sent. The salon will approve you soon.');
        }
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.providerShell,
          (route) => false,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } catch (e) {
      if (!mounted) return;
      _toast(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (_step > 0) {
                        setState(() => _step -= 1);
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: LooksUi.ink,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_step + 1) / 6,
                          minHeight: 4,
                          backgroundColor: const Color(0xFFE8E4F5),
                          color: LooksUi.purple,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _stepBody(),
                ),
              ),
              SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _busy ? null : _continue,
                    style: FilledButton.styleFrom(
                      backgroundColor: LooksUi.purple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFD9D3F5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _step == 0 && _type == ProviderWorkType.owner
                                ? 'Set up my salon'
                                : 'Continue',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _WorkTypeStep(
          key: const ValueKey('work'),
          type: _type,
          onChanged: (v) => setState(() => _type = v),
        );
      case 1:
        return _ProfileStep(
          key: const ValueKey('profile'),
          name: _name,
          profession: _profession,
          years: _years,
          professions: _professions,
          experience: _experience,
          localPhoto: _localPhoto,
          avatarUrl: _avatarUrl,
          uploading: _uploadingPhoto,
          onPickPhoto: _pickPhoto,
          onProfession: (v) => setState(() => _profession = v),
          onYears: (v) => setState(() => _years = v),
        );
      case 2:
        return _FindSalonStep(
          key: const ValueKey('salon'),
          search: _search,
          loading: _loadingSalons,
          error: _salonsError,
          salons: _salons,
          selectedId: _selectedShopId,
          onRetry: () => _loadSalons(
            q: _search.text.trim().isEmpty ? null : _search.text.trim(),
          ),
          onSearch: (q) {
            _salonSearchDebounce?.cancel();
            _loadSalons(q: q.trim().isEmpty ? null : q.trim());
          },
          onSelect: (id) => setState(() {
            _selectedShopId = id;
            _salonNotListed = false;
          }),
          onNotListed: () async {
            setState(() {
              _salonNotListed = true;
              _selectedShopId = null;
              _step = 3;
            });
            await _prepareServices();
          },
        );
      case 3:
        return _ServicesStep(
          key: const ValueKey('services'),
          options: _serviceOptions,
          selected: _selectedServices,
          onToggle: (name) {
            setState(() {
              if (_selectedServices.contains(name)) {
                _selectedServices.remove(name);
              } else {
                _selectedServices.add(name);
              }
            });
          },
        );
      case 4:
        return _SpecialtiesStep(
          key: const ValueKey('specialties'),
          options: _catalogSpecialties,
          selected: _selectedSpecialties,
          onToggle: (name) {
            setState(() {
              if (_selectedSpecialties.contains(name)) {
                _selectedSpecialties.remove(name);
              } else {
                _selectedSpecialties.add(name);
              }
            });
          },
        );
      default:
        return _PortfolioStep(
          key: const ValueKey('portfolio'),
          shots: _portfolio,
          adding: _addingPortfolio,
          onAdd: _addPortfolioPhotos,
        );
    }
  }
}

class _WorkTypeStep extends StatelessWidget {
  const _WorkTypeStep({
    super.key,
    required this.type,
    required this.onChanged,
  });

  final ProviderWorkType type;
  final ValueChanged<ProviderWorkType> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text(
          'How do you work?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: LooksUi.ink,
            height: 1.15,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 20),
        _WorkCard(
          icon: Icons.storefront_outlined,
          title: 'I own/manage a salon',
          subtitle: 'I run a salon, barbershop or beauty business.',
          selected: type == ProviderWorkType.owner,
          onTap: () => onChanged(ProviderWorkType.owner),
        ),
        const SizedBox(height: 12),
        _WorkCard(
          icon: Icons.person_outline_rounded,
          title: 'I work at a salon',
          subtitle: 'I’m a professional working at an existing salon.',
          selected: type == ProviderWorkType.staff,
          onTap: () => onChanged(ProviderWorkType.staff),
        ),
        const SizedBox(height: 12),
        _WorkCard(
          icon: Icons.local_shipping_outlined,
          title: 'I work independently',
          subtitle: 'I work mobile, from my own space, rent a chair, or both.',
          selected: type == ProviderWorkType.independent,
          onTap: () => onChanged(ProviderWorkType.independent),
        ),
      ],
    );
  }
}

class _WorkCard extends StatelessWidget {
  const _WorkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF3EEFF) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? LooksUi.purple : const Color(0xFFE6E4EE),
              width: selected ? 1.8 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: LooksUi.ink, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: LooksUi.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Color(0xFF6F6B80),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RadioMark(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? LooksUi.purple : Colors.white,
        border: Border.all(
          color: selected ? LooksUi.purple : const Color(0xFFC9C5D4),
          width: 1.6,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : null,
    );
  }
}

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({
    super.key,
    required this.name,
    required this.profession,
    required this.years,
    required this.professions,
    required this.experience,
    required this.localPhoto,
    required this.avatarUrl,
    required this.uploading,
    required this.onPickPhoto,
    required this.onProfession,
    required this.onYears,
  });

  final TextEditingController name;
  final String profession;
  final String years;
  final List<String> professions;
  final List<String> experience;
  final File? localPhoto;
  final String? avatarUrl;
  final bool uploading;
  final VoidCallback onPickPhoto;
  final ValueChanged<String> onProfession;
  final ValueChanged<String> onYears;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text(
          'Your professional profile',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: LooksUi.ink,
            height: 1.15,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: GestureDetector(
            onTap: uploading ? null : onPickPhoto,
            child: SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 112,
                      height: 112,
                      child: localPhoto != null
                          ? Image.file(localPhoto!, fit: BoxFit.cover)
                          : avatarUrl != null && avatarUrl!.isNotEmpty
                              ? Image.network(
                                  avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const ColoredBox(
                                    color: Color(0xFFF3F0FA),
                                    child: Icon(
                                      Icons.person_rounded,
                                      size: 52,
                                      color: LooksUi.purple,
                                    ),
                                  ),
                                )
                              : const ColoredBox(
                                  color: Color(0xFFF3F0FA),
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: 52,
                                    color: LooksUi.purple,
                                  ),
                                ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: LooksUi.purple,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: uploading
                          ? const Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.photo_camera_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const _FieldLabel('Display name'),
        const SizedBox(height: 8),
        _OutlinedField(
          child: TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Your name',
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Profession'),
        const SizedBox(height: 8),
        _OutlinedField(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: profession,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: [
                for (final p in professions)
                  DropdownMenuItem(value: p, child: Text(p)),
              ],
              onChanged: (v) {
                if (v != null) onProfession(v);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Years of experience'),
        const SizedBox(height: 8),
        _OutlinedField(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: years,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: [
                for (final y in experience)
                  DropdownMenuItem(value: y, child: Text(y)),
              ],
              onChanged: (v) {
                if (v != null) onYears(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FindSalonStep extends StatelessWidget {
  const _FindSalonStep({
    super.key,
    required this.search,
    required this.loading,
    required this.error,
    required this.salons,
    required this.selectedId,
    required this.onRetry,
    required this.onSearch,
    required this.onSelect,
    required this.onNotListed,
  });

  final TextEditingController search;
  final bool loading;
  final String? error;
  final List<ShopDto> salons;
  final String? selectedId;
  final VoidCallback onRetry;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onSelect;
  final VoidCallback onNotListed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Find your salon',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: LooksUi.ink,
            height: 1.15,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Where do you work?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: LooksUi.purple,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: search,
          textInputAction: TextInputAction.search,
          onSubmitted: onSearch,
          decoration: InputDecoration(
            hintText: 'Search salon name or location',
            hintStyle: const TextStyle(color: Color(0xFF9B98A8), fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9B98A8)),
            filled: true,
            fillColor: const Color(0xFFF4F3F8),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: LooksUi.purple),
                )
              : error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(error!, textAlign: TextAlign.center),
                          TextButton(
                            onPressed: onRetry,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      children: [
                        if (salons.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'No salons found. Try another search, or add yours.',
                              style: TextStyle(color: Color(0xFF6F6B80)),
                            ),
                          )
                        else
                          for (final shop in salons) ...[
                            _SalonRow(
                              shop: shop,
                              selected: selectedId == shop.id,
                              onTap: () => onSelect(shop.id),
                            ),
                            const SizedBox(height: 10),
                          ],
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: onNotListed,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: LooksUi.purple,
                              side: const BorderSide(
                                color: LooksUi.purple,
                                width: 1.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              'My salon isn’t listed',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}

class _SalonRow extends StatelessWidget {
  const _SalonRow({
    required this.shop,
    required this.selected,
    required this.onTap,
  });

  final ShopDto shop;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final area = shop.area ?? shop.district ?? shop.addressLine;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? LooksUi.purple : const Color(0xFFEDEAF4),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              StylAvatar(
                size: 48,
                imageUrl: shop.hasPhoto ? shop.imageUrl : null,
                name: shop.name,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: LooksUi.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${shop.distanceLabel} · $area',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6F6B80),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: LooksUi.ink,
      ),
    );
  }
}

class _OutlinedField extends StatelessWidget {
  const _OutlinedField({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E0EE)),
      ),
      child: child,
    );
  }
}

class _PortfolioShot {
  const _PortfolioShot({required this.file, this.url});

  final File file;
  final String? url;
}

class _ServicesStep extends StatelessWidget {
  const _ServicesStep({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text(
          'Your services',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: LooksUi.ink,
            height: 1.15,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Which services do you provide at this salon?',
          style: TextStyle(
            fontSize: 15,
            height: 1.35,
            color: Color(0xFF6F6B80),
          ),
        ),
        const SizedBox(height: 20),
        for (final name in options) ...[
          InkWell(
            onTap: () => onToggle(name),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  _CheckBox(checked: selected.contains(name)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: LooksUi.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: checked ? LooksUi.purple : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? LooksUi.purple : const Color(0xFFC9C5D4),
          width: 1.6,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}

class _SpecialtiesStep extends StatelessWidget {
  const _SpecialtiesStep({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  IconData _iconFor(String name) {
    return switch (name) {
      'Low Taper' || 'Skin Fade' => Icons.content_cut_rounded,
      'Afro Hair' => Icons.face_retouching_natural,
      'Beard Shaping' => Icons.spa_outlined,
      'Designs' => Icons.auto_awesome,
      'Kids Cuts' => Icons.child_care_outlined,
      _ => Icons.star_outline_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final compact = options.take(2).toList();
    final rest = options.skip(2).toList();
    return ListView(
      children: [
        const Text(
          'Your specialities',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: LooksUi.ink,
            height: 1.15,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'What are you best at?',
          style: TextStyle(
            fontSize: 15,
            height: 1.35,
            color: Color(0xFF6F6B80),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            for (var i = 0; i < compact.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _SpecialtyChip(
                  label: compact[i],
                  icon: _iconFor(compact[i]),
                  selected: selected.contains(compact[i]),
                  onTap: () => onToggle(compact[i]),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        for (final name in rest) ...[
          _SpecialtyChip(
            label: name,
            icon: _iconFor(name),
            selected: selected.contains(name),
            onTap: () => onToggle(name),
            expanded: true,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.expanded = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: selected ? LooksUi.purple : Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: expanded ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? LooksUi.purple : const Color(0xFFE4E0EE),
            ),
          ),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : icon,
                size: 18,
                color: selected ? Colors.white : LooksUi.ink,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : LooksUi.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return expanded ? child : child;
  }
}

class _PortfolioStep extends StatelessWidget {
  const _PortfolioStep({
    super.key,
    required this.shots,
    required this.adding,
    required this.onAdd,
  });

  final List<_PortfolioShot> shots;
  final bool adding;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      for (final shot in shots)
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(shot.file, fit: BoxFit.cover),
        ),
      _AddPhotoTile(busy: adding, onTap: onAdd),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Show your work',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: LooksUi.ink,
            height: 1.15,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Add photos of your best work.',
          style: TextStyle(
            fontSize: 15,
            height: 1.35,
            color: Color(0xFF6F6B80),
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: GridView.builder(
            itemCount: tiles.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (_, i) => tiles[i],
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F5FC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4E0EE)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: LooksUi.purple,
                  ),
                )
              else
                const Icon(Icons.add, size: 28, color: LooksUi.ink),
              const SizedBox(height: 8),
              Text(
                busy ? 'Uploading…' : 'Add photo',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: LooksUi.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

