import os

base_dir = r"c:\Users\46612581859\Desktop\nutriguard sem banco\nutriguard1\lib"

files = {
    "widgets/app_drawer.dart": """import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(child: Text('Menu NutriGuard')),
          ListTile(
            title: const Text('Perfil (ADM)'),
            onTap: () => Navigator.pushNamed(context, '/perfil-adm'),
          ),
          ListTile(
            title: const Text('Perfil (Gerente)'),
            onTap: () => Navigator.pushNamed(context, '/perfil-gerente'),
          ),
          ListTile(
            title: const Text('Perfil (Operador)'),
            onTap: () => Navigator.pushNamed(context, '/perfil-operador'),
          ),
          ListTile(
            title: const Text('Cadastrar funcionário'),
            onTap: () => Navigator.pushNamed(context, '/cadastrar-funcionario'),
          ),
          ListTile(
            title: const Text('Cadastrar dispositivo'),
            onTap: () => Navigator.pushNamed(context, '/cadastrar-dispositivo'),
          ),
          ListTile(
            title: const Text('Criar frotas'),
            onTap: () => Navigator.pushNamed(context, '/criar-frota'),
          ),
          ListTile(
            title: const Text('Lista de dispositivos'),
            onTap: () => Navigator.pushNamed(context, '/listar-dispositivos'),
          ),
          ListTile(
            title: const Text('Lista de operadores'),
            onTap: () => Navigator.pushNamed(context, '/listar-operadores'),
          ),
          ListTile(
            title: const Text('Lista de frotas'),
            onTap: () => Navigator.pushNamed(context, '/listar-frotas'),
          ),
          ListTile(
            title: const Text('Configurações'),
            onTap: () => Navigator.pushNamed(context, '/configuracoes'),
          ),
          ListTile(
            title: const Text('Parar viagem'),
            onTap: () => Navigator.pop(context), 
          ),
        ],
      ),
    );
  }
}
""",
    "widgets/app_bottom_nav.dart": """import 'package:flutter/material.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final String entityType; // 'frota' ou 'veiculo' para guiar as tabs

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    this.entityType = 'frota',
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        if (index == currentIndex) return;
        switch (index) {
          case 0:
            Navigator.pushNamed(context, entityType == 'veiculo' ? '/dashboard-veiculo' : '/dashboard-adm-frota');
            break;
          case 1:
            Navigator.pushNamed(context, entityType == 'veiculo' ? '/alertas-veiculo' : '/alertas-frota');
            break;
          case 2:
            Navigator.pushNamed(context, entityType == 'veiculo' ? '/relatorios-veiculo' : '/relatorios-frota');
            break;
          case 3:
            Navigator.pushNamed(context, entityType == 'veiculo' ? '/historico-veiculo' : '/historico-frota');
            break;
          case 4:
            Navigator.pushNamed(context, '/gps');
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Alertas'),
        BottomNavigationBarItem(icon: Icon(Icons.insert_chart), label: 'Relatórios'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Histórico'),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'GPS'),
      ],
    );
  }
}
""",
    "screens/auth/login_screen.dart": """import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NutriGuard - Login')),
      body: Column(
        children: [
          const Text('NutriGuard'),
          const TextField(decoration: InputDecoration(labelText: 'Nome de Usuário')),
          const TextField(decoration: InputDecoration(labelText: 'E-mail')),
          const TextField(decoration: InputDecoration(labelText: 'Senha')),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/dashboard-adm-frota'),
            child: const Text('Login'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/cadastro'),
            child: const Text('Não possue conta? cadastre-se aqui'),
          ),
        ],
      ),
    );
  }
}
""",
    "screens/auth/cadastro_screen.dart": """import 'package:flutter/material.dart';

class CadastroScreen extends StatelessWidget {
  const CadastroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro')),
      body: ListView(
        children: [
          const TextField(decoration: InputDecoration(labelText: 'E-mail')),
          const TextField(decoration: InputDecoration(labelText: 'Senha')),
          const TextField(decoration: InputDecoration(labelText: 'Confirmar senha')),
          const TextField(decoration: InputDecoration(labelText: 'Telefone')),
          const TextField(decoration: InputDecoration(labelText: 'CPF')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cadastrar'),
          ),
        ],
      ),
    );
  }
}
""",
    "screens/dashboard/dashboard_vazio_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_nav.dart';

class DashboardVazioScreen extends StatelessWidget {
  const DashboardVazioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      body: Column(
        children: [
          const Text('Nenhum dispositivo cadastrado, deseja Cadastrar um novo?'),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/cadastrar-dispositivo'),
            child: const Text('Cadastrar Dispositivo'),
          ),
        ],
      ),
    );
  }
}
""",
    "screens/dashboard/dashboard_adm_frota_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_nav.dart';

class DashboardAdmFrotaScreen extends StatelessWidget {
  const DashboardAdmFrotaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Adm')),
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0, entityType: 'frota'),
      body: ListView(
        children: [
          const Text('Gerenciamento de frota'),
          const Text('16 Veículos (12 Normais, 2 Atenção, 2 Crítico)'),
          const Text('Estatísticas: Temperatura média (8°C), Umidade média (32%), Veículos online'),
          const Text('Outras frotas:'),
          const ListTile(title: Text('Frota Norte')),
          const ListTile(title: Text('Frota Sul')),
          const Text('Eventos recentes:'),
          ListTile(
            title: const Text('Volvo FH 540 - Porta aberta'),
            trailing: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/dashboard-veiculo'),
              child: const Text('Ir para veículo'),
            ),
          ),
        ],
      ),
    );
  }
}
""",
    "screens/dashboard/dashboard_veiculo_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_nav.dart';

class DashboardVeiculoScreen extends StatelessWidget {
  const DashboardVeiculoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Veículo')),
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0, entityType: 'veiculo'),
      body: ListView(
        children: const [
          Text('Vendo: Volvo FH 540'),
          Text('Temperatura 5,4°C'),
          Text('Nível de umidade 32%'),
          Text('Compartimento Bateria 78% Fechado'),
          Text('Eventos recentes:'),
          ListTile(title: Text('Impacto leve registrado')),
          ListTile(title: Text('Vibração detectada')),
        ],
      ),
    );
  }
}
""",
    "screens/dashboard/dashboard_operador_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_nav.dart';

class DashboardOperadorScreen extends StatelessWidget {
  const DashboardOperadorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Operador')),
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0, entityType: 'veiculo'),
      body: Column(
        children: [
          const Text('Dispositivo desativado, deseja Iniciar viagem?'),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/iniciar-viagem'),
            child: const Text('Iniciar viagem'),
          ),
          const Text('Status da carga em andamento:'),
          const Text('Temperatura: 4°C'),
          const Text('Umidade: 30%'),
          const Text('Vibração: Normal'),
        ],
      ),
    );
  }
}
""",
    "screens/alertas/alertas_frota_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_nav.dart';

class AlertasFrotaScreen extends StatelessWidget {
  const AlertasFrotaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alertas de Frota')),
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1, entityType: 'frota'),
      body: ListView(
        children: const [
          Text('Vendo: Frota Sul'),
          Text('Status: Sensores online'),
          ListTile(title: Text('Porta aberta (Mal fechada)')),
          ListTile(title: Text('Aumento da taxa de vibrações')),
          ListTile(title: Text('Aquecimento (Temperatura acima do limite)')),
        ],
      ),
    );
  }
}
""",
    "screens/alertas/alertas_veiculo_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_nav.dart';

class AlertasVeiculoScreen extends StatelessWidget {
  const AlertasVeiculoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alertas do Veículo')),
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1, entityType: 'veiculo'),
      body: ListView(
        children: const [
          Text('Vendo: Volvo FH 540'),
          ListTile(title: Text('Nenhum alerta emitido')),
        ],
      ),
    );
  }
}
""",
    "screens/relatorios/relatorios_frota_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_nav.dart';

class RelatoriosFrotaScreen extends StatelessWidget {
  const RelatoriosFrotaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios de Frota')),
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2, entityType: 'frota'),
      body: ListView(
        children: [
          const Text('Relatório Vendo: Frota Sul'),
          ElevatedButton(onPressed: () {}, child: const Text('Exportar PDF')),
          const Text('Resumo:'),
          const Text('Temperatura Média: 6°C'),
          const Text('Umidade: 30%'),
          const Text('Impactos (Total): 4'),
          const Text('Alertas Carga: 2'),
          const Text('Estatísticas do período:'),
          const Text('Tempo monitorado: 144h'),
          const Text('Leituras totais: 2800'),
          const Text('Taxa de desempenho: 97%'),
        ],
      ),
    );
  }
}
""",
    "screens/relatorios/relatorios_veiculo_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_nav.dart';

class RelatoriosVeiculoScreen extends StatelessWidget {
  const RelatoriosVeiculoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios do Veículo')),
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2, entityType: 'veiculo'),
      body: ListView(
        children: [
          const Text('Relatório Vendo: Volvo FH 540'),
          ElevatedButton(onPressed: () {}, child: const Text('Exportar PDF')),
          const Text('Resumo:'),
          const Text('Temperatura Média: 5,4°C'),
          const Text('Umidade: 32%'),
          const Text('Impactos (Total): 1'),
          const Text('Alertas Carga: 0'),
          const Text('Estatísticas do período:'),
          const Text('Tempo monitorado: 48h'),
          const Text('Leituras totais: 500'),
          const Text('Taxa de desempenho: 100%'),
        ],
      ),
    );
  }
}
""",
    "screens/historico/historico_frota_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_nav.dart';

class HistoricoFrotaScreen extends StatelessWidget {
  const HistoricoFrotaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de Frota')),
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3, entityType: 'frota'),
      body: ListView(
        children: const [
          ListTile(title: Text('9:30 Temperatura média dentro do limite')),
          ListTile(title: Text('10:10 Temperatura acima do limite (Volvo FH 540)')),
        ],
      ),
    );
  }
}
""",
    "screens/historico/historico_veiculo_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_nav.dart';

class HistoricoVeiculoScreen extends StatelessWidget {
  const HistoricoVeiculoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico do Veículo')),
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3, entityType: 'veiculo'),
      body: ListView(
        children: const [
          ListTile(title: Text('9:30 Transporte iniciado')),
          ListTile(title: Text('9:50 Temperatura dentro do limite')),
          ListTile(title: Text('10:10 Impacto elevado - Intensidade 2kg')),
        ],
      ),
    );
  }
}
""",
    "screens/gps/gps_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_nav.dart';

class GpsScreen extends StatelessWidget {
  const GpsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GPS em tempo real')),
      drawer: const AppDrawer(),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      body: Column(
        children: const [
          TextField(decoration: InputDecoration(labelText: 'Pesquisar rotas')),
          Expanded(
            child: Center(
              child: Text('[MAPA AQUI] - Caminhão 1'),
            ),
          ),
        ],
      ),
    );
  }
}
""",
    "screens/perfil/perfil_adm_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';

class PerfilAdmScreen extends StatelessWidget {
  const PerfilAdmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil do Administrador')),
      drawer: const AppDrawer(),
      body: ListView(
        children: [
          const Text('Nome: João Silva'),
          const Text('Nascimento: 01/01/1980'),
          const Text('E-mail: adm@nutriguard.com'),
          const Text('Tel: (11) 99999-9999'),
          ElevatedButton(onPressed: () {}, child: const Text('Editar Perfil')),
          ElevatedButton(onPressed: () {}, child: const Text('Ver frotas')),
          const Text('Frota responsável:'),
          ListTile(
            title: const Text('Volvo'),
            trailing: ElevatedButton(onPressed: () {}, child: const Text('Ver mais')),
          ),
          ListTile(
            title: const Text('Scania'),
            trailing: ElevatedButton(onPressed: () {}, child: const Text('Ver mais')),
          ),
          ListTile(
            title: const Text('Mercedes'),
            trailing: ElevatedButton(onPressed: () {}, child: const Text('Ver mais')),
          ),
        ],
      ),
    );
  }
}
""",
    "screens/perfil/perfil_gerente_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';

class PerfilGerenteScreen extends StatelessWidget {
  const PerfilGerenteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil do Gerente')),
      drawer: const AppDrawer(),
      body: ListView(
        children: [
          const Text('Nome: Maria Souza'),
          const Text('Cargo: Gerente'),
          const Text('E-mail: maria@nutriguard.com'),
          const Text('Tel: (11) 98888-8888'),
          ElevatedButton(onPressed: () {}, child: const Text('Minha frota')),
          const Text('Frota responsável:'),
          const ListTile(title: Text('Frota Sul')),
        ],
      ),
    );
  }
}
""",
    "screens/perfil/perfil_operador_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';

class PerfilOperadorScreen extends StatelessWidget {
  const PerfilOperadorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil do Operador')),
      drawer: const AppDrawer(),
      body: ListView(
        children: [
          const Text('Nome: José Santos'),
          const Text('Cargo: Operador'),
          const Text('Histórico de viagens:'),
          const ListTile(title: Text('Legumes')),
          const ListTile(title: Text('Frutas')),
          ElevatedButton(onPressed: () {}, child: const Text('Suas entregas')),
          ElevatedButton(onPressed: () {}, child: const Text('Excluir perfil')),
        ],
      ),
    );
  }
}
""",
    "screens/cadastros/cadastrar_funcionario_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';

class CadastrarFuncionarioScreen extends StatelessWidget {
  const CadastrarFuncionarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar Funcionário')),
      drawer: const AppDrawer(),
      body: ListView(
        children: [
          const TextField(decoration: InputDecoration(labelText: 'Tipo de funcionário (Gerente ou Operador)')),
          const TextField(decoration: InputDecoration(labelText: 'Nome')),
          const TextField(decoration: InputDecoration(labelText: 'CPF')),
          const TextField(decoration: InputDecoration(labelText: 'E-mail')),
          const TextField(decoration: InputDecoration(labelText: 'Telefone')),
          const TextField(decoration: InputDecoration(labelText: 'Nascimento')),
          const TextField(decoration: InputDecoration(labelText: 'Número da CNH (se Operador)')),
          const TextField(decoration: InputDecoration(labelText: 'Validade da CNH')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Cadastrar')),
        ],
      ),
    );
  }
}
""",
    "screens/cadastros/cadastrar_dispositivo_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';

class CadastrarDispositivoScreen extends StatelessWidget {
  const CadastrarDispositivoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar Dispositivo')),
      drawer: const AppDrawer(),
      body: ListView(
        children: [
          const TextField(decoration: InputDecoration(labelText: 'Nome do dispositivo')),
          const TextField(decoration: InputDecoration(labelText: 'Nº Série')),
          const TextField(decoration: InputDecoration(labelText: 'Modelo')),
          const Text('Dados do veículo / Operador:'),
          const TextField(decoration: InputDecoration(labelText: 'Telefone')),
          const TextField(decoration: InputDecoration(labelText: 'CNH')),
          const TextField(decoration: InputDecoration(labelText: 'Nascimento do operador')),
          const Text('Configurações de Sensores:'),
          const TextField(decoration: InputDecoration(labelText: 'Temp Min/Max')),
          const TextField(decoration: InputDecoration(labelText: 'Umidade Max')),
          const TextField(decoration: InputDecoration(labelText: 'Sensibilidade vibração')),
          const TextField(decoration: InputDecoration(labelText: 'Intervalo de coletas')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Cadastrar')),
        ],
      ),
    );
  }
}
""",
    "screens/cadastros/criar_frota_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';

class CriarFrotaScreen extends StatelessWidget {
  const CriarFrotaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Frota')),
      drawer: const AppDrawer(),
      body: ListView(
        children: [
          const TextField(decoration: InputDecoration(labelText: 'Nome da frota')),
          const TextField(decoration: InputDecoration(labelText: 'Gerente responsável')),
          const Text('Selecionar veículos:'),
          Row(
            children: [
              Checkbox(value: true, onChanged: (bool? value) {}),
              const Text('Volvo FH 540')
            ],
          ),
          Row(
            children: [
              Checkbox(value: false, onChanged: (bool? value) {}),
              const Text('Scania R450')
            ],
          ),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Criar frota')),
        ],
      ),
    );
  }
}
""",
    "screens/listagens/listar_dispositivos_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';

class ListarDispositivosScreen extends StatelessWidget {
  const ListarDispositivosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Dispositivos')),
      drawer: const AppDrawer(),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Volvo FH 540 - Operador: José - Carga: Legumes'),
            trailing: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/dashboard-veiculo'),
              child: const Text('Ver mais'),
            ),
          ),
        ],
      ),
    );
  }
}
""",
    "screens/listagens/listar_operadores_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';

class ListarOperadoresScreen extends StatelessWidget {
  const ListarOperadoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Operadores')),
      drawer: const AppDrawer(),
      body: ListView(
        children: [
          ListTile(
            title: const Text('José - Veículo: Volvo FH 540'),
            trailing: ElevatedButton(
              onPressed: () {},
              child: const Text('Ver mais'),
            ),
          ),
        ],
      ),
    );
  }
}
""",
    "screens/listagens/listar_frotas_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';

class ListarFrotasScreen extends StatelessWidget {
  const ListarFrotasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Frotas')),
      drawer: const AppDrawer(),
      body: const Center(child: Text('Lista de Frotas (Em construção)')),
    );
  }
}
""",
    "screens/acoes/iniciar_viagem_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';

class IniciarViagemScreen extends StatelessWidget {
  const IniciarViagemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar Viagem')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          const Text('Para onde você vai?'),
          const TextField(decoration: InputDecoration(labelText: 'Destino da viagem')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Iniciar viagem'),
          ),
        ],
      ),
    );
  }
}
""",
    "screens/acoes/configuracoes_screen.dart": """import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';

class ConfiguracoesScreen extends StatelessWidget {
  const ConfiguracoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      drawer: const AppDrawer(),
      body: const Center(child: Text('Configurações do sistema (Em construção)')),
    );
  }
}
""",
    "main.dart": """import 'package:flutter/material.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/cadastro_screen.dart';
import 'screens/dashboard/dashboard_vazio_screen.dart';
import 'screens/dashboard/dashboard_adm_frota_screen.dart';
import 'screens/dashboard/dashboard_veiculo_screen.dart';
import 'screens/dashboard/dashboard_operador_screen.dart';
import 'screens/alertas/alertas_frota_screen.dart';
import 'screens/alertas/alertas_veiculo_screen.dart';
import 'screens/relatorios/relatorios_frota_screen.dart';
import 'screens/relatorios/relatorios_veiculo_screen.dart';
import 'screens/historico/historico_frota_screen.dart';
import 'screens/historico/historico_veiculo_screen.dart';
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
      initialRoute: '/',
      routes: {
        // Autenticação
        '/': (context) => const LoginScreen(),
        '/cadastro': (context) => const CadastroScreen(),
        
        // Dashboards
        '/dashboard-vazio': (context) => const DashboardVazioScreen(),
        '/dashboard-adm-frota': (context) => const DashboardAdmFrotaScreen(),
        '/dashboard-veiculo': (context) => const DashboardVeiculoScreen(),
        '/dashboard-operador': (context) => const DashboardOperadorScreen(),
        
        // Alertas
        '/alertas-frota': (context) => const AlertasFrotaScreen(),
        '/alertas-veiculo': (context) => const AlertasVeiculoScreen(),
        
        // Relatórios
        '/relatorios-frota': (context) => const RelatoriosFrotaScreen(),
        '/relatorios-veiculo': (context) => const RelatoriosVeiculoScreen(),
        
        // Histórico
        '/historico-frota': (context) => const HistoricoFrotaScreen(),
        '/historico-veiculo': (context) => const HistoricoVeiculoScreen(),
        
        // GPS
        '/gps': (context) => const GpsScreen(),
        
        // Perfis
        '/perfil-adm': (context) => const PerfilAdmScreen(),
        '/perfil-gerente': (context) => const PerfilGerenteScreen(),
        '/perfil-operador': (context) => const PerfilOperadorScreen(),
        
        // Cadastros e Listagens
        '/cadastrar-funcionario': (context) => const CadastrarFuncionarioScreen(),
        '/cadastrar-dispositivo': (context) => const CadastrarDispositivoScreen(),
        '/criar-frota': (context) => const CriarFrotaScreen(),
        '/listar-dispositivos': (context) => const ListarDispositivosScreen(),
        '/listar-operadores': (context) => const ListarOperadoresScreen(),
        '/iniciar-viagem': (context) => const IniciarViagemScreen(),
        
        // Rotas extras solicitadas no Drawer
        '/listar-frotas': (context) => const ListarFrotasScreen(),
        '/configuracoes': (context) => const ConfiguracoesScreen(),
      },
    );
  }
}
"""
}

for path, content in files.items():
    full_path = os.path.join(base_dir, path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "w", encoding="utf-8") as f:
        f.write(content)

print(f"Created {len(files)} files successfully in {base_dir}")
