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
      final authResponse = await _supabaseService.signIn(
        _emailCtrl.text.trim(),
        _senhaCtrl.text.trim(),
      );

      final user = authResponse.user ?? _supabaseService.currentUser;
      if (user == null) throw Exception('User not found');
      final currentUserId = user.id;

      // Inicia a busca do perfil imediatamente
      final perfilFuture = _supabaseService.getUsuarioPerfil(currentUserId);
      final roleHint = user.userMetadata?['cargo']?.toString().toLowerCase();

      String targetRoute = '/dashboard-frota';

      if (roleHint == 'admin') {
        // Para admin: validações de existência (LIMIT 1) concorrentes com a busca do perfil
        final results = await Future.wait([
          perfilFuture,
          _supabaseService.hasDispositivos(),
          _supabaseService.hasFrotas(),
        ]);
        final perfil = results[0] as UsuarioModel?;
        final hasDevices = results[1] as bool;
        final hasFrotas = results[2] as bool;

        final effectiveRole = perfil?.role ?? 'admin';
        if (effectiveRole == 'admin') {
          targetRoute = (!hasDevices || !hasFrotas) ? '/dashboard-frota' : '/listar-frotas';
        } else if (effectiveRole == 'gerente') {
          targetRoute = '/dashboard-frota';
        } else if (effectiveRole == 'operador') {
          final tripActive = await TripService().isTripActive(currentUserId);
          targetRoute = tripActive ? '/dashboard-veiculo' : '/iniciar-viagem';
        }
      } else if (roleHint == 'gerente') {
        await perfilFuture;
        targetRoute = '/dashboard-frota';
      } else if (roleHint == 'operador') {
        final results = await Future.wait([
          perfilFuture,
          TripService().isTripActive(currentUserId),
        ]);
        final tripActive = results[1] as bool;
        targetRoute = tripActive ? '/dashboard-veiculo' : '/iniciar-viagem';
      } else {
        // Fallback caso não haja metadado de cargo na autenticação
        final perfil = await perfilFuture;
        final role = perfil?.role ?? '';
        if (role == 'admin') {
          final results = await Future.wait([
            _supabaseService.hasDispositivos(),
            _supabaseService.hasFrotas(),
          ]);
          final hasDevices = results[0];
          final hasFrotas = results[1];
          targetRoute = (!hasDevices || !hasFrotas) ? '/dashboard-frota' : '/listar-frotas';
        } else if (role == 'operador') {
          final tripActive = await TripService().isTripActive(currentUserId);
          targetRoute = tripActive ? '/dashboard-veiculo' : '/iniciar-viagem';
        } else {
          targetRoute = '/dashboard-frota';
        }
      }

      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, targetRoute, (route) => false);
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
