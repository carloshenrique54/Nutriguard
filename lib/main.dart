import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/cadastro_screen.dart';
import 'screens/dashboard/dashboard_vazio_screen.dart';
import 'screens/dashboard/dashboard_adm_frota_screen.dart';
import 'screens/dashboard/dashboard_veiculo_screen.dart';
import 'screens/dashboard/dashboard_operador_screen.dart';
import 'screens/alertas/alertas_screen.dart';
import 'screens/relatorios/relatorios_screen.dart';
import 'screens/historico/historico_screen.dart';
import 'screens/gps/gps_screen.dart';
import 'screens/perfil/perfil_adm_screen.dart';
import 'screens/perfil/perfil_gerente_screen.dart';
import 'screens/perfil/perfil_operador_screen.dart';
import 'screens/cadastros/cadastrar_funcionario_screen.dart';
import 'screens/cadastros/cadastrar_dispositivo_screen.dart';
import 'screens/cadastros/criar_frota_screen.dart';
import 'screens/listagens/listar_dispositivos_screen.dart';
import 'screens/listagens/listar_operadores_screen.dart';
import 'screens/listagens/listar_frotas_screen.dart';
import 'screens/acoes/iniciar_viagem_screen.dart';
import 'screens/acoes/configuracoes_screen.dart';

void main() {
  runApp(const NutriGuardApp());
}

class NutriGuardApp extends StatelessWidget {
  const NutriGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriGuard',
      initialRoute: '/splash',
      routes: {
        // Splash
        '/splash': (context) => const SplashScreen(),

        // Autenticação
        '/': (context) => const LoginScreen(),
        '/login': (context) => const LoginScreen(),
        '/cadastro': (context) => const CadastroScreen(),

        // Dashboards
        '/dashboard-vazio': (context) => const DashboardVazioScreen(),
        '/dashboard-adm-frota': (context) => const DashboardAdmFrotaScreen(),
        '/dashboard-veiculo': (context) => const DashboardVeiculoScreen(),
        '/dashboard-operador': (context) => const DashboardOperadorScreen(),

        // Alertas
        '/alertas-frota': (context) => const AlertasScreen(
              userRole: 'ADM',
              viewContext: 'Vendo: Frota Sul (6 veículos)',
              hasAlerts: true,
            ),
        '/alertas-veiculo': (context) => const AlertasScreen(
              userRole: 'Operador',
              viewContext: 'Vendo: Volvo FH 540',
              hasAlerts: false,
            ),

        // Relatórios
        '/relatorios-frota': (context) => const RelatoriosScreen(userRole: 'ADM'),
        '/relatorios-veiculo': (context) => const RelatoriosScreen(userRole: 'Operador'),

        // Histórico
        '/historico-frota': (context) => const HistoricoScreen(userRole: 'ADM'),
        '/historico-veiculo': (context) => const HistoricoScreen(userRole: 'Operador'),

        // GPS
        '/gps': (context) => const GpsScreen(),

        // Perfis
        '/perfil': (context) => const PerfilAdmScreen(),
        '/perfil-adm': (context) => const PerfilAdmScreen(),
        '/perfil-gerente': (context) => const PerfilGerenteScreen(),
        '/perfil-operador': (context) => const PerfilOperadorScreen(),

        // Cadastros e Listagens
        '/cadastrar-funcionario': (context) =>
            const CadastrarFuncionarioScreen(),
        '/cadastrar-dispositivo': (context) =>
            const CadastrarDispositivoScreen(),
        '/criar-frota': (context) => const CriarFrotaScreen(),
        '/listar-dispositivos': (context) => const ListarDispositivosScreen(),
        '/listar-gerentes': (context) => const ListarOperadoresScreen(title: 'Gerentes'),
        '/listar-operadores': (context) => const ListarOperadoresScreen(title: 'Operadores'),
        '/iniciar-viagem': (context) => const IniciarViagemScreen(),

        // Rotas extras solicitadas no Drawer
        '/listar-frotas': (context) => const ListarFrotasScreen(),
        '/configuracoes': (context) => const ConfiguracoesScreen(),
      },
    );
  }
}
