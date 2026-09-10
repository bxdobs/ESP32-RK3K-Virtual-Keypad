// rk3k.h
#ifndef RVKC_H
#define RVKC_H      

//#include "includes.h"

// Declarations
// DSC Virtual RK3000 values
//
class Rk3kVirtualKeypadClass {
public:
   //struct RK_Parms {
   //} rkp;

   void begin();
   void loop();
   
   // hardware routines

   // dq tasks
   static void dqRk3kVKTask(void *pv);
   static void dqMqttPubTask(void *pv);
 
   // inter Core handlers
   bool wsHandler(JsonDocument& doc);
   String appEndPointExtension(const EspCoreClass::EndPoint& epp); // no endpoint for rk3k
   bool mqttHandler(const EspCoreClass::MqttMsg& M);

};
// ---- GLOBAL INSTANCE ----
extern Rk3kVirtualKeypadClass rvkc;

#endif // RVKC_H
