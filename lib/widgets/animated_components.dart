import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShimmerEffect extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerEffect({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 16,
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.5, 1.0],
              colors: const [
                Color(0xFFE0E0E0),
                Color(0xFFF5F5F5),
                Color(0xFFE0E0E0),
              ],
              transform: GradientRotation(_animation.value),
            ),
          ),
        );
      },
    );
  }
}

class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;
  
  const AnimatedListItem({super.key, required this.child, required this.index});

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    Future.delayed(Duration(milliseconds: 100 * widget.index), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.child,
      ),
    );
  }
}

class MorphingSubmitButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  
  const MorphingSubmitButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  State<MorphingSubmitButton> createState() => _MorphingSubmitButtonState();
}

class _MorphingSubmitButtonState extends State<MorphingSubmitButton> {
  bool _isLoading = false;
  bool _isSuccess = false;

  void _handlePress() async {
    if (_isLoading || _isSuccess) return;
    
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    // Simulate loading for 1 second
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
      
      // Delay before popping the screen and call action
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        widget.onPressed();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 56,
      width: _isLoading || _isSuccess ? 56 : MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        color: _isSuccess ? const Color(0xFFC8E569) : const Color(0xFFC23147),
        borderRadius: BorderRadius.circular(_isLoading || _isSuccess ? 28 : 12),
        boxShadow: [
          BoxShadow(
            color: _isSuccess ? const Color(0x4DC8E569) : const Color(0x4DC23147),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handlePress,
          borderRadius: BorderRadius.circular(_isLoading || _isSuccess ? 28 : 12),
          child: Center(
            child: _buildChild(),
          ),
        ),
      ),
    );
  }

  Widget _buildChild() {
    if (_isSuccess) {
      return const Icon(Icons.check, color: Colors.white, size: 28);
    } else if (_isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      );
    } else {
      return Text(
        widget.text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }
}

class AnimatedCounterText extends StatelessWidget {
  final int value;
  final String suffix;
  final TextStyle style;

  const AnimatedCounterText({
    super.key,
    required this.value,
    this.suffix = '',
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        return Text(
          '$val$suffix',
          style: style,
        );
      },
    );
  }
}
