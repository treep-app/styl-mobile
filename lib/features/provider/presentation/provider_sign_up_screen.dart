import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../widgets/phone_number_field.dart';
import '../../../widgets/styl_primary_button.dart';
import '../../../widgets/styl_text_field.dart';
import '../data/provider_demo_data.dart';

enum _ProviderType { salon, mobileBarber }

/// Figma Sign Up-(Barber)-1 / Link salon / Sign Up-(Barber)-2 — one multi-step flow.
class ProviderSignUpScreen extends StatefulWidget {
  const ProviderSignUpScreen({super.key});

  @override
  State<ProviderSignUpScreen> createState() => _ProviderSignUpScreenState();
}

class _ProviderSignUpScreenState extends State<ProviderSignUpScreen> {
  /// 0 personal · 1 link/add salon · 2 describe + availability
  var _step = 0;
  var _type = _ProviderType.salon;
  var _acceptedTerms = false;
  var _linkedSalonIndex = 0;
  var _busy = false;
  var _loadingSalons = false;
  String? _salonsError;
  List<LinkableSalon> _linkableSalons = const [];

  final _nameController = TextEditingController(text: 'Naman Malani');
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneFieldKey = GlobalKey<PhoneNumberFieldState>();
  final _districtController = TextEditingController(text: 'Mumbai');
  final _areaController = TextEditingController(text: 'Marine Drive');
  final _salonNameController =
      TextEditingController(text: 'Eliza Burke Hair saloon');
  final _pincodeController = TextEditingController(text: '552155');
  final _addressController =
      TextEditingController(text: '301 Dorty walks, Stockton, California');
  final _descriptionController = TextEditingController(
    text:
        'Lorem Ipsum is simply dummy text of the printing and typesetting industry.',
  );
  final _websiteController =
      TextEditingController(text: 'www.elizaburke.com');
  final _searchController = TextEditingController();
  var _obscurePassword = true;

  final _services = <_ServiceRow>[
    _ServiceRow(name: TextEditingController(text: 'Hair Cut'), price: TextEditingController(text: '50')),
    _ServiceRow(name: TextEditingController(text: 'Facial'), price: TextEditingController(text: '70')),
  ];

  final _slots = <_AvailSlot>[
    _AvailSlot(date: '12/02/2021', start: '10:00 AM', end: '08:00 PM'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _districtController.dispose();
    _areaController.dispose();
    _salonNameController.dispose();
    _pincodeController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _searchController.dispose();
    for (final s in _services) {
      s.name.dispose();
      s.price.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLinkableSalons({String? q}) async {
    setState(() {
      _loadingSalons = true;
      _salonsError = null;
    });
    try {
      final shops =
          await context.read<AuthController>().catalogApi.listShops(q: q);
      if (!mounted) return;
      setState(() {
        _linkableSalons = shops.map(LinkableSalon.fromShop).toList();
        if (_linkedSalonIndex >= _linkableSalons.length) {
          _linkedSalonIndex = 0;
        }
        _loadingSalons = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _salonsError = friendlyErrorMessage(e);
        _loadingSalons = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _salonsError = friendlyErrorMessage(e);
        _loadingSalons = false;
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goLogin() {
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.providerLogin,
      arguments: const LoginArgs(isServiceProvider: true),
    );
  }

  Future<void> _onPrimary() async {
    if (_step == 0) {
      if (_nameController.text.trim().isEmpty) {
        _toast('Please enter your name.');
        return;
      }
      if (_phoneController.text.trim().length < 7) {
        _toast('Enter a valid mobile number.');
        return;
      }
      if (_passwordController.text.length < 6) {
        _toast('Password must be at least 6 characters.');
        return;
      }
      if (!_acceptedTerms) {
        _toast('Please accept Terms & Conditions.');
        return;
      }
      setState(() => _step = 1);
      if (_type == _ProviderType.mobileBarber) {
        await _loadLinkableSalons();
      }
      return;
    }

    if (_step == 1) {
      if (_type == _ProviderType.salon) {
        if (_salonNameController.text.trim().isEmpty) {
          _toast('Enter salon name.');
          return;
        }
      } else if (_linkableSalons.isEmpty) {
        _toast('Select a salon to link, or add a new salon.');
        return;
      }
      setState(() => _step = 2);
      return;
    }

    final fullNumber = _phoneFieldKey.currentState?.fullNumber ??
        composeE164(
          dialCode: '+44',
          national: _phoneController.text.trim(),
          isoCountry: 'GB',
        );

    final draft = ProviderSignupDraft(
      createSalon: _type == _ProviderType.salon,
      linkShopId: _type == _ProviderType.mobileBarber && _linkableSalons.isNotEmpty
          ? _linkableSalons[_linkedSalonIndex].id
          : null,
      salonName: _salonNameController.text.trim(),
      addressLine: _addressController.text.trim(),
      area: _areaController.text.trim(),
      district: _districtController.text.trim(),
      pincode: _pincodeController.text.trim(),
      description: _descriptionController.text.trim(),
      website: _websiteController.text.trim(),
      services: [
        for (final s in _services)
          if (s.name.text.trim().isNotEmpty)
            ProviderServiceDraft(
              name: s.name.text.trim(),
              priceAmount: double.tryParse(s.price.text.trim()) ?? 0,
            ),
      ],
    );

    setState(() => _busy = true);
    try {
      final result = await context.read<AuthController>().sendOtp(
            phone: fullNumber,
            role: 'BARBER',
          );
      if (!mounted) return;
      if (result.devCode != null) {
        _toast('Dev OTP: ${result.devCode}');
      }
      Navigator.of(context).pushNamed(
        AppRoutes.customerOtp,
        arguments: OtpArgs(
          phoneNumber: fullNumber,
          fullName: _nameController.text.trim(),
          password: _passwordController.text,
          fromSignUp: true,
          isServiceProvider: true,
          providerSignup: draft,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _addService() {
    setState(() {
      _services.add(
        _ServiceRow(
          name: TextEditingController(),
          price: TextEditingController(),
        ),
      );
    });
  }

  void _removeService(int index) {
    if (_services.length <= 1) return;
    setState(() {
      final row = _services.removeAt(index);
      row.name.dispose();
      row.price.dispose();
    });
  }

  void _addSlot() {
    setState(() {
      _slots.add(
        _AvailSlot(date: '12/02/2021', start: '10:00 AM', end: '08:00 PM'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
              child: Row(
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
                  ),
                  Text(
                    _step == 0
                        ? 'Sign Up'
                        : _step == 1 && _type == _ProviderType.mobileBarber
                            ? 'Link a salon you work with'
                            : _step == 1
                                ? 'Add Salon'
                                : 'Add Salon',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: _step == 0
                    ? _buildPersonalStep()
                    : _step == 1
                        ? (_type == _ProviderType.mobileBarber
                            ? _buildLinkSalonStep()
                            : _buildAddSalonStep())
                        : _buildDescribeStep(),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
              child: Column(
                children: [
                  if (_step == 1 && _type == _ProviderType.salon)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _addService,
                        child: const Text(
                          'Add New Item',
                          style: TextStyle(color: Color(0xFF8C8C8C)),
                        ),
                      ),
                    ),
                  if (_step == 1 && _type == _ProviderType.mobileBarber)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _type = _ProviderType.salon;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brandPrimary,
                          side: const BorderSide(
                            color: AppColors.brandPrimary,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: const Text(
                          'Add New Salon',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  if (_step == 1 && _type == _ProviderType.mobileBarber)
                    const SizedBox(height: 12),
                  StylPrimaryButton(
                    label: _step == 2 ? 'Continue' : 'Next',
                    isLoading: _busy,
                    onPressed: _busy ? null : _onPrimary,
                  ),
                  if (_step == 0) ...[
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _goLogin,
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF575757),
                          ),
                          children: const [
                            TextSpan(text: 'Already have a account? '),
                            TextSpan(
                              text: 'Login',
                              style: TextStyle(
                                color: AppColors.brandPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StylTextField(
          controller: _nameController,
          label: 'Name',
          hintText: 'Enter your name',
        ),
        const SizedBox(height: 18),
        PhoneNumberField(
          key: _phoneFieldKey,
          controller: _phoneController,
          label: 'mobile No',
        ),
        const SizedBox(height: 18),
        StylTextField(
          controller: _passwordController,
          label: 'Password',
          hintText: 'At least 6 characters',
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppColors.lightOnSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 18),
        StylTextField(
          controller: _districtController,
          label: 'District/state',
          hintText: 'District',
        ),
        const SizedBox(height: 18),
        StylTextField(
          controller: _areaController,
          label: 'area',
          hintText: 'Area',
        ),
        const SizedBox(height: 18),
        const Text(
          'Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TypeChip(
                label: 'Salon',
                selected: _type == _ProviderType.salon,
                onTap: () => setState(() => _type = _ProviderType.salon),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _TypeChip(
                label: 'Mobile Barber',
                selected: _type == _ProviderType.mobileBarber,
                onTap: () => setState(() => _type = _ProviderType.mobileBarber),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: _acceptedTerms,
                onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                activeColor: AppColors.brandPrimary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 13, color: AppColors.brandPrimary),
                  children: [
                    TextSpan(text: 'Accept all '),
                    TextSpan(
                      text: 'Terms & Conditions',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLinkSalonStep() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          onSubmitted: (value) =>
              _loadLinkableSalons(q: value.trim().isEmpty ? null : value.trim()),
          decoration: InputDecoration(
            hintText: 'Search salon',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: AppColors.lightSurfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_loadingSalons)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: CircularProgressIndicator(),
          )
        else if (_salonsError != null)
          Column(
            children: [
              Text(_salonsError!),
              TextButton(
                onPressed: () => _loadLinkableSalons(),
                child: const Text('Retry'),
              ),
            ],
          )
        else if (_linkableSalons.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No salons found'),
          )
        else
          ...List.generate(_linkableSalons.length, (index) {
            final salon = _linkableSalons[index];
            final selected = _linkedSalonIndex == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () => setState(() => _linkedSalonIndex = index),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 93,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    children: [
                      Image.network(
                        salon.imageUrl,
                        width: 119,
                        height: 93,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 119,
                          color: AppColors.lightSurfaceVariant,
                          child: const Icon(Icons.storefront),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                salon.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                salon.address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF575757),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 18,
                          color: selected
                              ? AppColors.brandPrimary
                              : const Color(0xFFBDBDBD),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAddSalonStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StylTextField(
          controller: _salonNameController,
          label: 'Salon Name',
          hintText: 'Salon name',
        ),
        const SizedBox(height: 18),
        StylTextField(
          controller: _pincodeController,
          label: 'Pincode',
          hintText: 'Pincode',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 18),
        StylTextField(
          controller: _addressController,
          label: 'Address',
          hintText: 'Address',
        ),
        const SizedBox(height: 22),
        const Text(
          'Add Services',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...List.generate(_services.length, (index) {
          final row = _services[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.name,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.lightSurfaceVariant,
                      hintText: 'Service',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: row.price,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.lightSurfaceVariant,
                      hintText: '£',
                      prefixText: '£ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _removeService(index),
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFD64545)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDescribeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Describe your Salon',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _descriptionController,
          maxLines: 5,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.lightSurfaceVariant,
            hintText: 'Add description',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Link Website',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _websiteController,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.lightSurfaceVariant,
            hintText: 'www.example.com',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Upload Images',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: AppColors.lightSurfaceVariant,
            borderRadius: BorderRadius.circular(3),
          ),
          child: const Column(
            children: [
              Icon(Icons.upload_file_outlined, color: Color(0xFF8C8C8C)),
              SizedBox(height: 8),
              Text('Select Files', style: TextStyle(color: Color(0xFF8C8C8C))),
              SizedBox(height: 4),
              Text('Img.jpg', style: TextStyle(fontSize: 12, color: Color(0xFFBDBDBD))),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Availability',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: _addSlot,
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._slots.map((slot) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${slot.date}  ·  ${slot.start} - ${slot.end}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ServiceRow {
  _ServiceRow({required this.name, required this.price});

  final TextEditingController name;
  final TextEditingController price;
}

class _AvailSlot {
  _AvailSlot({
    required this.date,
    required this.start,
    required this.end,
  });

  final String date;
  final String start;
  final String end;
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPrimary : AppColors.lightSurfaceVariant,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 16,
              color: selected ? Colors.white : AppColors.brandPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.brandPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
