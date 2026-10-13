import 'dart:async';
import 'dart:math' as math;
import 'screens/admin_screens.dart';
import 'screens/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/api_client.dart';
import 'core/app_theme.dart';
import 'core/format.dart';
import 'features/gateway/presentation/gateway_screen.dart';
import 'features/store/presentation/guest_storefront.dart';
import 'screens/auth_extra.dart';
import 'services/shop_api.dart';
import 'state/session.dart';

const _sky = Color(0xFFC6E7F4);
const _ink = Color(0xFF594F4B);
const _blue = Color(0xFF9ABDE4);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.instance.restore();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: _sky,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const BabyShopHubApp());
}

class BabyShopHubApp extends StatelessWidget {
  const BabyShopHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BabyShopHub',
      debugShowCheckedModeBanner: false,
      navigatorKey: Session.navigatorKey,
      theme: buildAppTheme(),
      // Logged in -> admins go straight to the dashboard, shoppers to the shop.
      // Logged out -> splash, onboarding, sign-in.
      home: ListenableBuilder(
        listenable: Session.instance,
        builder: (context, _) {
          if (!Session.instance.isLoggedIn) return const StartupSequence();
          return Session.instance.isAdmin
              ? const AdminDashboardScreen()
              : const MainShell();
        },
      ),
    );
  }
}

/// Plays the three splash stages, then transitions into onboarding.
class StartupSequence extends StatefulWidget {
  const StartupSequence({super.key});

  @override
  State<StartupSequence> createState() => _StartupSequenceState();
}

class _StartupSequenceState extends State<StartupSequence> {
  static const _durations = <Duration>[
    Duration(milliseconds: 1250),
    Duration(milliseconds: 1750),
    Duration(milliseconds: 1500),
  ];

  int _page = 0;
  bool _showAccountAccess = false;
  bool _showGateway = false;
  bool _showGuestStore = false;
  bool _openRegistration = false;
  bool _returnToGuest = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleNextPage();
  }

  void _scheduleNextPage() {
    if (_page >= _durations.length) return;
    _timer = Timer(_durations[_page], () {
      if (!mounted) return;
      setState(() => _page++);
      _scheduleNextPage();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _pageForIndex() {
    if (_page >= _durations.length) {
      if (_showGuestStore) {
        return GuestStorefront(
          key: const ValueKey('guest-storefront'),
          onBackToGateway: () => setState(() => _showGuestStore = false),
          onRequireAccount: _openAccountFlow,
        );
      }
      if (_showAccountAccess) {
        return ShopperAccountFlow(
          key: const ValueKey('shopper-account-access'),
          initiallyShowRegistration: _openRegistration,
          onBackToOnboarding: () => setState(() {
            _showAccountAccess = false;
            _showGuestStore = _returnToGuest;
            _openRegistration = false;
            _returnToGuest = false;
          }),
        );
      }
      if (!_showGateway) {
        return OnboardingFlow(
          key: const ValueKey('onboarding'),
          onComplete: () => setState(() => _showGateway = true),
        );
      }
      return GatewayScreen(
        key: const ValueKey('gateway'),
        onBack: () => setState(() => _showGateway = false),
        onBrowseAsGuest: () => setState(() => _showGuestStore = true),
        onLogin: () => _openAccountFlow(false),
        onSignUp: () => _openAccountFlow(true),
      );
    }

    return switch (_page) {
      0 => const LogoIntroPage(key: ValueKey('logo')),
      1 => const LoadingPage(
        key: ValueKey('loading-dots'),
        indicator: _DotOrbit(),
      ),
      2 => const LoadingPage(
        key: ValueKey('loading-ring'),
        indicator: _TwoToneRing(),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  void _openAccountFlow(bool registration) {
    setState(() {
      _returnToGuest = _showGuestStore;
      _showGuestStore = false;
      _showAccountAccess = true;
      _openRegistration = registration;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: _sky,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _sky,
        body: Stack(
          children: [
            Positioned.fill(
              child: _page >= _durations.length
                  ? const ColoredBox(color: Colors.white)
                  : const CustomPaint(painter: _CloudPainter()),
            ),
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 520),
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.985, end: 1).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: child,
                    ),
                  );
                },
                child: _pageForIndex(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LogoIntroPage extends StatelessWidget {
  const LogoIntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CenteredStartupPage(
      key: ValueKey('logo-content'),
      child: _BrandLogo(width: 238),
    );
  }
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({required this.indicator, super.key});

  final Widget indicator;

  @override
  Widget build(BuildContext context) {
    return _CenteredStartupPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BrandLogo(width: 194),
          const SizedBox(height: 18),
          indicator,
          const SizedBox(height: 12),
          const Text(
            'Loading...',
            style: TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredStartupPage extends StatelessWidget {
  const _CenteredStartupPage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: child,
        ),
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/brand_logo.png',
          width: width * 0.72,
          fit: BoxFit.contain,
          semanticLabel: 'Baby-care logo mark',
        ),
        const SizedBox(height: 2),
        Text.rich(
          const TextSpan(
            children: [
              TextSpan(
                text: 'BabyShop',
                style: TextStyle(color: Color(0xFF7299C1)),
              ),
              TextSpan(
                text: 'Hub',
                style: TextStyle(color: Color(0xFFE88791)),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: width * 0.13,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

class _DotOrbit extends StatefulWidget {
  const _DotOrbit();

  @override
  State<_DotOrbit> createState() => _DotOrbitState();
}

class _DotOrbitState extends State<_DotOrbit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = <Color>[
      _blue,
      Color(0xFFF7B1B3),
      _blue,
      Color(0xFFF4C5AA),
      _blue,
      Color(0xFFF7B1B3),
      _blue,
      Color(0xFFF4C5AA),
    ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * math.pi * 2,
          child: child,
        );
      },
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < colors.length; i++)
              Transform.translate(
                offset: Offset(
                  math.cos(i * math.pi / 4) * 19,
                  math.sin(i * math.pi / 4) * 19,
                ),
                child: Container(
                  width: i.isEven ? 7 : 6,
                  height: i.isEven ? 7 : 6,
                  decoration: BoxDecoration(
                    color: colors[i],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TwoToneRing extends StatefulWidget {
  const _TwoToneRing();

  @override
  State<_TwoToneRing> createState() => _TwoToneRingState();
}

class _TwoToneRingState extends State<_TwoToneRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.rotate(
        angle: _controller.value * math.pi * 2,
        child: child,
      ),
      child: const SizedBox(
        width: 42,
        height: 42,
        child: CustomPaint(painter: _RingPainter()),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final blue = Paint()
      ..color = _blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final pink = Paint()
      ..color = const Color(0xFFF6A9AE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect.deflate(3), -math.pi / 2, math.pi * 8 / 9, false, blue);
    canvas.drawArc(rect.deflate(3), math.pi / 2, math.pi * 8 / 9, false, pink);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => false;
}

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({required this.onComplete, super.key});

  final VoidCallback onComplete;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const _slides = <_OnboardingSlideData>[
    _OnboardingSlideData(
      title: 'Everything Your\nBaby Needs',
      description:
          'From diapers to toys, find the best\nfor your little one, all in one place.',
      imagePath: 'assets/images/onboarding_need.jpg',
      imageDescription: 'Teddy bear and colorful baby toys',
    ),
    _OnboardingSlideData(
      title: 'Quality & Trusted\nProducts',
      description:
          'We bring you safe, high-quality\nand trusted products from\nreliable brands.',
      imagePath: 'assets/images/onboarding_quality.jpg',
      imageDescription: 'Baby bottle and organized baby products',
    ),
    _OnboardingSlideData(
      title: 'Shop with Confidence',
      description:
          'Secure payments, fast delivery\nand dedicated support for\nyou and your baby.',
      imagePath: 'assets/images/onboarding_confidence.jpg',
      imageDescription: 'Baby crib with a hanging mobile',
    ),
  ];

  final _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage == _slides.length - 1) {
      widget.onComplete();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: ColoredBox(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 14),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (page) =>
                        setState(() => _currentPage = page),
                    itemBuilder: (context, index) =>
                        _OnboardingSlide(data: _slides[index]),
                  ),
                ),
                _PageIndicator(
                  count: _slides.length,
                  selectedIndex: _currentPage,
                ),
                const SizedBox(height: 24),
                _OnboardingButton(
                  label: _currentPage == _slides.length - 1
                      ? 'Get Started'
                      : 'Next',
                  isLast: _currentPage == _slides.length - 1,
                  onPressed: _next,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.imageDescription,
  });

  final String title;
  final String description;
  final String imagePath;
  final String imageDescription;
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.data});

  final _OnboardingSlideData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 6,
          child: Center(child: _OnboardingArtwork(data: data)),
        ),
        Text(
          data.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF0751A5),
            fontSize: 23,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          data.description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF6383A8),
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

class _OnboardingArtwork extends StatelessWidget {
  const _OnboardingArtwork({required this.data});

  final _OnboardingSlideData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math
            .min(constraints.maxWidth * 0.82, constraints.maxHeight * 0.78)
            .toDouble();
        return SizedBox.square(
          dimension: size,
          child: Image.asset(
            data.imagePath,
            fit: BoxFit.contain,
            semanticLabel: data.imageDescription,
          ),
        );
      },
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.selectedIndex});

  final int count;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++) ...[
          if (index > 0) const SizedBox(width: 7),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: index == selectedIndex ? 8 : 6,
            height: index == selectedIndex ? 8 : 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index == selectedIndex
                  ? const Color(0xFF218CF2)
                  : const Color(0xFFD8E6F3),
            ),
          ),
        ],
      ],
    );
  }
}

class _OnboardingButton extends StatelessWidget {
  const _OnboardingButton({
    required this.label,
    required this.isLast,
    required this.onPressed,
  });

  final String label;
  final bool isLast;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = isLast
        ? const [Color(0xFFFF8DAA), Color(0xFFFF6D93)]
        : const [Color(0xFF39A5FF), Color(0xFF218CF2)];

    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shopper sign-in and registration screens.
class ShopperAccountFlow extends StatefulWidget {
  const ShopperAccountFlow({
    required this.onBackToOnboarding,
    this.initiallyShowRegistration = false,
    super.key,
  });

  final VoidCallback onBackToOnboarding;
  final bool initiallyShowRegistration;

  @override
  State<ShopperAccountFlow> createState() => _ShopperAccountFlowState();
}

class _ShopperAccountFlowState extends State<ShopperAccountFlow> {
  late bool _showRegistration = widget.initiallyShowRegistration;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: ColoredBox(
        color: Colors.white,
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _showRegistration
                ? _ShopperRegistrationPage(
                    key: const ValueKey('shopper-registration'),
                    onBack: () => setState(() => _showRegistration = false),
                    onSignIn: () => setState(() => _showRegistration = false),
                  )
                : _ShopperSignInPage(
                    key: const ValueKey('shopper-sign-in'),
                    onBack: widget.onBackToOnboarding,
                    onCreateAccount: () =>
                        setState(() => _showRegistration = true),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ShopperSignInPage extends StatefulWidget {
  const _ShopperSignInPage({
    required this.onBack,
    required this.onCreateAccount,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onCreateAccount;

  @override
  State<_ShopperSignInPage> createState() => _ShopperSignInPageState();
}

class _ShopperSignInPageState extends State<_ShopperSignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _rememberMe = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final email = _emailController.text.trim();
    try {
      await Session.instance.login(
        email,
        _passwordController.text,
        remember: _rememberMe,
      );
      // Success: the app root swaps to the shop by itself.
    } on ApiException catch (e) {
      if (!mounted) return;
      final notVerified =
          e.statusCode == 202 ||
          e.message.toLowerCase().contains('not verified') ||
          e.message.toLowerCase().contains('verification required');
      _showAuthError(
        context,
        e.message,
        actionLabel: notVerified ? 'Verify' : null,
        onAction: notVerified
            ? () async {
                final navigator = Navigator.of(context);
                // A 202 response means the backend already issued a fresh
                // code while handling this login attempt.
                if (e.statusCode != 202) {
                  try {
                    await ShopApi.resendCode(email);
                  } catch (_) {}
                }
                navigator.push(
                  MaterialPageRoute<bool>(
                    builder: (_) => VerifyOtpScreen(
                      email: email,
                      deliveryMessage: e.message,
                    ),
                  ),
                );
              }
            : null,
      );
    } catch (e) {
      if (!mounted) return;
      _showAuthError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountPageLayout(
      key: const ValueKey('sign-in-layout'),
      title: 'Welcome Back',
      subtitle: 'Log in to continue shopping\nfor your little one.',
      onBack: widget.onBack,
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: _accountInputDecoration(
                  'Email Address',
                  Icons.mail_outline_rounded,
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                obscureText: _hidePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: _accountInputDecoration(
                  'Password',
                  Icons.lock_outline_rounded,
                  suffix: IconButton(
                    tooltip: _hidePassword ? 'Show password' : 'Hide password',
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your password.'
                    : null,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Checkbox.adaptive(
                          value: _rememberMe,
                          visualDensity: VisualDensity.compact,
                          onChanged: (value) =>
                              setState(() => _rememberMe = value ?? false),
                        ),
                        Flexible(
                          child: InkWell(
                            onTap: () =>
                                setState(() => _rememberMe = !_rememberMe),
                            child: const Text(
                              'Remember me',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ForgotPasswordScreen(
                          initialEmail: _emailController.text.trim(),
                        ),
                      ),
                    ),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _AccountActionButton(
                label: 'Log In',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Don’t have an account? ',
                style: TextStyle(fontSize: 12, color: Color(0xFF71849A)),
              ),
              TextButton(
                onPressed: widget.onCreateAccount,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Sign Up', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShopperRegistrationPage extends StatefulWidget {
  const _ShopperRegistrationPage({
    required this.onBack,
    required this.onSignIn,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onSignIn;

  @override
  State<_ShopperRegistrationPage> createState() =>
      _ShopperRegistrationPageState();
}

class _ShopperRegistrationPageState extends State<_ShopperRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _dob;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      _showAuthError(context, 'Choose your date of birth.');
      return;
    }
    setState(() => _isSubmitting = true);
    final email = _emailController.text.trim();
    try {
      final registrationMessage = await ShopApi.register(
        name: _nameController.text.trim(),
        email: email,
        password: _passwordController.text,
        dob: _dob!,
        phone: _phoneController.text.trim(),
      );
      if (!mounted) return;
      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => VerifyOtpScreen(
            email: email,
            deliveryMessage: registrationMessage,
          ),
        ),
      );
      if (!mounted) return;
      if (verified == true) {
        _showAuthError(
          context,
          'Account verified. Please log in.',
          isError: false,
        );
        widget.onSignIn();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showAuthError(context, e.message);
    } catch (e) {
      if (!mounted) return;
      _showAuthError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountPageLayout(
      key: const ValueKey('registration-layout'),
      title: 'Create Account',
      subtitle: 'Join us and make shopping for your baby easier.',
      onBack: widget.onBack,
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: _accountInputDecoration(
                  'Full Name',
                  Icons.person_outline_rounded,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your name.'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: _accountInputDecoration(
                  'Email Address',
                  Icons.mail_outline_rounded,
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: _accountInputDecoration(
                  'Phone Number',
                  Icons.phone_outlined,
                ),
                validator: (value) => value == null || value.trim().length < 7
                    ? 'Enter your phone number.'
                    : null,
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickDob,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: _accountInputDecoration('', Icons.cake_outlined),
                  child: Text(
                    _dob == null ? 'Date of Birth' : formatDate(_dob),
                    style: TextStyle(
                      fontSize: 14,
                      color: _dob == null
                          ? const Color(0xFF7890A8)
                          : const Color(0xFF384D62),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                obscureText: _hidePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: _accountInputDecoration(
                  'Password',
                  Icons.lock_outline_rounded,
                  suffix: IconButton(
                    tooltip: _hidePassword ? 'Show password' : 'Hide password',
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: validateStrongPassword,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _confirmationController,
                obscureText: _hideConfirmation,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _submit(),
                decoration: _accountInputDecoration(
                  'Confirm Password',
                  Icons.lock_outline_rounded,
                  suffix: IconButton(
                    tooltip: _hideConfirmation
                        ? 'Show confirmation password'
                        : 'Hide confirmation password',
                    onPressed: () =>
                        setState(() => _hideConfirmation = !_hideConfirmation),
                    icon: Icon(
                      _hideConfirmation
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirm your password.';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _AccountActionButton(
                label: 'Sign Up',
                isLoading: _isSubmitting,
                isPrimaryPink: true,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Already have an account? ',
                style: TextStyle(fontSize: 12, color: Color(0xFF71849A)),
              ),
              TextButton(
                onPressed: widget.onSignIn,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Log In', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountPageLayout extends StatelessWidget {
  const _AccountPageLayout({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.children,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = math.min(constraints.maxWidth, 440.0);
        final horizontalInset = (pageWidth * 0.08).clamp(16.0, 32.0).toDouble();
        final useCompactLayout =
            constraints.maxWidth < 600 || constraints.maxHeight < 640;
        final logoWidth = useCompactLayout
            ? math.min(pageWidth * 0.46, constraints.maxHeight * 0.2)
            : 124.0;
        final headerHeight = useCompactLayout ? logoWidth * 0.92 : 100.0;
        final sectionGap = useCompactLayout
            ? math.min(constraints.maxHeight * 0.035, 28.0)
            : 0.0;
        return Center(
          child: SizedBox(
            width: pageWidth,
            height: constraints.maxHeight,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalInset,
                6,
                horizontalInset,
                16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: headerHeight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: 'Back',
                            onPressed: onBack,
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                        _BrandLogo(width: logoWidth),
                      ],
                    ),
                  ),
                  if (useCompactLayout) SizedBox(height: sectionGap),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF0751A5),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF6383A8),
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                  if (useCompactLayout) SizedBox(height: sectionGap),
                  for (
                    var index = 0;
                    index < children.length;
                    index++
                  ) ...[
                    if (useCompactLayout && index > 0)
                      SizedBox(height: sectionGap),
                    children[index],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

InputDecoration _accountInputDecoration(
  String hint,
  IconData icon, {
  Widget? suffix,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF7890A8), fontSize: 14),
    prefixIcon: Icon(icon, size: 20, color: const Color(0xFF7890A8)),
    suffixIcon: suffix,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD6E3EF)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD6E3EF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF218CF2), width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFB3261E)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.4),
    ),
  );
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email address.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

class _AccountActionButton extends StatelessWidget {
  const _AccountActionButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.isPrimaryPink = false,
  });

  final String label;
  final bool isLoading;
  final bool isPrimaryPink;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = isPrimaryPink
        ? const Color(0xFFFF6D93)
        : const Color(0xFF218CF2);
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.7),
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

void _showAuthError(
  BuildContext context,
  String message, {
  bool isError = true,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFFB3261E)
            : const Color(0xFF0751A5),
        behavior: SnackBarBehavior.floating,
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction ?? () {},
              ),
      ),
    );
}

class _CloudPainter extends CustomPainter {
  const _CloudPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _drawCloud(
      canvas,
      Rect.fromLTWH(-18, -38, 140, 128),
      const Color(0xFFFFF8EA),
    );
    _drawCloud(
      canvas,
      Rect.fromLTWH(-28, size.height - 96, 140, 116),
      const Color(0xFFFFF8EA),
    );
    _drawCloud(
      canvas,
      Rect.fromLTWH(size.width - 132, size.height - 112, 156, 132),
      const Color(0xFFFFE5E4),
      flipHorizontal: true,
    );
  }

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) => false;
}

void _drawCloud(
  Canvas canvas,
  Rect bounds,
  Color color, {
  bool flipHorizontal = false,
}) {
  final width = bounds.width;
  final height = bounds.height;
  final base = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-width * 0.08, height * 0.43, width * 1.16, height * 0.7),
        Radius.circular(height * 0.28),
      ),
    );
  final puffs = <Rect>[
    Rect.fromLTWH(-width * 0.13, height * 0.28, width * 0.44, height * 0.62),
    Rect.fromLTWH(width * 0.08, height * 0.02, width * 0.55, height * 0.75),
    Rect.fromLTWH(width * 0.39, height * 0.14, width * 0.48, height * 0.67),
    Rect.fromLTWH(width * 0.67, height * 0.32, width * 0.43, height * 0.58),
  ];
  var cloud = base;
  for (final puff in puffs) {
    final oval = Path()..addOval(puff);
    cloud = Path.combine(PathOperation.union, cloud, oval);
  }

  canvas.save();
  canvas.translate(bounds.left + (flipHorizontal ? width : 0), bounds.top);
  canvas.scale(flipHorizontal ? -1 : 1, 1);
  canvas.drawPath(cloud, Paint()..color = color);
  canvas.restore();
}
