import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../services/supabase_service.dart';
import '../../services/admin_context_service.dart';
import '../../models/models.dart';
import '../../widgets/watermark_background.dart';

/// Formatador de texto para transformar caracteres em caixa alta (ex: Placas de veículos)
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// Formatador estrito para números decimais com suporte a sinal negativo (ex: Temperaturas como -18.0 ou 4.5)
class SignedDecimalTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Permite que o usuário digite apenas o sinal de menos inicialmente
    if (text == '-') return newValue;

    // Aceita apenas dígitos, com no máximo um ponto ou vírgula, e sinal negativo opcional no início
    final regex = RegExp(r'^-?\d*([.,]\d*)?$');
    if (regex.hasMatch(text)) {
      return newValue;
    }
    return oldValue;
  }
}

/// Formatador estrito para valores percentuais numéricos entre 0 e 100%
class PercentageTextInputFormatter extends TextInputFormatter {
  final bool allowDecimal;

  PercentageTextInputFormatter({this.allowDecimal = true});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final regex = allowDecimal
        ? RegExp(r'^\d*([.,]\d*)?$')
        : RegExp(r'^\d+$');

    if (!regex.hasMatch(text)) {
      return oldValue;
    }

    final normalized = text.replaceAll(',', '.');
    final val = double.tryParse(normalized);
    if (val != null && val > 100) {
      return oldValue;
    }

    return newValue;
  }
}

class CadastrarDispositivoScreen extends StatefulWidget {
  final String userRole;
  final bool bypassAccessCheck;

  const CadastrarDispositivoScreen({
    super.key,
    this.userRole = 'ADM',
    this.bypassAccessCheck = false,
  });

  @override
  State<CadastrarDispositivoScreen> createState() => _CadastrarDispositivoScreenState();
}

class _CadastrarDispositivoScreenState extends State<CadastrarDispositivoScreen> {
  final SupabaseService _supabase = SupabaseService();

  // Controladores - Dados do Dispositivo
  final _nomeCtrl = TextEditingController();
  final _numSerieCtrl = TextEditingController();
  final _modeloDispCtrl = TextEditingController();

  // Controladores - Dados do Veículo
  final _modeloVeiculoCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();

  // Controladores - Configurações dos Sensores (Apenas Números)
  final _tempMinCtrl = TextEditingController();
  final _tempMaxCtrl = TextEditingController();
  final _humidadeCtrl = TextEditingController();
  final _sensibilidadeCtrl = TextEditingController();
  final _limiteVibracaoCtrl = TextEditingController();
  final _intervaloCtrl = TextEditingController();

  String? _selectedFrotaId;
  String? _selectedOperadorId;
  List<FrotaModel> _frotas = [];
  List<UsuarioModel> _operadores = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final frotasList = await _supabase.getFrotas();
      final usersRes = await Supabase.instance.client.from('Usuarios').select();
      final usersList = (usersRes as List).map((e) => UsuarioModel.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          _frotas = frotasList;
          _operadores = usersList.where((u) => u.cargo?.toLowerCase() == 'operador').toList();

          // Pré-seleciona a frota ativa no contexto (se houver)
          final contextFrota = AdminContextService().selectedFrota;
          if (contextFrota != null && _frotas.any((f) => f.id == contextFrota.id)) {
            _selectedFrotaId = contextFrota.id;
          } else if (_frotas.isNotEmpty && _selectedFrotaId == null) {
            _selectedFrotaId = _frotas.first.id;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar frotas ou operadores: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  num? _parseNum(String text) {
    final clean = text.trim().replaceAll(',', '.');
    if (clean.isEmpty) return null;
    return num.tryParse(clean);
  }

  num? _parseInt(String text) {
    final clean = text.trim().replaceAll(',', '.');
    if (clean.isEmpty) return null;
    final val = double.tryParse(clean);
    return val?.toInt() ?? int.tryParse(clean);
  }

  void _cadastrar() async {
    HapticFeedback.lightImpact();

    // 1. Validação de Frota (Obrigatório no Banco de Dados - NOT NULL)
    if (_selectedFrotaId == null || _selectedFrotaId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Selecione uma frota para vincular o dispositivo!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFC23147),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      );
      return;
    }

    // 2. Validação de Nome do Dispositivo
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Informe o nome do dispositivo!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFC23147),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      );
      return;
    }

    // 3. Validação lógica de temperatura (se ambas preenchidas)
    final tempMin = _parseNum(_tempMinCtrl.text);
    final tempMax = _parseNum(_tempMaxCtrl.text);
    if (tempMin != null && tempMax != null && tempMin > tempMax) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'A temperatura mínima não pode ser maior que a temperatura máxima!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFC23147),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _supabase.cadastrarDispositivo(
        nomeDispositivo: nome,
        idFrota: _selectedFrotaId!,
        idOperador: _selectedOperadorId,
        numeroSerie: _numSerieCtrl.text.trim(),
        modeloDispositivo: _modeloDispCtrl.text.trim(),
        modeloVeiculo: _modeloVeiculoCtrl.text.trim(),
        placaVeiculo: _placaCtrl.text.trim(),
        temperaturaMinima: tempMin,
        temperaturaMaxima: tempMax,
        umidadeMaxima: _parseNum(_humidadeCtrl.text),
        sensibilidadeVibracao: _parseInt(_sensibilidadeCtrl.text),
        limiteVibracao: _parseInt(_limiteVibracaoCtrl.text),
        intervaloDados: _parseNum(_intervaloCtrl.text),
      );

      HapticFeedback.mediumImpact();

      _nomeCtrl.clear();
      _numSerieCtrl.clear();
      _modeloDispCtrl.clear();
      _modeloVeiculoCtrl.clear();
      _placaCtrl.clear();
      _tempMinCtrl.clear();
      _tempMaxCtrl.clear();
      _humidadeCtrl.clear();
      _sensibilidadeCtrl.clear();
      _limiteVibracaoCtrl.clear();
      _intervaloCtrl.clear();

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Dispositivo cadastrado com sucesso!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
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
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _numSerieCtrl.dispose();
    _modeloDispCtrl.dispose();
    _modeloVeiculoCtrl.dispose();
    _placaCtrl.dispose();
    _tempMinCtrl.dispose();
    _tempMaxCtrl.dispose();
    _humidadeCtrl.dispose();
    _sensibilidadeCtrl.dispose();
    _limiteVibracaoCtrl.dispose();
    _intervaloCtrl.dispose();
    super.dispose();
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

    List<String> allowedRoles = ['admin'];

    if (!allowedRoles.contains(role)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acesso negado para seu perfil', style: TextStyle(color: Colors.white)),
            backgroundColor: Color(0xFFC23147),
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required String hintText,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    String? subtitle,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF4A4A4A),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(width: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: isRequired ? const Color(0xFFC23147) : Colors.black54,
                  fontWeight: isRequired ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: isRequired && value == null
                ? Border.all(color: const Color(0xFFC23147).withValues(alpha: 0.5), width: 1.5)
                : null,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(
                _isLoading ? 'Carregando opções...' : hintText,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFC23147)),
              items: items,
              onChanged: (_isLoading || _isSubmitting) ? null : onChanged,
            ),
          ),
        ),
      ],
    );
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
                      'Cadastrar\nDispositivo',
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
                      child: Text(
                        widget.userRole,
                        style: const TextStyle(
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

                // 3. SEÇÃO 1: DADOS DO DISPOSITIVO
                const SizedBox(height: 24),
                const Text(
                  'Dados do dispositivo',
                  style: TextStyle(
                    color: Color(0xFF4A4A4A),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8E569),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      CustomFormInput(
                        label: 'Nome do dispositivo',
                        hintText: 'Ex: Sensor Térmico Baú 01',
                        controller: _nomeCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !_isSubmitting,
                      ),
                      const SizedBox(height: 12),
                      CustomFormInput(
                        label: 'Número de série',
                        hintText: 'Ex: SN-2024-00189',
                        controller: _numSerieCtrl,
                        textCapitalization: TextCapitalization.characters,
                        enabled: !_isSubmitting,
                      ),
                      const SizedBox(height: 12),
                      CustomFormInput(
                        label: 'Modelo do dispositivo',
                        hintText: 'Ex: NG-SensorPro 4G',
                        controller: _modeloDispCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !_isSubmitting,
                      ),
                    ],
                  ),
                ),

                // 4. SEÇÃO 2: VÍNCULO E DADOS DO VEÍCULO
                const SizedBox(height: 20),
                const Text(
                  'Vínculo e Veículo',
                  style: TextStyle(
                    color: Color(0xFF4A4A4A),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8E569),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDropdownField(
                        label: 'Frota vinculada',
                        subtitle: '(Obrigatório)',
                        isRequired: true,
                        value: _selectedFrotaId,
                        hintText: _frotas.isEmpty ? 'Nenhuma frota encontrada' : 'Selecione a frota...',
                        items: _frotas
                            .map((f) => DropdownMenuItem(value: f.id, child: Text(f.nome ?? 'Frota sem nome')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedFrotaId = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDropdownField(
                        label: 'Operador responsável',
                        subtitle: '(Opcional)',
                        value: _selectedOperadorId,
                        hintText: 'Selecione o operador...',
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Nenhum operador atribuído', style: TextStyle(color: Colors.grey)),
                          ),
                          ..._operadores.map((u) => DropdownMenuItem(
                                value: u.id,
                                child: Text(u.nome ?? 'Sem nome'),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedOperadorId = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      CustomFormInput(
                        label: 'Modelo do veículo',
                        hintText: 'Ex: Mercedes-Benz Actros 2651',
                        controller: _modeloVeiculoCtrl,
                        textCapitalization: TextCapitalization.words,
                        enabled: !_isSubmitting,
                      ),
                      const SizedBox(height: 12),
                      CustomFormInput(
                        label: 'Placa do veículo',
                        hintText: 'Ex: BRA2E19 ou ABC-1234',
                        controller: _placaCtrl,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(8),
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
                          UpperCaseTextFormatter(),
                        ],
                        enabled: !_isSubmitting,
                      ),
                    ],
                  ),
                ),

                // 5. SEÇÃO 3: CONFIGURAÇÕES DOS SENSORES (APENAS NÚMEROS)
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      'Configurações dos sensores',
                      style: TextStyle(
                        color: Color(0xFF4A4A4A),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC23147).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Apenas números',
                        style: TextStyle(
                          color: Color(0xFFC23147),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
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
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          children: [
                            // Temperatura Mínima (°C)
                            CustomFormInput(
                              label: 'Temperatura mínima',
                              hintText: 'Ex: 2.0 ou -18.0',
                              controller: _tempMinCtrl,
                              suffixText: '°C',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              inputFormatters: [SignedDecimalTextInputFormatter()],
                              enabled: !_isSubmitting,
                            ),
                            const SizedBox(height: 12),

                            // Temperatura Máxima (°C)
                            CustomFormInput(
                              label: 'Temperatura máxima',
                              hintText: 'Ex: 8.0',
                              controller: _tempMaxCtrl,
                              suffixText: '°C',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              inputFormatters: [SignedDecimalTextInputFormatter()],
                              enabled: !_isSubmitting,
                            ),
                            const SizedBox(height: 12),

                            // Umidade Máxima (%)
                            CustomFormInput(
                              label: 'Umidade máxima',
                              hintText: 'Ex: 75',
                              controller: _humidadeCtrl,
                              suffixText: '%',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [PercentageTextInputFormatter()],
                              enabled: !_isSubmitting,
                            ),
                            const SizedBox(height: 12),

                            // Sensibilidade do Sensor de Vibração (%)
                            CustomFormInput(
                              label: 'Sensibilidade do sensor de vibração',
                              hintText: 'Ex: 50',
                              controller: _sensibilidadeCtrl,
                              suffixText: '%',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [PercentageTextInputFormatter()],
                              enabled: !_isSubmitting,
                            ),
                            const SizedBox(height: 12),

                            // Limite de Vibração (%)
                            CustomFormInput(
                              label: 'Limite de vibração',
                              hintText: 'Ex: 80',
                              controller: _limiteVibracaoCtrl,
                              suffixText: '%',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [PercentageTextInputFormatter()],
                              enabled: !_isSubmitting,
                            ),
                            const SizedBox(height: 12),

                            // Intervalo entre coletas de dados (segundos)
                            CustomFormInput(
                              label: 'Intervalo entre coletas de dados',
                              hintText: 'Ex: 30',
                              controller: _intervaloCtrl,
                              suffixText: 's',
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              enabled: !_isSubmitting,
                            ),
                          ],
                        ),
                      ),

                      // Botão Cadastrar
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        width: double.infinity,
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _cadastrar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC23147),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFC23147).withValues(alpha: 0.6),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.save_outlined, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Cadastrar Dispositivo',
                                        style: TextStyle(
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

/// Componente de Input Reutilizável com Suporte a Suffixes (°C, %, s), Formatadores e Estados
class CustomFormInput extends StatelessWidget {
  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final String? suffixText;
  final Widget? suffixIcon;
  final TextCapitalization textCapitalization;
  final bool enabled;

  const CustomFormInput({
    super.key,
    required this.label,
    this.hintText,
    this.controller,
    this.inputFormatters,
    this.keyboardType,
    this.suffixText,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  inputFormatters: inputFormatters,
                  keyboardType: keyboardType,
                  textCapitalization: textCapitalization,
                  enabled: enabled,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (suffixText != null)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC23147).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    suffixText!,
                    style: const TextStyle(
                      color: Color(0xFFC23147),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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
