import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomBottomNavBar extends StatefulWidget {
  final int? selectedIndex;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
  });

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isInit = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 75,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFC8E569),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background layout for spacing
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildNavItem(context, 0, Icons.notifications_none, 'Alertas', '/alertas-frota'),
              _buildNavItem(context, 1, Icons.description_outlined, 'Relatórios', '/relatorios-frota'),
              _buildNavItem(context, 2, Icons.dashboard_rounded, 'Dashboard', '/dashboard-adm-frota'),
              _buildNavItem(context, 3, Icons.access_time, 'Histórico', '/historico-frota'),
              _buildNavItem(context, 4, Icons.location_on_outlined, 'GPS', '/gps'),
            ],
          ),
          
          // Animated Bubble
          if (widget.selectedIndex != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              bottom: _isInit ? 20 : 0,
              left: _calculateLeftPosition(context, widget.selectedIndex!),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFC23147),
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4DC23147),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _getIconForIndex(widget.selectedIndex!),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _calculateLeftPosition(BuildContext context, int index) {
    final width = MediaQuery.of(context).size.width;
    final itemWidth = width / 5;
    // Calculate center of the item block, then subtract half the bubble width
    return (itemWidth * index) + (itemWidth / 2) - 28;
  }

  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0: return Icons.notifications_none;
      case 1: return Icons.description_outlined;
      case 2: return Icons.dashboard_rounded;
      case 3: return Icons.access_time;
      case 4: return Icons.location_on_outlined;
      default: return Icons.dashboard_rounded;
    }
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label, String routeName) {
    final bool isActive = widget.selectedIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (!isActive) {
          Navigator.pushReplacementNamed(context, routeName);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 5,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isActive ? 0.0 : 1.0, // Hide background icon when active bubble is over it
                child: Icon(icon, color: Colors.black87, size: 24),
              ),
              const SizedBox(height: 4),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isActive ? 0.0 : 1.0,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
