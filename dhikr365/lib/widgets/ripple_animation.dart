import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';

class RippleAnimation extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const RippleAnimation({super.key, required this.child, required this.onTap});

  @override
  State<RippleAnimation> createState() => _RippleAnimationState();
}

class _RippleAnimationState extends State<RippleAnimation> {
  final List<Widget> _ripples = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _addRipple(TapDownDetails details) {
    widget.onTap();
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.globalToLocal(details.globalPosition);
    setState(() {
      _ripples.add(_Ripple(
        key: UniqueKey(),
        position: position,
        onComplete: (key) {
          if (mounted) {
            setState(() => _ripples.removeWhere((e) => e.key == key));
          }
        },
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _addRipple,
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: Colors.transparent)),
          ..._ripples,
          widget.child,
        ],
      ),
    );
  }
}

class _Ripple extends StatefulWidget {
  final Offset position;
  final Function(Key) onComplete;

  const _Ripple({super.key, required this.position, required this.onComplete});

  @override
  State<_Ripple> createState() => _RippleState();
}

class _RippleState extends State<_Ripple> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scale = Tween<double>(begin: 0.0, end: 2.0).animate(_controller);
    _opacity = Tween<double>(begin: 0.5, end: 0.0).animate(_controller);
    _controller.forward().then((_) {
      if (widget.key != null) widget.onComplete(widget.key!);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 100,
      top: widget.position.dy - 100,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThemeProvider.etherealSage.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
