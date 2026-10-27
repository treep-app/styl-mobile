import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/constants/salon_service_catalog.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';

/// Add / Edit Service form matching the product screenshot.
class ProviderServiceEditScreen extends StatefulWidget {
  const ProviderServiceEditScreen({
    super.key,
    required this.shopId,
    this.service,
  });

  final String shopId;
  final ServiceDto? service;

  @override
  State<ProviderServiceEditScreen> createState() =>
      _ProviderServiceEditScreenState();
}

class _ProviderServiceEditScreenState extends State<ProviderServiceEditScreen> {
  static const _maxDescription = 300;
  static const _durations = [15, 30, 45, 60, 75, 90, 120];

  late String _category;
  late String _serviceName;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late int _durationMin;
  var _priceType = 'FIXED';
  String? _imageUrl;
  var _saving = false;
  var _uploading = false;
  var _isActive = true;

  bool get _isEdit => widget.service != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.service;
    if (existing != null) {
      _category = SalonServiceCatalog.normalizeCategory(existing.category);
      _serviceName = existing.name;
      _description = TextEditingController(text: existing.description ?? '');
      _price = TextEditingController(
        text: existing.priceAmount.toStringAsFixed(2),
      );
      _durationMin = existing.durationMin;
      _priceType = existing.priceType.toUpperCase() == 'FROM' ? 'FROM' : 'FIXED';
      _imageUrl = existing.imageUrl;
      _isActive = existing.isActive;
    } else {
      _category = SalonServiceCatalog.categories.first;
      final templates = SalonServiceCatalog.forCategory(_category);
      final first = templates.first;
      _serviceName = first.name;
      _description = TextEditingController(text: first.description);
      _price = TextEditingController(
        text: first.defaultPrice.toStringAsFixed(2),
      );
      _durationMin = first.defaultDurationMin;
    }
    _description.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  List<String> get _serviceNames =>
      SalonServiceCatalog.forCategory(_category).map((t) => t.name).toList();

  void _onCategoryChanged(String? value) {
    if (value == null) return;
    final templates = SalonServiceCatalog.forCategory(value);
    final first = templates.isNotEmpty ? templates.first : null;
    setState(() {
      _category = value;
      if (first != null) {
        _serviceName = first.name;
        _description.text = first.description;
        _price.text = first.defaultPrice.toStringAsFixed(2);
        _durationMin = first.defaultDurationMin;
      }
    });
  }

  void _onServiceChanged(String? value) {
    if (value == null) return;
    final template = SalonServiceCatalog.byName(value);
    setState(() {
      _serviceName = value;
      if (template != null && !_isEdit) {
        _description.text = template.description;
        _price.text = template.defaultPrice.toStringAsFixed(2);
        _durationMin = template.defaultDurationMin;
      }
    });
  }

  Future<void> _changeImage() async {
    late final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 88,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Could not open photo library.')),
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
    try {
      final bytes = await picked.readAsBytes();
      final uploaded =
          await context.read<AuthController>().uploadsApi.uploadImage(
                bytes: bytes,
                filename: picked.name.isNotEmpty ? picked.name : 'service.jpg',
                purpose: 'shop',
              );
      if (!mounted) return;
      setState(() {
        _imageUrl = uploaded.url;
        _uploading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not upload image.')),
      );
    }
  }

  Future<void> _removeService() async {
    final existing = widget.service;
    if (existing == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this service?'),
        content: Text(
          '“${existing.name}” will be removed from your salon and customers won’t be able to book it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await context.read<AuthController>().catalogApi.deleteService(
            widget.shopId,
            existing.id,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“${existing.name}” removed')),
      );
      Navigator.of(context).pop(true);
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

  Future<void> _save() async {
    final name = _serviceName.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a service.')),
      );
      return;
    }
    final price = double.tryParse(_price.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price.')),
      );
      return;
    }
    final description = _description.text.trim();
    if (description.length > _maxDescription) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Description must be 300 characters or less.')),
      );
      return;
    }

    setState(() => _saving = true);
    final api = context.read<AuthController>().catalogApi;
    try {
      late final ServiceDto saved;
      if (_isEdit) {
        saved = await api.updateService(
          widget.shopId,
          widget.service!.id,
          name: name,
          priceAmount: price,
          durationMin: _durationMin,
          category: _category,
          description: description,
          imageUrl: _imageUrl ?? '',
          priceType: _priceType,
          isActive: _isActive,
        );
      } else {
        saved = await api.createService(
          widget.shopId,
          name: name,
          priceAmount: price,
          durationMin: _durationMin,
          category: _category,
          description: description,
          imageUrl: _imageUrl,
          priceType: _priceType,
        );
      }
      if (!mounted) return;
      await Navigator.of(context).pushNamed(
        AppRoutes.providerServiceAssign,
        arguments: ProviderServiceAssignArgs(
          shopId: widget.shopId,
          service: saved,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    final names = _serviceNames;
    if (!names.contains(_serviceName) && names.isNotEmpty) {
      // Keep custom names editable by injecting into dropdown options.
    }
    final serviceItems = {
      ...names,
      if (_serviceName.isNotEmpty) _serviceName,
    }.toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: AppColors.brandPrimary,
                  ),
                  const Expanded(
                    child: Text(
                      'Add / Edit Service',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Service details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _LabeledDropdown<String>(
                                label: 'Category',
                                value: _category,
                                items: SalonServiceCatalog.categories,
                                onChanged: _onCategoryChanged,
                              ),
                              const SizedBox(height: 8),
                              _LabeledDropdown<String>(
                                label: 'Service',
                                value: serviceItems.contains(_serviceName)
                                    ? _serviceName
                                    : serviceItems.first,
                                items: serviceItems,
                                onChanged: _onServiceChanged,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 76,
                                height: 76,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (_imageUrl != null &&
                                        _imageUrl!.isNotEmpty)
                                      Image.network(
                                        _imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _imagePlaceholder(),
                                      )
                                    else
                                      _imagePlaceholder(),
                                    if (_uploading)
                                      ColoredBox(
                                        color:
                                            Colors.black.withValues(alpha: 0.4),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _uploading ? null : _changeImage,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Change',
                                style: TextStyle(
                                  color: Color(0xFF6B5CE7),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _description,
                      maxLines: 4,
                      minLines: 4,
                      maxLength: _maxDescription,
                      style: const TextStyle(fontSize: 14, height: 1.35),
                      decoration: _decoration().copyWith(
                        counterText: '',
                        alignLabelWithHint: true,
                        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_description.text.length}/$_maxDescription',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Price & time',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Price type',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _PriceTypeTile(
                            label: 'Fixed price',
                            selected: _priceType == 'FIXED',
                            onTap: () => setState(() => _priceType = 'FIXED'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PriceTypeTile(
                            label: 'From price',
                            selected: _priceType == 'FROM',
                            onTap: () => setState(() => _priceType = 'FROM'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: _decoration().copyWith(
                        prefixText: '£ ',
                        prefixStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _LabeledDropdown<int>(
                      label: 'Duration',
                      value: _durations.contains(_durationMin)
                          ? _durationMin
                          : 45,
                      items: _durations,
                      labelBuilder: (m) => '$m minutes',
                      onChanged: (v) {
                        if (v != null) setState(() => _durationMin = v);
                      },
                    ),
                    if (_isEdit) ...[
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text(
                          'Active (bookable)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        value: _isActive,
                        activeThumbColor: const Color(0xFF22C55E),
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                      TextButton.icon(
                        onPressed: _saving ? null : _removeService,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remove service'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                      ),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6B5CE7),
                          disabledBackgroundColor: const Color(0xFFD9D3F5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFEDE9FE),
      child: const Icon(Icons.content_cut, color: AppColors.brandPrimary),
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelBuilder,
  });

  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.brandPrimary,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          // ignore: deprecated_member_use
          value: value,
          isDense: true,
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    labelBuilder?.call(item) ?? item.toString(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceTypeTile extends StatelessWidget {
  const _PriceTypeTile({
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF6B5CE7)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 20,
                color: selected
                    ? const Color(0xFF6B5CE7)
                    : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
