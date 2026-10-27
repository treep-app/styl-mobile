import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../widgets/phone_number_field.dart';

const _accent = Color(0xFF4F6BFF);
const _muted = Color(0xFF8B93A7);
const _border = Color(0xFFE8EAF0);
const _infoBg = Color(0xFFEEF2FF);

enum _InviteChannel { email, phone }

/// Owner flow — invite a professional by email or phone (Brevo delivery).
class AddProfessionalScreen extends StatefulWidget {
  const AddProfessionalScreen({super.key, required this.args});

  final AddProfessionalArgs args;

  @override
  State<AddProfessionalScreen> createState() => _AddProfessionalScreenState();
}

class _AddProfessionalScreenState extends State<AddProfessionalScreen> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  final _phoneKey = GlobalKey<PhoneNumberFieldState>();

  var _channel = _InviteChannel.email;
  var _sending = false;
  var _messageTouched = false;
  String? _salonName;

  @override
  void initState() {
    super.initState();
    _salonName = widget.args.salonName;
    _messageController.text = _defaultMessage();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSalonName());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String _inviteeHint() {
    if (_channel == _InviteChannel.email) {
      final email = _emailController.text.trim();
      if (email.contains('@')) {
        final local = email.split('@').first.trim();
        if (local.isNotEmpty) {
          return local[0].toUpperCase() + local.substring(1);
        }
      }
    }
    return 'there';
  }

  String _defaultMessage() {
    final salon = (_salonName ?? 'our salon').trim();
    return 'Hi ${_inviteeHint()}, You’re invited to join $salon on STYL. '
        'Once you accept, you’ll be able to manage your own profile and '
        'customers can book you through our salon.';
  }

  void _refreshDefaultMessage() {
    if (_messageTouched) return;
    _messageController.text = _defaultMessage();
  }

  Future<void> _loadSalonName() async {
    if (_salonName != null && _salonName!.trim().isNotEmpty) return;
    try {
      final shop = await context
          .read<AuthController>()
          .catalogApi
          .getShop(widget.args.shopId);
      if (!mounted) return;
      setState(() => _salonName = shop.name);
      _refreshDefaultMessage();
    } catch (_) {
      // Keep fallback salon name in message.
    }
  }

  Future<void> _send() async {
    final message = _messageController.text.trim();
    if (message.length > 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Personal message must be 300 characters or less.')),
      );
      return;
    }

    String? email;
    String? phone;
    if (_channel == _InviteChannel.email) {
      email = _emailController.text.trim().toLowerCase();
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid email address.')),
        );
        return;
      }
    } else {
      final local = _phoneController.text.trim();
      if (local.length < 7) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid mobile number.')),
        );
        return;
      }
      phone = _phoneKey.currentState?.fullNumber ??
          composeE164(dialCode: '+44', national: local, isoCountry: 'GB');
    }

    setState(() => _sending = true);
    try {
      final invitation =
          await context.read<AuthController>().catalogApi.createShopInvitation(
                shopId: widget.args.shopId,
                channel: _channel == _InviteChannel.email ? 'EMAIL' : 'PHONE',
                email: email,
                phone: phone,
                personalMessage: message.isEmpty ? null : message,
              );
      if (!mounted) return;
      // Navigate only after the API returns — delivery already confirmed server-side.
      await Navigator.of(context).pushReplacementNamed(
        AppRoutes.providerInvitationSent,
        arguments: InvitationSentArgs(
          shopId: widget.args.shopId,
          salonName: _salonName ?? invitation.shopName ?? 'your salon',
          invitation: invitation,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      final msg = e.message.trim().isEmpty
          ? 'Could not send invitation. Please try again.'
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _channel == _InviteChannel.email
                ? 'Could not send the email invitation. Please try again.'
                : 'Could not send the SMS invitation. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chars = _messageController.text.length;

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
                    onPressed: _sending
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: AppColors.brandPrimary,
                  ),
                  const Expanded(
                    child: Text(
                      'Add Professional',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const Text(
                    'Invite a professional',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandPrimary,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Send an invitation to a professional to join your salon. '
                    'They’ll create or log in to their own account.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Invite by',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ChannelChip(
                          label: 'Email',
                          icon: Icons.mail_outline,
                          selected: _channel == _InviteChannel.email,
                          onTap: () {
                            setState(() => _channel = _InviteChannel.email);
                            _refreshDefaultMessage();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ChannelChip(
                          label: 'Phone number',
                          icon: Icons.phone_outlined,
                          selected: _channel == _InviteChannel.phone,
                          onTap: () {
                            setState(() => _channel = _InviteChannel.phone);
                            _refreshDefaultMessage();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_channel == _InviteChannel.email) ...[
                    const Text(
                      'Email address',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(_refreshDefaultMessage),
                      decoration: _inputDecoration(
                        hint: 'jay@gmail.com',
                      ),
                    ),
                  ] else ...[
                    PhoneNumberField(
                      key: _phoneKey,
                      controller: _phoneController,
                      label: 'Phone number',
                      hintText: 'Enter mobile number',
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Personal message (optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    maxLines: 5,
                    maxLength: 300,
                    onChanged: (_) {
                      _messageTouched = true;
                      setState(() {});
                    },
                    decoration: _inputDecoration(
                      hint: 'Add a short personal note…',
                    ).copyWith(
                      counterText: '$chars/300',
                      counterStyle: const TextStyle(
                        fontSize: 12,
                        color: _muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _infoBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: _accent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _channel == _InviteChannel.email
                                ? 'They’ll receive an email invitation with a link to join. If they’re new to STYL, they’ll need to create an account.'
                                : 'They’ll receive an SMS with a link to join. If they’re new to STYL, they’ll need to create an account.',
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFF3B4663),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _sending ? null : _send,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Send invitation',
                            style: TextStyle(fontWeight: FontWeight.w700),
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

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB0B6C3)),
      filled: true,
      fillColor: const Color(0xFFF2F3F7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  const _ChannelChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEEF0FF) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _accent : _border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? _accent : _muted,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? _accent : const Color(0xFF5B6475),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
