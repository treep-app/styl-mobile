import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/session_store.dart';
import '../../../core/routing/app_routes.dart';
import 'looks_ui.dart';

class LeaveReviewScreen extends StatefulWidget {
  const LeaveReviewScreen({super.key, required this.args});

  final LeaveReviewArgs args;

  @override
  State<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends State<LeaveReviewScreen> {
  var _stars = 5;
  String? _matchPhoto;
  String? _wouldReturn;
  final _comment = TextEditingController();
  String? _photoPath;
  var _submitting = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _photoPath = file.path);
  }

  Future<void> _submit() async {
    if (_matchPhoto == null || _wouldReturn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer the quick questions.')),
      );
      return;
    }
    setState(() => _submitting = true);
    await SessionStore().saveReview(
      appointmentId: widget.args.appointmentId,
      rating: _stars,
      matchPhoto: _matchPhoto!,
      wouldReturn: _wouldReturn!,
      comment: _comment.text.trim(),
      photoPath: _photoPath,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks — your review was saved.')),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final photo = _photoPath;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close, color: LooksUi.ink),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                const Text(
                  'How was your appointment?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    color: LooksUi.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: args.imageUrl != null &&
                                args.imageUrl!.trim().isNotEmpty
                            ? Image.network(
                                args.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _fallback(args.salonName),
                              )
                            : _fallback(args.salonName),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            args.salonName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: LooksUi.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${args.serviceName} · ${args.dateLabel}',
                            style: const TextStyle(
                              color: LooksUi.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Overall, how was it?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: LooksUi.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (i) {
                    final n = i + 1;
                    final on = n <= _stars;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _stars = n),
                        child: Icon(
                          Icons.star_rounded,
                          size: 40,
                          color: on ? LooksUi.purple : const Color(0xFFE4E0F0),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Did the result match the photo?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: LooksUi.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final opt in ['Yes', 'Almost', 'No']) ...[
                      if (opt != 'Yes') const SizedBox(width: 8),
                      Expanded(
                        child: _OptionChip(
                          label: opt,
                          selected: _matchPhoto == opt,
                          showRadio: true,
                          onTap: () => setState(() => _matchPhoto = opt),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Would you return?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: LooksUi.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _OptionChip(
                        label: 'Yes',
                        selected: _wouldReturn == 'Yes',
                        showRadio: true,
                        onTap: () => setState(() => _wouldReturn = 'Yes'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _OptionChip(
                        label: 'No',
                        selected: _wouldReturn == 'No',
                        showRadio: false,
                        onTap: () => setState(() => _wouldReturn = 'No'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Add a photo (optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: LooksUi.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE6E3F0)),
                  ),
                  child: InkWell(
                    onTap: _pickPhoto,
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 52,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (photo != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(photo),
                                width: 28,
                                height: 28,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Photo added',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: LooksUi.ink,
                              ),
                            ),
                          ] else ...[
                            const Icon(
                              Icons.photo_camera_outlined,
                              color: LooksUi.ink,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Upload photo',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: LooksUi.ink,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _comment,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Tell others about your experience...',
                    hintStyle: const TextStyle(color: LooksUi.muted),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE6E3F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: LooksUi.purple),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: LooksUi.purple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: LooksUi.purple.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  _submitting ? 'Submitting…' : 'Submit Review',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(String name) {
    return ColoredBox(
      color: LooksUi.searchFill,
      child: Center(
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: LooksUi.ink,
          ),
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.showRadio,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool showRadio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : LooksUi.searchFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? LooksUi.purple : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showRadio) ...[
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? LooksUi.purple : const Color(0xFFD0CDD8),
                    width: selected ? 5 : 2,
                  ),
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: selected ? LooksUi.purple : LooksUi.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
