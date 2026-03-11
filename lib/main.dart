import 'package:flutter/material.dart'; //UI oluşturmak için kullanılan temel kütüphane
import 'package:geolocator/geolocator.dart'; //Konum almak için kullanılan paket
import 'package:http/http.dart' as http; //İnternet üzerinden Api isteği almak için paket
import 'dart:convert'; //JSON verisini çözmek için
import 'package:intl/intl.dart'; //*Tarih formatlamak için kullanılan paket
import 'package:intl/date_symbol_data_local.dart'; //Türkçe gün isimlerini kullanabilmek için kullandığım  paket

void main() async {//Uygulamanın başlangıç noktası
  WidgetsFlutterBinding.ensureInitialized(); //Flutter başlatılmadan önce hazırlıkların yapılması için
  await initializeDateFormatting('tr_TR', null);//Tarih formetını Türkçe kullanabilmek için
  runApp(const WeatherApp());//Uygulamanın ayağa  kalktığı kısım
}

class WeatherApp extends StatelessWidget { //Ana widget
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(   //Uygulamanın temel yapı taşı
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true), //Kullanılan tasarım sistemi
      home: const WeatherPage(),//Uygulama açılınca ilk gösterilecek sayfa
    );
  }
}

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();  //Ana sayfamız üzerinden  ikinci sayfayı oluşturuyoruz
}

class _WeatherPageState extends State<WeatherPage> {
  final String apiKey = "BURAYA_KENDI_API_ANAHTARINIZI_YAZIN";

  Map<String, dynamic>? current;
  List hourly = [];
  List fiveDayForecast = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    getWeather();
  }

  Future<void> getWeather() async {//Zaman alabilir/Gelene kadar bekle
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();//Konumun açık olup olmadığını kontrol eder
      if (!serviceEnabled) {
        setState(() => isLoading = false);//Konum servisi açık değilse yüklemeyi durdur
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();//Konum izni var mı kontrol et true or false
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();//false ise konum izni iste
      }

      if (permission == LocationPermission.deniedForever) { //Kullanıcı "asla izin verme " dediyse  yüklemeyi durdur
        setState(() => isLoading = false);
        return;
      }

      Position pos = await Geolocator.getCurrentPosition( //Mevcut kordinatları al(düşük hassasiyette)
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));

      double lat = pos.latitude;//enlem değerini atar
      double lon = pos.longitude;//boylam değerini atar

      //URL'leri verilen enlem ve boylam bilgilerine göre oluştur
      var currentUrl = "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=tr";
      var forecastUrl = "https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=tr";

      //İnternetten aynı anda istek gönder
      var responses = await Future.wait([
        http.get(Uri.parse(currentUrl)),
        http.get(Uri.parse(forecastUrl))
      ]);
     //Api isteklerinin başarılı olması durumunda gelen verileri ayıkla
      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        var currentData = json.decode(responses[0].body);
        var forecastData = json.decode(responses[1].body);

        setState(() { //Değişkenleri güncelleyerek ekranın yeniden çizilmesini sağlar
          current = currentData;
          hourly = forecastData["list"].take(12).toList();
          fiveDayForecast = forecastData["list"]
              .where((e) => e["dt_txt"].toString().contains("12:00:00"))
              .toList();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  String getBackground(String condition) {
    switch (condition.toLowerCase()) {
      case "clear": return "assets/images/clear.png";
      case "clouds": return "assets/images/cloudy_weather.png";
      case "rain": return "assets/images/rainy_weather.png";
      case "snow": return "assets/images/snowy_weather.png";
      case "thunderstorm": return "assets/images/thunderstorm.jpg";
      default: return "assets/images/foggy_weather.png";
    }
  }

  Widget weatherCard(String title, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 0.5),//alpha,rengin ne kadar görünür placağını belirler
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || current == null) {//Veri daha gelmediyse
      return const Scaffold(
        backgroundColor: Color(0xFF1D2635),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    String condition = current!["weather"][0]["main"];

    return Scaffold(
      // Arka plan resminin butonun arkasından devam etmesi için
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // GÜNCELLEME BUTONU BURADA
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
            onPressed: () {
              setState(() => isLoading = true);
              getWeather();
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Container(
        width: double.infinity, //ekranın genişliği kadar
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(getBackground(condition)),//AssetImage,resimler uygulamada zaten var
            fit: BoxFit.cover, //Şeklini bozmadan boşluk bırakmadan yerleştir.
          ),
        ),
        child: Container(
          color: Colors.black.withValues(alpha: 0.4),
          child: SafeArea(//Uygulamayı fiziksel engellerden korur
            child: SingleChildScrollView( //Ekrana sığmazsa aşağı kaydırabil
              physics: const BouncingScrollPhysics(),//Ekranın bittiğini gösterir
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Text(current!["name"], style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  Text("${current!["main"]["temp"].round()}°", style: const TextStyle(color: Colors.white, fontSize: 85, fontWeight: FontWeight.w100)),
                  Text(current!["weather"][0]["description"].toString().toUpperCase(),
                      style: const TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1.2)),

                  const SizedBox(height: 25),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60), //Sağdan ve soldan 60 cm içeri iter
                    child: GridView.count( //Izgara düzeni
                      shrinkWrap: true, //GridView'e dur der boyunu ayarlar
                      physics: const NeverScrollableScrollPhysics(),//Grid yapısının kendi içinde kaymasına gerek yok.
                      crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 2.2,
                      children: [
                        weatherCard("HİSSEDİLEN", "${current!["main"]["feels_like"].round()}°"),
                        weatherCard("NEM", "%${current!["main"]["humidity"]}"),
                        weatherCard("RÜZGAR", "${current!["wind"]["speed"]} m/s"),
                        weatherCard("BASINÇ", "${current!["main"]["pressure"]}"),
                        weatherCard("BULUT", "%${current!["clouds"]["all"]}"),
                        weatherCard("GÖRÜŞ", "${(current!["visibility"] / 1000).round()} km"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                  const Text("SAATLİK TAHMİN", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      scrollDirection: Axis.horizontal,
                      itemCount: hourly.length,
                      itemBuilder: (context, i) {
                        var data = hourly[i];
                        String iconCode = data["weather"][0]["icon"];

                        return Container(
                          width: 90,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(data["dt_txt"].substring(11, 16), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 5),
                              Image.network(
                                "https://openweathermap.org/img/wn/$iconCode@2x.png",
                                width: 60, height: 60,
                              ),
                              Text("${data["main"]["temp"].round()}°", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 40),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ForecastPage(fiveDayForecast)));
                    },
                    child: const Text("5 GÜNLÜK TAHMİN"),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ForecastPage extends StatelessWidget {
  final List forecastList;
  const ForecastPage(this.forecastList, {super.key});

  String getDayName(String dateStr) {
    DateTime date = DateTime.parse(dateStr);
    return DateFormat('EEEE', 'tr_TR').format(date); //Türkçe karşılığını alır
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D2635),
      appBar: AppBar(
        title: const Text("5 Günlük Tahmin", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        itemCount: forecastList.length,
        itemBuilder: (context, i) {
          var data = forecastList[i];
          String iconCode = data["weather"][0]["icon"];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(15),
            ),
            child: ListTile(
              leading: Image.network("https://openweathermap.org/img/wn/$iconCode@2x.png", width: 50),
              title: Text(getDayName(data["dt_txt"]), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text(data["weather"][0]["description"], style: const TextStyle(color: Colors.white54)),
              trailing: Text("${data["main"]["temp"].round()}°C", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }
}