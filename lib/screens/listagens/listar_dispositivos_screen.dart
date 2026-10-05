import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';
import '../../widgets/animated_components.dart';
import '../../widgets/watermark_background.dart';

class ListarDispositivosScreen extends StatefulWidget {
  const ListarDispositivosScreen({super.key});

  @override
  State<ListarDispositivosScreen> createState() => _ListarDispositivosScreenState();
}

class _ListarDispositivosScreenState extends State<ListarDispositivosScreen> {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = true;
  List<DispositivoModel> _dispositivos = [];
  Map<String, String> _operadoresNomes = {};
  String _userRole = 'ADM';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final dispositivos = await _supabase.getDispositivos();
      
      final currentUserId = _supabase.currentUser?.id;
      if (currentUserId != null) {
        final perfil = await _supabase.getUsuarioPerfil(currentUserId);
        if (perfil != null) _userRole = perfil.cargo ?? 'ADM';
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
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar dispositivos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF2E0),
      extendBody: true,
      
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 2),
      body: WatermarkBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0),
            child: Column(
              children: [
                // 1. CABEÇALHO
                Row(
                  children: [
                    const Text(
                      'Dispositivos',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFC23147),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC23147),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _userRole.toUpperCase(),
                        style: const TextStyle(
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
                const SizedBox(height: 24),

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
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: _dispositivos.length,
                            itemBuilder: (context, index) {
                              final device = _dispositivos[index];
                              final opName = device.idOperador != null ? _operadoresNomes[device.idOperador] ?? 'Sem Operador' : 'Sem Operador';

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
                                      // Edit Action
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Redirecionando para edição...'),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                        ),
                                      );
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
                                    cargoType: 'Carga Padrão', // no property in model
                                    onDelete: () {
                                      HapticFeedback.mediumImpact();
                                      _showDeleteDialog(context, device);
                                    },
                                    onTap: () {},
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

  Future<bool?> _showDeleteDialog(BuildContext context, DispositivoModel device) {
    return showGeneralDialog<bool>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'Delete',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return Stack(
          children: [
            FadeTransition(
              opacity: animation,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                child: Container(color: const Color(0x33000000)),
              ),
            ),
            ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              child: AlertDialog(
                title: const Text('Excluir Dispositivo'),
                content: Text('Tem certeza que deseja remover ${device.nomeDispositivo}?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context, true);
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Removido com sucesso (simulado)', style: TextStyle(color: Colors.white)),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      );
                      _fetchData();
                    },
                    child: const Text('Excluir', style: TextStyle(color: Color(0xFFC23147))),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class DeviceCard extends StatelessWidget {
  final DispositivoModel device;
  final String operatorName;
  final String cargoType;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.device,
    required this.operatorName,
    required this.cargoType,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 12),
      padding: const EdgeInsets.all(16),
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
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Operador: $operatorName',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Carga: $cargoType',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
