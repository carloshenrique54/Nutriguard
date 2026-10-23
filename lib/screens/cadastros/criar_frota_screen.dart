import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../services/supabase_service.dart';
import '../../services/admin_context_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import '../../widgets/watermark_background.dart';

class VeiculoItem {
  final DispositivoModel device;
  final String operador;
  bool isSelected;

  VeiculoItem({required this.device, required this.operador, this.isSelected = false});
}

class CriarFrotaScreen extends StatefulWidget {
  final bool bypassAccessCheck;
  final List<UsuarioModel>? initialUsers;
  final List<FrotaModel>? initialFrotas;
  final List<DispositivoModel>? initialDispositivos;
  final FrotaModel? frotaToEdit;

  const CriarFrotaScreen({
    super.key,
    this.bypassAccessCheck = false,
    this.initialUsers,
    this.initialFrotas,
    this.initialDispositivos,
    this.frotaToEdit,
  });

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
  bool _isSubmitting = false;
  FrotaModel? _frotaToEdit;
  bool _hasInitializedRoute = false;

  bool get isEditing => _frotaToEdit != null;

  @override
  void initState() {
    super.initState();
    if (widget.frotaToEdit != null) {
      _frotaToEdit = widget.frotaToEdit;
      _nomeCtrl.text = _frotaToEdit!.nome ?? '';
      _selectedGerenteId = _frotaToEdit!.idGerente;
    }
    _checkAccess();
    _fetchData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitializedRoute) {
      _hasInitializedRoute = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (_frotaToEdit == null && args is FrotaModel) {
        _frotaToEdit = args;
        _nomeCtrl.text = _frotaToEdit!.nome ?? '';
        _selectedGerenteId = _frotaToEdit!.idGerente;
        _fetchData();
      }
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final dispositivos = widget.initialDispositivos ?? await _supabase.getDispositivos();
      final frotas = widget.initialFrotas ?? await _supabase.getFrotas();
      
      final List<UsuarioModel> allUsers;
      if (widget.initialUsers != null) {
        allUsers = widget.initialUsers!;
      } else {
        final res = await Supabase.instance.client.from('Usuarios').select();
        allUsers = (res as List).map((e) => UsuarioModel.fromJson(e)).toList();
      }
      
      // Identificar gerentes que já possuem frota vinculada (exceto a frota sendo editada)
      final gerentesComFrotaIds = frotas
          .where((f) => !isEditing || f.id != _frotaToEdit!.id)
          .map((f) => f.idGerente?.trim())
          .where((id) => id != null && id.isNotEmpty)
          .toSet();

      // Apenas gerentes que NÃO têm frota definida devem aparecer como opção
      _gerentes = allUsers
          .where((u) =>
              (u.role == 'gerente' || u.cargo?.trim().toLowerCase() == 'gerente') &&
              !gerentesComFrotaIds.contains(u.id.trim()))
          .toList();

      if (isEditing && _frotaToEdit?.idGerente != null) {
        final currentGerente = allUsers.where((u) => u.id == _frotaToEdit!.idGerente).firstOrNull;
        if (currentGerente != null && !_gerentes.any((g) => g.id == currentGerente.id)) {
          _gerentes.add(currentGerente);
        }
      }

      if (_selectedGerenteId != null && !_gerentes.any((g) => g.id.trim() == _selectedGerenteId!.trim())) {
        if (!isEditing) {
          _selectedGerenteId = null;
        }
      }

      if (!isEditing) {
        // Filtrar apenas veículos que NÃO têm frota vinculada
        final semFrota = dispositivos.where((d) => d.idFrota == null || d.idFrota!.isEmpty).toList();

        veiculos = semFrota.map((d) {
          final op = allUsers.firstWhere((u) => u.id == d.idOperador, orElse: () => UsuarioModel(id: ''));
          return VeiculoItem(
            device: d,
            operador: op.nome != null ? 'Operador: ${op.nome}' : 'Sem operador',
            isSelected: false,
          );
        }).toList();
      } else {
        // Modo de edição:
        // Exibe veículos desta frota (selecionados), sem frota, e de outras frotas (permitindo transferência)
        final frotasMap = {for (var f in frotas) f.id: f.nome ?? 'Outra frota'};

        veiculos = dispositivos.map((d) {
          final op = allUsers.firstWhere((u) => u.id == d.idOperador, orElse: () => UsuarioModel(id: ''));
          final bool isInThisFleet = d.idFrota == _frotaToEdit!.id;
          final String statusText;
          if (isInThisFleet) {
            statusText = ' (Nesta frota)';
          } else if (d.idFrota == null || d.idFrota!.isEmpty) {
            statusText = ' (Sem frota)';
          } else {
            statusText = ' (Frota: ${frotasMap[d.idFrota] ?? "Outra"})';
          }
          final opStr = op.nome != null ? 'Operador: ${op.nome}' : 'Sem operador';

          return VeiculoItem(
            device: d,
            operador: '$opStr$statusText',
            isSelected: isInThisFleet,
          );
        }).toList();

        veiculos.sort((a, b) {
          final aIn = a.device.idFrota == _frotaToEdit!.id ? 0 : (a.device.idFrota == null || a.device.idFrota!.isEmpty ? 1 : 2);
          final bIn = b.device.idFrota == _frotaToEdit!.id ? 0 : (b.device.idFrota == null || b.device.idFrota!.isEmpty ? 1 : 2);
          return aIn.compareTo(bIn);
        });
      }

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
    if (_isSubmitting) return;

    if (_nomeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Preencha o nome da frota!', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFFC23147),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      );
      return;
    }

    if (_selectedGerenteId == null || _selectedGerenteId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selecione o gerente responsável pela frota!', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFFC23147),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Verificação em tempo real: garante que o gerente não possui outra frota atribuída
      final frotasAtuais = await _supabase.getFrotas();
      final outroComGerente = frotasAtuais
          .where((f) => !isEditing || f.id != _frotaToEdit!.id)
          .any((f) => f.idGerente != null && f.idGerente!.trim() == _selectedGerenteId!.trim());

      if (outroComGerente) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Este gerente já possui uma frota vinculada! Selecione outro gerente.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFC23147),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final selectedDevices = veiculos.where((v) => v.isSelected).map((v) => v.device.id).toList();

      if (isEditing) {
        final updatedFrota = await _supabase.updateFrota(
          id: _frotaToEdit!.id,
          nome: _nomeCtrl.text.trim(),
          idGerente: _selectedGerenteId,
          selectedDeviceIds: selectedDevices,
        );

        if (AdminContextService().selectedFrota?.id == _frotaToEdit!.id) {
          AdminContextService().setFrota(updatedFrota);
        }

        HapticFeedback.mediumImpact();
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Frota atualizada com sucesso!', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        );

        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          Navigator.pushReplacementNamed(context, '/listar-frotas');
        }
      } else {
        final response = await Supabase.instance.client.from('Frotas').insert({
          'nome': _nomeCtrl.text.trim(),
          'id_gerente': _selectedGerenteId,
        }).select().single();
        
        final newFrota = FrotaModel.fromJson(response);
        final newFrotaId = newFrota.id;

        // Atualizar o id_frota nos dispositivos selecionados (se houver algum)
        for (var devId in selectedDevices) {
          await Supabase.instance.client.from('Dispositivos').update({'id_frota': newFrotaId}).eq('id', devId);
        }

        // Ativa imediatamente a nova frota no contexto administrativo
        AdminContextService().setFrota(newFrota);
        AdminContextService().clearVehicle();

        HapticFeedback.mediumImpact();
        _nomeCtrl.clear();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Frota criada com sucesso!', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        );
        Navigator.pushReplacementNamed(context, '/listar-frotas');
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
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. CABEÇALHO
              Row(
                children: [
                  Text(
                    isEditing ? 'Editar frota' : 'Criar frota',
                    style: const TextStyle(
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
                  const Row(
                    children: [
                      Text(
                        'Nome da frota',
                        style: TextStyle(
                          color: Color(0xFF333333),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '*',
                        style: TextStyle(
                          color: Color(0xFFC23147),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
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
              const Row(
                children: [
                  Text(
                    'Gerente responsável',
                    style: TextStyle(
                      color: Color(0xFF333333),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '*',
                    style: TextStyle(
                      color: Color(0xFFC23147),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    '(Obrigatório)',
                    style: TextStyle(
                      color: Color(0xFFC23147),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
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
                    value: _gerentes.any((u) => u.id == _selectedGerenteId) ? _selectedGerenteId : null,
                    hint: Text(
                      _isLoading
                          ? 'Carregando gerentes...'
                          : _gerentes.isEmpty
                              ? 'Nenhum gerente disponível sem frota'
                              : 'Selecione o gerente...',
                      style: TextStyle(
                        color: _gerentes.isEmpty ? Colors.grey.shade500 : Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFC23147)),
                    items: _gerentes
                        .map((u) => DropdownMenuItem(value: u.id, child: Text(u.nome ?? 'Sem nome')))
                        .toList(),
                    onChanged: (_isSubmitting || _gerentes.isEmpty)
                        ? null
                        : (val) {
                            setState(() => _selectedGerenteId = val);
                          },
                  ),
                ),
              ),

              // 4. CABEÇALHO DA LISTA DE VEÍCULOS
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Text(
                        'Selecionar veículos',
                        style: TextStyle(
                          color: Color(0xFF333333),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '(Opcional)',
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$selectedCount veículos',
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
                      : veiculos.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Text(
                                  isEditing
                                      ? 'Nenhum veículo disponível'
                                      : 'Nenhum veículo disponível sem frota',
                                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
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
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC23147),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    shadowColor: const Color(0x4DC23147),
                  ),
                  onPressed: _isSubmitting ? null : _criarFrota,
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
                            Icon(isEditing ? Icons.save_outlined : Icons.add_circle_outline, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              isEditing ? 'Salvar alterações' : 'Criar frota',
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
            ],
          ),
        ),
        ),
      ),
    );
  }
}
