import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../repository/app_repository.dart';
import '../../models/models.dart';
import '../../widgets/animated_components.dart';
import '../../widgets/watermark_background.dart';

class ListarDispositivosScreen extends StatefulWidget {
  const ListarDispositivosScreen({super.key});

  @override
  State<ListarDispositivosScreen> createState() => _ListarDispositivosScreenState();
}

class _ListarDispositivosScreenState extends State<ListarDispositivosScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _simulateLoading();
  }

  Future<void> _simulateLoading() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _isLoading = false);
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
            child: ListenableBuilder(
              listenable: AppRepository.instance,
              builder: (context, child) {
                final devices = AppRepository.instance.devices;

                return Column(
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
                            AppRepository.instance.currentUser?.role.toUpperCase() ?? 'ADM',
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
                                'nutriguard1/web/icons/1.png',
                                errorBuilder: (ctx, error, stackTrace) =>
                                    const Icon(Icons.apple, color: Color(0xFFC23147), size: 32),
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
                          await _simulateLoading();
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
                                itemCount: devices.length,
                                itemBuilder: (context, index) {
                                  final device = devices[index];
                                  final op = AppRepository.instance.getUserById(device.operadorId);

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
                                        operatorName: op?.nome ?? 'Sem operador',
                                        cargoType: device.carga ?? 'N/A',
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context, Device device) {
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
                content: Text('Tem certeza que deseja remover ${device.nome}?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                  ),
                  TextButton(
                    onPressed: () {
                      AppRepository.instance.removeDevice(device.id);
                      Navigator.pop(context, true);
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Removido com sucesso', style: TextStyle(color: Colors.white)),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      );
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
  final Device device;
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
                      device.nome,
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
