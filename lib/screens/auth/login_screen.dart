import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/auth_components.dart';
import '../../services/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _supabaseService = SupabaseService();
  bool _isLoading = false;

  void _login() async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      await _supabaseService.signIn(_emailCtrl.text.trim(), _senhaCtrl.text.trim());
      
      final currentUserId = _supabaseService.currentUser?.id;
      if (currentUserId == null) throw Exception('User not found');
      
      final perfil = await _supabaseService.getUsuarioPerfil(currentUserId);
      
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      
      final role = perfil?.role ?? '';
      if (role == 'admin' || role == 'gerente') {
        Navigator.pushReplacementNamed(context, '/dashboard-adm-frota');
      } else if (role == 'operador') {
        Navigator.pushReplacementNamed(context, '/dashboard-veiculo');
      } else {
        Navigator.pushReplacementNamed(context, '/dashboard-vazio');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao fazer login: ${e.toString()}', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      
      backgroundColor: const Color(0xFFFFF2E0),
      body: SafeArea(
        child: Column(
          children: [
            const TopSection(),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: const BoxDecoration(
                  color: Color(0xFFC8E569),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      CustomTextField(
                        controller: _emailCtrl,
                        prefixIcon: Icons.mail_outline,
                        hintText: "E-mail",
                      ),
                      CustomTextField(
                        controller: _senhaCtrl,
                        prefixIcon: Icons.lock_outline,
                        hintText: "Senha",
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      _isLoading 
                          ? const CircularProgressIndicator(color: Color(0xFFAD2C3F))
                          : PrimaryGradientButton(
                              text: "Login",
                              onPressed: _login,
                            ),
                      if (!_isLoading) ...[
                        GoogleButton(
                          text: "Entrar com Google",
                          onPressed: () {},
                        ),
                      ],
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/cadastro'),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            children: [
                              TextSpan(
                                text: 'Não possui conta? Faça ',
                                style: TextStyle(color: Colors.black54),
                              ),
                              TextSpan(
                                text: 'Cadastro!',
                                style: TextStyle(color: Color(0xFFAD2C3F), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
