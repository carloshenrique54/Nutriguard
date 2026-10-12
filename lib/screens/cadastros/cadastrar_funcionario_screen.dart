import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../services/supabase_service.dart';
import '../../widgets/watermark_background.dart';

class CadastrarFuncionarioScreen extends StatefulWidget {
  final bool bypassAccessCheck;
  const CadastrarFuncionarioScreen({super.key, this.bypassAccessCheck = false});

  @override
  State<CadastrarFuncionarioScreen> createState() => _CadastrarFuncionarioScreenState();
}

class _CadastrarFuncionarioScreenState extends State<CadastrarFuncionarioScreen> {
  final _nomeCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _dataNascimentoCtrl = TextEditingController();
  final _numeroCnhCtrl = TextEditingController();
  final _validadeCnhCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmaSenhaCtrl = TextEditingController();
  final SupabaseService _supabase = SupabaseService();

  String _selectedRole = 'gerente';
  bool _isLoading = false;
  bool _obscureSenha = true;
  bool _obscureConfirmaSenha = true;

  final _cpfFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  final _telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  final _dataNascimentoFormatter = MaskTextInputFormatter(
    mask: '##/##/####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  final _validadeCnhFormatter = MaskTextInputFormatter(
    mask: '##/##/####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    if (widget.bypassAccessCheck) return;
    final currentUserId = _supabase.currentUser?.id;
    if (currentUserId == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final perfil = await _supabase.getUsuarioPerfil(currentUserId);
    final role = perfil?.role ?? '';

    if (role != 'admin') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acesso permitido apenas para Administradores.', style: TextStyle(color: Colors.white)),
            backgroundColor: Color(0xFFC23147),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  String get _roleLabel {
    switch (_selectedRole) {
      case 'gerente':
        return 'Gerente';
      case 'operador':
        return 'Operador';
      case 'admin':
        return 'Administrador';
      default:
        return 'Funcionário';
    }
  }

  DateTime? _parseDate(String text) {
    final clean = text.trim();
    final parts = clean.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    if (year < 1920 || year > 2100) return null;
    try {
      final date = DateTime(year, month, day);
      if (date.year != year || date.month != month || date.day != day) return null;
      return date;
    } catch (_) {
      return null;
    }
  }

  Future<void> _selectDate(TextEditingController controller, {required bool isBirthDate}) async {
    final now = DateTime.now();
    final initialDate = isBirthDate
        ? DateTime(now.year - 25, now.month, now.day)
        : DateTime(now.year + 2, now.month, now.day);
    final firstDate = isBirthDate ? DateTime(1920) : DateTime(now.year - 5);
    final lastDate = isBirthDate ? now : DateTime(now.year + 20);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFC23147),
              onPrimary: Colors.white,
              onSurface: Color(0xFF4A4A4A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final day = picked.day.toString().padLeft(2, '0');
      final month = picked.month.toString().padLeft(2, '0');
      final year = picked.year.toString();
      controller.text = '$day/$month/$year';
    }
  }

  String? _validate() {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) {
      return 'Informe o nome completo do funcionário.';
    }
    if (nome.length < 3) {
      return 'O nome deve ter no mínimo 3 caracteres.';
    }

    final cpfDigits = _cpfCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (cpfDigits.isEmpty) {
      return 'Informe o CPF do funcionário.';
    }
    if (cpfDigits.length != 11) {
      return 'O CPF deve conter exatamente 11 dígitos.';
    }

    final email = _emailCtrl.text.trim();
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    if (email.isEmpty) {
      return 'Informe o e-mail do funcionário.';
    }
    if (!emailRegex.hasMatch(email)) {
      return 'Informe um e-mail válido.';
    }

    final telDigits = _telefoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (telDigits.isEmpty) {
      return 'Informe o telefone de contato.';
    }
    if (telDigits.length < 10) {
      return 'O telefone deve conter DDD e pelo menos 10 dígitos.';
    }

    if (_selectedRole == 'operador') {
      final dataNascText = _dataNascimentoCtrl.text.trim();
      if (dataNascText.isEmpty) {
        return 'Informe a data de nascimento do operador.';
      }
      final dataNasc = _parseDate(dataNascText);
      if (dataNasc == null) {
        return 'Data de nascimento inválida. Use o formato DD/MM/AAAA.';
      }
      if (dataNasc.isAfter(DateTime.now())) {
        return 'A data de nascimento não pode ser futura.';
      }
      final age = DateTime.now().difference(dataNasc).inDays ~/ 365;
      if (age < 18) {
        return 'O operador deve ter pelo menos 18 anos.';
      }

      final cnhDigits = _numeroCnhCtrl.text.replaceAll(RegExp(r'\D'), '');
      if (cnhDigits.isEmpty) {
        return 'Informe o número da CNH do operador.';
      }
      if (cnhDigits.length < 9 || cnhDigits.length > 11) {
        return 'O número da CNH deve conter de 9 a 11 dígitos.';
      }

      final validadeCnhText = _validadeCnhCtrl.text.trim();
      if (validadeCnhText.isEmpty) {
        return 'Informe a validade da CNH do operador.';
      }
      final validadeCnh = _parseDate(validadeCnhText);
      if (validadeCnh == null) {
        return 'Data de validade da CNH inválida. Use o formato DD/MM/AAAA.';
      }
    }

    final senha = _senhaCtrl.text;
    if (senha.isEmpty) {
      return 'Defina uma senha de acesso.';
    }
    if (senha.length < 6) {
      return 'A senha deve conter no mínimo 6 caracteres.';
    }

    final confirmaSenha = _confirmaSenhaCtrl.text;
    if (confirmaSenha != senha) {
      return 'A confirmação de senha não confere.';
    }

    return null;
  }

  Future<void> _cadastrar() async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    final validationError = _validate();
    if (validationError != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFFC23147),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final nome = _nomeCtrl.text.trim();
    final cargo = _selectedRole;

    try {
      DateTime? dataNasc;
      String? numeroCnh;
      DateTime? validadeCnh;

      if (cargo == 'operador') {
        dataNasc = _parseDate(_dataNascimentoCtrl.text.trim());
        numeroCnh = _numeroCnhCtrl.text.replaceAll(RegExp(r'\D'), '');
        validadeCnh = _parseDate(_validadeCnhCtrl.text.trim());
      }

      await _supabase.cadastrarFuncionario(
        email: _emailCtrl.text.trim(),
        password: _senhaCtrl.text,
        nome: nome,
        cpf: _cpfCtrl.text.trim(),
        telefone: _telefoneCtrl.text.trim(),
        cargo: cargo,
        dataNascimento: dataNasc,
        numeroCnh: numeroCnh,
        validadeCnh: validadeCnh,
      );

      HapticFeedback.mediumImpact();

      _nomeCtrl.clear();
      _cpfCtrl.clear();
      _emailCtrl.clear();
      _telefoneCtrl.clear();
      _senhaCtrl.clear();
      _confirmaSenhaCtrl.clear();
      _dataNascimentoCtrl.clear();
      _numeroCnhCtrl.clear();
      _validadeCnhCtrl.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Funcionário "$nome" cadastrado com sucesso!', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );

      _showSuccessDialog(nome, cargo);
    } catch (e) {
      if (!mounted) return;
      final msg = SupabaseService.formatarErro(e);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFFC23147),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String nome, String cargo) {
    final roleLabel = cargo == 'gerente'
        ? 'Gerente'
        : cargo == 'operador'
            ? 'Operador'
            : 'Administrador';

    final String? listRoute = cargo == 'gerente'
        ? '/listar-gerentes'
        : cargo == 'operador'
            ? '/listar-operadores'
            : null;

    final String? listButtonTitle = cargo == 'gerente'
        ? 'Ver Gerentes'
        : cargo == 'operador'
            ? 'Ver Operadores'
            : null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 28),
            SizedBox(width: 8),
            Text(
              'Cadastro Concluído',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFFC23147),
              ),
            ),
          ],
        ),
        content: Text(
          '$nome foi registrado(a) com sucesso no sistema com o perfil de $roleLabel.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF4A4A4A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cadastrar outro',
              style: TextStyle(color: Color(0xFF4A4A4A), fontWeight: FontWeight.bold),
            ),
          ),
          if (listRoute != null && listButtonTitle != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, listRoute);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC23147),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(listButtonTitle),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cpfCtrl.dispose();
    _emailCtrl.dispose();
    _telefoneCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmaSenhaCtrl.dispose();
    _dataNascimentoCtrl.dispose();
    _numeroCnhCtrl.dispose();
    _validadeCnhCtrl.dispose();
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
                      'Cadastrar\nFuncionário',
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
                  'Tipo de funcionário',
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
                        DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                      ],
                      onChanged: _isLoading
                          ? null
                          : (val) {
                              if (val != null) setState(() => _selectedRole = val);
                            },
                    ),
                  ),
                ),

                // 4. ÁREA DO FORMULÁRIO (Cartão Verde)
                const SizedBox(height: 24),
                const Text(
                  'Dados do funcionário',
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
                              label: 'Nome do ${_roleLabel.toLowerCase()}',
                              hintText: 'Nome completo',
                              controller: _nomeCtrl,
                              textCapitalization: TextCapitalization.words,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 12),
                            CustomFormInput(
                              label: 'CPF do ${_roleLabel.toLowerCase()}',
                              hintText: '000.000.000-00',
                              controller: _cpfCtrl,
                              inputFormatters: [_cpfFormatter],
                              keyboardType: TextInputType.number,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 12),
                            CustomFormInput(
                              label: 'E-mail do ${_roleLabel.toLowerCase()}',
                              hintText: 'exemplo@email.com',
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 12),
                            CustomFormInput(
                              label: 'Telefone do ${_roleLabel.toLowerCase()}',
                              hintText: '(00) 00000-0000',
                              controller: _telefoneCtrl,
                              inputFormatters: [_telefoneFormatter],
                              keyboardType: TextInputType.phone,
                              enabled: !_isLoading,
                            ),
                            if (_selectedRole == 'operador') ...[
                              const SizedBox(height: 12),
                              CustomFormInput(
                                label: 'Data de nascimento do operador',
                                hintText: 'DD/MM/AAAA',
                                controller: _dataNascimentoCtrl,
                                inputFormatters: [_dataNascimentoFormatter],
                                keyboardType: TextInputType.datetime,
                                enabled: !_isLoading,
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.calendar_today_outlined,
                                    color: Color(0xFFC23147),
                                    size: 20,
                                  ),
                                  onPressed: _isLoading
                                      ? null
                                      : () => _selectDate(_dataNascimentoCtrl, isBirthDate: true),
                                ),
                              ),
                              const SizedBox(height: 12),
                              CustomFormInput(
                                label: 'Número da CNH do operador',
                                hintText: '00000000000 (11 dígitos)',
                                controller: _numeroCnhCtrl,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(11),
                                ],
                                keyboardType: TextInputType.number,
                                enabled: !_isLoading,
                              ),
                              const SizedBox(height: 12),
                              CustomFormInput(
                                label: 'Validade da CNH do operador',
                                hintText: 'DD/MM/AAAA',
                                controller: _validadeCnhCtrl,
                                inputFormatters: [_validadeCnhFormatter],
                                keyboardType: TextInputType.datetime,
                                enabled: !_isLoading,
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.event_available_outlined,
                                    color: Color(0xFFC23147),
                                    size: 20,
                                  ),
                                  onPressed: _isLoading
                                      ? null
                                      : () => _selectDate(_validadeCnhCtrl, isBirthDate: false),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            CustomFormInput(
                              label: 'Senha do ${_roleLabel.toLowerCase()}',
                              hintText: 'Mínimo 6 caracteres',
                              obscureText: _obscureSenha,
                              controller: _senhaCtrl,
                              enabled: !_isLoading,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureSenha ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: const Color(0xFFC23147),
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureSenha = !_obscureSenha),
                              ),
                            ),
                            const SizedBox(height: 12),
                            CustomFormInput(
                              label: 'Confirmar senha',
                              hintText: 'Repita a senha digitada',
                              obscureText: _obscureConfirmaSenha,
                              controller: _confirmaSenhaCtrl,
                              enabled: !_isLoading,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmaSenha ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: const Color(0xFFC23147),
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureConfirmaSenha = !_obscureConfirmaSenha),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Botão Submeter no Rodapé
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        width: double.infinity,
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _cadastrar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC23147),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFC23147).withValues(alpha: 0.6),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.person_add_alt_1, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Cadastrar ${_roleLabel.toLowerCase()}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
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
  final Widget? suffixIcon;
  final TextCapitalization textCapitalization;
  final bool enabled;

  const CustomFormInput({
    super.key,
    required this.label,
    required this.hintText,
    this.obscureText = false,
    this.controller,
    this.inputFormatters,
    this.keyboardType,
    this.suffixIcon,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
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
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: suffixIcon != null ? 2 : 14,
          ),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  inputFormatters: inputFormatters,
                  keyboardType: keyboardType,
                  textCapitalization: textCapitalization,
                  enabled: enabled,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    contentPadding: suffixIcon != null
                        ? const EdgeInsets.symmetric(vertical: 12)
                        : EdgeInsets.zero,
                  ),
                ),
              ),
              ?suffixIcon,
            ],
          ),
        ),
      ],
    );
  }
}
