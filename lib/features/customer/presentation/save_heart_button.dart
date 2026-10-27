import 'package:flutter/material.dart';

import '../../../core/auth/session_store.dart';
import 'looks_ui.dart';

const savedHeartColor = Color(0xFFE45D7A);

class SaveShopHeart extends StatefulWidget {
  const SaveShopHeart({
    super.key,
    required this.shopId,
    this.barberUserId,
    this.size = 22,
    this.onChanged,
  });

  final String shopId;
  final String? barberUserId;
  final double size;
  final ValueChanged<bool>? onChanged;

  @override
  State<SaveShopHeart> createState() => _SaveShopHeartState();
}

class _SaveShopHeartState extends State<SaveShopHeart> {
  var _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SaveShopHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) _load();
  }

  Future<void> _load() async {
    final saved = await SessionStore().isShopSaved(widget.shopId);
    if (mounted) setState(() => _saved = saved);
  }

  Future<void> _toggle() async {
    final next = !_saved;
    setState(() => _saved = next);
    await SessionStore().setShopSaved(widget.shopId, next);
    final barber = widget.barberUserId;
    if (next && barber != null && barber.isNotEmpty) {
      await SessionStore().setBarberSaved(barber, true);
    }
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _toggle,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tight(Size(widget.size + 16, widget.size + 16)),
      icon: Icon(
        _saved ? Icons.favorite_rounded : Icons.favorite_border,
        size: widget.size,
        color: _saved ? savedHeartColor : LooksUi.ink,
      ),
    );
  }
}

class SaveLookHeart extends StatefulWidget {
  const SaveLookHeart({
    super.key,
    required this.lookId,
    this.size = 22,
    this.onChanged,
  });

  final String lookId;
  final double size;
  final ValueChanged<bool>? onChanged;

  @override
  State<SaveLookHeart> createState() => _SaveLookHeartState();
}

class _SaveLookHeartState extends State<SaveLookHeart> {
  var _saved = false;

  @override
  void initState() {
    super.initState();
    SessionStore().isLookSaved(widget.lookId).then((v) {
      if (mounted) setState(() => _saved = v);
    });
  }

  Future<void> _toggle() async {
    final next = !_saved;
    setState(() => _saved = next);
    await SessionStore().setLookSaved(widget.lookId, next);
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _toggle,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tight(Size(widget.size + 16, widget.size + 16)),
      icon: Icon(
        _saved ? Icons.favorite_rounded : Icons.favorite_border,
        size: widget.size,
        color: _saved ? savedHeartColor : LooksUi.ink,
      ),
    );
  }
}

class SaveBarberHeart extends StatefulWidget {
  const SaveBarberHeart({
    super.key,
    required this.barberUserId,
    this.size = 22,
    this.onChanged,
  });

  final String barberUserId;
  final double size;
  final ValueChanged<bool>? onChanged;

  @override
  State<SaveBarberHeart> createState() => _SaveBarberHeartState();
}

class _SaveBarberHeartState extends State<SaveBarberHeart> {
  var _saved = false;

  @override
  void initState() {
    super.initState();
    SessionStore().isBarberSaved(widget.barberUserId).then((v) {
      if (mounted) setState(() => _saved = v);
    });
  }

  Future<void> _toggle() async {
    final next = !_saved;
    setState(() => _saved = next);
    await SessionStore().setBarberSaved(widget.barberUserId, next);
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _toggle,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tight(Size(widget.size + 16, widget.size + 16)),
      icon: Icon(
        _saved ? Icons.favorite_rounded : Icons.favorite_border,
        size: widget.size,
        color: _saved ? savedHeartColor : LooksUi.ink,
      ),
    );
  }
}
