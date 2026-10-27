import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/phone_utils.dart';

  /// Pro phone field: flag + dial code + full-width number input.
class PhoneNumberField extends StatefulWidget {
  const PhoneNumberField({
    super.key,
    required this.controller,
    this.label = 'Mobile Number',
    this.hintText = 'Enter mobile number',
    this.initialCountryCode = 'GB',
    this.onCountryChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;

  /// ISO-3166 alpha-2 — default United Kingdom.
  final String initialCountryCode;
  final ValueChanged<Country>? onCountryChanged;

  @override
  State<PhoneNumberField> createState() => PhoneNumberFieldState();
}

class PhoneNumberFieldState extends State<PhoneNumberField> {
  late Country _country;
  late final FocusNode _focusNode;
  var _focused = false;

  Country get country => _country;

  String get dialCode => '+${_country.phoneCode}';

  String get fullNumber {
    return composeE164(
      dialCode: dialCode,
      national: widget.controller.text,
      isoCountry: _country.countryCode,
    );
  }

  @override
  void initState() {
    super.initState();
    _country = CountryParser.parseCountryCode(widget.initialCountryCode);
    _focusNode = FocusNode()
      ..addListener(() {
        setState(() => _focused = _focusNode.hasFocus);
      });
  }

  @override
  void didUpdateWidget(covariant PhoneNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCountryCode != widget.initialCountryCode) {
      _country = CountryParser.parseCountryCode(widget.initialCountryCode);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _openPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      favorite: const ['GB', 'US', 'IN', 'AE', 'ZA', 'IE'],
      countryListTheme: CountryListThemeData(
        flagSize: 24,
        backgroundColor: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.xl),
        ),
        bottomSheetHeight: MediaQuery.sizeOf(context).height * 0.72,
        inputDecoration: InputDecoration(
          hintText: 'Search country',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: AppColors.lightSurfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        searchTextStyle: context.textStyles.bodyMedium,
        textStyle: context.textStyles.bodyMedium?.copyWith(
          color: AppColors.lightOnSurface,
        ),
      ),
      onSelect: (country) {
        setState(() => _country = country);
        widget.onCountryChanged?.call(country);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxLen = _maxNationalLength(_country);
    final borderColor = _focused
        ? AppColors.brandPrimary
        : Colors.transparent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: context.textStyles.bodyLarge?.copyWith(
            color: AppColors.lightOnSurface,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.lightSurfaceVariant,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: borderColor,
              width: _focused ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openPicker,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppRadii.md),
                  ),
                  child: SizedBox(
                    height: 56,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _country.flagEmoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dialCode,
                            style: const TextStyle(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 22,
                            color: AppColors.lightOnSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: const Color(0xFFD0D4DB),
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                    color: AppColors.lightOnSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(maxLen),
                  ],
                  decoration: InputDecoration(
                    hintText: _country.countryCode == 'GB'
                        ? '079XX XXXXXX'
                        : widget.hintText,
                    hintStyle: TextStyle(
                      color: AppColors.lightHint.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
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

  int _maxNationalLength(Country country) {
    switch (country.countryCode) {
      case 'IN':
        return 10;
      case 'US':
      case 'CA':
        return 10;
      case 'GB':
        return 11;
      case 'AE':
        return 9;
      case 'ZA':
        return 9;
      case 'IE':
        return 10;
      default:
        return 15;
    }
  }
}
