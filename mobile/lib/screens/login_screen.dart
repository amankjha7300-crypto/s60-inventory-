import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSignUp = false;

  // Sign In Controllers
  final _emailController = TextEditingController(text: 'admin@s60sviet.in');
  final _passwordController = TextEditingController(text: 'S60Admin@2026');
  bool _obscurePassword = true;

  // Sign Up Controllers
  final _signupNameController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupUsernameController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmPasswordController = TextEditingController();
  String _selectedRole = 'COORDINATOR';
  bool _obscureSignupPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupUsernameController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    super.dispose();
  }

  void _showApiSettingsDialog() {
    final apiService = ApiService();
    final urlController = TextEditingController(text: apiService.baseUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('API Base URL', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configure backend API address (e.g. for physical Android phone over Wi-Fi):',
              style: TextStyle(fontSize: 13, color: AppColors.textGray),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                hintText: 'http://192.168.1.X:8000/api/v1',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await apiService.setBaseUrl(urlController.text);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('API URL updated to: ${urlController.text}')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password.')),
      );
      return;
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    final success = await provider.login(email, password);

    if (success && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        (route) => false,
      );
    } else if (mounted && provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOutOfStock,
          content: Text(provider.errorMessage!),
        ),
      );
    }
  }

  Future<void> _handleSignUp() async {
    final name = _signupNameController.text.trim();
    final email = _signupEmailController.text.trim();
    final username = _signupUsernameController.text.trim();
    final password = _signupPasswordController.text.trim();
    final confirm = _signupConfirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match. Please verify.')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters.')),
      );
      return;
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    final success = await provider.signUp({
      'full_name': name,
      'email': email,
      if (username.isNotEmpty) 'username': username,
      'role': _selectedRole,
      'password': password,
    });

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusDistributed,
          content: Text('Welcome to Super60, $name! Account created.'),
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        (route) => false,
      );
    } else if (mounted && provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOutOfStock,
          content: Text(provider.errorMessage!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.primaryNavy),
            tooltip: 'Configure Backend URL',
            onPressed: _showApiSettingsDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Official Logos Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/sviet_logo.png',
                      height: 48,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 16),
                    Container(width: 1.5, height: 36, color: AppColors.borderSubtle),
                    const SizedBox(width: 16),
                    Image.asset(
                      'assets/s60_logo.png',
                      height: 48,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Text(
                  _isSignUp ? "Create Account" : "Welcome Back",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isSignUp
                      ? "Register as an S60 coordinator or faculty"
                      : "Sign in to S60 Inventory & Rewards System",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textGray,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 24),

                // Segmented Switcher (Sign In vs Sign Up)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGray,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isSignUp = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isSignUp ? AppColors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: !_isSignUp
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "Sign In",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: !_isSignUp ? AppColors.primaryNavy : AppColors.textGray,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isSignUp = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isSignUp ? AppColors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _isSignUp
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "Sign Up",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _isSignUp ? AppColors.primaryNavy : AppColors.textGray,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Card Container
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: _isSignUp ? _buildSignUpForm(provider) : _buildSignInForm(provider),
                ),

                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp
                          ? "Already registered? Sign in here"
                          : "Need a new account? Register coordinator",
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInForm(AppProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Email or Username",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryNavy),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'admin@s60sviet.in',
            prefixIcon: Icon(Icons.person_outline, color: AppColors.primaryOrange),
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          "Password",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryNavy),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryOrange),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textGray,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: provider.isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: provider.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text("Sign In to Portal", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSignUpForm(AppProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Full Name *",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryNavy),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _signupNameController,
          decoration: const InputDecoration(
            hintText: 'e.g. Dr. Harpreet Singh',
            prefixIcon: Icon(Icons.badge_outlined, color: AppColors.primaryOrange),
          ),
        ),
        const SizedBox(height: 14),

        const Text(
          "Email Address *",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryNavy),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _signupEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'harpreet@sviet.ac.in',
            prefixIcon: Icon(Icons.email_outlined, color: AppColors.primaryOrange),
          ),
        ),
        const SizedBox(height: 14),

        const Text(
          "Username (Optional)",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryNavy),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _signupUsernameController,
          decoration: const InputDecoration(
            hintText: 'harpreet_s',
            prefixIcon: Icon(Icons.alternate_email, color: AppColors.primaryOrange),
          ),
        ),
        const SizedBox(height: 14),

        const Text(
          "Department Role *",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryNavy),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedRole,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.security, color: AppColors.primaryOrange),
          ),
          items: const [
            DropdownMenuItem(value: 'COORDINATOR', child: Text('S60 Event Coordinator')),
            DropdownMenuItem(value: 'EVENT_MANAGER', child: Text('Event Lead / Manager')),
            DropdownMenuItem(value: 'INVENTORY_MANAGER', child: Text('Inventory In-Charge')),
            DropdownMenuItem(value: 'FACULTY', child: Text('Faculty Member (CSE)')),
            DropdownMenuItem(value: 'SUPER_ADMIN', child: Text('Head of Department')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedRole = val);
          },
        ),
        const SizedBox(height: 14),

        const Text(
          "Password *",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryNavy),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _signupPasswordController,
          obscureText: _obscureSignupPassword,
          decoration: InputDecoration(
            hintText: 'Min 6 characters',
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryOrange),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureSignupPassword ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textGray,
              ),
              onPressed: () => setState(() => _obscureSignupPassword = !_obscureSignupPassword),
            ),
          ),
        ),
        const SizedBox(height: 14),

        const Text(
          "Confirm Password *",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryNavy),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _signupConfirmPasswordController,
          obscureText: _obscureSignupPassword,
          decoration: const InputDecoration(
            hintText: 'Re-enter password',
            prefixIcon: Icon(Icons.lock_reset, color: AppColors.primaryOrange),
          ),
        ),
        const SizedBox(height: 22),

        ElevatedButton(
          onPressed: provider.isLoading ? null : _handleSignUp,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: provider.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text("Register & Enter Portal", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
