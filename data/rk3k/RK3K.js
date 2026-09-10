// ============================================================================
// DSC RK3K ESP32 Virtual Keypad (HTML/js)  
// ============================================================================
//
// This Virtual Keypad originated as a VB6 App converted which was converted to 
// work in a HA Custom js Card ... HA custom Card writen with HTML and js
// VB and HA utilized fixed pixel png files with overlays to sim leds on/off
// or keypad keys presses ... there were 33 png files a base file with all 
// keypad keys up and all zone leds on and all indicators on
// 
// the HTML only version for ESP32 was taking too long to load so 2 changes 
// made ... the base image now has all zones and indicators off 
// the Leds; Red, Yellow, Green are in one file RK3K_Leds.png 39x13 Led(13x13)
// the Keys; 1-9, *, 0, #, F, A, P are in one file RK3K_Keys.png 68x68 Key(17x17)
// the Zones; 1-16 are in one file RK3K_Zones.png 99x165 Zone(33x33)
//
// display is 480 wide (x width) x 416 tall (y height)
// left relates to x or width
// top relates to y or height
//

//console.log("RK3K CARD VERSION TEST 25");

// ============================================================================
// --- KEYPAD Buttons fixed pixel COORDINATES ---
// ============================================================================
const R1   =  42;   // rows
const R2   =  98;
const R3   = 154;
const R4   = 210;
const R5   = 266;
const C1   =  62;   // columns
const C2   = 129;
const C3   = 193;

// ============================================================================
// DISPLAY ELEMENT DEFINITIONS
// ============================================================================
// COS bit order: <ABCDEFXX
// Display bits are defined by the first 6 hex ascii characters
//    A - Zone09, Zone10, Zone11, Zone12
//    B - Zone13, Zone14, Zone15, Zone16
//    C - Zone01, Zone02, Zone03, Zone04
//    D - Zone05, Zone06, Zone07, Zone08
//    E - Ready,  Armed,  Memory, ByPass
//    F - Trouble, Program, Fire, Sonalert
//
// Bit 23 = Sonalert currently has no visual or audible indicator.
//
// --- COS Led Indicator Bit Positions ---
const leds = ["ZN09","ZN10","ZN11","ZN12","ZN13","ZN14","ZN15","ZN16",
              "ZN01","ZN02","ZN03","ZN04","ZN05","ZN06","ZN07","ZN08",
              "iReady","iArmed","iMemory","iByPass","iTrouble","iProgram",
              "iFire"];      
        
// -- Display Indicator Order
const tlds = ["ZN01","ZN02","ZN03","ZN04","ZN05","ZN06","ZN07","ZN08",
              "ZN09","ZN10","ZN11","ZN12","ZN13","ZN14","ZN15","ZN16",
              "iFire", "iReady","iArmed","iMemory","iByPass","iTrouble","iProgram"];              

//  Physical keypad order in RK3K_Keys.png:
//
//   1 2 3
//   4 5 6
//   7 8 9
//   * 0 #
//   F A P
// -- Keypad Key Order
const keys = ["1","2","3",
              "4","5","6",
              "7","8","9",
            "AST","0","NMB",
              "F","A","P"];              

//------------------------------------------------------------------------------------
// To speed up the initiation of graphic elements the idea is to combine like graphics
// in to a single file called a sprite file

// Leds Sprite
// Led indicators are 13x13 pixels so Red, Yellow, and Green are being stored in one
// RK3K_Leds.png:  1 row 3 cols  39x13

function setLed(el, index) {

   if (!el) return;

   //
   //  +---------+---------+---------+
   //  |   RED   | YELLOW  |  GREEN  |
   //  |  13x13  |  13x13  |  13x13  |
   //  +---------+---------+---------+

   const x = index * 13;

   el.style.backgroundPosition = `-${x}px 0px`;
}

// Zones Sprite
// Zone indicators are 17x17 pixels
// RK3K_Zones.png 4 rows 4 cols  68x68

function setZone(el, index) {

   if (!el) return;

   // RK3K_Zones.png = 4 columns x 4 rows
   // each image = 17 x 17

   const x = (index % 4) * 17;
   const y = Math.floor(index / 4) * 17;

   el.style.backgroundPosition = `-${x}px -${y}px`;
}

// Keyss Sprite
// Key indicators are 33x33 pixels
// RK3K_Keys.png 5 rows 3 cols  99x165

function setKey(el, index) {

   if (!el) return;

   // RK3K_Keys.png = 3 columns x 5 rows
   // each image = 33 x 33

   const x = (index % 3) * 33;
   const y = Math.floor(index / 3) * 33;

   el.style.backgroundPosition = `-${x}px -${y}px`;
}

// --------------------------------------------------------------------
class Rk3kCard extends HTMLElement {

   constructor() {
      super(); // HTMLElement Constructor

      this.rk3kWS = null;

      this.drOpen = false;

      this.testActive = false;

      this.dbgDsp = false;
      this.dbgLines = [];

      // Zone rollover tips -- defaults used if /app/zns.json cannot be loaded
      this.zoneTooltips = Object.fromEntries(
         Array.from(
            { length: 16 },
            (_, i) => [`Zn${i + 1}`, `Zone ${i + 1}`]
         )
      );

      this.zoneLoadDone = false;
      this.zoneLoadTimer = null;

      //this.dspCOS = this.hexCos2binCos("000000");
      //this.dspCOS = "000000000000000000000000"; // 24 bit binary string 
      this.dspCOS = Array(24).fill("0");
   }

   // ========================================================================
   // WEBSOCKET
   // ========================================================================

   rk3k_connect() {
      this.rk3kWS = new WebSocket(`ws://${location.host}/ws`);

      this.rk3kWS.onopen = () => {
         this.zoneLoadDone = false;

    // Request Zone Location Definitions. /app/zns.json
         this.sendKey("Z");

         // Don't let a failed Z request prevent COS from starting
         this.zoneLoadTimer = setTimeout(() => {
            if (!this.zoneLoadDone) {
               this.zoneLoadDone = true;
               this.addDebugLine("> Z timeout - using default zone tips");

               // request a COS Refresh
               this.sendKey("U");
            }
         }, 1000);
      };

      this.rk3kWS.onmessage = (event) => {

         this.addDebugLine("> " + event.data);
         
         // pretest inbound message; COS messages are in side of {} but there
         // are also other messages like system or info that must be handled

         // ai added the 1st 2 ifs ... need to determine if they are valid
         if (typeof event.data !== "string" ||
             event.data.length === 0 ||
             event.data[0] !== "{") {
            this.addDebugLine("> RK3K WS data (not JSON): " + event.data);
            return;
         }

         try {
            const msg = JSON.parse(event.data);
            //console.log("RK3K WS COS0:" + String(msg.cmd), msg.data);
            // ---------------------------------------------------------------
            // COS response
            // ---------------------------------------------------------------
            if (msg.cmd === 67) {

               this.onCOS(msg.data);
               //console.log("RK3K WS COS:1", msg.data);
               return;
            }

            // ---------------------------------------------------------------
            // Zone definitions response
            // cmd 122 = ASCII 'z'
            // ---------------------------------------------------------------
            if (msg.cmd === 122) {
               //console.log("RK3K WS ZNS:", msg.data);
               //console.log("RK3K WS ZNS: ENTERED HANDLER");
               this.zoneLoadDone = true;
               clearTimeout(this.zoneLoadTimer);

               if (msg.data !== "not_found") {

                  try {
                     const zns = (typeof msg.data === "string")
                                 ? JSON.parse(msg.data)
                                 : msg.data;

                     for (let i = 0; i < 16; i++) {
                        //console.log(`RK3K WS ZNS: processing zone ${i + 1}`);
                        const key = `Z${String(i + 1).padStart(2, "0")}`;

                        if (key in zns && typeof zns[key] === "string") {
                           this.zoneTooltips[i] = "Zn" + String(i+1) + ": " + zns[key];
                           //console.log(`RK3K WS ZNS: zone ${i + 1} tooltip set to "${zns[key]}"`);
                        }
                     
                        // Update the visible rollover
                        const id = `ZN${String(i + 1).padStart(2, "0")}`;
                        //const led = this.querySelector(`#${id}`);
                        const hit = this.querySelector(`#${id}_hit`);

                        if (hit) {
                           const tip = hit.querySelector(".tooltip");
                           //console.log(`RK3K WS ZNS: found hit for ${id}`);

                           if (tip) {
                              //console.log(`RK3K WS ZNS: updating tooltip for ${id} to "${this.zoneTooltips[i]}"`);
                              tip.textContent = this.zoneTooltips[i];
                           }  
                        }
                     }
                  
                     //console.log("RK3K WS ZNS:", this.zoneTooltips);

                  } catch (e) {
                     //console.log("RK3K WS ZNS JSON error:", e);
                     this.addDebugLine("> ZNS JSON error: " + e.message);
                  }

               } else {
                  //console.log("RK3K WS ZNS: not_found");
                  this.addDebugLine("> ZNS not found - using defaults");
               }

               // Zone load is finished, successful or not.
               // Now request the initial COS.
               this.sendKey("U");
               return;
            }

         } catch (e) {
            //console.log("RK3K WS data with error:", event.data);
            this.addDebugLine("> RK3K WS data with error: " + e.message);
         }
         
      };
   }

   connectedCallback() {
      this.innerHTML = `
<style>
html, body {
  margin: 0;
  width: 100%;
  height: 100%;
  background: #000000;
}

body {
  overflow: hidden;
}

:host {
  display: block;
  width: 100vw;
  height: 100vh;
  background: #000000;
}

.wrapper {
  display: flex;
  justify-content: center;
  align-items: center;
  width: 100%;
  height: 100%;
  background-color: #000000; /* dashboard black */
}

#DSC {
  position: relative;
  width: 480px;
  height: 416px;
}

#rk3kdisplay {
  width: 480px;
  height: 416px;
  display: block;
}

.led {
  position:absolute;
  width: 13px;
  height: 13px;
  background-image: url("/rk3k/RK3K_Leds.png");
  background-repeat: no-repeat;
  pointer-events: none;
  visibility:hidden;
}

.zoneled {
  position:absolute;
  width: 17px;
  height: 17px;
  background-image: url("/rk3k/RK3K_Zones.png");
  pointer-events: none;
  visibility:hidden;
}

.key-press {
  position:absolute;
  width: 33px;
  height: 33px;
  background-image: url("/rk3k/RK3K_Keys.png");
  background-repeat: no-repeat;
  visibility:hidden;
}

.door {
  visibility:visible;
  left: 0;
  top: 0;
  position:absolute;
  width:312px;
  height:416px;
  z-index:2;
}

.zoneled-wrapper {
   position: absolute;

   width: 17px;
   height: 17px;

   cursor: default;
}

.button {
  position:absolute;
  width:33px;
  height:33px;
  cursor:pointer;
  z-index:1;
}

.doorbtn {
  position:absolute;
  left:234px;
  top:354px;
  width:33px;
  height:33px;
  cursor:pointer;
  z-index:3;
}

.dbgDspBtn{
   position:absolute;
   left:420px;
   top: 260px;
   width: 33px;
   height: 33px;
   cursor:pointer;
   z-index: 997;
}  

.debug-close-btn {
   width: 28px;
   height: 28px;
   margin: 2px;
   padding: 0;
   border: 1px solid #808080;
   background: #eeeeee;
   color: #000000;
   font-family: Arial, sans-serif;
   font-size: 22px;
   line-height: 24px;
   text-align: center;
   cursor: pointer;
   border-radius: 3px;
}

.debug-close-btn:active {
   background: #cccccc;
}

.helpbtn {
   position:absolute;
   left:420px;
   top: 210px;
   width: 33px;
   height: 33px;
   cursor:pointer;   
   z-index: 998;   
}

.rk3k-back-btn {
  position: absolute;
  left: 445px;
  top: 375px;
  width: 24px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #000000;
  border-radius: 4px;
  cursor: pointer;
  z-index: 999; /* above overlays */
}

.tooltip {
  position: absolute;
  left: 50%;
  top: -32px;
  transform: translateX(-50%);
  padding: 4px 8px;
  background: #ffffcc;
  color: #000000;
  border: 1px solid #808080;
  border-radius: 3px;
  font-family: Arial, sans-serif;
  font-size: 12px;
  white-space: nowrap;
  visibility: hidden;
  opacity: 0;
  pointer-events: none;
  z-index: 1000;
  transition: opacity 0.1s;
}

.doorbtn:hover .tooltip,
.helpbtn:hover .tooltip,
.rk3k-back-btn:hover .tooltip,
.dbgDspBtn:hover  .tooltip,
.zoneled-wrapper:hover .tooltip {
  visibility:visible;
  opacity: 1;
}

.zoneled-wrapper.active .tooltip {
   visibility: visible;
   opacity: 1;
}

.debug-sidebar {
  position: fixed !important;

  top: 0 !important;
  right: 0 !important;
  bottom: 0 !important;

  width: 320px !important;
  height: 100vh !important;

  margin: 0 !important;
  padding: 0 !important;

  background: #ffffff !important;
  color: #000000 !important;

  border-left: 2px solid #333 !important;

  display: none !important;
  flex-direction: column !important;

  box-sizing: border-box !important;

  z-index: 2000 !important;
}

.debug-sidebar.open {
  display: flex !important;
}

.debug-titlebar {
   width: 100%;
   height: 42px;
   min-height: 42px;

   display: flex;
   align-items: center;
   justify-content: space-between;

   padding: 0 8px 0 12px;

   background: #333;
   color: #fff;

   box-sizing: border-box;
}

.debug-title {
   margin: 0;
   padding: 0;

   font-family: Arial, sans-serif;
   font-size: 18px;
   font-weight: bold;
}

.debug-close {
   width: 32px;
   height: 30px;

   margin: 0;
   padding: 0;

   background: #555;
   color: #fff;

   border: 1px solid #aaa;
   border-radius: 4px;

   font-family: Arial, sans-serif;
   font-size: 18px;
   font-weight: bold;

   line-height: 28px;
   text-align: center;

   cursor: pointer;
}

.debug-list {
  position: static !important;

  flex: 1 !important;

  width: 100% !important;
  height: auto !important;

  margin: 0 !important;
  padding: 6px !important;

  overflow-x: hidden !important;
  overflow-y: auto !important;

  background: #fff !important;
  color: #000 !important;

  box-sizing: border-box !important;

  font-family: monospace !important;
  font-size: 13px !important;
  line-height: 18px !important;

  white-space: pre-wrap !important;
  word-break: break-all !important;
}

</style>

<div class="wrapper">

<div id="RK3K">

<img id="rk3kdisplay" src="/rk3k/RK3K_Keypad.png">

<img id="rk3kdoor" class="door" src="/rk3k/RK3K_Door.png">

<div id="door_btn" class="doorbtn" tabindex="0">
 <span class="tooltip">Toggle Door</span>
</div>

<div id="help_btn" class="helpbtn" tabindex="0">
 <span class="tooltip">Help</span>
</div>

<div id="dbgDspBtn" class="dbgDspBtn" tabindex="0">
 <span class="tooltip">Debug Display</span>
</div>

 ${keys.map(key => `
         <div
            id="iK${key}"
            class="key-press"
         ></div>
      `).join("")}
${[...Array(16)].map((_, i) => {
  const n   = i + 1;
  const col = n <= 7 ? 347 : (n <= 12 ? 372 : 397);
  const row = [14,39,64,89,114,139,164,14,39,64,89,114,14,39,64,89][i];
  const id  = `ZN${String(n).padStart(2,"0")}`;

  return `
    <div id="${id}_hit"
         class="zoneled-wrapper"
         tabindex="0"
         style="position:absolute;
                left:${col}px;
                top:${row}px;
                width:17px;
                height:17px;">

      <div id="${id}" class="zoneled" > </div>

      <div class="tooltip">Zone ${n}</div>
    </div>
  `;
}).join("")}

      <div
         id="iFire"
         class="led"
         style="left:407px; top:191px;"
      ></div>

      <div
         id="iReady"
         class="led"
         style="left:349px; top:249px;"
      ></div>

      <div
         id="iArmed"
         class="led"
         style="left:349px; top:274px;"
      ></div>

      <div
         id="iMemory"
         class="led"
         style="left:349px; top:299px;"
      ></div>

      <div
         id="iByPass"
         class="led"
         style="left:349px; top:324px;"
      ></div>

      <div
         id="iTrouble"
         class="led"
         style="left:349px; top:349px;"
      ></div>

      <div
         id="iProgram"
         class="led"
         style="left:349px; top:374px;"
      ></div>
      ${keys.map(key => `
         <div
            id="K${key}"
            class="button"
         ></div>
      `).join("")}

    <div class="rk3k-back-btn" tabindex="0">
      <svg width="20" height="20" viewBox="0 0 24 24">
        <path fill="white"
        d="M20,11V13H8L13.5,18.5L12.08,19.92L4.16,12L12.08,4.08L13.5,5.5L8,11H20Z"/>
      </svg>
      <span class="tooltip">Exit</span>
      </div>
   </div>

   <div id="debugSidebar" class="debug-sidebar">

      <div class="debug-titlebar">
         <span class="debug-title">RK3K DEBUG DISPLAY</span>
         <button id="debugClose" class="debug-close">X</button>
      </div>

      <div id="debugList" class="debug-list"></div>
   </div>
</div>
      `;
      
      // ====================================================================
      // ASSIGN SPRITE POSITIONS
      // ====================================================================

      // LED sprite:
      //
      // 0 = Red
      // 1 = Yellow
      // 2 = Green

      setLed(
         this.querySelector("#iFire"),
         0
      );

      setLed(
         this.querySelector("#iReady"),
         2
      );

      setLed(
         this.querySelector("#iArmed"),
         0
      );

      setLed(
         this.querySelector("#iMemory"),
         0
      );

      setLed(
         this.querySelector("#iByPass"),
         0
      );

      setLed(
         this.querySelector("#iTrouble"),
         1
      );

      setLed(
         this.querySelector("#iProgram"),
         0
      );

      // ====================================================================
      // ASSIGN 16 ZONE SPRITES
      // ====================================================================

      for (let i = 0; i < 16; i++) {

         const id =
            `ZN${String(i + 1).padStart(2, "0")}`;

         setZone(
            this.querySelector(`#${id}`),
            i
         );
      }

      // ====================================================================
      // ASSIGN 15 KEY SPRITES
      // ====================================================================

      keys.forEach((key, i) => {

         setKey(
            this.querySelector(`#iK${key}`),
            i
         );
      });

      window.addEventListener("keydown", this._onKeyDown, true);

      this.rk3k_connect();

      const back = this.querySelector('.rk3k-back-btn');

      if (back) {
         
         back.addEventListener('click', () => {
            this.fnExit();
         });
      }

      const doorBtn = this.querySelector("#door_btn");

      if (doorBtn) {
         //console.log("RK3K WS door button found, adding click event listener");
         doorBtn.addEventListener("click", () => {
            this.toggleDoor();
         });
      }

      const dbgDspBtn = this.querySelector("#dbgDspBtn");
      const debugSidebar = this.querySelector("#debugSidebar");
      const debugClose = this.querySelector("#debugClose");

      if (dbgDspBtn) {
         dbgDspBtn.addEventListener("click", () => {
            this.toggleDebugDisplay();
         });   
      }

      if (debugClose) {
         debugClose.addEventListener("click", () => {
            this.toggleDebugDisplay();
         });
      }

      const helpBtn = this.querySelector("#help_btn");

      if (helpBtn) {
         helpBtn.addEventListener("click", () => {
            window.location.href = "/rk3k/rk3k_help.html";
         });
      }
      // ====================================================================
      // TOUCH ROLLOVER SUPPORT
      // iPhone / iPad Safari does not reliably support :hover.
      //
      // Existing mouse :hover remains unchanged.
      // On touch devices, touching one of these objects temporarily
      // activates the same tooltip using the active class.
      // , .doorbtn, .helpbtn, .dbgDspBtn"
      // ====================================================================

      const rolloverTargets = this.querySelectorAll(
         ".zoneled-wrapper" 
      );
/*
      rolloverTargets.forEach(el => {

         el.addEventListener("pointerdown", (e) => {

            // Only add touch rollover for actual touch input.
            // Mouse continues to use the existing CSS :hover.
            if (e.pointerType === "touch") {

               // Remove any previous touch rollover
               rolloverTargets.forEach(other => {
                  if (other !== el) {
                     other.classList.remove("active");
                  }
               });

               // Activate this rollover
               el.classList.add("active");

               // Remove it after a short delay
               clearTimeout(el._rolloverTimer);

               el._rolloverTimer = setTimeout(() => {
                  el.classList.remove("active");
               }, 1500);
            }
         });

         el.addEventListener("pointerup", (e) => {

            if (e.pointerType === "touch") {
               clearTimeout(el._rolloverTimer);

               el._rolloverTimer = setTimeout(() => {
                  el.classList.remove("active");
               }, 1000);
            }
         });

         el.addEventListener("pointercancel", () => {
            clearTimeout(el._rolloverTimer);
            el.classList.remove("active");
         });
      });
*/
      rolloverTargets.forEach(el => {

         el.addEventListener("pointerdown", (e) => {

            if (e.pointerType !== "touch") {
               return;
            }

            // Remove rollover from every other zone
            rolloverTargets.forEach(other => {
               if (other !== el) {
                  other.classList.remove("active");
                  clearTimeout(other._rolloverTimer);
               }
            });

            // Activate this zone
            el.classList.add("active");

            // Cancel any previous timer for this zone
            clearTimeout(el._rolloverTimer);

            // Automatically remove rollover after 1.5 seconds
            el._rolloverTimer = setTimeout(() => {
               el.classList.remove("active");
               el._rolloverTimer = null;
            }, 1500);
         });

         el.addEventListener("pointercancel", (e) => {

            if (e.pointerType === "touch") {
               clearTimeout(el._rolloverTimer);
               el._rolloverTimer = null;
               el.classList.remove("active");
            }
         });

      });

      const place = () => {
         let i = 0
         for (let r = 1; r <= 5; r++) {
            for (let c = 1; c <= 3; c++) {
               let bs = this.querySelector("#K" + keys[i]);
               let tp = this.querySelector("#iK" + keys[i]); 
               let top = (r === 5 ? R5 : r === 4 ? R4 : r === 3 ? R3 : r === 2 ? R2 : R1) + "px";
               let left = (c === 3 ? C3 : c === 2 ? C2 : C1) + "px";
               bs.style.top  = top;
               tp.style.top  = top;
               bs.style.left  = left;
               tp.style.left  = left;
               i++;
            }
         }      
      }

      place();

      // keypad click handlers
      this.querySelectorAll(".button").forEach(btn => {
         btn.addEventListener("click", (e) => {

            const id = btn.id;
            const kc = id.substring(1);   // remove leading K

            let key = kc;

            if (key === "AST") key = "*";
            if (key === "NMB") key = "#";

            if ((e.ctrlKey || e.shiftKey) && "fap".includes(key)) {
               key = key.toUpperCase();
            }

            this.pressKey(key);
         });
      });
   }
   
   _onKeyDown = (e) => {
  
      //console.log(
      //   "RK3K KEY:",
      //   "key=[" + e.key + "]",
      //   "code=[" + e.code + "]",
      //   "ctrl=[" + e.ctrlKey + "]",
      //   "shift=[" + e.shiftKey + "]",
      //   "alt=[" + e.altKey + "]",
      //   "target=[" + e.target.tagName + "]"
      //);

      // Let the debug window handle normal keyboard operations
      if (e.target.closest("#debugSidebar")) {
         return;
      }

      let k = e.key;

      if (e.ctrlKey && (k === "c" || k === "C")) {
         return;
      }

      if (e.ctrlKey && (k === "S" || k === "s")) {
         e.preventDefault();
         e.stopPropagation();
         e.stopImmediatePropagation();
         this.fnTest();
         return;
      }

      // Escape or clicking white arrow returns to default dashboard
      if (e.code === "Escape" || (e.ctrlKey && (k == "X" || k == "x"))) {
         e.preventDefault();
         e.stopPropagation();
         e.stopImmediatePropagation();
         //window.location.href = "/";
         this.fnExit();        
         return;
      }

      if (k == "?" || (e.ctrlKey && (k == "H" || k == "h"))) {
         e.preventDefault();
         e.stopPropagation();
         e.stopImmediatePropagation();
         window.location.href = "/rk3k/rk3k_help.html";
         return;
      }

      // SPACE toggles door OR Ctrl-D toggles door
      if (e.code === "Space" ) {
         e.preventDefault();
         e.stopPropagation();
         e.stopImmediatePropagation();
         this.toggleDoor();
         return;
      }

      if (e.ctrlKey && (k == "D" || k == "d")) {
         e.preventDefault();
         e.stopPropagation();
         e.stopImmediatePropagation();
         this.toggleDebugDisplay();
         return;
      }  

      // force all CTRL SHIFT keys to upper case chars
      // special cases
      // F -> Fire         
      // A -> Ambulance   
      // P -> Police        
      // U -> Refresh cos 
      // R -> reset Rk3k Interface 
      // V -> Rk3k Interface Version
      if (e.ctrlKey || e.shiftKey) {
         k = e.key.toUpperCase();
         e.preventDefault();
         e.stopPropagation();
         e.stopImmediatePropagation();
         if ("FAPURV".includes(k)) {
            this.pressKey(k);
         }  
         return;
      }

      // keypad valid chars
      if ("0123456789fap*#".includes(k)) {
         if (this.drOpen) {
            this.pressKey(k);
         }  
      }
   };

   // ========================================================================
   // get the display COS 
   // cos can contain both cos data and information 
   // display data is prefixed with < or > in the form <DDDDDDKK or >DDDDDDKK
   // data is in ASCII HEX format and the display data is in the first 6 chars
   // getDspCos only returns DDDDDD of COS's prefixed with > or < 
   // ========================================================================
   getHexCos(pnlCOS) { // panel cos 
      let hexCos = null;

      if (typeof pnlCOS == "string") {

         let hx = pnlCOS.trim();

         // If framed, drop the first char
         if (hx.startsWith("<") || hx.startsWith(">")) {
           hx = hx.slice(1);

           // Must be at least 6 chars after framing
           if (hx.length >= 6) { 

              hx = hx.slice(0, 6).toUpperCase();

              // Validate 6 hex nibbles
              if (/^[0-9A-F]{6}$/.test(hx)) {
                 hexCos = hx;  
              }
           }
         }
      }
      return hexCos;
   }
  
   // ascii hex cos to 24 bit binary cos 
   hexCos2binCos(hexCos) {
      // convert to 24-bit binary
      let binCos = "";
      for (const ch of hexCos) {
         binCos += parseInt(ch, 16).toString(2).padStart(4, "0");
      }

      return binCos; // 24 chars
   }

   fnExit() {
      if (window.history.length > 1) {
         window.history.back();
      } else {
         window.location.href = "/";
      }
   }

   // refresh the display from COS
   dspRefresh(hexCOS) {
      if (!this.testActive || (this.testActive && hexCOS == "000000")) {
         const bCOS = this.hexCos2binCos(hexCOS); // get the 24 bit binary values for the cos (hex)
         // NOTE: 0 is a number ... bCOS[23] is the Sonalert could be used to beep the terminal?
         
         //console.log("dspRefresh [" + hexCOS + ((this.testActive)? "] tA" : "] tia"));

         // COS has 8 Ascii hexidecimal characters DDDDDDKK where D is Display data and K is Key data  
         // 0xABCDEF 
      
         // where the bits of each char represent the following display elements 
         //    A - Zone09,  Zone10,  Zone11, Zone12
         //    B - Zone13,  Zone14,  Zone15, Zone16
         //    C - Zone01,  Zone02,  Zone03, Zone04
         //    D - Zone05,  Zone06,  Zone07, Zone08
         //    E - Ready,   Armed,   Memory, ByPass
         //    F - Trouble, Program, Fire,   Sonalert
         leds.forEach((led, i) => { 
            if (bCOS[i] !== this.dspCOS[i]) {
               //console.log(`RK3K DSP REFRESH: ${led} ${bCOS[i]} (was ${this.dspCOS[i]})`);
               this.querySelector("#" + led).style.visibility = (bCOS[i] === "1") ? "visible" : "hidden";
               this.dspCOS[i] = bCOS[i];  // save new state
            }
         }); 
      }
   }

   onCOS(cosString) {
      const hexCOS = this.getHexCos(cosString);
      if (hexCOS) this.dspRefresh(hexCOS);
   }

   sendKey(k) {

      if (k === "Z") {
         if (this.rk3kWS && this.rk3kWS.readyState === WebSocket.OPEN) {
            //console.log("RK3K WS sending ZNS request");
            this.rk3kWS.send(JSON.stringify({
               cmd: 90,
               data: "zns.json"
            }));
         }  
      } else {   
         const payload = {
            who:  "Virtual RK3K-Esp32 Keypad",
            when: new Date().toISOString(),
            what: k
         };

         const keyString = JSON.stringify(payload);

         if (this.rk3kWS && this.rk3kWS.readyState === WebSocket.OPEN) {
            this.rk3kWS.send(JSON.stringify({
               cmd: 75,
               data: keyString
            }));
         }
      }
   }

   // ========================================================================
   // UI KEY PRESS HANDLING
   // ========================================================================
   toggleDoor() {

      this.drOpen = !this.drOpen;

      const door = this.querySelector("#rk3kdoor");
     
      if (door) {
         door.style.visibility = this.drOpen ? "hidden" : "visible";         
      }
   }
  
   toggleDebugDisplay() {
      this.dbgDsp = !this.dbgDsp;
      const sidebar = this.querySelector("#debugSidebar");

      if (!sidebar) return;

      if (this.dbgDsp) {
         sidebar.classList.add("open");
      } else {
         sidebar.classList.remove("open");
      }
   }
   
   addDebugLine(msg) {

      // Only capture debug data while display is open
      if (!this.dbgDsp) return;

      const debugList = this.querySelector("#debugList");

      if (!debugList) return;

      // Keep maximum of 100 lines
      this.dbgLines.push(String(msg));

      // Add new line without rebuilding the entire display
      const div = document.createElement("div");
      div.className = "debug-line";
      div.textContent = String(msg);
      debugList.appendChild(div);

      // Remove oldest line from display and memory
      if (this.dbgLines.length > 100) {
         this.dbgLines.shift();

         if (debugList.firstElementChild) {
            debugList.removeChild(debugList.firstElementChild);
         }
      }

      // Always show newest message
      debugList.scrollTop = debugList.scrollHeight;
   }

   // this function used to simulate a button press on the screen by unhiding 
   // the button pressed or clicked for a short period of time 
   pressKey(kc) {
      let othr  = false;
      let kpx   = null;
      let kpz   = "";
      let emerg = false;

      const msk = "0123456789AaFfPp*#".includes(kc); // true if kc in list

      // get the button id
      switch (kc) {
         case "0": kpz = "#iK0";   break;
         case "1": kpz = "#iK1";   break;
         case "2": kpz = "#iK2";   break;
         case "3": kpz = "#iK3";   break;
         case "4": kpz = "#iK4";   break;
         case "5": kpz = "#iK5";   break;
         case "6": kpz = "#iK6";   break;
         case "7": kpz = "#iK7";   break;
         case "8": kpz = "#iK8";   break;
         case "9": kpz = "#iK9";   break;
         case "*": kpz = "#iKAST"; break;
         case "#": kpz = "#iKNMB"; break;
         case "f": kpz = "#iKF";   break;
         case "a": kpz = "#iKA";   break;
         case "p": kpz = "#iKP";   break;
         case "F": kpz = "#iKF";   emerg = true; break;
         case "A": kpz = "#iKA";   emerg = true; break;
         case "P": kpz = "#iKP";   emerg = true; break;
         default:  othr = true;   break;
      }
      this.addDebugLine(`< kc=${kc}, emerg=${emerg}, drOpen=${this.drOpen}`);
      // Handle visual press for normal keys (door must be open)
      if ((msk || emerg) && this.drOpen) {

         // get the button pointer 
         kpx = this.querySelector(kpz);
         if (!kpx) return; // THIS SHOULD NEVER HAPPEN!!! 

         // graphically sim a button closure
         kpx.style.visibility = "visible";
         clearTimeout(kpx._t);
         kpx._t = setTimeout(() => {
            kpx.style.visibility = "hidden";
         }, 150);

         // send kc to esp32
         this.sendKey(kc);
         return;  // exit to prevent double send
      }

      // Emergency keys or other programming keys
      if (othr || ( emerg && !this.drOpen)) {
         // send kc to esp32
         this.sendKey(kc);
         // No return needed here
      }
   }

   fnTest() {
      this.testActive = true;
      //console.log("fnTest started");
      this.onCOS(">000000FF");
      //console.log("fnTest after clear");
      tlds.forEach((led, i) => {
         const el = this.querySelector("#" + led);
         //console.log("fnTest dsp item " + String(i)); 
         // Each LED starts 500ms after the previous one
         setTimeout(() => {
            el.style.visibility = "visible";

            setTimeout(() => {
               el.style.visibility = "hidden";
            }, 500);

         }, i * 500);
      });

      // total duration = 23 * 500ms
      setTimeout(() => {
         this.testActive = false;
         //console.log("fnTest complete");
         this.sendKey("U");
         //console.log("fnTest after ^U");  
      }, tlds.length * 500);
   }
}

customElements.define("rk3k-card", Rk3kCard);
