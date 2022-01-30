#include "WiFi.h"
int i=0;
void setup() {
  Serial.begin(115200);
 
 
  WiFi.mode(WIFI_AP_STA);
  WiFi.beginSmartConfig();

 
  Serial.println("Waiting for Wi-Fi credentials.");
  while (!WiFi.smartConfigDone()) {
    delay(500);
   
    
    Serial.print(".");
 
  }

  Serial.println("");
  Serial.println("Wi-Fi Credentials Recieved. ESP will be connected to the WI-Fi if the password is correct");


  Serial.println("Waiting for WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
    //if in case user sends wrong credentials, the esp will restart after 20 seconds to be in the state of receiving the credentials again  
     i++;
       if(i==20){
        Serial.println("restarting in 2 seconds");
        delay(2000);
   ESP.restart();
    
      }
    
  }

  Serial.println("WiFi Connected.");


  Serial.println("Connected to " +WiFi.SSID());
 
}

void loop() {
  // put your main code here, to run repeatedly:

  Serial.println("Connected to " +WiFi.SSID());
  delay(5000);
}
