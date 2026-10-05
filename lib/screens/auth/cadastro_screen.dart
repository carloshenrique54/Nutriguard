import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../widgets/auth_components.dart';
import '../../services/supabase_service.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmaSenhaCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _supabaseService = SupabaseService();
  bool _isLoading = false;

  final _cpfFormatter = MaskTextInputFormatter(
      mask: '###.###.###-##', 
      filter: { "#": RegExp(r'[0-9]') },
      type: MaskAutoCompletionType.lazy
  );

  final _telefoneFormatter = MaskTextInputFormatter(
      mask: '(##) #####-####', 
      filter: { "#": RegExp(r'[0-9]') },
      type: MaskAutoCompletionType.lazy
  );

  void _cadastrar() async {
    if (_senhaCtrl.text != _confirmaSenhaCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('As senhas não coincidem.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _supabaseService.signUp(
        email: _emailCtrl.text.trim(),
        password: _senhaCtrl.text.trim(),
        nome: _nomeCtrl.text.trim(),
        cpf: _cpfCtrl.text.trim(),
        telefone: _telefoneCtrl.text.trim(),
        cargo: 'operador', // default
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastro realizado! Faça login.'), backgroundColor: Colors.green),
      );
      Navigator.pop(context); // Voltar para a tela de login
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao cadastrar: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmaSenhaCtrl.dispose();
    _telefoneCtrl.dispose();
    _cpfCtrl.dispose();
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
                        controller: _nomeCtrl,
                        prefixIcon: Icons.person_outline,
                        hintText: "Nome de Usuário",
                      ),
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
                      CustomTextField(
                        controller: _confirmaSenhaCtrl,
                        prefixIcon: Icons.lock_outline,
                        hintText: "Confirmar senha",
                        obscureText: true,
                      ),
                      CustomTextField(
                        controller: _telefoneCtrl,
                        prefixIcon: Icons.phone_outlined,
                        hintText: "Telefone",
                        inputFormatters: [_telefoneFormatter],
                        keyboardType: TextInputType.phone,
                      ),
                      CustomTextField(
                        controller: _cpfCtrl,
                        prefixIcon: Icons.description_outlined,
                        hintText: "CPF",
                        inputFormatters: [_cpfFormatter],
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _isLoading 
                          ? const CircularProgressIndicator(color: Color(0xFFAD2C3F))
                          : PrimaryGradientButton(
                              text: "Cadastrar",
                              onPressed: _cadastrar,
                            ),
                      if (!_isLoading) ...[
                        GoogleButton(
                          text: "crie uma conta com google",
                          onPressed: () {},
                        ),
                      ],
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/'),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            children: [
                              TextSpan(
                                text: 'Ja tem conta? Faça ',
                                style: TextStyle(color: Colors.black54),
                              ),
                              TextSpan(
                                text: 'Login!',
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
