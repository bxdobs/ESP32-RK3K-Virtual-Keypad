// rk3k.cpp

#include "espcore.h"
#include "rk3k.h"

// rk3k_index.html has 2 streams: 
//   publish: 
//  rk3k-card -> id=75:key -> wsWsHandler -> app2eccQ -> dqPubMqttTask -> rk3k/cmd 
// subscribe: 
//  rk3k/cos -> mqttHandler -> ecc2appQ -> dqRK3000Task -> ws.textAll -> id=67:cos -> rk3k-card 


// rk3k_index -> cmd 75:key -> wsHandler[] -> appQ -> rvkc.dqMqttPubTask -> ecc.mqttQ -> ecc.dqMqttQ publish XXXX
// epp fcx:XXXX -> appEPext[] -> appQ -> fcc.dqMqttPubTask -> ecc.mqttQ -> ecc.dqMqttQ publish XXXX
// mqtt subscribe XXXX -> mqttHandler[] -> eccQ -> fcc.dqFCTask -> fcc.fc(XXXX)
//
//fc_index.html (x10 virtual keypad encodes 16 bits in ascii char format 0xXXXX) 
//	-> wsHandler(doc[cmd]:18 doc[fcx]:XXXX]) 
//		XXXX -> appQ 
//curl http://<fc_ip>/fcx/XXXX
//	-> appEndPointExtension(epp[cmd]:fcx epp[action]:XXXX]) 
//		XXXX -> appQ 
//appQ
//	-> fcc.dqMqttPubTask
//		appQ -> XXXX 
//		-> ecc.qMqttMsg(/firecracker/cmd, XXXX)
//			MqttMsg([topic]:/Firecracker/cmd [payload]:XXXX) -> mqttQ
//		-> ecc.dqMqttTask
//                         -> publish([topic], [payload])
//mqtt subscribe /Firecracker/cmd 
//	-> mqttHandler(MqttMsg[topic], MqttMsg[payload]) 
//		M([topic],[payload] -> eccQ 
//	-> fcc.dqFirecrackerTask 
//		eccQ -> fcc.fc(MqttMsg[payload])

//EspCoreClass     ecc;
Rk3kVirtualKeypadClass rvkc;

bool Rk3kVirtualKeypadClass::wsHandler(JsonDocument& doc) {
   //Serial.println("wshanlder top1");
   ecc._fdpl("rvkc wsHandler ...",_DBG1_MSG);
   //Serial.println("wshanlder top2");
 
   //if (deserializeJson(doc, msg) != DeserializationError::Ok) return false;

   int cmd = doc["cmd"] | -1;

   if (cmd == 75) {
      //Serial.println("wshandler 75");
      // publish to MQTT
      char buf[_APPQ_BUF_MAXLEN];
      String key = doc["data"];
      key.toCharArray(buf, _APPQ_BUF_MAXLEN);
      ecc._fdpl("rckc wsHandler ... " + key,_DBG2_MSG);
      ecc._fdpl("rckc inc appQ " + ecc.qDepth(ecc._APP_Q,"inc"),_DBG3_MSG);
      xQueueSend(ecc.app2eccQ, buf, 0);
      //Serial.println("wshandler 75 bottom");
   }
   //Serial.println("wshandler bottom");
   return true;
}

String Rk3kVirtualKeypadClass::appEndPointExtension(const EspCoreClass::EndPoint& epp) {
   //Serial.println("appEndPointExension top");
   ecc._fdpl("rvkc appEndPointExtension ...",_DBG1_MSG);
   String rtnMsg = "Unknown_Request";
   //Serial.println("appEndpointextension bottom");
   //if (epp.cmd == "fcx") {
   //   String hex = epp.action;

      // sanitize: 4 hex chars
   //   hex.toLowerCase();
   //   if (hex.length() == 4) {
   //      ecc._fdpl("fc addEndPointExtension hex ... " + hex ,_DBG2_MSG);
   //      ecc._fdpl("fc inc appQ " + ecc.qDepth(ecc._APP_Q,"inc"),_DBG3_MSG);
   //      xQueueSend(ecc.app2eccQ, &hex, 0);
   //      rtnMsg = epp.cmd + " " + hex;
   //   }
   //}   
   return rtnMsg;
}

// subscriber link
bool Rk3kVirtualKeypadClass::mqttHandler(const EspCoreClass::MqttMsg& M) {
   //Serial.println("mqtthandler top1");
   ecc._fdpl("rvkc mqttHandler ... " + String(M.topic) + " " + String(M.payload) ,_DBG1_MSG);
   //Serial.println("mqtthandler top2");
    
   if (strcmp(M.topic, _APP_TOPIC_SUB) == 0) { // rk3k/cos
      //Serial.println("mqtthandler top3");
      // push ASCII hex payload into ecc2appQ
      ecc._fdpl("rvkc nqttHandler handle payload",_DBG2_MSG);
      // push ASCII hex payload into ecc2appQ
      ecc._fdpl("rvkc inc eccQ " + ecc.qDepth(ecc._ECC_Q,"inc"),_DBG3_MSG);
      char buf[_APPQ_BUF_MAXLEN];
      String cmd = M.payload;
      cmd.toCharArray(buf, _APPQ_BUF_MAXLEN);
      xQueueSend(ecc.ecc2appQ, buf, 0);
      //Serial.println("mqtthandler bottom1");

      return true;
   }
   //Serial.println("mqtthandler bottom2");
 
   return false;
}

void Rk3kVirtualKeypadClass::dqRk3kVKTask(void *pv) {
   ecc._fdpl("rvkc dqRk3kVKTask_ ... ");
   
   DynamicJsonDocument doc(128);
   char   buf[_APPQ_BUF_MAXLEN];
   for (;;) {
      if (xQueueReceive(ecc.ecc2appQ, buf, portMAX_DELAY) == pdTRUE) {
         //Serial.println("dqRk3kVKTask Top");
         String cmd(buf);
         ecc._fdpl("rvkc dqRk3kVKTask ... " + cmd ,_DBG2_MSG);
         ecc._fdpl("rvkc dec eccQ "  + ecc.qDepth(ecc._ECC_Q,"dec"),_DBG3_MSG);

         doc["cmd"] = 67;
         doc["data"] = cmd;
         String msg;
         serializeJson(doc,msg);
         ecc.ws.textAll(msg);
         //Serial.println("dqRk3kVKTask Bottom");
      } else {
         delay(100);
      }
   }
}

void Rk3kVirtualKeypadClass::dqMqttPubTask(void *pv) {
   ecc._fdpl("rvkc dqMqttPubTask_ ... ");
   char   buf[_APPQ_BUF_MAXLEN];
   for (;;) {
      if (xQueueReceive(ecc.app2eccQ, buf, portMAX_DELAY) == pdTRUE) {
         //Serial.println("dqMqttPubTask top");
         String topic = _APP_TOPIC_PUB;
         String key(buf);

         ecc._fdpl("rvkc dqMqttPubTask ... " + topic + ":" + key ,_DBG2_MSG);
         ecc._fdpl("rvkc dec appQ " + ecc.qDepth(ecc._APP_Q,"dec"),_DBG3_MSG);

         ecc.qMqttMsg(topic, key);        
         //Serial.println("dqMqttPubTask bottom");
      } else {
         delay(100);
      }
   }
}

void Rk3kVirtualKeypadClass::begin() {
   //Serial.begin(115200);
   //Serial.println("rk3k-begin 0");
   ecc.appWsHandler = [&](JsonDocument& doc){
      return rvkc.wsHandler(doc);
   };

   //Serial.println("rk3k-begin 1");
   ecc.appEndPointExtension = [&](const EspCoreClass::EndPoint& epp){
      return rvkc.appEndPointExtension(epp);
   };

   //Serial.println("rk3k-begin 2");
   ecc.appMqttHandler = [&](const EspCoreClass::MqttMsg& M){
      return rvkc.mqttHandler(M);
   };

   //Serial.println("rk3k-begin 3");
   xTaskCreate(
      Rk3kVirtualKeypadClass::dqRk3kVKTask,
      "RK3K_TX",
      4096,
      nullptr,
      3,
      nullptr
   );

   //Serial.println("rk3k-begin 4");
   xTaskCreate(
      Rk3kVirtualKeypadClass::dqMqttPubTask,
      "RK3k_MQTT",
      4096,
      nullptr,
      3,
      nullptr
   );
  //Serial.println("rk3k-begin 5");
 
}

void Rk3kVirtualKeypadClass::loop() {  

   if (ecc.vars.enm.mqttState == ecc._MQTT_RESUB) {
      //Serial.println("rk3k loop top");
      ecc._fdpl("rvkc reconnect Topics ... mqtt ... " + String(_APP_TOPIC_SUB) ,_DBG3_MSG);

      ecc.mqtt.subscribe(_APP_TOPIC_SUB);
      ecc.vars.enm.mqttState = ecc._MQTT_CON;
      ecc._fdpl("rvkc MQTT NOW FULLY CONNECTED ",_DBG3_MSG);
      //Serial.println("rk3k loop bottom");
   }
   delay(100);
}