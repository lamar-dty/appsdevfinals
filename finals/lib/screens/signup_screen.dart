import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  late AnimationController _entryController;
  late Animation<double> _cardFade;
  late Animation<double> _cardSlide;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _cardFade = CurvedAnimation(parent: _entryController, curve: Curves.easeIn);
    _cardSlide = CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic);
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _createAccount() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final pass = _passController.text;
    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    // Simulate account creation then go to login
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    });
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
              // ── Rabbit peeks from top ─────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: size.height * 0.22,
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      heightFactor: 0.6,
                      child: Image.asset(
                        'assets/images/login.png',
                        fit: BoxFit.fitWidth,
                        width: size.width * 0.30,
                      ),
                    ),
                  ),
                ),
              ),

              // ── White card ───────────────────────────────
              Positioned(
                top: size.height * 0.22 + (1 - _cardSlide.value) * 50,
                left: 20,
                right: 20,
                bottom: 0,
                child: Opacity(
                  opacity: _cardFade.value,
                  child: SingleChildScrollView(
                    child: _SignupCard(
                      nameController: _nameController,
                      emailController: _emailController,
                      passController: _passController,
                      obscure: _obscure,
                      loading: _loading,
                      error: _error,
                      onToggleObscure: () => setState(() => _obscure = !_obscure),
                      onCreate: _createAccount,
                      onLogin: () => Navigator.of(context).pop(),
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
class _SignupCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passController;
  final bool obscure;
  final bool loading;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onCreate;
  final VoidCallback onLogin;

  const _SignupCard({
    required this.nameController,
    required this.emailController,
    required this.passController,
    required this.obscure,
    required this.loading,
    required this.error,
    required this.onToggleObscure,
    required this.onCreate,
    required this.onLogin,
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
          const Text(
            'Manage your tasks and budget efficiently',
            style: TextStyle(
              fontSize: 12,
              color: kNavyDark,
              decoration: TextDecoration.underline,
            ),
          ),
          const SizedBox(height: 22),

          // Name
          const Text('Name',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: kNavyDark)),
          const SizedBox(height: 6),
          _AuthField(controller: nameController, hint: 'Name', obscure: false),
          const SizedBox(height: 14),

          // Email
          const Text('Email',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: kNavyDark)),
          const SizedBox(height: 6),
          _AuthField(controller: emailController, hint: 'Email', obscure: false),
          const SizedBox(height: 14),

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

          // Create Account button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: loading ? null : onCreate,
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
                      'Create Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // OR divider
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('or',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),

          const SizedBox(height: 16),

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

          // Log in link
          Center(
            child: GestureDetector(
              onTap: onLogin,
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: kNavyDark),
                  children: [
                    const TextSpan(text: 'Already have an account? '),
                    const TextSpan(
                      text: 'Log In',
                      style: TextStyle(
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
// Reused auth field
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
// Social icons (same as login)
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