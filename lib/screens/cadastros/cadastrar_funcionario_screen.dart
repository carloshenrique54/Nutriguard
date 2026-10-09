import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../services/supabase_service.dart';
import '../../widgets/animated_components.dart';
import '../../widgets/watermark_background.dart';

class CadastrarFuncionarioScreen extends StatefulWidget {
  const CadastrarFuncionarioScreen({super.key});

  @override
  State<CadastrarFuncionarioScreen> createState() => _CadastrarFuncionarioScreenState();
}

class _CadastrarFuncionarioScreenState extends State<CadastrarFuncionarioScreen> {
  final _nomeCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final SupabaseService _supabase = SupabaseService();
  
  String _selectedRole = 'gerente';

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


  @override
  void initState() {
    super.initState();
    _checkAccess();
  }
  
  Future<void> _checkAccess() async {
    final currentUserId = _supabase.currentUser?.id;
    if (currentUserId == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final perfil = await _supabase.getUsuarioPerfil(currentUserId);
    final role = perfil?.role ?? '';
    
    List<String> allowedRoles = ['admin'];

    if (!allowedRoles.contains(role)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acesso negado para seu perfil', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  void _cadastrar() async {
    HapticFeedback.lightImpact();
    if (_nomeCtrl.text.isEmpty || _cpfCtrl.text.isEmpty || _emailCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Preencha os campos obrigatórios!', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      );
      return;
    }

    try {
      await _supabase.signUp(
        email: _emailCtrl.text.trim(),
        password: _senhaCtrl.text.trim(),
        nome: _nomeCtrl.text.trim(),
        cpf: _cpfCtrl.text.trim(),
        telefone: _telefoneCtrl.text.trim(),
        cargo: _selectedRole,
      );

      HapticFeedback.mediumImpact();

      _nomeCtrl.clear();
      _cpfCtrl.clear();
      _emailCtrl.clear();
      _telefoneCtrl.clear();
      _senhaCtrl.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Funcionário cadastrado com sucesso!', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao cadastrar: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cpfCtrl.dispose();
    _emailCtrl.dispose();
    _telefoneCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF2E0),
      
      body: WatermarkBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. CABEÇALHO
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cadastrar\nFuncionario',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC23147),
                      height: 1.1,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC23147),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ADM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Builder(
                    builder: (ctx) => GestureDetector(
                      onTap: () => CustomEndDrawer.showMenu(context),
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 40,
                        height: 40,
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 32,
                          height: 32,
                          color: const Color(0xFFC23147),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              // 2. BOTÃO VOLTAR
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: const Color(0xFFC23147),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Voltar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // 3. SELETOR DE TIPO
              const SizedBox(height: 24),
              const Text(
                'Tipo de funcionario',
                style: TextStyle(
                  color: Color(0xFF4A4A4A),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFC23147)),
                    items: const [
                      DropdownMenuItem(value: 'gerente', child: Text('Gerente')),
                      DropdownMenuItem(value: 'operador', child: Text('Operador')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRole = val);
                    },
                  ),
                ),
              ),
              
              // 4. ÁREA DO FORMULÁRIO (Cartão Verde)
              const SizedBox(height: 24),
              const Text(
                'Dados do funcionario',
                style: TextStyle(
                  color: Color(0xFF4A4A4A),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFC8E569),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: Column(
                        children: [
                          CustomFormInput(
                            label: 'Nome do $_selectedRole',
                            hintText: 'Nome completo',
                            controller: _nomeCtrl,
                          ),
                          const SizedBox(height: 12),
                          CustomFormInput(
                            label: 'CPF do $_selectedRole',
                            hintText: 'XXX.XXX.XXX-XX',
                            controller: _cpfCtrl,
                            inputFormatters: [_cpfFormatter],
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          CustomFormInput(
                            label: 'E-mail do $_selectedRole',
                            hintText: 'exemplo@email.com',
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          CustomFormInput(
                            label: 'Telefone do $_selectedRole',
                            hintText: '(XX) XXXXX-XXXX',
                            controller: _telefoneCtrl,
                            inputFormatters: [_telefoneFormatter],
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          CustomFormInput(
                            label: 'Senha do $_selectedRole',
                            hintText: 'Mínimo 8 caracteres',
                            obscureText: true,
                            controller: _senhaCtrl,
                          ),
                        ],
                      ),
                    ),
                    // Botão Submeter no Rodapé
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      width: double.infinity,
                      child: MorphingSubmitButton(
                        text: 'Cadastrar',
                        onPressed: _cadastrar,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

// COMPONENTE REUTILIZÁVEL DE INPUT
class CustomFormInput extends StatelessWidget {
  final String label;
  final String hintText;
  final bool obscureText;
  final TextEditingController? controller;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;

  const CustomFormInput({
    super.key,
    required this.label,
    required this.hintText,
    this.obscureText = false,
    this.controller,
    this.inputFormatters,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF4A4A4A),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            inputFormatters: inputFormatters,
            keyboardType: keyboardType,
            decoration: InputDecoration.collapsed(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey.shade400),
            ),
          ),
        ),
      ],
    );
  }
}
