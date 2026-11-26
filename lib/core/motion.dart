import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

/// True when the user asked the OS for less motion.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

const kEase = Curves.easeOutCubic;

/// Fades and lifts its child in once, after [index] * [step]. Used for
/// staggered lists and grids. Skipped when reduce motion is on.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 380),
    this.offset = 14,
  });

  final Widget child;
  final int index;
  final Duration step;
  final Duration duration;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: kEase);
  bool _started = false;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _c.value = 1;
      return;
    }
    // cap the delay so long lists do not wait
    final delay = widget.step * widget.index.clamp(0, 8);
    if (delay == Duration.zero) {
      _c.forward();
    } else {
      _timer = Timer(delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _t.value) * widget.offset),
          child: child,
        ),
      ),
    );
  }
}

/// Shrinks slightly while pressed. Wrap tappable cards and chips.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down && !still ? widget.scale : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Favourite button with a small pop when it turns on.
class HeartButton extends StatefulWidget {
  const HeartButton({
    super.key,
    required this.saved,
    required this.onPressed,
    this.size = 20,
    this.filledBackground = true,
  });

  final bool saved;
  final VoidCallback onPressed;
  final double size;
  final bool filledBackground;

  @override
  State<HeartButton> createState() => _HeartButtonState();
}

class _HeartButtonState extends State<HeartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _pop = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.32), weight: 35),
    TweenSequenceItem(
        tween: Tween<double>(begin: 1.32, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 65),
  ]).animate(_c);

  @override
  void didUpdateWidget(HeartButton old) {
    super.didUpdateWidget(old);
    if (widget.saved && !old.saved && !reduceMotion(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
      child: Icon(
        widget.saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        key: ValueKey(widget.saved),
        size: widget.size,
        color: widget.saved
            ? cs.secondary
            : (widget.filledBackground ? Brand.ink : cs.onSurface),
      ),
    );
    return Semantics(
      button: true,
      toggled: widget.saved,
      label: widget.saved ? 'Remove from saved' : 'Save recipe',
      child: InkResponse(
        onTap: widget.onPressed,
        radius: widget.size + 6,
        child: ScaleTransition(
          scale: _pop,
          child: Container(
            padding: EdgeInsets.all(widget.size * 0.4),
            decoration: widget.filledBackground
                ? BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 8,
                          offset: Offset(0, 2)),
                    ],
                  )
                : null,
            child: icon,
          ),
        ),
      ),
    );
  }
}
