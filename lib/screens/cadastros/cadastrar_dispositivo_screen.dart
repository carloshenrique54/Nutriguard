import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import '../../widgets/animated_components.dart';
import '../../widgets/watermark_background.dart';

class CadastrarDispositivoScreen extends StatefulWidget {
  final String userRole;

  const CadastrarDispositivoScreen({
    super.key,
    this.userRole = 'ADM',
  });

  @override
  State<CadastrarDispositivoScreen> createState() => _CadastrarDispositivoScreenState();
}

class _CadastrarDispositivoScreenState extends State<CadastrarDispositivoScreen> {
  final SupabaseService _supabase = SupabaseService();
  final _nomeCtrl = TextEditingController();
  final _numSerieCtrl = TextEditingController();
  final _modeloDispCtrl = TextEditingController();
  final _modeloVeiculoCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _tempMinCtrl = TextEditingController();
  final _tempMaxCtrl = TextEditingController();
  final _humidadeCtrl = TextEditingController();
  final _sensibilidadeCtrl = TextEditingController();
  final _limiteVibracaoCtrl = TextEditingController();
  final _intervaloCtrl = TextEditingController();
  
  String? _selectedOperadorId;
  List<UsuarioModel> _operadores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAccess();
    _fetchOperadores();
  }

  Future<void> _fetchOperadores() async {
    try {
      final res = await Supabase.instance.client.from('Usuarios').select();
      final allUsers = (res as List).map((e) => UsuarioModel.fromJson(e)).toList();
      if (mounted) {
        setState(() {
          _operadores = allUsers.where((u) => u.cargo?.toLowerCase() == 'operador').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cadastrar() async {
    HapticFeedback.lightImpact();
    if (_nomeCtrl.text.isEmpty || _numSerieCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Preencha pelo menos o Nome e Número de Série!', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      );
      return;
    }

    try {
      await Supabase.instance.client.from('Dispositivos').insert({
        'nome_dispositivo': _nomeCtrl.text,
        'id_operador': _selectedOperadorId,
        'temperatura_minima': double.tryParse(_tempMinCtrl.text),
        'temperatura_maxima': double.tryParse(_tempMaxCtrl.text),
        'umidade_maxima': double.tryParse(_humidadeCtrl.text),
      });

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Dispositivo cadastrado com sucesso!', style: TextStyle(color: Colors.white)),
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
              
              // 4. ÁREA DO FORMULÁRIO 1 (Dados do dispositivo)
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
                    CustomFormInput(label: 'Nome do dispositivo', controller: _nomeCtrl),
                    const SizedBox(height: 12),
                    CustomFormInput(label: 'Número de série', controller: _numSerieCtrl),
                    const SizedBox(height: 12),
                    CustomFormInput(label: 'Modelo do dispositivo', controller: _modeloDispCtrl),
                  ],
                ),
              ),

              // 5. ÁREA DO FORMULÁRIO 2 (Dados do veiculo)
              const SizedBox(height: 16),
              const Text(
                'Dados do veiculo',
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
                    const Text(
                      'Operador responsável:',
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
                          value: _selectedOperadorId,
                          hint: Text(_isLoading ? 'Carregando...' : 'Selecione...'),
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFC23147)),
                          items: _operadores
                              .map((u) => DropdownMenuItem(value: u.id, child: Text(u.nome ?? 'Sem nome')))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedOperadorId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CustomFormInput(label: 'Modelo do veículo', controller: _modeloVeiculoCtrl),
                    const SizedBox(height: 12),
                    CustomFormInput(label: 'Placa do veiculo', controller: _placaCtrl),
                  ],
                ),
              ),

              // 6. ÁREA DO FORMULÁRIO 3 (Configurações dos sensores)
              const SizedBox(height: 16),
              const Text(
                'Configurações dos sensores',
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
                clipBehavior: Clip.antiAlias, // Previne que o botão saia pelas bordas de baixo
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        children: [
                          CustomFormInput(label: 'Temperatura mínima', controller: _tempMinCtrl),
                          const SizedBox(height: 12),
                          CustomFormInput(label: 'Temperatura maxima', controller: _tempMaxCtrl),
                          const SizedBox(height: 12),
                          CustomFormInput(label: 'Umidade máxima', controller: _humidadeCtrl),
                          const SizedBox(height: 12),
                          CustomFormInput(label: 'Sensibilidade do sensor de vibração', controller: _sensibilidadeCtrl),
                          const SizedBox(height: 12),
                          CustomFormInput(label: 'Limite de vibração', controller: _limiteVibracaoCtrl),
                          const SizedBox(height: 12),
                          CustomFormInput(label: 'Intervalo entre coletas de dados', controller: _intervaloCtrl),
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
              
              const SizedBox(height: 40), // Espaçamento final
            ],
          ),
        ),
        ),
      ),
    );
  }
}

// 3. COMPONENTE DE INPUT REUTILIZÁVEL
class CustomFormInput extends StatelessWidget {
  final String label;
  final TextEditingController? controller;

  const CustomFormInput({
    super.key,
    required this.label,
    this.controller,
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
            decoration: const InputDecoration.collapsed(
              hintText: '', // Sem placeholder, fundo branco puro
            ),
          ),
        ),
      ],
    );
  }
}
