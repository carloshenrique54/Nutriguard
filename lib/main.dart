import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/cadastro_screen.dart';
import 'screens/dashboard/dashboard_frota_screen.dart';
import 'screens/dashboard/dashboard_veiculo_screen.dart';
import 'screens/alertas/alertas_screen.dart';
import 'screens/relatorios/relatorios_screen.dart';
import 'screens/historico/historico_screen.dart';
import 'screens/gps/gps_screen.dart';
import 'screens/perfil/perfil_screen.dart';
import 'screens/cadastros/cadastrar_funcionario_screen.dart';
import 'screens/cadastros/cadastrar_dispositivo_screen.dart';
import 'screens/cadastros/criar_frota_screen.dart';
import 'screens/listagens/listar_dispositivos_screen.dart';
import 'screens/listagens/listar_operadores_screen.dart';
import 'screens/listagens/listar_frotas_screen.dart';
import 'screens/acoes/iniciar_viagem_screen.dart';
import 'screens/acoes/configuracoes_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://tlcsqlemhpxftatpivac.supabase.co',
    publishableKey: 'sb_publishable_RkyrNG8clRlnHWJFvmOEPQ_DIRp4SKV',
  );

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
        '/dashboard-frota': (context) => const DashboardFrotaScreen(),
        '/dashboard-veiculo': (context) => const DashboardVeiculoScreen(),

        // Alertas
        '/alertas-frota': (context) => const AlertasScreen(isVehicleContext: false),
        '/alertas-veiculo': (context) => const AlertasScreen(isVehicleContext: true),

        // Relatórios
        '/relatorios-frota': (context) => const RelatoriosScreen(isVehicleContext: false),
        '/relatorios-veiculo': (context) => const RelatoriosScreen(isVehicleContext: true),

        // Histórico
        '/historico-frota': (context) => const HistoricoScreen(isVehicleContext: false),
        '/historico-veiculo': (context) => const HistoricoScreen(isVehicleContext: true),

        // GPS
        '/gps': (context) => const GpsScreen(),

        // Perfis
        '/perfil': (context) => const PerfilScreen(),

        // Cadastros e Listagens
        '/cadastrar-funcionario': (context) => const CadastrarFuncionarioScreen(),
        '/cadastrar-dispositivo': (context) => const CadastrarDispositivoScreen(),
        '/criar-frota': (context) => const CriarFrotaScreen(),
        '/listar-dispositivos': (context) => const ListarDispositivosScreen(),
        '/listar-gerentes': (context) => const ListarOperadoresScreen(title: 'Gerentes'),
        '/listar-operadores': (context) => const ListarOperadoresScreen(title: 'Operadores'),
        '/iniciar-viagem': (context) => const IniciarViagemScreen(),

        // Listagens e Ações extras
        '/listar-frotas': (context) => const ListarFrotasScreen(),
        '/configuracoes': (context) => const ConfiguracoesScreen(),
      },
    );
  }
}
