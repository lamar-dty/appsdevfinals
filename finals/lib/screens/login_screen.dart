import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'signup_screen.dart';

// Hard-coded credentials
const _kValidUser = 'user';
const _kValidPass = 'user';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  late AnimationController _entryController;
  late Animation<double> _rabbitSlide;
  late Animation<double> _cardSlide;
  late Animation<double> _cardFade;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _rabbitSlide = CurvedAnimation(
        parent: _entryController, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack));
    _cardSlide = CurvedAnimation(
        parent: _entryController, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic));
    _cardFade = CurvedAnimation(
        parent: _entryController, curve: const Interval(0.3, 1.0, curve: Curves.easeIn));
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _login() {
    final email = _emailController.text.trim();
    final pass = _passController.text;
    if (email == _kValidUser && pass == _kValidPass) {
      setState(() { _loading = true; _error = null; });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        // Navigate to main app
        Navigator.of(context).pushReplacementNamed('/main');
      });
    } else {
      setState(() => _error = 'Invalid username or password.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: kNavyDark,
      resizeToAvoidBottomInset: true,
      body: AnimatedBuilder(
        animation: _entryController,
        builder: (context, _) {
          return Stack(
            children: [
              // ── Rabbit peeks from top ──────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Transform.translate(
                  offset: Offset(0, (1 - _rabbitSlide.value) * -120),
                  child: SizedBox(
                    height: size.height * 0.22,
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        heightFactor: 0.6,
                        child: Image.asset(
                          'assets/images/login.png',
                          fit: BoxFit.fitWidth,
                          width: size.width * 0.55,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── White card slides up ───────────────────────
              Positioned(
                top: size.height * 0.22 + (1 - _cardSlide.value) * 60,
                left: 20,
                right: 20,
                child: Opacity(
                  opacity: _cardFade.value,
                  child: _LoginCard(
                    emailController: _emailController,
                    passController: _passController,
                    obscure: _obscure,
                    loading: _loading,
                    error: _error,
                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                    onLogin: _login,
                    onSignUp: () => Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, a, __) => const SignupScreen(),
                        transitionsBuilder: (_, anim, __, child) =>
                            FadeTransition(opacity: anim, child: child),
                        transitionDuration: const Duration(milliseconds: 300),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _LoginCard extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passController;
  final bool obscure;
  final bool loading;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;
  final VoidCallback onSignUp;

  const _LoginCard({
    required this.emailController,
    required this.passController,
    required this.obscure,
    required this.loading,
    required this.error,
    required this.onToggleObscure,
    required this.onLogin,
    required this.onSignUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'Welcome to Nibble',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: kNavyDark,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            child: const Text(
              'Manage your tasks and budget efficiently',
              style: TextStyle(
                fontSize: 12,
                color: kNavyDark,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Email
          const Text('Email',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: kNavyDark)),
          const SizedBox(height: 6),
          _AuthField(
            controller: emailController,
            hint: 'Email',
            obscure: false,
          ),
          const SizedBox(height: 16),

          // Password
          const Text('Password',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: kNavyDark)),
          const SizedBox(height: 6),
          _AuthField(
            controller: passController,
            hint: 'Password',
            obscure: obscure,
            suffix: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: Colors.grey,
              ),
              onPressed: onToggleObscure,
            ),
          ),

          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],

          const SizedBox(height: 20),

          // Login button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: loading ? null : onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: kTeal,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text(
                      'Log in',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 20),

          // Social icons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SocialButton(icon: _SocialIcon.facebook),
              const SizedBox(width: 16),
              _SocialButton(icon: _SocialIcon.google),
              const SizedBox(width: 16),
              _SocialButton(icon: _SocialIcon.x),
            ],
          ),

          const SizedBox(height: 18),

          // Sign up link
          Center(
            child: GestureDetector(
              onTap: onSignUp,
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: kNavyDark),
                  children: [
                    const TextSpan(text: "Don't have an account? "),
                    TextSpan(
                      text: 'Sign Up',
                      style: const TextStyle(
                        color: kTeal,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationColor: kTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared auth text field
// ─────────────────────────────────────────────────────────────
class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? suffix;

  const _AuthField({
    required this.controller,
    required this.hint,
    required this.obscure,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 14, color: kNavyDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFEFF6F6),
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kTeal.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kTeal, width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Social icons
// ─────────────────────────────────────────────────────────────
enum _SocialIcon { facebook, google, x }

class _SocialButton extends StatelessWidget {
  final _SocialIcon icon;
  const _SocialButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: icon == _SocialIcon.x ? Colors.black : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Center(child: _iconWidget()),
    );
  }

  Widget _iconWidget() {
    switch (icon) {
      case _SocialIcon.facebook:
        return const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 26);
      case _SocialIcon.google:
        return const Text('G',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEA4335)));
      case _SocialIcon.x:
        return const Text('𝕏',
            style: TextStyle(fontSize: 20, color: Colors.white));
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Small rabbit painter (head peeks from top center)
// ─────────────────────────────────────────────────────────────
class _SmallRabbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tealPaint = Paint()..color = const Color(0xFF90D0CB);
    final darkPaint = Paint()..color = const Color(0xFF1A1A2E);
    final whitePaint = Paint()..color = Colors.white;

    final cx = size.width / 2;
    final headR = size.width * 0.16;
    final headCY = size.height * 0.72;

    // ── Ears ─────────────────────────────────────────────────
    _drawEar(canvas, tealPaint, cx - headR * 0.75, size.height * 0.08, headR, size);
    _drawEar(canvas, tealPaint, cx + headR * 0.75, size.height * 0.08, headR, size);

    // ── Head ─────────────────────────────────────────────────
    canvas.drawCircle(Offset(cx, headCY), headR, tealPaint);

    // ── Eyes ─────────────────────────────────────────────────
    final eyeR = headR * 0.22;
    final pupilR = eyeR * 0.65;
    // left
    canvas.drawCircle(Offset(cx - headR * 0.42, headCY - headR * 0.08), eyeR, whitePaint);
    canvas.drawCircle(Offset(cx - headR * 0.38, headCY - headR * 0.08), pupilR, darkPaint);
    // right
    canvas.drawCircle(Offset(cx + headR * 0.42, headCY - headR * 0.08), eyeR, whitePaint);
    canvas.drawCircle(Offset(cx + headR * 0.38, headCY - headR * 0.08), pupilR, darkPaint);

    // ── Shine ────────────────────────────────────────────────
    canvas.drawCircle(Offset(cx - headR * 0.31, headCY - headR * 0.15), eyeR * 0.28, whitePaint);
    canvas.drawCircle(Offset(cx + headR * 0.53, headCY - headR * 0.15), eyeR * 0.28, whitePaint);

    // ── Nose ─────────────────────────────────────────────────
    canvas.drawCircle(
        Offset(cx, headCY + headR * 0.22),
        headR * 0.08,
        Paint()..color = const Color(0xFF243D6D));
  }

  void _drawEar(Canvas canvas, Paint paint, double cx, double tipY, double headR, Size size) {
    final path = Path();
    final baseY = size.height * 0.60;
    final halfW = headR * 0.40;
    path.moveTo(cx - halfW, baseY);
    path.quadraticBezierTo(cx - halfW * 1.4, tipY, cx, tipY);
    path.quadraticBezierTo(cx + halfW * 1.4, tipY, cx + halfW, baseY);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}