#include <WiFiNINA.h>
#include <ArduinoBearSSL.h>
#include <ArduinoECCX08.h>
#include <ArduinoMqttClient.h>
#include <Arduino_JSON.h>
#include <Arduino_MKRENV.h>

#include "config.h"

WiFiClient wifiClient;
BearSSLClient sslClient(wifiClient);
MqttClient mqttClient(sslClient);

//const int dhtPin = 2;
//DHT dht(dhtPin, DHT11);

String clientId;
float lastKnownTemperature = 0.00;
float lastKnownHumidity = 0.00;
int lastKnownLedValue = 0;

// Publish every 10 seconds for the workshop. Real world apps need this data every 5 or 10 minutes.
unsigned long publishInterval = 10 * 1000;
unsigned long lastMillis = 0;

unsigned long getTime() {
  return WiFi.getTime();
}

void setup() {
  Serial.begin(9600);

  // Comment the next line to NOT wait for a serial connection for debugging
  //while (!Serial);

  // initialize digital pin LED_BUILTIN as an output.
  pinMode(LED_BUILTIN, OUTPUT);

  // initialize MKR ENV shield
  if (!ENV.begin()) {
    Serial.println("Failed to initialize MKR ENV shield!");
    while (1);
  }

  // set a callback to get the current time
  // used for certification validation
  ArduinoBearSSL.onGetTime(getTime);

  if (!ECCX08.begin()) {
    Serial.println("No ECCX08 present!");
    while (1);
  }

  // Use the serial number of the ECCx08 chip for the clientId
  // The client must match the common name in the X.509 certificate
  // If they don't match AWS Core IoT is configured to reject the connection
  clientId = CLIENT_ID;
  Serial.print("Client id = ");
  Serial.println(clientId);

  // set the ECCX08 slot to use for the private key
  // and the accompanying public cert for it
  sslClient.setEccSlot(0, CERTIFICATE);

  // set the client id
  mqttClient.setId(clientId);

  // set the message callback
  mqttClient.onMessage(messageReceived);
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  if (!mqttClient.connected()) {
    connectMQTT();
  }

  // poll for new MQTT messages and send keep alives
  mqttClient.poll();

  if (millis() - lastMillis > publishInterval) {
    lastMillis = millis();

    sendSensorData();
  }
}

void connectWiFi() {
  Serial.print("Attempting to connect to SSID: ");
  Serial.print(WIFI_SSID);
  Serial.print(" ");

  while (WiFi.begin(WIFI_SSID, WIFI_PASS) != WL_CONNECTED) {
    // failed, retry
    Serial.print(".");
    delay(3000);
  }
  Serial.println();

  Serial.println("You're connected to the network");
  Serial.println();

  IPAddress ip = WiFi.localIP();
  Serial.print("IP Address: ");
  Serial.println(ip);
}

void connectMQTT() {
  Serial.print("Attempting to MQTT broker: ");
  Serial.print(MQTT_BROKER);
  Serial.println(" ");

  while (!mqttClient.connect(MQTT_BROKER, 8883)) {
    // failed, retry
    Serial.print(".");
    delay(5000);
  }
  Serial.println();

  Serial.println("You're connected to the MQTT broker");
  Serial.println();

  mqttClient.subscribe("$aws/things/" + clientId + "/shadow/update/delta");
}

void messageReceived(int messageSize) {
  String topic = mqttClient.messageTopic();

  // we received a message, print out the topic and contents
  Serial.print("Received a message with topic '");
  Serial.print(topic);
  Serial.print("', length ");
  Serial.print(messageSize);
  Serial.println(" bytes");

  
  Serial.print("Handling message on topic ");
  Serial.println(topic);

  String jsonString = mqttClient.readString();
  Serial.println(jsonString);

  JSONVar jsonData = JSON.parse(jsonString);
  int newLedValue = jsonData["state"]["led"];
  lastKnownLedValue = newLedValue;
  analogWrite(LED_BUILTIN, newLedValue);
  sendShadowUpdate(true);
}

void sendSensorData() {
  // read all the sensor values
  float temperature = ENV.readTemperature(FAHRENHEIT);
  float humidity    = ENV.readHumidity();
  float pressure    = ENV.readPressure();
  float illuminance = ENV.readIlluminance();
  float uva         = ENV.readUVA();
  float uvb         = ENV.readUVB();
  float uvIndex     = ENV.readUVIndex();

  // create a JSON object with the data
  JSONVar payload;
  payload["temperature"] = temperature;
  payload["humidity"] = humidity;
  payload["pressure"] = pressure;
  payload["lux"] = illuminance;
  payload["uva"] = uva;
  payload["uvb"] = uvb;
  payload["uvindex"] = uvIndex;

  Serial.println(payload);

  // Write the data to the AWS Core IoT MQTT topic
  mqttClient.beginMessage("things/" + clientId + "/environment");
  mqttClient.print(JSON.stringify(payload));
  mqttClient.endMessage();

  sendShadowUpdate(false);
}

void sendShadowUpdate(bool forceSend) {
  // read all the sensor values
  float temperature = ENV.readTemperature(FAHRENHEIT);
  float humidity    = ENV.readHumidity();
  float pressure    = ENV.readPressure();
  float illuminance = ENV.readIlluminance();
  float uva         = ENV.readUVA();
  float uvb         = ENV.readUVB();
  float uvIndex     = ENV.readUVIndex();

  float roundedCurrTemp = round(temperature * 100)/100.0;
  float roundedCurrHumid = round(humidity * 10)/10.0;

  if (lastKnownTemperature != roundedCurrTemp || lastKnownHumidity != roundedCurrHumid || forceSend) {
    lastKnownTemperature = roundedCurrTemp;
    lastKnownHumidity = roundedCurrHumid;
    
    Serial.println("Sending shadow update");
    Serial.print("current temp as float: ");
    Serial.println(lastKnownTemperature);
    Serial.print("current humid as float: ");
    Serial.println(lastKnownHumidity);
    
    JSONVar shadowUpdateDoc;
    shadowUpdateDoc["state"]["reported"]["temperature"] = lastKnownTemperature;
    shadowUpdateDoc["state"]["reported"]["humidity"] = lastKnownHumidity;
    shadowUpdateDoc["state"]["reported"]["led"] = lastKnownLedValue;

    Serial.println(shadowUpdateDoc);

    mqttClient.beginMessage("$aws/things/" + clientId + "/shadow/update");
    mqttClient.print(JSON.stringify(shadowUpdateDoc));
    mqttClient.endMessage();
  }
}
