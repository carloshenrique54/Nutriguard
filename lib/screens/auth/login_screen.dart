import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../widgets/auth_components.dart';
import '../../services/supabase_service.dart';
import '../../services/trip_service.dart';

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
      if (role == 'admin') {
        final results = await Future.wait([
          _supabaseService.getDispositivos(),
          _supabaseService.getFrotas(),
        ]);
        final devices = results[0] as List<DispositivoModel>;
        final frotas = results[1] as List<FrotaModel>;
        if (!mounted) return;
        // Sem dispositivos ou sem frotas: o Dashboard — Frota exibe o estado
        // vazio com botão para /cadastrar-dispositivo ou /criar-frota.
        if (devices.isEmpty || frotas.isEmpty) {
          Navigator.pushNamedAndRemoveUntil(context, '/dashboard-frota', (route) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/listar-frotas', (route) => false);
        }
      } else if (role == 'gerente') {
        Navigator.pushNamedAndRemoveUntil(context, '/dashboard-frota', (route) => false);
      } else if (role == 'operador') {
        final tripActive = await TripService().isTripActive(currentUserId);
        if (!mounted) return;
        if (!tripActive) {
          Navigator.pushNamedAndRemoveUntil(context, '/iniciar-viagem', (route) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/dashboard-veiculo', (route) => false);
        }
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/dashboard-frota', (route) => false);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = SupabaseService.formatarErro(e);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFFC23147),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
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
        ),
      ),
    );
  }
}
