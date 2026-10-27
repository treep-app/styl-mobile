import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/theme/app_theme.dart';

const _accent = Color(0xFF4F6BFF);
const _muted = Color(0xFF8B93A7);
const _border = Color(0xFFE5E7EB);
const _chipSelectedBg = Color(0xFFEEF0FF);

/// Assign team members + related look tags to a salon service.
class ProviderServiceAssignScreen extends StatefulWidget {
  const ProviderServiceAssignScreen({
    super.key,
    required this.shopId,
    required this.service,
  });

  final String shopId;
  final ServiceDto service;

  @override
  State<ProviderServiceAssignScreen> createState() =>
      _ProviderServiceAssignScreenState();
}

class _ProviderServiceAssignScreenState
    extends State<ProviderServiceAssignScreen> {
  static const _lookCatalog = [
    'Skin Fade',
    'Low Fade',
    'Mid Fade',
    'High Fade',
    'Burst Fade',
    'Taper Fade',
    'Beard Trim',
    'Designs',
    'Kids Cuts',
    'Afro Hair',
    'Colour',
    'Blow Dry',
  ];

  var _loading = true;
  var _saving = false;
  var _showAllLooks = false;
  String? _error;
  List<SpecialistDto> _team = const [];
  late Set<String> _selectedBarbers;
  late Set<String> _selectedLooks;

  @override
  void initState() {
    super.initState();
    _selectedBarbers = {...widget.service.assignedBarberIds};
    _selectedLooks = {...widget.service.relatedLooks};
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  List<String> get _visibleLooks {
    if (_showAllLooks) return _lookCatalog;
    return _lookCatalog.take(5).toList();
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
      final team = await context
          .read<AuthController>()
          .catalogApi
          .listSpecialists(widget.shopId);
      if (!mounted) return;
      setState(() {
        _team = team;
        // Empty assignment means "all team" in product terms — preselect all.
        if (_selectedBarbers.isEmpty && team.isNotEmpty) {
          _selectedBarbers = {for (final m in team) m.id};
        }
        if (_selectedLooks.isEmpty) {
          final name = widget.service.name.trim();
          if (_lookCatalog.any((l) => l.toLowerCase() == name.toLowerCase())) {
            _selectedLooks = {name};
          }
        }
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

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await context.read<AuthController>().catalogApi.updateService(
            widget.shopId,
            widget.service.id,
            assignedBarberIds: _selectedBarbers.toList(),
            relatedLooks: _selectedLooks.toList(),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: AppColors.brandPrimary,
                  ),
                  const Expanded(
                    child: Text(
                      'Assign professionals',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: (_saving || _loading) ? null : _save,
                    child: Text(
                      _saving ? 'Saving…' : 'Save',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: (_saving || _loading)
                            ? _accent.withValues(alpha: 0.4)
                            : _accent,
                      ),
                    ),
                  ),
                ],
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
                              Text(_error!),
                              TextButton(
                                onPressed: _load,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _border),
                              ),
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Select which professionals can perform this service.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _muted,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  if (_team.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      child: Text(
                                        'No team members yet. Invite professionals from Team first.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _muted,
                                        ),
                                      ),
                                    )
                                  else
                                    for (final member in _team) ...[
                                      _ProfessionalRow(
                                        member: member,
                                        role: _roleLabel(member),
                                        selected:
                                            _selectedBarbers.contains(member.id),
                                        onChanged: (v) {
                                          setState(() {
                                            if (v == true) {
                                              _selectedBarbers.add(member.id);
                                            } else {
                                              _selectedBarbers.remove(member.id);
                                            }
                                          });
                                        },
                                      ),
                                      if (member != _team.last)
                                        const SizedBox(height: 6),
                                    ],
                                  const SizedBox(height: 22),
                                  const Text(
                                    'Related looks',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.brandPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Which looks can this service create?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _muted,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final look in _visibleLooks)
                                        _LookChip(
                                          label: look,
                                          selected:
                                              _selectedLooks.contains(look),
                                          onTap: () {
                                            setState(() {
                                              if (_selectedLooks.contains(look)) {
                                                _selectedLooks.remove(look);
                                              } else {
                                                _selectedLooks.add(look);
                                              }
                                            });
                                          },
                                        ),
                                      if (!_showAllLooks &&
                                          _lookCatalog.length > 5)
                                        InkWell(
                                          onTap: () => setState(
                                            () => _showAllLooks = true,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: _accent.withValues(
                                                  alpha: 0.35,
                                                ),
                                              ),
                                            ),
                                            child: const Text(
                                              '+ Show more',
                                              style: TextStyle(
                                                color: _accent,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfessionalRow extends StatelessWidget {
  const _ProfessionalRow({
    required this.member,
    required this.role,
    required this.selected,
    required this.onChanged,
  });

  final SpecialistDto member;
  final String role;
  final bool selected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final name = member.displayName;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: selected,
                onChanged: onChanged,
                activeColor: _accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: const BorderSide(color: Color(0xFFC5CBD8), width: 1.4),
              ),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 40,
                height: 40,
                child: member.avatarUrl != null &&
                        member.avatarUrl!.trim().isNotEmpty
                    ? Image.network(
                        member.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _AvatarFallback(initial),
                      )
                    : _AvatarFallback(initial),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    role,
                    style: const TextStyle(fontSize: 13, color: _muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback(this.initial);

  final String initial;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _chipSelectedBg,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.brandPrimary,
          ),
        ),
      ),
    );
  }
}

class _LookChip extends StatelessWidget {
  const _LookChip({
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
      color: selected ? _chipSelectedBg : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _accent.withValues(alpha: 0.45) : _border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: selected,
                  onChanged: (_) => onTap(),
                  activeColor: _accent,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: Color(0xFFC5CBD8)),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? _accent : AppColors.brandPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
