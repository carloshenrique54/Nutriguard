import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import '../../widgets/animated_components.dart';
import '../../widgets/watermark_background.dart';

class VeiculoItem {
  final DispositivoModel device;
  final String operador;
  bool isSelected;

  VeiculoItem({required this.device, required this.operador, this.isSelected = false});
}

class CriarFrotaScreen extends StatefulWidget {
  const CriarFrotaScreen({super.key});

  @override
  State<CriarFrotaScreen> createState() => _CriarFrotaScreenState();
}

class _CriarFrotaScreenState extends State<CriarFrotaScreen> {
  final _nomeCtrl = TextEditingController();
  final SupabaseService _supabase = SupabaseService();
  String? _selectedGerenteId;
  List<VeiculoItem> veiculos = [];
  List<UsuarioModel> _gerentes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final dispositivos = await _supabase.getDispositivos();
      
      // Obter todos os usuários (necessário filtrar gerentes e operadores localmente ou via API)
      final res = await Supabase.instance.client.from('Usuarios').select();
      final allUsers = (res as List).map((e) => UsuarioModel.fromJson(e)).toList();
      
      _gerentes = allUsers.where((u) => u.cargo?.toLowerCase() == 'gerente').toList();

      veiculos = dispositivos.map((d) {
        final op = allUsers.firstWhere((u) => u.id == d.idOperador, orElse: () => UsuarioModel(id: ''));
        return VeiculoItem(
          device: d,
          operador: op.nome != null ? 'Operador: ${op.nome}' : 'Sem operador',
          isSelected: false,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar dados: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get selectedCount => veiculos.where((v) => v.isSelected).length;

  void _criarFrota() async {
    HapticFeedback.lightImpact();
    if (_nomeCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Preencha o nome da frota!', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      );
      return;
    }

    // Insert new frota
    try {
      final response = await Supabase.instance.client.from('Frotas').insert({
        'nome': _nomeCtrl.text,
        'id_gerente': _selectedGerenteId,
      }).select().single();
      
      final newFrotaId = response['id'];

      // Atualizar o id_frota nos dispositivos selecionados
      final selectedDevices = veiculos.where((v) => v.isSelected).map((v) => v.device.id).toList();
      for (var devId in selectedDevices) {
        await Supabase.instance.client.from('Dispositivos').update({'id_frota': newFrotaId}).eq('id', devId);
      }

      HapticFeedback.mediumImpact();
      _nomeCtrl.clear();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Frota criada com sucesso!', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao criar frota: $e', style: const TextStyle(color: Colors.white)),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF2E0),
      
      body: WatermarkBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. CABEÇALHO
              Row(
                children: [
                  const Text(
                    'Criar frota',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC23147),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
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
                  const Spacer(),
                  Builder(
                    builder: (ctx) => GestureDetector(
                      onTap: () => CustomEndDrawer.showMenu(context),
                      child: SizedBox(
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
              
              // 2. SECÇÃO NOME DA FROTA E VOLTAR
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text(
                    'Nome da frota',
                    style: TextStyle(
                      color: Color(0xFF333333),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: const Color(0xFFC23147),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Voltar',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _nomeCtrl,
                  decoration: const InputDecoration.collapsed(
                    hintText: 'Ex: Frota Sul',
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ),

              // 3. SECÇÃO GERENTE RESPONSÁVEL
              const SizedBox(height: 16),
              const Text(
                'Gerente responsável',
                style: TextStyle(
                  color: Color(0xFF333333),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedGerenteId,
                    hint: const Text('Selecione...'),
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFC23147)),
                    items: _gerentes
                        .map((u) => DropdownMenuItem(value: u.id, child: Text(u.nome ?? 'Sem nome')))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedGerenteId = val);
                    },
                  ),
                ),
              ),

              // 4. CABEÇALHO DA LISTA DE VEÍCULOS
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Selecionar veiculos',
                    style: TextStyle(
                      color: Color(0xFF333333),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$selectedCount veiculos',
                    style: const TextStyle(
                      color: Color(0xFF8DC63F), // Verde Claro
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // 5. LISTA DE VEÍCULOS (Expanded)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      scrollbarTheme: ScrollbarThemeData(
                        thumbColor: WidgetStateProperty.all(const Color(0xFFC23147)),
                        trackColor: WidgetStateProperty.all(Colors.white),
                        trackBorderColor: WidgetStateProperty.all(Colors.transparent),
                      ),
                    ),
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFC23147)))
                      : Scrollbar(
                      thickness: 6,
                      radius: const Radius.circular(3),
                      thumbVisibility: true,
                      trackVisibility: true,
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: veiculos.length,
                        separatorBuilder: (context, index) => Divider(
                          color: Colors.grey.shade200,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final veiculo = veiculos[index];
                          return InkWell(
                            onTap: () {
                              setState(() {
                                veiculo.isSelected = !veiculo.isSelected;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  // Checkbox Customizada
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: veiculo.isSelected
                                          ? const Color(0xFFC8E569)
                                          : const Color(0xFF333333),
                                      borderRadius: BorderRadius.circular(4),
                                      border: veiculo.isSelected 
                                          ? Border.all(color: Colors.black, width: 2) 
                                          : null,
                                    ),
                                    child: veiculo.isSelected
                                        ? const Icon(Icons.check, color: Colors.black, size: 16)
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  const Icon(
                                    Icons.local_shipping_outlined,
                                    color: Color(0xFFC23147),
                                    size: 28,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          veiculo.device.nomeDispositivo ?? 'Sem Nome',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          veiculo.operador,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              
              // 6. BOTÃO CRIAR FROTA
              const SizedBox(height: 16),
              MorphingSubmitButton(
                text: 'Criar frota',
                onPressed: _criarFrota,
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
