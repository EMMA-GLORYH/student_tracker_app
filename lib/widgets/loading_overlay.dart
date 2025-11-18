import 'package:flutter/material.dart';
import 'dart:ui';

/// Custom loading overlay with 3-dot animation
/// Usage: LoadingOverlay.show(context, message: 'Loading...');
class LoadingOverlay {
  static OverlayEntry? _overlayEntry;

  static void show(BuildContext context, {String message = 'Loading...'}) {
    if (_overlayEntry != null) return; // Prevent multiple overlays

    _overlayEntry = OverlayEntry(
      builder: (context) => _LoadingOverlayWidget(message: message),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _LoadingOverlayWidget extends StatefulWidget {
  final String message;

  const _LoadingOverlayWidget({required this.message});

  @override
  State<_LoadingOverlayWidget> createState() => _LoadingOverlayWidgetState();
}

class _LoadingOverlayWidgetState extends State<_LoadingOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Blurred background
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),
          // Loading content
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 3-dot animation
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (index) {
                          final delay = index * 0.2;
                          final value = (_controller.value + delay) % 1.0;
                          final offset =
                              (value < 0.5 ? value * 2 : (1 - value) * 2) * 20;

                          // Colors: Left navy, Middle white, Right navy
                          Color dotColor;
                          if (index == 1) {
                            // Middle dot - white with navy border
                            dotColor = Colors.white;
                          } else {
                            // Left and right dots - navy blue
                            dotColor = const Color(0xFF2563eb);
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Transform.translate(
                              offset: Offset(0, -offset),
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: dotColor,
                                  border: index == 1
                                      ? Border.all(
                                    color: const Color(0xFF2563eb),
                                    width: 2,
                                  )
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563eb)
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.message,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF0A1929),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simplified 3-dot loading indicator for inline use
class ThreeDotLoading extends StatefulWidget {
  final double size;
  final Color navyColor;
  final Color whiteColor;

  const ThreeDotLoading({
    super.key,
    this.size = 12,
    this.navyColor = const Color(0xFF2563eb),
    this.whiteColor = Colors.white,
  });

  @override
  State<ThreeDotLoading> createState() => _ThreeDotLoadingState();
}

class _ThreeDotLoadingState extends State<ThreeDotLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = (_controller.value + delay) % 1.0;
            final offset = (value < 0.5 ? value * 2 : (1 - value) * 2) * 15;

            Color dotColor;
            if (index == 1) {
              dotColor = widget.whiteColor;
            } else {
              dotColor = widget.navyColor;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.translate(
                offset: Offset(0, -offset),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    border: index == 1
                        ? Border.all(
                      color: widget.navyColor,
                      width: 2,
                    )
                        : null,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}