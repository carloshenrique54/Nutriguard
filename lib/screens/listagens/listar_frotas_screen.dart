import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_end_drawer.dart';
import '../../repository/app_repository.dart';
import '../../models/models.dart';
import '../../widgets/animated_components.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/watermark_background.dart';

class ListarFrotasScreen extends StatefulWidget {
  const ListarFrotasScreen({super.key});

  @override
  State<ListarFrotasScreen> createState() => _ListarFrotasScreenState();
}

class _ListarFrotasScreenState extends State<ListarFrotasScreen> {
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
                final fleets = AppRepository.instance.fleets;

                return Column(
                  children: [
                    // 1. CABEÇALHO
                    Row(
                      children: [
                        const Text(
                          'Frotas',
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

                    // 2. LISTA DE Frotas
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
                                    height: 120,
                                    borderRadius: 12,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 100),
                                itemCount: fleets.length,
                                itemBuilder: (context, index) {
                                  final fleet = fleets[index];
                                  final gerente = AppRepository.instance.getUserById(fleet.gerenteId);
                                  final deviceCount = fleet.deviceIds.length;

                                  return AnimatedListItem(
                                    index: index,
                                    child: Dismissible(
                                      key: Key(fleet.id),
                                      direction: DismissDirection.horizontal,
                                      confirmDismiss: (direction) async {
                                        HapticFeedback.mediumImpact();
                                        if (direction == DismissDirection.endToStart) {
                                          return await _showDeleteDialog(context, fleet);
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
                                      child: FleetCard(
                                        fleet: fleet,
                                        gerenteName: gerente?.nome ?? 'Sem Gerente',
                                        deviceCount: deviceCount,
                                        onDelete: () {
                                          HapticFeedback.mediumImpact();
                                          _showDeleteDialog(context, fleet);
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

  Future<bool?> _showDeleteDialog(BuildContext context, Fleet fleet) {
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
                title: const Text('Excluir Frota'),
                content: Text('Tem certeza que deseja remover ${fleet.nome}?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                  ),
                  TextButton(
                    onPressed: () {
                      AppRepository.instance.removeFleet(fleet.id);
                      Navigator.pop(context, true);
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Removida com sucesso', style: TextStyle(color: Colors.white)),
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

class FleetCard extends StatelessWidget {
  final Fleet fleet;
  final String gerenteName;
  final int deviceCount;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const FleetCard({
    super.key,
    required this.fleet,
    required this.gerenteName,
    required this.deviceCount,
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
            color: Color(0x0D000000), // Sombra muito difusa
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Hero(
            tag: 'fleet_icon_${fleet.id}',
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFC8E569),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.fire_truck_outlined,
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
                  tag: 'fleet_title_${fleet.id}',
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      fleet.nome,
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
                  'Gerente: $gerenteName',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFC23147)),
                onPressed: onDelete,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 4),
              Text(
                'Veículos na frota',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 10,
                ),
                textAlign: TextAlign.right,
              ),
              AnimatedCounterText(
                value: deviceCount,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: const Color(0xFFC23147),
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      'Ver mais',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
