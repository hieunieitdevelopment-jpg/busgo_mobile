import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:busgo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:busgo_mobile/features/auth/presentation/widgets/google_login_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isEmailType = true; // Toggle between Email and Phone
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final String loginUser = _isEmailType ? _emailController.text.trim() : _phoneController.text.trim();

    final success = await authProvider.signIn(
      loginUser,
      _passwordController.text,
    );

    if (success) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Đăng nhập thành công! Chào mừng quay trở lại BusGo.'),
          backgroundColor: Color(0xff006e1c),
        ),
      );
      // Redirect dynamically to HomePage
      router.go('/');
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Đăng nhập thất bại. Vui lòng kiểm tra lại.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // Xử lý đăng nhập bằng Google
  Future<void> _handleGoogleLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final success = await authProvider.signInWithGoogle();

    if (success) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Đăng nhập Google thành công! Chào mừng đến BusGo.'),
          backgroundColor: Color(0xff006e1c),
        ),
      );
      router.go('/');
    } else {
      final errorMsg = authProvider.errorMessage;
      if (errorMsg != null && errorMsg.isNotEmpty) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // Xử lý đăng nhập bằng Facebook
  Future<void> _handleFacebookLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final success = await authProvider.signInWithFacebook();

    if (success) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Đăng nhập Facebook thành công! Chào mừng đến BusGo.'),
          backgroundColor: Color(0xff006e1c),
        ),
      );
      router.go('/');
    } else {
      final errorMsg = authProvider.errorMessage;
      if (errorMsg != null && errorMsg.isNotEmpty) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // GoRouter redirect guard tự động chuyển user đã login về Home

    return Scaffold(
      backgroundColor: const Color(0xfff7f9fa),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Sleek Emerald Green Top Illustration Banner (Matches Web Left Column)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff006e1c), Color(0xff004510)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: AssetImage('busgo.jpg'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Flexible(
                        child: Text(
                          'BusGo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user_outlined, color: Colors.amber, size: 14),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Đặt vé nhanh, quản lý rõ ràng',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Một tài khoản cho mọi hành trình.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Theo dõi vé, thanh toán, lịch trình và hồ sơ cá nhân trong cùng một không gian làm việc gọn gàng.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // 2. High-fidelity Login Card Form (Matches Web Right Column)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                elevation: 4,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(22.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Web Badge: Đăng nhập tài khoản
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xffe8f5e9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline, color: Color(0xff006e1c), size: 14),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Đăng nhập tài khoản',
                                  style: TextStyle(color: Color(0xff006e1c), fontSize: 11, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Chào mừng trở lại',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Dùng email hoặc số điện thoại để tiếp tục vào BusGo.',
                          style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
                        ),
                        const SizedBox(height: 24),

                        // Switch Tab (Email vs Số điện thoại)
                        Container(
                          height: 44,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xfff1f3f4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _isEmailType = true),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _isEmailType ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: _isEmailType
                                          ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                                          : [],
                                    ),
                                    alignment: Alignment.center,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.email_outlined,
                                            size: 16,
                                            color: _isEmailType ? const Color(0xff006e1c) : Colors.grey,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Email',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: _isEmailType ? const Color(0xff006e1c) : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _isEmailType = false),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: !_isEmailType ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: !_isEmailType
                                          ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                                          : [],
                                    ),
                                    alignment: Alignment.center,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.phone_android_outlined,
                                            size: 16,
                                            color: !_isEmailType ? const Color(0xff006e1c) : Colors.grey,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Số điện thoại',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: !_isEmailType ? const Color(0xff006e1c) : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Form Inputs
                        if (_isEmailType) ...[
                          const Text(
                            'Email',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'hieunieitdevelopment@gmail.com',
                              prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                              filled: true,
                              fillColor: const Color(0xffeef3f8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Vui lòng nhập Email.';
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return 'Email không đúng định dạng.';
                              }
                              return null;
                            },
                          ),
                        ] else ...[
                          const Text(
                            'Số điện thoại',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: '09xx xxx xxx',
                              prefixIcon: const Icon(Icons.phone_android_outlined, size: 20),
                              filled: true,
                              fillColor: const Color(0xffeef3f8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Vui lòng nhập số điện thoại.';
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Password Field
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Mật khẩu',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Tính năng khôi phục mật khẩu đang phát triển.')),
                                );
                              },
                              child: const Text(
                                'Quên mật khẩu?',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff006e1c)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: const Color(0xffeef3f8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Remember Me Checkbox
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              activeColor: const Color(0xff006e1c),
                              onChanged: (val) => setState(() => _rememberMe = val ?? true),
                            ),
                            const Text('Ghi nhớ đăng nhập', style: TextStyle(fontSize: 12, color: Colors.black87)),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Green Submit Button: [→ Đăng nhập]
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: authProvider.isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff006e1c),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            child: authProvider.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.login_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Đăng nhập',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ─── Divider: "Hoặc đăng nhập với" ───
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'Hoặc đăng nhập với',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ─── Social Login Buttons ───
                        Column(
                          children: [
                            // Nút Google
                            buildGoogleLoginButton(
                              isLoading: authProvider.isLoading ||
                                  authProvider.isSocialLoading ||
                                  !authProvider.isGoogleSignInReady,
                              onPressed: _handleGoogleLogin,
                            ),
                            const SizedBox(height: 12),
                            // Nút Facebook
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: (authProvider.isLoading || authProvider.isSocialLoading)
                                    ? null
                                    : () => _handleFacebookLogin(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff1877F2),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                icon: authProvider.isSocialLoading
                                    ? const SizedBox.shrink()
                                    : const Icon(Icons.facebook, size: 22),
                                label: const Text(
                                  'Facebook',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Switch to Register (Tạo tài khoản)
                        Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            const Text('Chưa có tài khoản? ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            GestureDetector(
                              onTap: () => context.push('/register'),
                              child: const Text(
                                'Tạo tài khoản ngay',
                                style: TextStyle(
                                  color: Color(0xff006e1c),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
