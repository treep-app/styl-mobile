import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../data/looks_catalog.dart';
import 'looks_ui.dart';
import 'nearby_map_screen.dart';

class FindThisLookArgs {
  const FindThisLookArgs({required this.photoPath});

  final String photoPath;
}

/// Confirm the catalog style to search — we do not auto-scan the photo.
class FindThisLookScreen extends StatefulWidget {
  const FindThisLookScreen({super.key, required this.args});

  final FindThisLookArgs args;

  @override
  State<FindThisLookScreen> createState() => _FindThisLookScreenState();
}

class _FindThisLookScreenState extends State<FindThisLookScreen> {
  late String _photoPath;
  StyleLook? _suggested;
  List<StyleLook> _choices = const [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _photoPath = widget.args.photoPath;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthController>();
    await auth.loadMarketplace();
    try {
      final data = await auth.catalogApi.lookSuggestions(categoryId: 'barber');
      if (!mounted) return;
      final suggested = data.suggested ??
          auth.lookById('low-taper') ??
          (auth.marketplaceLooks.isNotEmpty ? auth.marketplaceLooks.first : null);
      final chips = <StyleLook>[
        if (suggested != null) suggested,
        ...data.alternatives,
      ];
      final seen = <String>{};
      final unique = <StyleLook>[];
      for (final look in chips) {
        if (seen.add(look.id)) unique.add(look);
      }
      setState(() {
        _suggested = suggested;
        _choices = unique.take(4).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      final fallback = auth.lookById('low-taper') ??
          (auth.marketplaceLooks.isNotEmpty ? auth.marketplaceLooks.first : null);
      final related = auth.marketplaceLooks
          .where((l) => l.categoryId == (fallback?.categoryId ?? 'barber') && l.id != fallback?.id)
          .take(3)
          .toList();
      setState(() {
        _suggested = fallback;
        _choices = [if (fallback != null) fallback, ...related];
        _loading = false;
      });
    }
  }

  Future<void> _changePhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() => _photoPath = file.path);
  }

  void _findMatches() {
    final look = _suggested;
    if (look == null) return;
    Navigator.of(context).pushNamed(
      AppRoutes.nearbyMap,
      arguments: NearbyMapArgs(lookId: look.id, lookName: look.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shops = _suggested == null
        ? 0
        : context.watch<AuthController>().shopsForLook(_suggested!).length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: LooksUi.toolbar,
        iconTheme: const IconThemeData(color: LooksUi.toolbar),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Find This Look',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18,
            color: LooksUi.ink,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Center(
                  child: SizedBox(
                    width: 240,
                    child: AspectRatio(
                      aspectRatio: 0.92,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(
                              File(_photoPath),
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 14,
                            child: Center(
                              child: Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                child: InkWell(
                                  onTap: _changePhoto,
                                  borderRadius: BorderRadius.circular(22),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.photo_camera_outlined,
                                          size: 16,
                                          color: LooksUi.ink,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Change photo',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: LooksUi.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Closest catalog style',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: LooksUi.muted, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  _suggested?.name ?? 'Pick a style',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: LooksUi.ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We match your photo to styles salons actually list nearby — not an AI scan. Confirm or choose another:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: LooksUi.muted,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _choices.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.8,
                  ),
                  itemBuilder: (context, i) {
                    final look = _choices[i];
                    final selected = look.id == _suggested?.id;
                    return GestureDetector(
                      onTap: () => setState(() => _suggested = look),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? LooksUi.purple : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: selected ? LooksUi.purple : LooksUi.chipIdle,
                            width: 1.4,
                          ),
                        ),
                        child: Text(
                          look.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : LooksUi.ink,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: shops == 0 ? null : _findMatches,
                    style: FilledButton.styleFrom(
                      backgroundColor: LooksUi.purple,
                      disabledBackgroundColor: LooksUi.chipIdle,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      shops == 0
                          ? 'No salon lists this style yet'
                          : 'Find matches',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                if (shops > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '$shops nearby salon${shops == 1 ? '' : 's'} list ${_suggested?.name}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: LooksUi.muted, fontSize: 13),
                    ),
                  ),
              ],
            ),
    );
  }
}
