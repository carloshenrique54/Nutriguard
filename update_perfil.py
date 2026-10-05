import os

base_dir = r"c:\Users\46612581859\Desktop\nutriguard sem banco\nutriguard1\lib"

files = {
    "screens/perfil/perfil_screen.dart": """import 'package:flutter/material.dart';

enum UserRole { adm, gerente, operador }

class PerfilScreen extends StatelessWidget {
  final UserRole role;

  const PerfilScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF2E0),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFFC8E569),
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavBtn(context, Icons.notifications_none, 'Alertas', false, '/alertas-frota'),
              _buildBottomNavBtn(context, Icons.description_outlined, 'Relatórios', false, '/relatorios-frota'),
              _buildBottomNavBtn(context, Icons.dashboard_rounded, 'Dashboard', true, '/dashboard-adm-frota'),
              _buildBottomNavBtn(context, Icons.access_time, 'Histórico', false, '/historico-frota'),
              _buildBottomNavBtn(context, Icons.location_on_outlined, 'GPS', false, '/gps'),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildProfileCard(),
              const SizedBox(height: 24),
              _buildActionButtons(),
              const SizedBox(height: 24),
              _buildListSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBtn(BuildContext context, IconData icon, String label, bool isActive, String route) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? const Color(0xFFC23147) : Colors.black87),
          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFFC23147) : Colors.black87,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String roleText = 'Operador';
    if (role == UserRole.adm) roleText = 'ADM';
    if (role == UserRole.gerente) roleText = 'Gerente';

    return Row(
      children: [
        const Text(
          'Perfil',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFFC23147),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFC23147),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            roleText,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 40,
          height: 40,
          child: Image.asset(
            'nutriguard1/web/icons/1.png',
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.apple,
              color: Color(0xFFC23147),
              size: 32,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFC23147),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: Icon(Icons.person_outline, size: 50, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sobre',
                    style: TextStyle(
                      color: Color(0xFFC23147),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildProfileInfoRow(Icons.person, 'João Silva'),
                  _buildProfileInfoRow(Icons.calendar_today, '01/01/1980'),
                  _buildProfileInfoRow(Icons.mail, 'joao@nutriguard.com'),
                  _buildProfileInfoRow(Icons.phone, '(11) 99999-9999'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFFE56B7A)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFE56B7A), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (role == UserRole.operador) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC23147),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Editar perfil', style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC23147),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Editar perfil', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC23147),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ver frotas', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildListSection() {
    String title = role == UserRole.operador ? 'Historico de viagens >' : 'Frota responsavel >';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFC8E569),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFFC23147), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Scrollbar track (visual placeholder)
              Container(
                width: 4,
                height: 250,
                margin: const EdgeInsets.only(right: 12, top: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
                alignment: Alignment.topCenter,
                child: Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC23147),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    return const VehicleCard();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class VehicleCard extends StatelessWidget {
  const VehicleCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9), // Cor verde clara
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_shipping, color: Colors.black54, size: 30),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Volvo FH 540',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'Operador: José Santos',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Carga monitorada', style: TextStyle(fontSize: 10, color: Colors.black54)),
              const Text('Legumes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC23147),
                  minimumSize: const Size(60, 24),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Ver mais', style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ],
          )
        ],
      ),
    );
  }
}
""",
    "screens/perfil/perfil_adm_screen.dart": """import 'package:flutter/material.dart';
import 'perfil_screen.dart';

class PerfilAdmScreen extends StatelessWidget {
  const PerfilAdmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PerfilScreen(role: UserRole.adm);
  }
}
""",
    "screens/perfil/perfil_gerente_screen.dart": """import 'package:flutter/material.dart';
import 'perfil_screen.dart';

class PerfilGerenteScreen extends StatelessWidget {
  const PerfilGerenteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PerfilScreen(role: UserRole.gerente);
  }
}
""",
    "screens/perfil/perfil_operador_screen.dart": """import 'package:flutter/material.dart';
import 'perfil_screen.dart';

class PerfilOperadorScreen extends StatelessWidget {
  const PerfilOperadorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PerfilScreen(role: UserRole.operador);
  }
}
"""
}

for path, content in files.items():
    full_path = os.path.join(base_dir, path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "w", encoding="utf-8") as f:
        f.write(content)

print(f"Updated {len(files)} files successfully in {base_dir}")
