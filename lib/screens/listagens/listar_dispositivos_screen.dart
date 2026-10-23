import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';
import '../../widgets/animated_components.dart';
import '../../widgets/watermark_background.dart';
import '../../services/admin_context_service.dart';
import '../../widgets/confirmation_dialog.dart';

class ListarDispositivosScreen extends StatefulWidget {
  final SupabaseService? supabaseService;
  const ListarDispositivosScreen({super.key, this.supabaseService});

  @override
  State<ListarDispositivosScreen> createState() => _ListarDispositivosScreenState();
}

class _ListarDispositivosScreenState extends State<ListarDispositivosScreen> {
  late final SupabaseService _supabase = widget.supabaseService ?? SupabaseService();
  bool _isLoading = true;
  List<DispositivoModel> _dispositivos = [];
  Map<String, String> _operadoresNomes = {};
  Map<String, String> _frotasNomes = {};
  Map<String, FrotaModel> _frotasById = {};
  String _userRole = '';
  FrotaModel? _currentFrota;
  bool _hasFleets = true;

  @override
  void initState() {
    super.initState();
    _checkAccess();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final currentUserId = _supabase.currentUser?.id;
      if (currentUserId != null) {
        final perfil = await _supabase.getUsuarioPerfil(currentUserId);
        if (perfil != null) _userRole = perfil.role;
      }

      if (!mounted) return;
      final routeArg = ModalRoute.of(context)?.settings.arguments;
      if (routeArg is FrotaModel) {
        _currentFrota = routeArg;
      } else if (routeArg is String) {
        final frotas = await _supabase.getFrotas();
        _currentFrota = frotas.where((f) => f.id == routeArg).firstOrNull;
      } else if (_userRole == 'admin' && AdminContextService().selectedFrota != null) {
        _currentFrota = AdminContextService().selectedFrota;
      }

      List<DispositivoModel> dispositivos = [];
      List<FrotaModel> frotasList = [];
      try {
        frotasList = await _supabase.getFrotas();
      } catch (_) {}
      final frotasMap = {for (var f in frotasList) f.id: f.nome ?? 'Sem nome'};
      final frotasObjMap = {for (var f in frotasList) f.id: f};

      if (_userRole == 'admin') {
        _hasFleets = frotasList.isNotEmpty;
        if (_currentFrota != null) {
          AdminContextService().setFrota(_currentFrota);
          AdminContextService().clearVehicle();
          dispositivos = await _supabase.getDispositivosByFrota(_currentFrota!.id);
        } else {
          dispositivos = await _supabase.getDispositivos();
        }
      } else if (_userRole == 'gerente') {
        if (_currentFrota != null) {
          _hasFleets = true;
          dispositivos = await _supabase.getDispositivosByFrota(_currentFrota!.id);
        } else if (currentUserId != null) {
          final frotas = await _supabase.getFrotasByGerente(currentUserId);
          _hasFleets = frotas.isNotEmpty;
          for (var f in frotas) {
            final fDevs = await _supabase.getDispositivosByFrota(f.id);
            dispositivos.addAll(fDevs);
          }
        }
      } else {
        if (currentUserId != null) {
          dispositivos = await _supabase.getDispositivosByOperador(currentUserId);
        }
      }

      Map<String, String> opsMap = {};
      for (var d in dispositivos) {
        if (d.idOperador != null) {
          if (!opsMap.containsKey(d.idOperador)) {
            final op = await _supabase.getUsuarioPerfil(d.idOperador!);
            opsMap[d.idOperador!] = op?.nome ?? 'Sem Operador';
          }
        }
      }

      if (mounted) {
        setState(() {
          _dispositivos = dispositivos;
          _operadoresNomes = opsMap;
          _frotasNomes = frotasMap;
          _frotasById = frotasObjMap;
          _userRole = _userRole;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar dispositivos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAccess() async {
    final currentUserId = _supabase.currentUser?.id;
    if (currentUserId == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final perfil = await _supabase.getUsuarioPerfil(currentUserId);
    final role = perfil?.role ?? '';
    if (mounted && role.isNotEmpty) {
      setState(() => _userRole = role);
    }
    
    List<String> allowedRoles = ['admin', 'gerente'];

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
    final bool isGerenteEmpty = _userRole == 'gerente' && (_frotasNomes.isEmpty || _dispositivos.isEmpty);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF2E0),
      extendBody: true,
      
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: null,
        isDisabled: isGerenteEmpty,
        hasDevicesOverride: _dispositivos.isNotEmpty,
        hasFleetsOverride: _currentFrota != null || _frotasNomes.isNotEmpty,
        userRoleOverride: _userRole.isNotEmpty ? _userRole : null,
      ),
      body: WatermarkBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0),
            child: Column(
              children: [
                // 1. CABEÇALHO
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _currentFrota != null ? 'Dispositivos — ${_currentFrota!.nome ?? "Frota"}' : 'Listar dispositivos',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFC23147),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC23147),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        (_userRole == 'admin' || _userRole == 'adm') ? 'ADM' : _userRole.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Builder(
                      builder: (ctx) => GestureDetector(
                        onTap: () => CustomEndDrawer.showMenu(
                          context,
                          userRoleOverride: _userRole.isNotEmpty ? _userRole : null,
                          hasFleetsOverride: _userRole == 'operador' ? null : _hasFleets,
                          hasDevicesOverride: _dispositivos.isNotEmpty,
                        ),
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
                if (_currentFrota != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8E569),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.filter_alt_outlined, size: 14, color: Color(0xFF333333)),
                          const SizedBox(width: 4),
                          Text(
                            'Frota: ${_currentFrota!.nome ?? "Frota"}',
                            style: const TextStyle(
                              color: Color(0xFF333333),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              AdminContextService().clearFrota();
                              setState(() => _currentFrota = null);
                              _fetchData();
                            },
                            child: const Row(
                              children: [
                                Icon(Icons.close, size: 14, color: Color(0xFFC23147)),
                                SizedBox(width: 2),
                                Text(
                                  'Ver todos',
                                  style: TextStyle(
                                    color: Color(0xFFC23147),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // 2. LISTA DE DISPOSITIVOS
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFFC23147),
                    onRefresh: () async {
                      HapticFeedback.lightImpact();
                      await _fetchData();
                    },
                    child: _isLoading
                        ? ListView.builder(
                            itemCount: 4,
                            itemBuilder: (context, index) => const Padding(
                              padding: EdgeInsets.only(bottom: 16.0, right: 12),
                              child: ShimmerEffect(
                                width: double.infinity,
                                height: 92,
                                borderRadius: 12,
                              ),
                            ),
                          )
                        : _dispositivos.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.devices_other_outlined, size: 64, color: Color(0xFFC23147)),
                                      const SizedBox(height: 16),
                                      Text(
                                        _currentFrota != null
                                            ? 'Nenhum dispositivo encontrado nesta frota.'
                                            : 'Nenhum dispositivo cadastrado no sistema.',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _userRole.toLowerCase() == 'admin' || _userRole.toLowerCase() == 'adm'
                                            ? 'Cadastre um dispositivo para começar a monitorar seus veículos.'
                                            : 'Aguarde o cadastro de dispositivos pelo Administrador.',
                                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 20),
                                      if (_userRole.toLowerCase() == 'admin' || _userRole.toLowerCase() == 'adm')
                                        ElevatedButton.icon(
                                          onPressed: () => Navigator.pushNamed(context, '/cadastrar-dispositivo'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFC23147),
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          icon: const Icon(Icons.add_box_outlined, color: Colors.white, size: 18),
                                          label: const Text('Cadastrar dispositivo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        )
                                      else
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            HapticFeedback.lightImpact();
                                            _fetchData();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFC23147),
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                                          label: const Text('Atualizar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 100),
                                itemCount: _dispositivos.length,
                                itemBuilder: (context, index) {
                                  final device = _dispositivos[index];
                                  final opName = device.idOperador != null ? _operadoresNomes[device.idOperador] ?? 'Sem Operador' : 'Sem Operador';
                                  final frotaName = device.idFrota != null ? _frotasNomes[device.idFrota] : null;

                                  return AnimatedListItem(
                                    index: index,
                                    child: Dismissible(
                                      key: Key(device.id),
                                      direction: DismissDirection.horizontal,
                                      confirmDismiss: (direction) async {
                                        HapticFeedback.mediumImpact();
                                        if (direction == DismissDirection.endToStart) {
                                          return await _showDeleteDialog(context, device);
                                        } else {
                                          if (_userRole == 'admin' || _userRole == 'adm') {
                                            final res = await Navigator.pushNamed(context, '/editar-dispositivo', arguments: device);
                                            if (res == true || mounted) _fetchData();
                                          }
                                          return false;
                                        }
                                      },
                                      background: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        margin: const EdgeInsets.only(bottom: 16, right: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8DB600),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.edit, color: Colors.white),
                                      ),
                                      secondaryBackground: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        margin: const EdgeInsets.only(bottom: 16, right: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFC23147),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.delete, color: Colors.white),
                                      ),
                                      child: DeviceCard(
                                        device: device,
                                        operatorName: opName,
                                        frotaName: frotaName,
                                        onEdit: (_userRole == 'admin' || _userRole == 'adm')
                                            ? () async {
                                                HapticFeedback.lightImpact();
                                                final res = await Navigator.pushNamed(context, '/editar-dispositivo', arguments: device);
                                                if (res == true || mounted) _fetchData();
                                              }
                                            : null,
                                        onDelete: () {
                                          HapticFeedback.mediumImpact();
                                          _showDeleteDialog(context, device);
                                        },
                                        onTap: () {
                                          if (_userRole == 'admin') {
                                            final devFrota = _currentFrota ?? (device.idFrota != null ? _frotasById[device.idFrota] : null);
                                            AdminContextService().setDevice(device, frota: devFrota);
                                          }
                                          Navigator.pushNamed(context, '/dashboard-veiculo', arguments: device);
                                        },
                                      ),
                                    ),
                                  );
                                },
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

  Future<bool?> _showDeleteDialog(BuildContext context, DispositivoModel device) async {
    final confirmed = await showDeleteConfirmationModal(
      context: context,
      title: 'Excluir Dispositivo',
      itemName: device.nomeDispositivo ?? device.modeloVeiculo ?? 'Dispositivo',
      itemDetail: device.placaVeiculo != null && device.placaVeiculo!.isNotEmpty
          ? 'Placa: ${device.placaVeiculo}'
          : (device.modeloVeiculo != null ? 'Modelo: ${device.modeloVeiculo}' : null),
      itemIcon: Icons.directions_car_outlined,
    );

    if (confirmed == true && context.mounted) {
      try {
        await _supabase.deleteDispositivo(device.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dispositivo "${device.nomeDispositivo ?? "Dispositivo"}" removido com sucesso!', style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          );
          _fetchData();
        }
        return true;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e', style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          );
        }
        return false;
      }
    }
    return false;
  }
}

class DeviceCard extends StatelessWidget {
  final DispositivoModel device;
  final String operatorName;
  final String? frotaName;
  final String cargoType;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.device,
    required this.operatorName,
    this.frotaName,
    this.cargoType = 'Carga Padrão',
    this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // Sombra difusa colorida
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Hero(
                  tag: 'device_icon_${device.id}',
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC8E569),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: Color(0xFF333333),
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'device_title_${device.id}',
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            device.nomeDispositivo ?? 'Sem Nome',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (device.modeloVeiculo != null && device.modeloVeiculo!.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.directions_car, size: 14, color: Color(0xFFC23147)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${device.modeloVeiculo}${device.placaVeiculo != null && device.placaVeiculo!.isNotEmpty ? " • ${device.placaVeiculo}" : ""}',
                                style: const TextStyle(
                                  color: Color(0xFF333333),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        'Operador: $operatorName',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (frotaName != null && frotaName!.isNotEmpty)
                        Text(
                          'Frota: $frotaName',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onEdit != null) ...[
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFF4A4A4A), size: 20),
                            onPressed: onEdit,
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 8),
                        ],
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFC23147), size: 20),
                          onPressed: onDelete,
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC23147),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 14, color: Colors.white),
                      label: const Text(
                        'Ver mais',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
