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
  final String? initialFrotaId;
  final String? initialOperadorId;
  final DispositivoModel? dispositivoToEdit;

  const CadastrarDispositivoScreen({
    super.key,
    this.userRole = 'ADM',
    this.bypassAccessCheck = false,
    this.initialFrotaId,
    this.initialOperadorId,
    this.dispositivoToEdit,
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
  DispositivoModel? _dispositivoToEdit;
  bool _hasInitializedRoute = false;

  bool get isEditing => _dispositivoToEdit != null;

  @override
  void initState() {
    super.initState();
    _selectedFrotaId = widget.initialFrotaId;
    _selectedOperadorId = widget.initialOperadorId;
    if (widget.dispositivoToEdit != null) {
      _initFromDispositivo(widget.dispositivoToEdit!);
    }
    _checkAccess();
    _fetchInitialData();
  }

  void _initFromDispositivo(DispositivoModel d) {
    _dispositivoToEdit = d;
    _nomeCtrl.text = d.nomeDispositivo ?? '';
    _numSerieCtrl.text = d.numeroSerie ?? '';
    _modeloDispCtrl.text = d.modeloDispositivo ?? '';
    _modeloVeiculoCtrl.text = d.modeloVeiculo ?? '';
    _placaCtrl.text = d.placaVeiculo ?? '';
    _selectedFrotaId = d.idFrota;
    _selectedOperadorId = d.idOperador;
    _tempMinCtrl.text = d.temperaturaMinima?.toString() ?? '';
    _tempMaxCtrl.text = d.temperaturaMaxima?.toString() ?? '';
    _humidadeCtrl.text = d.umidadeMaxima?.toString() ?? '';
    _sensibilidadeCtrl.text = d.sensibilidadeVibracao?.toString() ?? '';
    _limiteVibracaoCtrl.text = d.limiteVibracao?.toString() ?? '';
    _intervaloCtrl.text = d.intervaloDados?.toString() ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitializedRoute) {
      _hasInitializedRoute = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (_dispositivoToEdit == null && args is DispositivoModel) {
        _initFromDispositivo(args);
      }
    }
  }

  Future<void> _fetchInitialData() async {
    try {
      final frotasList = await _supabase.getFrotas();
      final usersRes = await Supabase.instance.client.from('Usuarios').select();
      final usersList = (usersRes as List).map((e) => UsuarioModel.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          _frotas = frotasList;
          _operadores = usersList.where((u) => u.cargo?.trim().toLowerCase() == 'operador').toList();

          // Pré-seleciona a frota ativa no contexto se não especificada
          if (_selectedFrotaId == null && !isEditing) {
            final contextFrota = AdminContextService().selectedFrota;
            if (contextFrota != null && _frotas.any((f) => f.id == contextFrota.id)) {
              _selectedFrotaId = contextFrota.id;
            }
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

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensagem,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFC23147),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  void _cadastrar() async {
    HapticFeedback.lightImpact();

    // 1. Frota vinculada (Opcional - sem bloqueio)

    // 2. Operador responsável (Obrigatório)
    if (_selectedOperadorId == null || _selectedOperadorId!.trim().isEmpty) {
      _mostrarErro('Selecione o operador responsável pelo dispositivo!');
      return;
    }

    // 3. Nome do Dispositivo (Obrigatório)
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) {
      _mostrarErro('Informe o nome do dispositivo!');
      return;
    }

    // 4. Número de Série (Obrigatório)
    final numSerie = _numSerieCtrl.text.trim();
    if (numSerie.isEmpty) {
      _mostrarErro('Informe o número de série do dispositivo!');
      return;
    }

    // 5. Modelo do Dispositivo (Obrigatório)
    final modeloDisp = _modeloDispCtrl.text.trim();
    if (modeloDisp.isEmpty) {
      _mostrarErro('Informe o modelo do dispositivo!');
      return;
    }

    // 6. Modelo do Veículo (Obrigatório)
    final modeloVeiculo = _modeloVeiculoCtrl.text.trim();
    if (modeloVeiculo.isEmpty) {
      _mostrarErro('Informe o modelo do veículo!');
      return;
    }

    // 7. Placa do Veículo (Obrigatório)
    final placa = _placaCtrl.text.trim();
    if (placa.isEmpty) {
      _mostrarErro('Informe a placa do veículo!');
      return;
    }

    // 8. Temperatura Mínima (Obrigatório)
    if (_tempMinCtrl.text.trim().isEmpty) {
      _mostrarErro('Informe a temperatura mínima do dispositivo!');
      return;
    }
    final tempMin = _parseNum(_tempMinCtrl.text);
    if (tempMin == null) {
      _mostrarErro('Informe um valor numérico válido para a temperatura mínima!');
      return;
    }

    // 9. Temperatura Máxima (Obrigatório)
    if (_tempMaxCtrl.text.trim().isEmpty) {
      _mostrarErro('Informe a temperatura máxima do dispositivo!');
      return;
    }
    final tempMax = _parseNum(_tempMaxCtrl.text);
    if (tempMax == null) {
      _mostrarErro('Informe um valor numérico válido para a temperatura máxima!');
      return;
    }

    // Validação de coerência das temperaturas
    if (tempMin > tempMax) {
      _mostrarErro('A temperatura mínima não pode ser maior que a temperatura máxima!');
      return;
    }

    // 10. Umidade Máxima (Obrigatório)
    if (_humidadeCtrl.text.trim().isEmpty) {
      _mostrarErro('Informe a umidade máxima do dispositivo!');
      return;
    }
    final humidade = _parseNum(_humidadeCtrl.text);
    if (humidade == null) {
      _mostrarErro('Informe um valor numérico válido para a umidade máxima!');
      return;
    }

    // 11. Sensibilidade do Sensor de Vibração (Obrigatório)
    if (_sensibilidadeCtrl.text.trim().isEmpty) {
      _mostrarErro('Informe a sensibilidade do sensor de vibração!');
      return;
    }
    final sensibilidade = _parseInt(_sensibilidadeCtrl.text);
    if (sensibilidade == null) {
      _mostrarErro('Informe um valor numérico válido para a sensibilidade de vibração!');
      return;
    }

    // 12. Limite de Vibração (Obrigatório)
    if (_limiteVibracaoCtrl.text.trim().isEmpty) {
      _mostrarErro('Informe o limite de vibração!');
      return;
    }
    final limiteVibracao = _parseInt(_limiteVibracaoCtrl.text);
    if (limiteVibracao == null) {
      _mostrarErro('Informe um valor numérico válido para o limite de vibração!');
      return;
    }

    // 13. Intervalo entre Coletas de Dados (Obrigatório)
    if (_intervaloCtrl.text.trim().isEmpty) {
      _mostrarErro('Informe o intervalo entre coletas de dados!');
      return;
    }
    final intervalo = _parseNum(_intervaloCtrl.text);
    if (intervalo == null) {
      _mostrarErro('Informe um valor numérico válido para o intervalo entre coletas!');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (isEditing) {
        final updated = await _supabase.updateDispositivo(
          id: _dispositivoToEdit!.id,
          nomeDispositivo: nome,
          idFrota: (_selectedFrotaId != null && _selectedFrotaId!.isNotEmpty) ? _selectedFrotaId : null,
          idOperador: _selectedOperadorId!,
          numeroSerie: numSerie,
          modeloDispositivo: modeloDisp,
          modeloVeiculo: modeloVeiculo,
          placaVeiculo: placa,
          temperaturaMinima: tempMin,
          temperaturaMaxima: tempMax,
          umidadeMaxima: humidade,
          sensibilidadeVibracao: sensibilidade,
          limiteVibracao: limiteVibracao,
          intervaloDados: intervalo,
        );

        if (AdminContextService().selectedDevice?.id == _dispositivoToEdit!.id) {
          AdminContextService().setDevice(updated);
        }

        HapticFeedback.mediumImpact();

        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Dispositivo atualizado com sucesso!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        );

        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          Navigator.pushReplacementNamed(context, '/listar-dispositivos');
        }
      } else {
        await _supabase.cadastrarDispositivo(
          nomeDispositivo: nome,
          idFrota: _selectedFrotaId,
          idOperador: _selectedOperadorId!,
          numeroSerie: numSerie,
          modeloDispositivo: modeloDisp,
          modeloVeiculo: modeloVeiculo,
          placaVeiculo: placa,
          temperaturaMinima: tempMin,
          temperaturaMaxima: tempMax,
          umidadeMaxima: humidade,
          sensibilidadeVibracao: sensibilidade,
          limiteVibracao: limiteVibracao,
          intervaloDados: intervalo,
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
      }
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
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Color(0xFFC23147),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
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
                    Text(
                      isEditing ? 'Editar\nDispositivo' : 'Cadastrar\nDispositivo',
                      style: const TextStyle(
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
                  'Dados do dispositivo (Todos obrigatórios)',
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
                  'Vínculo e Veículo (Frota opcional)',
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
                        subtitle: '(Opcional)',
                        isRequired: false,
                        value: _selectedFrotaId ?? '',
                        hintText: _frotas.isEmpty ? 'Nenhuma frota encontrada' : 'Selecione a frota (Opcional)...',
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Nenhuma frota (Sem frota)', style: TextStyle(color: Colors.black54)),
                          ),
                          if (_selectedFrotaId != null &&
                              _selectedFrotaId!.isNotEmpty &&
                              !_frotas.any((f) => f.id == _selectedFrotaId))
                            DropdownMenuItem(
                              value: _selectedFrotaId,
                              child: const Text('Frota selecionada'),
                            ),
                          ..._frotas.map((f) => DropdownMenuItem(value: f.id, child: Text(f.nome ?? 'Frota sem nome'))),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedFrotaId = (val == null || val.isEmpty) ? null : val);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDropdownField(
                        label: 'Operador responsável',
                        subtitle: '(Obrigatório)',
                        isRequired: true,
                        value: _selectedOperadorId,
                        hintText: _operadores.isEmpty ? 'Nenhum operador cadastrado' : 'Selecione o operador...',
                        items: [
                          if (_selectedOperadorId != null &&
                              _selectedOperadorId!.isNotEmpty &&
                              !_operadores.any((u) => u.id == _selectedOperadorId))
                            DropdownMenuItem(
                              value: _selectedOperadorId,
                              child: const Text('Operador selecionado'),
                            ),
                          ..._operadores.map((u) => DropdownMenuItem(
                                value: u.id,
                                child: Text(u.nome ?? 'Sem nome'),
                              )),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedOperadorId = val);
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
                      'Configurações dos sensores (Todos obrigatórios)',
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
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.save_outlined, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        isEditing ? 'Salvar alterações' : 'Cadastrar Dispositivo',
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
  final bool isRequired;

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
    this.isRequired = true,
  });

  @override
  Widget build(BuildContext context) {
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
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Color(0xFFC23147),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
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
