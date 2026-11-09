part of '../../main.dart';

class ThemeReveal extends StatefulWidget {
  const ThemeReveal({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<ThemeReveal> createState() => _ThemeRevealState();
}

class _ThemeRevealState extends State<ThemeReveal>
    with SingleTickerProviderStateMixin {
  final _pageKey = GlobalKey();

  late final AnimationController _animation;

  ui.Image? _previousTheme;

  Offset? _lastTap;
  Offset _origin = Offset.zero;

  bool _capturing = false;

  @override
  void initState() {
    super.initState();

    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addStatusListener(_onAnimationStatus);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;

    final previous = _previousTheme;

    setState(() {
      _previousTheme = null;
    });

    // تصویر پس از حذف شدن از درخت ویجت آزاد می‌شود.
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        previous.dispose();
      });
    }
  }

  Future<void> changeTo(
    String? category, {
    VoidCallback? onChange,
  }) async {
    if (!mounted ||
        _capturing ||
        _animation.isAnimating ||
        _previousTheme != null) {
      return;
    }

    // اگر صفحه تغییر می‌کند، حتی با تم یکسان انیمیشن داریم.
    if (selectedTheme.value == category && onChange == null) {
      return;
    }

    final tapPosition = _lastTap;
    ui.Image? snapshot;

    setState(() {
      _capturing = true;
    });

    try {
      // صفحهٔ فعلی پیش از عکس گرفتن کاملاً رسم شود.
      await WidgetsBinding.instance.endOfFrame;

      if (!mounted) return;

      final page = _pageKey.currentContext?.findRenderObject();

      if (page is RenderRepaintBoundary && page.hasSize) {
        _origin = tapPosition == null
            ? page.size.center(Offset.zero)
            : page.globalToLocal(tapPosition);

        snapshot = await page.toImage(pixelRatio: 1.5);
      }
    } catch (_) {
      // اگر تصویرگیری ممکن نبود، تغییر صفحه همچنان انجام می‌شود.
      snapshot = null;
    }

    if (!mounted) {
      snapshot?.dispose();
      return;
    }

    _animation.value = 0;

    // تصویر قدیمی ابتدا روی صفحه قرار می‌گیرد.
    setState(() {
      _previousTheme = snapshot;
      _capturing = false;
    });

    // تغییر رنگ و محتوای صفحه، در یک نوبت و زیر تصویر قبلی.
    selectedTheme.value = category;
    onChange?.call();

    if (snapshot == null) return;

    // فرم جدید زیر تصویر قبلی رسم شود، بعد دایره باز شود.
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) return;

    _animation.forward(from: 0);
  }

  @override
  void dispose() {
    _animation.removeStatusListener(_onAnimationStatus);
    _animation.dispose();

    _previousTheme?.dispose();
    _previousTheme = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _lastTap = event.position;
      },
      child: AbsorbPointer(
        // جلوگیری از لمس دوباره هنگام انتقال.
        absorbing: _capturing || _previousTheme != null,
        child: Stack(
          alignment: Alignment.topLeft,
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              key: _pageKey,
              child: widget.child,
            ),
            if (_previousTheme case final snapshot?)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return ClipPath(
                      clipper: _OutsideCircle(
                        _origin,
                        Curves.easeInOutCubic.transform(
                          _animation.value,
                        ),
                      ),
                      child: child,
                    );
                  },
                  child: RawImage(
                    image: snapshot,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OutsideCircle extends CustomClipper<Path> {
  const _OutsideCircle(
    this.origin,
    this.progress,
  );

  final Offset origin;
  final double progress;

  @override
  Path getClip(Size size) {
    final bounds = Offset.zero & size;

    final corners = [
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomLeft,
      bounds.bottomRight,
    ];

    final maxRadius = corners
        .map((corner) => (corner - origin).distance)
        .reduce(math.max);

    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(bounds)
      ..addOval(
        Rect.fromCircle(
          center: origin,
          radius: maxRadius * progress,
        ),
      );
  }

  @override
  bool shouldReclip(_OutsideCircle oldClipper) {
    return oldClipper.origin != origin ||
        oldClipper.progress != progress;
  }
}