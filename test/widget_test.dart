import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_forecast_app/main.dart';

void main() {

  testWidgets('Weather app yukleme ekrani testi',
          (WidgetTester tester) async {

        // Uygulamayı başlat
        await tester.pumpWidget(const WeatherApp());

        // Loading indicator var mı kontrol et
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Ana sayfa widgeti var mı
        expect(find.byType(WeatherPage), findsOneWidget);

      });

}