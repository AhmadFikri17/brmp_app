import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../services/firebase_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String _errorMessage = '';

  static const Color _green = Color(0xFF2D6A4F);
  static const double _mountainAspectFactor = 0.85;

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final result = await FirebaseService.registerWithEmail(
      nama: _namaController.text,
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: 'user',
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Akun berhasil dibuat! Selamat datang ${_namaController.text}'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Registrasi gagal';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final viewInsets = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final mountainHeight = screenWidth * _mountainAspectFactor;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // BACKGROUND - Tetap di bawah, tidak ikut scroll
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: mountainHeight,
              width: screenWidth,
              child: const _MountainBackground(),
            ),
          ),

          // CONTENT - Bisa scroll
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 16,
                  bottom: 16 + viewInsets,
                ),
                child: Column(
                  children: [
                    const _HeaderWidget(),
                    const SizedBox(height: 24),
                    
                    // Error message
                    if (_errorMessage.isNotEmpty) ...[
                      _ErrorMessageWidget(errorMessage: _errorMessage),
                      const SizedBox(height: 16),
                    ],
                    
                    // Form register
                    _RegisterFormWidget(
                      formKey: _formKey,
                      namaController: _namaController,
                      emailController: _emailController,
                      passwordController: _passwordController,
                      confirmPasswordController: _confirmPasswordController,
                      obscurePassword: _obscurePassword,
                      obscureConfirmPassword: _obscureConfirmPassword,
                      isLoading: _isLoading,
                      onRegister: _register,
                      onTogglePassword: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      onToggleConfirmPassword: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    const _LoginButtonWidget(),
                    
                    // Spacer dinamis - lebih kecil saat keyboard muncul
                    SizedBox(
                      height: viewInsets > 0 
                          ? 20 
                          : screenHeight * 0.25,
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

// ============== BACKGROUND WIDGET ==============

class _MountainBackground extends StatelessWidget {
  const _MountainBackground();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
          ],
          stops: [0.0, 1.0, 2.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: Image.asset(
        'assets/images/mountain.png',
        fit: BoxFit.cover,
        alignment: Alignment.bottomCenter,
      ),
    );
  }
}

// ============== HEADER WIDGET ==============

class _HeaderWidget extends StatelessWidget {
  const _HeaderWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Image.asset(
          'assets/icons/logo.png',
          width: 90,
          height: 90,
        ),
        const SizedBox(height: 12),
        const Text(
          'WEATHER STATION',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _RegisterScreenState._green,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Monitoring Cerdas,\nPertanian Berkualitas',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

// ============== ERROR MESSAGE WIDGET ==============

class _ErrorMessageWidget extends StatelessWidget {
  final String errorMessage;

  const _ErrorMessageWidget({required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============== REGISTER FORM WIDGET ==============

class _RegisterFormWidget extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController namaController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final bool isLoading;
  final VoidCallback onRegister;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;

  const _RegisterFormWidget({
    required this.formKey,
    required this.namaController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.isLoading,
    required this.onRegister,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Buat Akun Baru',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            _NamaField(controller: namaController),
            const SizedBox(height: 16),
            _EmailField(controller: emailController),
            const SizedBox(height: 16),
            _PasswordField(
              controller: passwordController,
              obscurePassword: obscurePassword,
              onToggle: onTogglePassword,
              onSubmitted: () => FocusScope.of(context).nextFocus(),
            ),
            const SizedBox(height: 16),
            _ConfirmPasswordField(
              controller: confirmPasswordController,
              obscurePassword: obscureConfirmPassword,
              onToggle: onToggleConfirmPassword,
              passwordController: passwordController,
              onSubmitted: onRegister,
            ),
            const SizedBox(height: 24),
            _RegisterButton(
              isLoading: isLoading,
              onPressed: onRegister,
            ),
          ],
        ),
      ),
    );
  }
}

// ============== NAMA FIELD ==============

class _NamaField extends StatelessWidget {
  final TextEditingController controller;

  const _NamaField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'Nama Lengkap',
        hintText: 'Masukkan Nama Lengkap',
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _RegisterScreenState._green, width: 1.5),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Nama tidak boleh kosong';
        }
        if (value.length < 3) {
          return 'Nama minimal 3 karakter';
        }
        return null;
      },
    );
  }
}

// ============== EMAIL FIELD ==============

class _EmailField extends StatelessWidget {
  final TextEditingController controller;

  const _EmailField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'Masukkan Email',
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _RegisterScreenState._green, width: 1.5),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Email tidak boleh kosong';
        }
        if (!value.contains('@') || !value.contains('.')) {
          return 'Email tidak valid';
        }
        return null;
      },
    );
  }
}

// ============== PASSWORD FIELD ==============

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscurePassword;
  final VoidCallback onToggle;
  final VoidCallback onSubmitted;

  const _PasswordField({
    required this.controller,
    required this.obscurePassword,
    required this.onToggle,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscurePassword,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => onSubmitted(),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Minimal 6 karakter',
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
        suffixIcon: IconButton(
          icon: Icon(
            obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.grey,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _RegisterScreenState._green, width: 1.5),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Password tidak boleh kosong';
        }
        if (value.length < 6) {
          return 'Password minimal 6 karakter';
        }
        return null;
      },
    );
  }
}

// ============== CONFIRM PASSWORD FIELD ==============

class _ConfirmPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggle;
  final VoidCallback onSubmitted;

  const _ConfirmPasswordField({
    required this.controller,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggle,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => onSubmitted(),
      decoration: InputDecoration(
        labelText: 'Konfirmasi Password',
        hintText: 'Masukkan ulang password',
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
        suffixIcon: IconButton(
          icon: Icon(
            obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.grey,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _RegisterScreenState._green, width: 1.5),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Konfirmasi password tidak boleh kosong';
        }
        if (value != passwordController.text) {
          return 'Password tidak sama';
        }
        return null;
      },
    );
  }
}

// ============== REGISTER BUTTON ==============

class _RegisterButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _RegisterButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _RegisterScreenState._green,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Daftar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

// ============== LOGIN BUTTON WIDGET (Navigate to Login) ==============

class _LoginButtonWidget extends StatelessWidget {
  const _LoginButtonWidget();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Sudah punya akun?"),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              ),
            );
          },
          child: const Text(
            'Masuk',
            style: TextStyle(
              color: _RegisterScreenState._green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}