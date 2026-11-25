/*
  NutriGuard — Monitor de carga refrigerada (ESP32)

  Componentes (simulados no Wokwi):
    - DHT22          -> temperatura e umidade do baú
    - MPU6050        -> vibração (desvio da aceleração em relação a 1 g)
    - Botão          -> porta do baú: cada aperto abre/fecha (começa fechada)
    - Potenciômetro  -> carga da bateria do dispositivo, de 0 a 100%
    - Buzzer         -> alerta sonoro
    - LEDs           -> verde (normal), amarelo (atenção), vermelho (crítico)
    - GPS            -> não existe no Wokwi: a posição é simulada percorrendo
                        a rota CD São Paulo -> Santos

  Plataforma:
    A cada INTERVALO_ENVIO_MS o ESP32 envia as leituras para o NutriGuard
    (Supabase, função enviar_medicao), identificado pelo token do dispositivo.
    O token é gerado no app: Listar dispositivos > ícone da chave.
    A resposta traz os limites configurados para o veículo (temperatura,
    umidade, vibração, bateria) e os alertas gerados pela medição.
*/

#include <Wire.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <DHTesp.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

// ---------- Conexão com a plataforma ----------
const char* WIFI_SSID         = "Wokwi-GUEST";
const char* WIFI_SENHA        = "";
const char* SUPABASE_URL      = "https://tlcsqlemhpxftatpivac.supabase.co";
const char* SUPABASE_ANON_KEY = "sb_publishable_RkyrNG8clRlnHWJFvmOEPQ_DIRp4SKV";

// ---------- Identificação do veículo ----------
// Cole aqui o token gerado no app (Listar dispositivos > ícone da chave).
const char* TOKEN_DISPOSITIVO = "COLE_O_TOKEN_AQUI";

// ---------- Pinos ----------
const int PIN_DHT      = 15;
const int PIN_PORTA    = 4;    // botão da porta (INPUT_PULLUP: apertado = LOW)
const int PIN_BAT      = 34;   // potenciômetro (entrada analógica)
const int PIN_BUZZER   = 26;
const int PIN_LED_OK   = 25;
const int PIN_LED_ATEN = 33;
const int PIN_LED_CRIT = 32;
// MPU6050 no I2C padrão do ESP32: SDA = 21, SCL = 22

const unsigned long INTERVALO_ENVIO_MS = 10000;   // 10 s entre medições

// ---------- Limites (valores padrão até a plataforma responder) ----------
float tempMin       = 2.0;
float tempMax       = 8.0;
float umidadeMax    = 80.0;
float limiteVibracao = 6.0;
float bateriaMin    = 20.0;
String veiculo      = "—";
bool plataformaOk   = false;
String statusPlataforma = "aguardando primeiro envio";
bool emViagem       = false;
String alertasPlataforma = "";

DHTesp dht;
Adafruit_MPU6050 mpu;
bool mpuOk = false;

enum Estado { NORMAL, ATENCAO, CRITICO };

// ---------- GPS simulado: rota CD São Paulo -> Santos ----------
struct Ponto { double lat; double lng; };
const Ponto ROTA[] = {
  {-23.5275, -46.7300},   // CD São Paulo (Vila Leopoldina)
  {-23.5880, -46.6790},
  {-23.6650, -46.6200},   // Imigrantes
  {-23.7700, -46.5750},
  {-23.8800, -46.4300},   // Serra do Mar
  {-23.9608, -46.3336},   // Santos
};
const int N_ROTA = sizeof(ROTA) / sizeof(ROTA[0]);
const unsigned long DURACAO_ROTA_MS = 10UL * 60UL * 1000UL;   // ida em 10 min, depois recomeça

void posicaoSimulada(double &lat, double &lng) {
  double t = (double)(millis() % DURACAO_ROTA_MS) / DURACAO_ROTA_MS * (N_ROTA - 1);
  int i = (int)t;
  if (i >= N_ROTA - 1) i = N_ROTA - 2;
  double f = t - i;
  lat = ROTA[i].lat + (ROTA[i + 1].lat - ROTA[i].lat) * f;
  lng = ROTA[i].lng + (ROTA[i + 1].lng - ROTA[i].lng) * f;
}

// ---------- Leituras ----------
int lerBateriaPercentual() {
  return map(analogRead(PIN_BAT), 0, 4095, 0, 100);
}

// Porta controlada pelo botão: cada aperto alterna aberta/fechada.
// A interrupção garante que o aperto não se perca enquanto o ESP32 envia dados.
volatile bool portaEstaAberta = false;
volatile bool portaMudou = false;
volatile unsigned long ultimoAperto = 0;

void IRAM_ATTR aoApertarPorta() {
  unsigned long agora = millis();
  if (agora - ultimoAperto > 250) {   // debounce
    ultimoAperto = agora;
    portaEstaAberta = !portaEstaAberta;
    portaMudou = true;
  }
}

bool portaAberta() {
  return portaEstaAberta;
}

// Vibração = quanto a aceleração total se afasta de 1 g (m/s²)
float lerVibracao() {
  if (!mpuOk) return 0;
  sensors_event_t a, g, t;
  mpu.getEvent(&a, &g, &t);
  float total = sqrt(a.acceleration.x * a.acceleration.x +
                     a.acceleration.y * a.acceleration.y +
                     a.acceleration.z * a.acceleration.z);
  return fabs(total - 9.81);
}

// ---------- Plataforma ----------
void conectarWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  Serial.print("Conectando ao Wi-Fi");
  WiFi.begin(WIFI_SSID, WIFI_SENHA, 6);
  unsigned long inicio = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - inicio < 10000) {
    delay(250);
    Serial.print(".");
  }
  Serial.println(WiFi.status() == WL_CONNECTED ? " conectado" : " sem conexão, tentando de novo depois");
}

// Lê um campo simples da resposta JSON ("campo":valor)
String campoJSON(const String &json, const char* campo) {
  String chave = String("\"") + campo + "\":";
  int i = json.indexOf(chave);
  if (i < 0) return "";
  i += chave.length();
  while (i < (int)json.length() && json.charAt(i) == ' ') i++;
  if (json.charAt(i) == '"') {
    int fim = json.indexOf('"', i + 1);
    return json.substring(i + 1, fim);
  }
  if (json.charAt(i) == '[') {
    int fim = json.indexOf(']', i);
    return json.substring(i + 1, fim);
  }
  int fim = i;
  while (fim < (int)json.length() && json.charAt(fim) != ',' && json.charAt(fim) != '}') fim++;
  return json.substring(i, fim);
}

float campoNumero(const String &json, const char* campo, float padrao) {
  String v = campoJSON(json, campo);
  return (v.length() && v != "null") ? v.toFloat() : padrao;
}

// Conexão HTTPS mantida aberta entre os envios (keep-alive): sem isso, cada
// envio refaz o handshake TLS, que no simulador leva alguns segundos.
WiFiClientSecure cliente;
HTTPClient http;
unsigned long duracaoEnvioMs = 0;

void enviarMedicao(float temp, float umid, float vib, bool porta, int bateria, double lat, double lng) {
  if (WiFi.status() != WL_CONNECTED) {
    plataformaOk = false;
    statusPlataforma = "sem Wi-Fi";
    conectarWiFi();
    return;
  }

  unsigned long inicio = millis();
  String url = String(SUPABASE_URL) + "/rest/v1/rpc/enviar_medicao";
  if (!http.begin(cliente, url)) {
    plataformaOk = false;
    statusPlataforma = "falha ao abrir conexão";
    return;
  }
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);

  String corpo = String("{\"p_token\":\"") + TOKEN_DISPOSITIVO + "\"" +
                 ",\"p_temperatura\":" + (isnan(temp) ? String("null") : String(temp, 1)) +
                 ",\"p_umidade\":" + (isnan(umid) ? String("null") : String(umid, 1)) +
                 ",\"p_vibracao\":" + String(vib, 2) +
                 ",\"p_porta_aberta\":" + (porta ? "true" : "false") +
                 ",\"p_bateria\":" + String(bateria) +
                 ",\"p_latitude\":" + String(lat, 6) +
                 ",\"p_longitude\":" + String(lng, 6) + "}";

  int status = http.POST(corpo);
  if (status == 200) {
    String resposta = http.getString();
    plataformaOk = campoJSON(resposta, "ok") == "true";
    if (!plataformaOk) {
      statusPlataforma = "medição recusada: " + campoJSON(resposta, "erro") + " (confira TOKEN_DISPOSITIVO)";
    } else {
      veiculo        = campoJSON(resposta, "veiculo");
      emViagem       = campoJSON(resposta, "em_viagem") == "true";
      tempMin        = campoNumero(resposta, "temperatura_minima", tempMin);
      tempMax        = campoNumero(resposta, "temperatura_maxima", tempMax);
      umidadeMax     = campoNumero(resposta, "umidade_maxima", umidadeMax);
      limiteVibracao = campoNumero(resposta, "limite_vibracao", limiteVibracao);
      bateriaMin     = campoNumero(resposta, "bateria_minima", bateriaMin);
      alertasPlataforma = campoJSON(resposta, "alertas");
      alertasPlataforma.replace("\"", "");
    }
  } else {
    plataformaOk = false;
    statusPlataforma = "falha no envio (HTTP " + String(status) + ")";
  }
  http.end();   // com setReuse(true), a conexão continua aberta para o próximo envio
  duracaoEnvioMs = millis() - inicio;
}

// ---------- Saída no terminal ----------
String barra(float valor, float minimo, float maximo, int largura) {
  float p = (valor - minimo) / (maximo - minimo);
  int cheios = constrain((int)round(p * largura), 0, largura);
  String s = "[";
  for (int i = 0; i < largura; i++) s += (i < cheios) ? "█" : "░";
  return s + "]";
}

String fixo(float valor, int casas, int largura) {
  String s = isnan(valor) ? String("---") : String(valor, casas);
  while ((int)s.length() < largura) s = " " + s;
  return s;
}

void imprimirPainel(float temp, float umid, float vib, bool porta, int bateria,
                    double lat, double lng, Estado estado, const String &alerta) {
  Serial.println();
  Serial.println("┌──────────────────────────────────────────────────────────");
  Serial.print  ("│  ❄  NUTRIGUARD · CARGA REFRIGERADA     veículo ");
  Serial.println(veiculo);
  Serial.print  ("│  Plataforma   ");
  if (!plataformaOk) Serial.println(statusPlataforma);
  else {
    Serial.print(emViagem ? "conectado · EM VIAGEM" : "conectado · sem viagem registrada");
    Serial.print("  (envio em "); Serial.print(duracaoEnvioMs); Serial.println(" ms)");
  }
  Serial.println("├──────────────────────────────────────────────────────────");

  Serial.print("│  Temperatura ");
  Serial.print(fixo(temp, 1, 6)); Serial.print(" °C  ");
  Serial.print(barra(temp, tempMin - 10, tempMax + 10, 16));
  Serial.print("  faixa: "); Serial.print(tempMin, 1); Serial.print(" a "); Serial.print(tempMax, 1); Serial.println(" °C");

  Serial.print("│  Umidade     ");
  Serial.print(fixo(umid, 1, 6)); Serial.print(" %   ");
  Serial.print(barra(umid, 0, 100, 16));
  Serial.print("  máx: "); Serial.print(umidadeMax, 0); Serial.println("%");

  Serial.print("│  Vibração    ");
  Serial.print(fixo(vib, 2, 6)); Serial.print(" m/s²");
  Serial.print(barra(vib, 0, limiteVibracao * 2, 16));
  Serial.print("  limite: "); Serial.println(limiteVibracao, 1);

  Serial.print("│  Bateria     ");
  Serial.print(fixo(bateria, 0, 6)); Serial.print(" %   ");
  Serial.print(barra(bateria, 0, 100, 16));
  Serial.print("  mínima: "); Serial.print(bateriaMin, 0); Serial.println("%");

  Serial.print("│  Porta       ");
  Serial.println(porta ? "   ABERTA" : "   fechada");

  Serial.print("│  GPS (sim.)  ");
  Serial.print(lat, 5); Serial.print(", "); Serial.println(lng, 5);

  Serial.println("├──────────────────────────────────────────────────────────");
  Serial.print("│  Estado      ");
  if (estado == NORMAL)       Serial.println("🟢 NORMAL");
  else if (estado == ATENCAO) Serial.println("🟡 ATENÇÃO");
  else                        Serial.println("🔴 CRÍTICO");
  Serial.print("│  Alerta      ");
  Serial.println(estado == NORMAL ? "nenhum, carga dentro dos limites" : alerta);
  if (alertasPlataforma.length()) {
    Serial.print("│  Plataforma  alertas registrados: ");
    Serial.println(alertasPlataforma);
  }
  Serial.println("└──────────────────────────────────────────────────────────");
}

// ---------- Buzzer e LEDs sem travar o loop ----------
void atualizarSinais(Estado estado) {
  digitalWrite(PIN_LED_OK,   estado == NORMAL);
  digitalWrite(PIN_LED_ATEN, estado == ATENCAO);
  digitalWrite(PIN_LED_CRIT, estado == CRITICO);

  static unsigned long ultimo = 0;
  static bool ligado = false;
  if (estado == NORMAL) {
    noTone(PIN_BUZZER);
    ligado = false;
    return;
  }
  unsigned long intervalo = (estado == CRITICO) ? 150 : 600;
  int frequencia          = (estado == CRITICO) ? 2000 : 1000;
  if (millis() - ultimo >= intervalo) {
    ultimo = millis();
    ligado = !ligado;
    if (ligado) tone(PIN_BUZZER, frequencia);
    else        noTone(PIN_BUZZER);
  }
}

void setup() {
  Serial.begin(115200);

  pinMode(PIN_PORTA, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(PIN_PORTA), aoApertarPorta, FALLING);
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_LED_OK, OUTPUT);
  pinMode(PIN_LED_ATEN, OUTPUT);
  pinMode(PIN_LED_CRIT, OUTPUT);
  analogReadResolution(12);

  dht.setup(PIN_DHT, DHTesp::DHT22);

  Wire.begin(21, 22);
  mpuOk = mpu.begin();
  if (mpuOk) {
    mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
    mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
  } else {
    Serial.println("MPU6050 não encontrado: vibração ficará em 0");
  }

  Serial.println("\n══════════  NUTRIGUARD · monitor de carga iniciado  ══════════");
  if (String(TOKEN_DISPOSITIVO) == "COLE_O_TOKEN_AQUI") {
    Serial.println("⚠ Defina TOKEN_DISPOSITIVO (app: Listar dispositivos > ícone da chave).");
  }
  cliente.setInsecure();   // sem verificação de certificado no simulador
  http.setReuse(true);     // mantém a conexão aberta entre os envios
  http.setTimeout(10000);   // o handshake TLS no simulador pode demorar
  conectarWiFi();
}

void loop() {
  static unsigned long ultimoEnvio = 0;
  static Estado estado = NORMAL;

  // Porta abriu/fechou: avisa e envia na hora, sem esperar o intervalo
  bool envioImediato = false;
  if (portaMudou) {
    portaMudou = false;
    envioImediato = true;
    Serial.println(portaAberta() ? "\n🚪 Porta do baú ABERTA" : "\n🚪 Porta do baú fechada");
  }

  if (envioImediato || ultimoEnvio == 0 || millis() - ultimoEnvio >= INTERVALO_ENVIO_MS) {
    ultimoEnvio = millis();

    TempAndHumidity th = dht.getTempAndHumidity();
    float temp = th.temperature;
    float umid = th.humidity;
    float vib = lerVibracao();
    bool porta = portaAberta();
    int bateria = lerBateriaPercentual();
    double lat, lng;
    posicaoSimulada(lat, lng);

    // Avaliação local (o mais grave vence); a plataforma registra os alertas
    estado = NORMAL;
    String alerta = "";
    if (porta)                                { estado = ATENCAO; alerta = "porta do baú aberta"; }
    if (!isnan(umid) && umid > umidadeMax)    { estado = ATENCAO; alerta = "umidade acima do limite"; }
    if (vib > limiteVibracao)                 { estado = ATENCAO; alerta = "vibração excessiva"; }
    if (bateria < bateriaMin)                 { estado = ATENCAO; alerta = "bateria do dispositivo baixa"; }
    if (!isnan(temp) && (temp > tempMax || temp < tempMin)) {
      estado = CRITICO;
      alerta = temp > tempMax ? "TEMPERATURA ACIMA DA FAIXA: carga em risco"
                              : "TEMPERATURA ABAIXO DA FAIXA: risco de congelamento";
    }

    enviarMedicao(temp, umid, vib, porta, bateria, lat, lng);
    imprimirPainel(temp, umid, vib, porta, bateria, lat, lng, estado, alerta);
  }

  atualizarSinais(estado);
}
