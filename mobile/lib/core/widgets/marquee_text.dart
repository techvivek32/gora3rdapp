import 'package:flutter/material.dart';

/// A single-line text that scrolls horizontally and loops seamlessly.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double gap; // space between the repeated copies
  final double velocity; // pixels per second

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.gap = 60,
    this.velocity = 55,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final AnimationController _anim;
  late double _unit; // width of one text + gap

  @override
  void initState() {
    super.initState();
    _unit = _measure() + widget.gap;
    final ms = (_unit / widget.velocity * 1000).round().clamp(4000, 60000);
    _anim = AnimationController(vsync: this, duration: Duration(milliseconds: ms))
      ..addListener(_tick)
      ..repeat();
  }

  double _measure() {
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp.width;
  }

  void _tick() {
    if (!_scroll.hasClients) return;
    // Scroll by exactly one unit, then the animation wraps to 0 — because the
    // second copy now sits where the first did, the reset is invisible.
    _scroll.jumpTo(_anim.value * _unit);
  }

  @override
  void dispose() {
    _anim.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          Text(widget.text, style: widget.style, maxLines: 1),
          SizedBox(width: widget.gap),
          Text(widget.text, style: widget.style, maxLines: 1),
          SizedBox(width: widget.gap),
        ],
      ),
    );
  }
}
