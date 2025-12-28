import 'package:flutter/material.dart';

class TrackpadWidget extends StatefulWidget {
  final Function(int dx, int dy, int buttons)? onPointerReport;
  final String label;

  const TrackpadWidget({
    super.key,
    this.onPointerReport,
    this.label = 'TRACKPAD',
  });

  @override
  State<TrackpadWidget> createState() => _TrackpadWidgetState();
}

class _TrackpadWidgetState extends State<TrackpadWidget> {
  bool _isTouched = false;
  Offset _touchPosition = Offset.zero;
  
  // For tap detection
  DateTime? _lastDownTime;
  Offset? _lastDownPos;
  static const _tapDuration = Duration(milliseconds: 200);
  static const _tapSlop = 10.0;

  void _handlePointerDown(PointerDownEvent event, Size size) {
    _lastDownTime = DateTime.now();
    _lastDownPos = event.localPosition;

    setState(() {
      _isTouched = true;
      _touchPosition = Offset(
        (event.localPosition.dx / size.width).clamp(0.0, 1.0),
        (event.localPosition.dy / size.height).clamp(0.0, 1.0),
      );
    });
  }

  void _handlePointerMove(PointerMoveEvent event, Size size) {
    // Send delta movement
    final sendDx = event.delta.dx.round();
    final sendDy = event.delta.dy.round();

    // Only send if there's actual movement
    if (sendDx != 0 || sendDy != 0) {
      widget.onPointerReport?.call(sendDx, sendDy, 0);
    }

    // Update visual position
    setState(() {
      _touchPosition = Offset(
        (event.localPosition.dx / size.width).clamp(0.0, 1.0),
        (event.localPosition.dy / size.height).clamp(0.0, 1.0),
      );
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    // Check for tap
    if (_lastDownTime != null && _lastDownPos != null) {
      final now = DateTime.now();
      final diff = now.difference(_lastDownTime!);
      final dist = (event.localPosition - _lastDownPos!).distance;
      
      if (diff < _tapDuration && dist < _tapSlop) {
        // It's a tap! Send a left click (button bit 1)
        _sendTap();
      }
    }

    setState(() {
      _isTouched = false;
    });
  }

  void _sendTap() async {
    // Left click: Press (1) then Release (0)
    widget.onPointerReport?.call(0, 0, 1);
    await Future.delayed(const Duration(milliseconds: 20));
    widget.onPointerReport?.call(0, 0, 0);
  }

  void _handleRelease() {
    setState(() {
      _isTouched = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        
        return Container(
          decoration: BoxDecoration(
            color: _isTouched 
                ? Colors.blueAccent.withValues(alpha: 0.2) 
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isTouched ? Colors.blueAccent : Colors.white24,
              width: 2,
            ),
          ),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _handlePointerDown(e, size),
            onPointerMove: (e) => _handlePointerMove(e, size),
            onPointerUp: (e) => _handlePointerUp(e),
            onPointerCancel: (_) => _handleRelease(),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: _isTouched ? 0.5 : 0.2),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                if (_isTouched)
                  Positioned(
                    left: _touchPosition.dx * size.width - 20,
                    top: _touchPosition.dy * size.height - 20,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blueAccent.withValues(alpha: 0.4),
                        border: Border.all(color: Colors.blueAccent, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
