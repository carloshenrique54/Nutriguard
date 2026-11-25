import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/models/models.dart';
import 'package:nutriguard1/screens/relatorios/relatorios_screen.dart';
import 'package:nutriguard1/services/admin_context_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'relatorios_telemetry_alerts_test.dart' show MockRelatoriosPopulatedSupabaseService;

/// Cargas congeladas têm temperatura negativa: o gráfico de temperatura média
/// precisa ajustar o eixo para que linha e barras fiquem dentro do cartão.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://tlcsqlemhpxftatpivac.supabase.co',
        publishableKey: 'sb_publishable_RkyrNG8clRlnHWJFvmOEPQ_DIRp4SKV',
      );
    } catch (_) {}
  });

  setUp(() => AdminContextService().clearAll());

  testWidgets('Gráfico de temperatura acomoda valores negativos (linha e barras)', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final frota = FrotaModel(id: 'frota-01', nome: 'Frota Congelados');
    final congelado = DispositivoModel(
      id: 'dev-01',
      nomeDispositivo: 'Câmara Fria 01',
      placaVeiculo: 'NJP8P20',
      idFrota: 'frota-01',
      temperaturaMinima: -18,
      temperaturaMaxima: -12,
    );
    final agora = DateTime.now();
    final leituras = [-16.0, -15.2, -14.8, -13.5, -12.9, -10.4, -15.5];
    final medicoes = [
      for (var i = 0; i < leituras.length; i++)
        MedicaoModel(
          id: 'med-$i',
          idDispositivo: 'dev-01',
          temperatura: leituras[i],
          umidade: 55,
          vibracao: 0.5,
          bateria: 90,
          registradoEm: agora.subtract(Duration(minutes: (leituras.length - i) * 40)),
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: RelatoriosScreen(
          isVehicleContext: false,
          supabaseService: MockRelatoriosPopulatedSupabaseService(
            frotas: [frota],
            dispositivos: [congelado],
            medicoes: medicoes,
            ocorrencias: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Barras (tipo padrão): todas dentro do eixo, que vai abaixo de zero
    final barras = tester.widget<BarChart>(find.byType(BarChart).first).data;
    expect(barras.minY, lessThan(0));
    for (final g in barras.barGroups) {
      for (final rod in g.barRods) {
        expect(rod.toY, inInclusiveRange(barras.minY, barras.maxY), reason: 'barra ${rod.toY} fora do eixo');
        expect(rod.backDrawRodData.fromY, barras.minY);
      }
    }

    // Linha: mesma garantia depois de alternar o tipo de gráfico
    await tester.tap(find.byIcon(Icons.show_chart_rounded).last);
    await tester.pumpAndSettle();
    final linha = tester.widget<LineChart>(find.byType(LineChart).first).data;
    expect(linha.minY, lessThan(0));
    for (final p in linha.lineBarsData.first.spots) {
      expect(p.y, inInclusiveRange(linha.minY, linha.maxY), reason: 'ponto ${p.y} fora do eixo');
    }
  });
}
