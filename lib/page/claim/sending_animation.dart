import 'package:flutter/material.dart';

enum SendingStatus { sending, success, error }

class SendingAnimation extends StatefulWidget {
  final ValueNotifier<SendingStatus> statusNotifier;
  final String message;
  final String successMessage;
  final String errorMessage;

  const SendingAnimation({
    super.key,
    required this.statusNotifier,
    this.message = 'กำลังส่งข้อมูล...',
    this.successMessage = 'ส่งข้อมูลสำเร็จ',
    this.errorMessage = 'เกิดข้อผิดพลาด',
  });

  @override
  State<SendingAnimation> createState() => _SendingAnimationState();
}

class _SendingAnimationState extends State<SendingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _planeController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  late AnimationController _successController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _planeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _slideAnimation = Tween<double>(begin: 0, end: 50).animate(
      CurvedAnimation(
        parent: _planeController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _planeController,
        curve: const Interval(0.4, 0.6, curve: Curves.easeOut),
      ),
    );

    _successController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );

    widget.statusNotifier.addListener(_onStatusChanged);
  }

  void _onStatusChanged() {
    if (widget.statusNotifier.value == SendingStatus.success) {
      _planeController.stop();
      _successController.forward();
    } else if (widget.statusNotifier.value == SendingStatus.error) {
      _planeController.stop();
    }
  }

  @override
  void dispose() {
    widget.statusNotifier.removeListener(_onStatusChanged);
    _planeController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SendingStatus>(
      valueListenable: widget.statusNotifier,
      builder: (context, status, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 60,
                width: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (status == SendingStatus.sending)
                      AnimatedBuilder(
                        animation: _planeController,
                        builder: (context, child) {
                          double slideValue = _slideAnimation.value;
                          double opacity = _fadeAnimation.value;
                          double slideValue2 = -50 + _slideAnimation.value;
                          double opacity2 = 1 - _fadeAnimation.value;

                          return Stack(
                            children: [
                              Transform.translate(
                                offset: Offset(slideValue, 0),
                                child: Opacity(
                                  opacity: opacity,
                                  child: Icon(
                                    Icons.send_rounded,
                                    size: 40,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              if (_planeController.value > 0.4)
                                Transform.translate(
                                  offset: Offset(slideValue2, 0),
                                  child: Opacity(
                                    opacity: opacity2,
                                    child: Icon(
                                      Icons.send_rounded,
                                      size: 40,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    if (status == SendingStatus.success)
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    if (status == SendingStatus.error)
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 40,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                status == SendingStatus.sending
                    ? widget.message
                    : status == SendingStatus.success
                        ? widget.successMessage
                        : widget.errorMessage,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: status == SendingStatus.error
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
