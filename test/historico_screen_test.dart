import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriguard1/screens/historico/historico_screen.dart';

void main() {
  group('HistoricoScreen & TimelineCard Tests', () {
    testWidgets('TimelineCard renders normal conformance card with green theme', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TimelineCard(
              title: 'Umidade dentro do limite',
              location: 'São José dos Campos',
              time: '9:30',
              isAlert: false,
              icon: Icons.water_drop_outlined,
              iconColor: Color(0xFF8DB600),
              iconBgColor: Color(0xFFF1F8E9),
              iconBorderColor: Color(0xFFD4E7B5),
            ),
          ),
        ),
      );

      expect(find.text('Umidade dentro do limite'), findsOneWidget);
      expect(find.text('São José dos Campos'), findsOneWidget);
      expect(find.text('9:30'), findsOneWidget);
      expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });

    testWidgets('TimelineCard renders alert card with left accent strip and extra detail', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TimelineCard(
              title: 'Temperatura acima do limite de 8°C',
              location: 'São José dos Campos',
              time: '12:00',
              isAlert: true,
              extraDetail: '10°C',
              icon: Icons.thermostat_outlined,
              iconColor: Color(0xFFC23147),
              iconBgColor: Color(0xFFFDE8EC),
              iconBorderColor: Color(0xFFF8BBD0),
            ),
          ),
        ),
      );

      expect(find.text('Temperatura acima do limite de 8°C'), findsOneWidget);
      expect(find.text('São José dos Campos'), findsOneWidget);
      expect(find.text('10°C'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
      expect(find.byIcon(Icons.thermostat_outlined), findsOneWidget);
    });

    testWidgets('TimelineCard renders impact alert card with extra intensity detail', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TimelineCard(
              title: 'Impacto elevado',
              location: 'São José dos Campos',
              time: '10:10',
              isAlert: true,
              extraDetail: 'Intensidade 2Kg',
              icon: Icons.view_in_ar_outlined,
              iconColor: Color(0xFFC23147),
              iconBgColor: Color(0xFFFDE8EC),
              iconBorderColor: Color(0xFFF8BBD0),
            ),
          ),
        ),
      );

      expect(find.text('Impacto elevado'), findsOneWidget);
      expect(find.text('Intensidade 2Kg'), findsOneWidget);
      expect(find.text('10:10'), findsOneWidget);
      expect(find.byIcon(Icons.view_in_ar_outlined), findsOneWidget);
    });
  });
}
