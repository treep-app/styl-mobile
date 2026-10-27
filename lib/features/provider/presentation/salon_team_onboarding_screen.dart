import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/session_store.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';

const _accent = Color(0xFF4F6BFF);
const _muted = Color(0xFF8B93A7);
const _border = Color(0xFFE8EAF0);
const _chipIdle = Color(0xFFF1F2F6);

enum _TeamFilter { all, active, pending, inactive }

enum _MemberStatus { active, pending, inactive }

/// Owner onboarding — invite / manage salon team (matches product UI).
class SalonTeamOnboardingScreen extends StatefulWidget {
  const SalonTeamOnboardingScreen({
    super.key,
    this.shopId,
    this.fromOnboarding = false,
  });

  final String? shopId;
  final bool fromOnboarding;

  @override
  State<SalonTeamOnboardingScreen> createState() =>
      _SalonTeamOnboardingScreenState();
}

class _SalonTeamOnboardingScreenState extends State<SalonTeamOnboardingScreen> {
  var _loading = true;
  String? _error;
  String? _shopId;
  String? _salonName;
  List<SpecialistDto> _team = const [];
  List<ShopInvitationDto> _invitations = const [];
  var _filter = _TeamFilter.all;

  @override
  void initState() {
    super.initState();
    _shopId = widget.shopId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  _MemberStatus _statusOf(SpecialistDto m) {
    if (m.membershipStatus == 'PENDING') return _MemberStatus.pending;
    if (!m.isOnboarded) return _MemberStatus.pending;
    // Soft inactive: onboarded but marked offline / not available and not busy.
    if (!m.isOnline && !m.isAvailableNow && m.presenceLabel == 'Offline') {
      // Still treat as Active for roster unless explicitly unlinked.
      return _MemberStatus.active;
    }
    return _MemberStatus.active;
  }

  List<SpecialistDto> get _filteredMembers {
    switch (_filter) {
      case _TeamFilter.all:
        return _team;
      case _TeamFilter.active:
        return _team.where((m) => _statusOf(m) == _MemberStatus.active).toList();
      case _TeamFilter.pending:
        return _team
            .where((m) => _statusOf(m) == _MemberStatus.pending)
            .toList();
      case _TeamFilter.inactive:
        return _team
            .where((m) => _statusOf(m) == _MemberStatus.inactive)
            .toList();
    }
  }

  List<ShopInvitationDto> get _filteredInvites {
    if (_filter == _TeamFilter.active || _filter == _TeamFilter.inactive) {
      return const [];
    }
    return _invitations;
  }

  int get _totalCount => _team.length + _invitations.length;

  int _count(_TeamFilter filter) {
    switch (filter) {
      case _TeamFilter.all:
        return _totalCount;
      case _TeamFilter.active:
        return _team.where((m) => _statusOf(m) == _MemberStatus.active).length;
      case _TeamFilter.pending:
        return _team.where((m) => _statusOf(m) == _MemberStatus.pending).length +
            _invitations.length;
      case _TeamFilter.inactive:
        return _team
            .where((m) => _statusOf(m) == _MemberStatus.inactive)
            .length;
    }
  }

  String _roleLabel(SpecialistDto m) {
    final specialty = m.specialty?.trim();
    if (specialty != null && specialty.isNotEmpty) return specialty;
    return switch (m.memberRole) {
      'OWNER' => 'Owner',
      'FREELANCER' => 'Stylist',
      _ => 'Barber',
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthController>();
      var shopId = _shopId;
      ShopDto? shop;
      if (shopId == null) {
        final mine = await auth.catalogApi.listMyShops();
        shop = mine.where((s) => s.isOwner == true).firstOrNull ??
            mine.firstOrNull;
        shopId = shop?.id;
      } else {
        try {
          shop = await auth.catalogApi.getShop(shopId);
        } catch (_) {}
      }
      if (shopId == null) throw Exception('Salon not found');
      final team = await auth.catalogApi.listSpecialists(
        shopId,
        includePending: true,
      );
      List<ShopInvitationDto> invitations = const [];
      try {
        invitations = await auth.catalogApi.listShopInvitations(shopId);
      } catch (_) {
        // Older API / non-owner — ignore.
      }
      if (!mounted) return;
      setState(() {
        _shopId = shopId;
        _salonName = shop?.name;
        _team = team;
        _invitations = invitations;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _invite() async {
    final shopId = _shopId;
    if (shopId == null) return;
    final added = await Navigator.of(context).pushNamed(
      AppRoutes.providerAddProfessional,
      arguments: AddProfessionalArgs(
        shopId: shopId,
        salonName: _salonName,
      ),
    );
    if ((added == true || added == null) && mounted) await _load();
  }

  Future<void> _openMember(SpecialistDto m) async {
    final shopId = _shopId;
    if (shopId == null) return;
    if (m.membershipStatus == 'PENDING') {
      await _reviewJoinRequest(m);
      if (mounted) await _load();
      return;
    }
    if (_statusOf(m) == _MemberStatus.pending) {
      await Navigator.of(context).pushNamed(
        AppRoutes.providerBarberDetail,
        arguments: ProviderBarberDetailArgs(
          shopId: shopId,
          barberUserId: m.id,
          specialist: m,
          isOwner: true,
        ),
      );
    } else {
      await Navigator.of(context).pushNamed(
        AppRoutes.providerProfessionalAdded,
        arguments: ProfessionalAddedArgs(
          shopId: shopId,
          specialist: m,
          showJoinedBanner: false,
        ),
      );
    }
    if (mounted) await _load();
  }

  Future<void> _reviewJoinRequest(SpecialistDto m) async {
    final shopId = _shopId;
    if (shopId == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${m.displayName} wants to join',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Approve to show them under your salon. Reject to decline.',
                  style: TextStyle(color: _muted, height: 1.4),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, 'approve'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Approve'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, 'reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Reject'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (action == null || !mounted) return;
    try {
      final api = context.read<AuthController>().catalogApi;
      if (action == 'approve') {
        await api.approveShopMember(shopId: shopId, barberUserId: m.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${m.displayName} is now on your team')),
        );
      } else {
        await api.rejectShopMember(shopId: shopId, barberUserId: m.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${m.displayName} was declined')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
  }

  Future<void> _openInvitation(ShopInvitationDto invite) async {
    final shopId = _shopId;
    if (shopId == null) return;
    final changed = await Navigator.of(context).pushNamed(
      AppRoutes.providerPendingInvitation,
      arguments: PendingInvitationArgs(
        shopId: shopId,
        invitation: invite,
      ),
    );
    if (mounted) await _load();
    if (changed == true && mounted) {
      // Already refreshed.
    }
  }

  Future<void> _continue() async {
    await SessionStore().setProviderSetupStage('booking_settings');
    await SessionStore().setProviderSetupShopId(_shopId);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.providerSalonBookingSettings,
      (route) => false,
      arguments: SalonSetupArgs(
        shopId: _shopId,
        fromOnboarding: true,
      ),
    );
  }

  Future<void> _onBack() async {
    if (widget.fromOnboarding) {
      await SessionStore().setProviderSetupStage('opening_hours');
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.providerSalonHours,
        (route) => false,
        arguments: SalonSetupArgs(
          shopId: _shopId,
          fromOnboarding: true,
        ),
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMembers;
    final invites = _filteredInvites;
    final empty = filtered.isEmpty && invites.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _onBack,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: AppColors.brandPrimary,
                  ),
                  const Expanded(
                    child: Text(
                      'Team',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _invite,
                    child: const Text(
                      '+ Invite',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in _TeamFilter.values) ...[
                      _FilterChip(
                        label: switch (f) {
                          _TeamFilter.all => 'All',
                          _TeamFilter.active => 'Active',
                          _TeamFilter.pending => 'Pending',
                          _TeamFilter.inactive => 'Inactive',
                        },
                        count: _count(f),
                        selected: _filter == f,
                        onTap: () => setState(() => _filter = f),
                      ),
                      if (f != _TeamFilter.inactive) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(_error!, textAlign: TextAlign.center),
                              ),
                              TextButton(
                                onPressed: _load,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _border),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: empty
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 36,
                                        ),
                                        child: Column(
                                          children: [
                                            const Icon(
                                              Icons.groups_outlined,
                                              size: 40,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              _totalCount == 0
                                                  ? 'No team members yet'
                                                  : 'No members in this filter',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.brandPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _totalCount == 0
                                                  ? 'Invite professionals to join your salon. You can skip and add them later.'
                                                  : 'Try another filter or invite someone new.',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: _muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Column(
                                        children: [
                                          for (var i = 0;
                                              i < invites.length;
                                              i++) ...[
                                            _PendingInviteRow(
                                              invitation: invites[i],
                                              onTap: () =>
                                                  _openInvitation(invites[i]),
                                            ),
                                            if (i < invites.length - 1 ||
                                                filtered.isNotEmpty)
                                              const Divider(
                                                height: 1,
                                                thickness: 1,
                                                color: Color(0xFFF0F1F5),
                                              ),
                                          ],
                                          for (var i = 0;
                                              i < filtered.length;
                                              i++) ...[
                                            _TeamMemberRow(
                                              member: filtered[i],
                                              role: _roleLabel(filtered[i]),
                                              status: _statusOf(filtered[i]),
                                              onTap: () =>
                                                  _openMember(filtered[i]),
                                            ),
                                            if (i < filtered.length - 1)
                                              const Divider(
                                                height: 1,
                                                thickness: 1,
                                                color: Color(0xFFF0F1F5),
                                              ),
                                          ],
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
            ),
            if (widget.fromOnboarding)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _continue,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _continue,
                        child: const Text(
                          'Skip for now',
                          style: TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w600,
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
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _accent : _chipIdle,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF5B6475),
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingInviteRow extends StatelessWidget {
  const _PendingInviteRow({
    required this.invitation,
    required this.onTap,
  });

  final ShopInvitationDto invitation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            children: [
              _SquareAvatar(
                name: invitation.displayName,
                imageUrl: invitation.avatarUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invitation.specialty,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: Color(0xFFF59E0B)),
                  SizedBox(width: 6),
                  Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFB0B6C3),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamMemberRow extends StatelessWidget {
  const _TeamMemberRow({
    required this.member,
    required this.role,
    required this.status,
    required this.onTap,
  });

  final SpecialistDto member;
  final String role;
  final _MemberStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (status) {
      _MemberStatus.active => const Color(0xFF22C55E),
      _MemberStatus.pending => const Color(0xFFF59E0B),
      _MemberStatus.inactive => const Color(0xFF9CA3AF),
    };
    final statusLabel = switch (status) {
      _MemberStatus.active => 'Active',
      _MemberStatus.pending => 'Pending',
      _MemberStatus.inactive => 'Inactive',
    };

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            children: [
              _SquareAvatar(
                name: member.displayName,
                imageUrl: member.avatarUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFB0B6C3),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquareAvatar extends StatelessWidget {
  const _SquareAvatar({
    required this.name,
    this.imageUrl,
  });

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 48,
        height: 48,
        child: imageUrl != null && imageUrl!.trim().isNotEmpty
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(initial),
              )
            : _fallback(initial),
      ),
    );
  }

  Widget _fallback(String initial) {
    return ColoredBox(
      color: const Color(0xFFEDE9FE),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.brandPrimary,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
