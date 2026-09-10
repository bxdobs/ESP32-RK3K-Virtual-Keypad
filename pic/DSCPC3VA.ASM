           list n=78, p=PIC16C84, r=HEX
;*******************************************************************************
           TITLE "PC RS232C -> DSC PC3000 Alarm Panel Interface (RK3000 Keypad)"
;
;
;    Comments: PIC-16C84/PC RS232C Interface to the DSC PC3000 Alarm Panel
;              via the RK3000 Keypad Interface
;
;         06-Apr-95  Completed the DSC interface
;         02-Jul-97  Changed to 4800 Baud
;
; This design provides;
;     - full duplex 2400 Baud with 8 bits no parity 1 stop using
;       a standard 5.0688 MHz communication xtal.
;     - no RS232C interface chips
;     - power supply not required <7ma required from keypad
;     - Hardware flow control using RTS and CTS
;     - 4 byte circular Rx buffer (FIFO)
;
; revised 13-Apr-95
;     - added; get updated keypad status ctrl-U
;     - added; display DSC keypad activity with hardware enable/disable i/p
 PAGE
; The DSC RK-3000 serial keypad specifications.
;
;       Red    = +12V    iMax 126mA iNominal 30mA
;       Black  = GND
;       Yellow = CLOCK
;       Green  = TX/RX
;
;           column 1      column 2      column 3
;   row 1      1             2             3
;   row 2      4             5             6
;   row 3      7             8             9
;   row 4      *             0             #
;   row 5     Fire       Ambulance      Police
;
; The serial protocol is made up of a continuous stream of multiplexed data.
; The RK-3000 (which has 24 indicators) has a data stream of 47 1mSec cells
; followed by a 22mSec sonalert cell (69mSec total). The odd cells are used
; for the keypad row/column closures and the even cells are used for the 24
; indicators.
;
; The RK-3000 69mSec serial clock frame is as follows: (Clock)
;           ³<------------------69mSec------------------>³
;           ³                               ³<--22mSec-->³
;   ÄÄÄÄÄÄÄÄ¿  ÚÄÄ¿       ÄÄ¿  ÚÄÄ     ÄÄ¿  ÚÄÄÄÄÄÄÄÄÄÄÄÄ¿
;      48   ³01³02³03 ... 16³17³18 ... 46³47³     48     ³
;           ÀÄÄÙ  ÀÄÄ       ÀÄÄÙ         ÀÄÄÙ            À
;
; The RK3000 69mSec serial data frame is as follows:  (TX/RX)
;           ³<------------------69mSec------------------>³
;           ³                               ³<--22mSec-->³
;   ÄÄÄÄÄÄÄÄÂÄÄÂÄÄÂÄÄ     ÄÄÂÄÄÂÄÄ     ÄÄÂÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÂ
;      48   ³01³02³03 ... 16³17³18 ... 46³47³     48     ³
;   ÄÄÄÄÄÄÄÄÁÄÄÁÄÄÁÄÄ     ÄÄÙ  ÀÄÄ     ÄÄÙ  ÀÄÄÄÄÄÄÄÄÄÄÄÄÁ
;
;       cell                             cell
;       01    row 5                      02    Zone 09
;       03    column 1                   04    Zone 10
;       05    column 2                   06    Zone 11
;       07    column 3                   08    Zone 12
;       09    row 4                      10    Zone 13
;       11    row 3                      12    Zone 14
;       13    row 2                      14    Zone 15
;       15    row 1                      16    Zone 16
;   C1 C2 C3 R1 R2 R3 R4 R5              18    Zone 01
; 1  L        L                          20    Zone 02
; 2     L     L                          22    Zone 03
; 3        L  L                          24    Zone 04
; 4  L           L                       26    Zone 05
; 5     L        L                       28    Zone 06
; 6        L     L                       30    Zone 07
; 7  L              L                    32    Zone 08
; 8     L           L                    34    Ready
; 9        L        L                    36    Arm
; *  L                 L                 38    Memory
; 0     L              L                 40    Bypass
; #        L           L                 42    Trouble
; F  L                    L              44    Program
; A     L                 L              46    Fire
; P        L              L              48    Sonalert
;
; The circuit consists of 3*8 bit serial shift in registers parallel latched
; with the strobe and 1 8 bit parallel load serial shift out register. The
; strobe is generated 7mSec after the start of the 48th clock (rising edge).
; The strobe latches the 24 indicators and loads the keypad shift out register.
; The rising edge of the clock is used to shift in and out the data (the clock
; is shifted by 500uSec for the shift in registers). Note: the shift out data
; can be late (measured 100uSec).
;                                >³³< 100uSec
;           ÚÄÄÄÄÄÄÄÄÄÄ¿          Ú¿         |          ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;  sonalert ³  row 5   ³  zone 9  ³³ col 1   |  zone 10 ³  col 2   | zone 10  |
; ÄÄÄÄÄÄÄÄÄÄÙ          ÀÄÄÄÄÄÄÄÄÄÄÙÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ          |          |
;                                   col 1 on                        zone 10 on
; RS232C - PC to DSC Interface  Apr/95                   
;
;   1 - male db9 connector      2 - 22pf                   PC DTE
;   1 - female db9 connector    2 - .001uf               db9 - db25
;   1 - pc board                3 - .1uf                  3 tx   2
;   1 - case                    1 - 1uf                   2 rx   3
;   1 - 10 ohm                  1 - 10uf                  7 rts  4
;   2 - 470 ohm                 1 - 5.0688 MHz            8 cts  5
;  13 - 10k  (5 and 1 sip)      1 - 1N4148                5 gnd  7
;   1 - 1k                      2 - 1N4150                6 dsr  6
;   1 - 2k7                     1 - 1N5233B 6V Zener      4 dtr 20
;   1 - 3k3                     1 - LED green             1 cd   8
;   2 - 100k                    2 - 2N3904                9 ri  22
;   2 - 470k                    1 - 16C84-10  PIC
;
; PC  DTE  DCE
;       db25
;  RX<(3)--(3)-/\/\/\/-----------------------------+--/\/\/\/----+
;                470                               |    10k      |
; CTS<(5)--(5)-/\/\/\/------+---/\/\/\/---+        |            ///
;                470        |     10k     |
; ^ +5V2                    |            ///       |
; |  |\ |                   |                      |
; +--| >|--/\/\/\/-------+  +--------------------+ |
; |  |/ |    2k7         |     _______________   | |
; |  LED                 |    < RA2   U   RA1 >--+ |
; |   1N4148T            |    < RA3       RA0 >----+
; |    | /|           1k +----< RA4   1  Osc1 >------------------+
; +----|< |---+--+--/\/\/\/---< /MCLR 6  Osc2 >------+           |
; |    | \|   | _|_   +-------< Vss   C   Vdd >--+   |     _     |
; |           | ___1uf| +-----< RB0   8   RB7 >  |   +---||_||---+
; +--/\/\/\/--+  +----+ |  +--< RB1   4   RB6 >  |   | 5.0688MHz |
;       10k      |      |  |  < RB2       RB5 >  |  _|_         _|_
;               ///     |  |  < RB3       RB4 >  |  ___22pf     ___22pf
;  TX>(2)--(2)-/\/\/\/--+  |   ---------------   |   |           |
;               470k       |                     |  ///         ///
; RTS>(4)--(4)-/\/\/\/-----+                     |
;               470k                             +---------------+
;                                  +-----------------+           |
;                  1N4150   ^ Vi   |                 |           |
;                   |\ |    |      |    3k3       |/-+    ^ +5V2 |
; DTR>(20)-(20)+   -| >|-   +------+--/\/\/\/--+--|       |      |
;              |    |/ |    |                  |  |\>+----+------+
; DSR<(6)--(6)-+           _|_        1N5233B  | 2N3904  _|_
;                          ___10uf      |\ \   |         ___.1uf
; GND (7)--(7)-+            |       +---| >|---+          |
;              |           ///      |   |/ \             ///
;             ///                  ///  6V .5W                 Alarm Panel
;                                                              Keypad I/O
;                                          10                      db9
;                  10k    |/-+-----------/\/\/\/-----------+-->8 Green Wire
; +--------------/\/\/\/--|   2N3904                       |
; |                       |\>+-----+                       |
; |                                |                       |          ^ Vi
; |       10k     _______________ ///      10k      100k   |   10k    |
; |  +--/\/\/\/--< RA2   U   RA1 >    +--/\/\/\/-+-/\/\/\/-+-/\/\/\/--+
; |  |      +----< RA3       RA0 >    |         _|_
; | ///     |    < RA4   1  Osc1 >    |         ___.001uf  +-->6 Yellow Wire
; |         |    < /MCLR 6  Osc2 >    |          |         |
; +---------+    < Vss   C   Vdd >    |         ///        |          ^ Vi
;                < RB0   8   RB7 >----+    10k      100k   |   10k    |
;         10k    < RB1   4   RB6 >-------/\/\/\/-+-/\/\/\/-+-/\/\/\/--+
;    +--/\/\/\/--< RB2       RB5 >----+         _|_Vi ^ 1N4150
;    +--/\/\/\/--< RB3       RB4 >--+ |   .001uf___   |  | /|
;    |    10k     ---------------   | |          |    +--|< |->2 Red Wire
;   ///                             | |         ///  _|_ | \|
;                                   | |    10k       ___.1uf
;                                   | +--/\/\/\/--+   |
;                                   +----/\/\/\/--+---+------->4 Black Wire
;                                          10k    |
;                                                ///

           INCLUDE "PIC16C84.H"
; Fuses:
;  OSC  = XT
;  PWDT = ON
;  WDT  = ON
;  CP   = OFF   Note: this WILL be ON for release

 __FUSES _XT_OSC&_PWDT_ON&_WDT_ON&_CP_OFF
 __IDLOCS h'3341'

tmrdelay   equ d'256'-d'132'+d'3'  ; 104 uSec TMR0 interval
bitlen     equ d'2'                ; (1/baud)/TMR0 interval
txbitcnt   equ d'20'               ; (TX Bits + 2) * bitlen
txmod      equ bitlen-1            ; bitlen-1
rxinitcnt  equ d'3'                ; bitlen-(bitlen/2)

#define rxbuf    _ind0             ; RS232 Indirect Pointer to Next Rx FIFO Byte
#define rxtail   _fsr              ; RS232 Pointer to Next Rx FIFO Byte
#define rxptr    _fsr              ; RS232 Pointer to Next Rx FIFO Byte
#define fifo4    h'23'             ; FIFO Depth = 4 bytes
fifomask equ fifo4                 ; Set FIFO Depth
#define CR h'0D'                   ; Carriage Return
#define keydown 3                  ; 786 mSec keypad down
#define keyup 3                    ; 786 mSec keypad up before next key

           CBLOCK 0x0C
             S_Save                ;0C Status register - used during irq
             W_Save                ;0D W register - used during irq
             flags                 ;0E User Flag register for User Programs
             moreflags             ;0F More user flags for User Programs
             portb                 ;10 Port B holding register
             rxhead                ;11 RS232 Rx FIFO Head Pointer
             rxtail_Save           ;12 RS232 Rx FIFO Tail Pointer
             txreg                 ;13 RS232 Tx O/P Register
             txbuf                 ;14 RS232 Tx Holding Register
             txcnt                 ;15 RS232 Tx O/P Bit Counter
             rxreg                 ;16 RS232 Rx I/P Register
             rxcnt                 ;17 RS232 RX I/P Bit Counter
             Mscratch              ;18 Mainloop Scratchpad Register
             Iscratch              ;19 irq scratchpad register
             dscnt                 ;1A data read offset counter
             dscth                 ;1B Keypad timer high
             dsctl                 ;1C Keypad timer low
             dsckey                ;1D Keypad output register
             keypad                ;1E Keypad shift register
      ;      smplreg               ;1F DSC sample bit register (I/P Noise?)
             sunreg                ;1F
             rxfifo0               ;20 RS232 Rx FIFO (2, 4, 8 or 16 Bytes)
             rxfifo1               ;21
             rxfifo2               ;22
             rxfifo3               ;23
             dsco0                 ;24 display COS register
             dsco1                 ;25 display COS register
             dsco2                 ;26 display COS register
             dsco3                 ;27 keyin COS register
             dsco4                 ;28 keyin COS register
             dsco5                 ;29 keyin COS register
             dsci0                 ;2A display shift register
             dsci1                 ;2B display shift register
             dsci2                 ;2C display shift register
             dsci3                 ;2D keyin shift register
             dsci4                 ;2E keyin shift register
             dsci5                 ;2F keyin shift register
           ENDC

#define    txflg   flags,0         ; RS232 Tx Flag
#define    stopbit flags,1         ; RS232 Stop Bit
#define    ctsflg  flags,2         ; RS232 CTS Flag
#define    strtsun flags,3
#define    stpsun  flags,4
#define    xflag   flags,5
#define    lstclk  flags,6         ; last dsc keypad clock level
#define    emerg   flags,7         ; keypad emergency function flag

#define    pass1    moreflags,0    ; keypad syncronization flag
#define    dsckeydn moreflags,1    ; keypad keypress done flag
#define    dsckpflg moreflags,2    ; keypad keypress start flag
#define    ctrlu    moreflags,3    ; ctrl-U flag
#define    rstflg   moreflags,4    ; Software Reset request flag
#define    dscout   moreflags,5    ; keypad COS flag
#define    updtflg  moreflags,6    ; update request flag
#define    enkeyflg moreflags,7    ; hardware DSC keyin enable flag


;  7  6  5  4  3  2  1  0
; r5,c1,c2,c3,r4,r3,r2,r1          ; keyad output format

#define    row1    dsckey,0        ;
#define    row2    dsckey,1        ;
#define    row3    dsckey,2        ;
#define    row4    dsckey,3        ;
#define    col3    dsckey,4        ;
#define    col2    dsckey,5        ;
#define    col1    dsckey,6        ;
#define    row5    dsckey,7        ;

#define    txbit  _porta,0         ; RS232 Tx O/P  DCE pin 3 OC Vcc
#define    cts    _porta,1         ; RS232 CTS O/P DCE pin 5 OC Vcc
#define    x10tx  _porta,2         ; x10 tx
#define    txdsc  _porta,3         ; Keypad Data o/p (Green wire) OC gnd
#define    led    _porta,4         ;@test Led ground activated

#define    rxbit   portb,0          ; RS232 Rx I/P  DCE pin 2
#define    rts     portb,1          ; RS232 RTS I/P DCE pin 4
#define    x10rx   portb,2          ; x10 rx
#define    sunbit  portb,3          ; sun bit input
#define    xover   portb,4          ; zero xover
#define    enkey   portb,5          ; DSC keyin enable/disable 1=enabled
#define    clkdsc  portb,6          ; Keypad Clock (Yellow wire)
#define    rxdsc   portb,7          ; Keypad Data i/p (Green wire)
 PAGE
;*******************************************************************************

           ORG _ResetVector
Reset      goto Start

;*******************************************************************************

           ORG _IntVector
Interrupt  movwf W_Save                ; preserve w reg
           swapf _status,w             ; preserve zero flag
           movwf S_Save

intchk     btfsc _toif                 ; TMR0 interrupt?
           b chkcts                    ; yes
           btfsc _intf                 ; INT interrupt?
           b strtint                   ; yes

endint     swapf S_Save,W              ; restore Status reg
           movwf _status
           swapf W_Save,f              ; Restore W reg
           swapf W_Save,W
           retfie                      ; return from interrupt

strtint    movlw rxinitcnt             ; initialize the Rx counter
           movwf rxcnt

           movlw h'80'                 ; initialize the RX register
           movwf rxreg
           bcf _inte                   ; clear the INTE
           bcf _intf                   ; clear the INTF

           b intchk                    ; exit via intchk (rechecking TMR0)

chkcts     clrwdt
           movf _portb,w               ; read port b
           movwf portb                 ; store for irq usage

           btfss strtsun               ; sun check in progress?
           b chkctsz                   ; no
           incfsz sunreg,f             ; increment counter
           btfss sunbit                ; if sun bit clear goto done
           b sundn
           b chkctsz                   ; not done
sundn      bcf strtsun                 ; sun check done
           bsf stpsun                  ; set done flag

chkctsz    btfss xflag
           b chkcts0
           btfsc xover
           bsf led
           btfss xover
           bcf led

chkcts0    btfss dsckeydn              ; skip if a keypad function
           b chkcts1                   ;
           decfsz dsctl,f              ; decrement low timer
           b chkcts1                   ;
           movf dscth,f                ; is the high timer 0
           skpz                        ; yes:
           b chkcts2                   ; no:

           btfss dsckpflg              ; is the start flag set
           bcf dsckeydn                ; no: keypad function is done.

           movlw keyup                 ; yes: set keypad delay time
           movwf dscth                 ;
           bcf dsckpflg                ; keypad o/p done
           skpnz                       ;
chkcts2    decf dscth,f                ; decrement high timer

chkcts1    btfsc ctsflg                ; is the CTS flag clear?
           b chktx                     ; no:
setcts     bsf cts                     ; yes: set the CTS lead (allow TX)
           bsf _rp0                    ; switch banks for tris reg access
           bcf _trisa,1                ; RA1 -> output (cts -> 1 -> active)
           bcf _rp0                    ; switch banks back to normal

chktx      decfsz txcnt,w              ; is tx in progress (txcnt > 1 = yes)
           b chktxcnt                  ; yes:

           btfss rts                   ; no: is RTS valid?
           b chkrx                     ; no:

           btfss txflg                 ; yes: is there a TX char waiting?
           b chkrx                     ; no:

           movf txbuf,w                ; yes: transfer the char to the TX reg
           movwf txreg

           movlw txbitcnt              ; set the TX bit counter
           movwf txcnt
           bcf txflg                   ; clear the TX flag for next char
           clrc                        ; clear carry for start bit
           bsf txbit                   ; always set RA0 to 1
           b outputbit                 ; output the start bit

chktxcnt   movwf txcnt                 ; is it time to output the next bit?
           andlw txmod                 ; mod txmod = 0?
           skpz                        ; if 0 -> output the next bit
           b chkrx                     ; else go check the RX routine

tx         bsf txbit                   ; always set RA0 to 1
           setc                        ; set Carry for Stop bit
           rrf txreg,f                 ; LSB is transmitted first so shift right

outputbit  bsf _rp0                    ; switch banks for tris reg access
           skpc
           bcf _trisa,0                ; if no carry, set RA0 as output (bit=0)
           skpnc
           bsf _trisa,0                ; if carry, tristate RA0 (bit=1)
           bcf _rp0                    ; switch banks back to normal

chkrx      btfss _inte                 ; is rx in progress?
           decfsz rxcnt,f              ; is it time to check the rx input
           b tmrend                    ; no

           movlw bitlen                ; reload the RX counter for next bit
           movwf rxcnt

;rx        rrf _portb,w                ; move Rx Bit into carry
rx         rrf  portb,w                ; move Rx Bit into carry
           btfsc stopbit               ; is it time to check the stopbit?
           b chkstop                   ; yes
rxc        rrf rxreg,f                 ; rotate carry into rxreg LSB first
           skpnc                       ; if carry set, RX is done
           bsf stopbit                 ; set flag to test stop bit
           b tmrend

chkstop    bcf stopbit                 ; clear the stop bit flag
           skpnc                       ; this is a valid rx char
           b rxc                       ; go find the next stop bit

           movf rxptr,w                ; save indirect pointer
           movwf rxtail_Save
           movf rxhead,w               ; set indirect pointer to rxhead
           movwf rxptr

           comf rxreg,w                ; complement & move the rxreg to rxbuf
           movwf rxbuf

           xorlw h'12'                 ; was the I/P a ctrl-R?
           skpnz                       ; no: skip
           bsf rstflg                  ; yes: set Reset Flag

           xorlw (h'15' ^ h'12')       ; was the I/P a ctrl-U?
           skpnz                       ; mo: skip
           bsf updtflg                 ; yes: set update flag

adjfifo    incf rxhead,w               ; adjust fifo head pointer
           andlw fifomask              ; 4 byte FIFO mask
           movwf rxhead                ; save adjusted pointer

           addlw h'01'                 ; if the head+1 = tail then clear CTS
           andlw fifomask              ; 4 byte FIFO
           xorwf rxtail_Save,w         ; are pointers equal?
           bnz rstptr                  ; no:

           bsf ctsflg                  ; yes: set the CTS flag (clear CTS)
           bsf cts                     ; always set cts bit to 1
           bsf _rp0                    ; switch banks for tris reg access
           bsf _trisa,1                ; tristate RA1 (cts -> 0 -> stop sending)
           bcf _rp0                    ; switch banks back to normal

rstptr     movf rxtail_Save,w          ; restore the indirect pointer
           movwf rxptr

           bcf _intf                   ; clear the INTF
           bsf _inte                   ; re-enable the rx interrupt

tmrend     decfsz dscnt,f   ; decrement the dsc counter: cnt = 0?
           b chkclk         ; no:

      ;     incf smplreg,f   ; force a halfway test sample (1's cnt)
      ;     clrc
      ;     btfsc smplreg,2
      ;     setc


      ;   bcf sprpa2       ; @@strobe test indicates end of display cycle

           btfsc  lstclk    ; yes: is this a display bit (lstclk=1)
           b tmrend3        ; yes:
           btfss enkeyflg   ; is the Keyin Flag disabled?
           b tmrend2        ; yes:

           rlf portb,w      ; shift input into dsci5
           rlf dsci5,f
           rlf dsci4,f
           rlf dsci3,f
           b tmrend2

tmrend3    rlf portb,w      ; shift input into dsci2
           rlf dsci2,f      ;
           rlf dsci1,f      ;
           rlf dsci0,f      ;

tmrend2    movlw tmrdelay   ; Reload irq interval timer
           addwf _tmr0,f

; Adding the irq time to the tmrdelay constant is equivalent to subtracting the
; time from the next irq interval. The result is an exact irq interval.

           bcf _toif        ; clear the TOIF
           b endint

chkclk  ;   btfsc rxdsc      ; Yes: count the # of 1's
        ;   incf smplreg,f   ;
        ;   btfss dscnt,7
        ;   b tmrend2

; We need to find the strobe pulse: The Keypad H/W determines this after
; a 7 mSec period of no clock pulse change. We may have to to set our S/W
; trigger here ... as some events appear to extend the 1 mSec cells
; ie. phone ringing causes at least 2 adjacent cells to change duty cycle
; from 50% to 65%.
; Max S/W strobe delay = (K+1)*104uS where K is dscnt
; dscnt has 2 trip points the read point which triggers at the value of 0
; (300-400usS) and at the lower limit which is the strobe (currently set
; at about 2.5 mSec)
; Note: we have to TX a complete COS before the next COS cycle starts.
; a COS TX requires a MAx of 16 charcters * 10 bits * 1/2400 = 66.6 mSec
; a COS cycle = 47+22 = 69 mSec

           movf dscnt,w     ; Test the data read offset counter
           xorlw h'C0'      ; has the counter reached hex C0? (7mS)
           skpz             ; yes: this is the end of display data
           b chkclk2        ; no: go check the clock edges

           clrf Iscratch    ; Clear COS Test Register

           btfss pass1      ; Skip on 1st time through
           b chkclk4        ; Syncronize the data I/P

      ;    bsf sprpa2       ; @@strobe test indicates end of display cycle

           movf dsci0,w     ; Get i/p byte
           xorwf dsco0,f    ; Test byte with last i/p
           movwf dsco0      ; Save i/p byte
           skpz             ; skip if no COS
           incf Iscratch,f  ; update COS Test Register
           movf dsci1,w     ; Get i/p byte
           xorwf dsco1,f    ; Test byte with last i/p
           movwf dsco1      ; Save i/p byte
           skpz             ; skip if no COS
           incf Iscratch,f  ; update COS Test Register
           movf dsci2,w     ; Get i/p byte
           xorwf dsco2,f    ; Test byte with last i/p
           movwf dsco2      ; Save i/p byte
           skpz             ; skip if no COS
           incf Iscratch,f  ; update COS Test Register
           btfss enkeyflg   ; bypass if not enabled
           b chkclk4
           movf dsci3,w     ; Get i/p byte
           xorwf dsco3,f    ; Test byte with last i/p
           movwf dsco3      ; Save i/p byte
           skpz             ; skip if no COS
           incf Iscratch,f  ; update COS Test Register
           movf dsci4,w     ; Get i/p byte
           xorwf dsco4,f    ; Test byte with last i/p
           movwf dsco4      ; Save i/p byte
           skpz             ; skip if no COS
           incf Iscratch,f  ; update COS Test Register
           movf dsci5,w     ; Get i/p byte
           xorwf dsco5,f    ; Test byte with last i/p
           movwf dsco5      ; Save i/p byte
           skpz             ; skip if no COS
           incf Iscratch,f  ; update COS Test Register

chkclk4    bsf pass1        ; set the 1st pass flag
           movf dsckey,w    ; copy the keypad data to the shift register
           movwf keypad     ;
           btfss dsckpflg   ; is there a pending keypad o/p?
           clrf keypad      ; no: clear shift register
           clrf dsci0       ; yes: Clear i/p Shift Registers
           clrf dsci1       ;
           clrf dsci2       ;
           clrf dsci3       ;
           clrf dsci4       ;
           clrf dsci5       ;
           btfss updtflg    ; Test forced update flag
           b chkclk5
           incf Iscratch,f  ; update COS Test Register
           bsf ctrlu
chkclk5    bcf updtflg      ; always clear the update flag
           movf Iscratch,f  ; Test COS Test Register
           skpz             ; If COS Test Register is 0 then Skip
           bsf dscout       ; A COS has occured flag o/p routine
           b tmrend2        ;

chkclk2    ;clrf Iscratch
           ;btfsc _portb,6
           ;incf Iscratch,f
           ;btfsc clkdsc
           ;incf Iscratch,f
           ;btfsc _portb,6
           ;incf Iscratch,f
           ;btfss Iscratch,1 ; Clock = 1?
           btfss clkdsc     ; Clock = 1?
           b chkclk1        ; no: clock = 0
           btfsc lstclk     ; yes: last clock = 0? clock = 1
           b tmrend2        ; no: no change
           bsf lstclk       ; yes: set lstclk
           bcf txdsc        ; always clear the dsc tx
chkclk3    movlw h'02'      ; init counter (300-400 uS delay to read)
           movwf dscnt      ;
;          clrf smplreg     ;
           b tmrend2        ;
chkclk1    btfss lstclk     ; last clock = 1? clock = 0
           b tmrend2        ; no: no change
           bcf lstclk       ; yes: clr lstclk
           clrc             ; always shift 0 into shift register
           rlf keypad,f     ;
           skpnc            ;
           bsf txdsc        ; set o/p if carry bit = 1
           b chkclk3        ;

;*******************************************************************************
 PAGE
; Note: The RS232 CTS signal is turned off until the initialization has been
; completed. This disables the interface from sending the PIC characters
; until the PIC is ready. For the DSC keypad it is important the TX lead
; (_porta,3) is held low until data output is required.

Start      movlw h'17'       ; Initialize Port A
           movwf _porta

           bsf _rp0          ; switch banks for tris reg access
           movlw h'03'       ; Init Port A - tristate bits 0,1
                             ; Tx -> idle, CTS -> Not Ready for I/P
           movwf _trisa      ; Init Port A - bits  2, 3, 4 as O/P

           movlw h'ff'       ; Init Port B - bit 0 - 7 as I/P
           movwf _trisb

           movlw h'cd'       ; Init tmr/int modes: INTEDG = 1 rising,
           movwf _option     ; RTS = 0 internal, RBPU = 1 disabled
           bcf _rp0          ; switch banks back to normal

           movlw h'01'       ; init the txcnt
           movwf txcnt
           clrf rxcnt        ; init the rxcnt
           clrf flags        ; init the flag reg
           clrf Mscratch

           clrf dscth        ; Init the dsc regs
           clrf dsctl
           clrf dsckey
           clrf moreflags
           clrf keypad
           clrf dscnt
;          clrf keyincnt
;          clrf smplreg
           clrf dsco0
           clrf dsco1
           clrf dsco2
           clrf dsco3
           clrf dsco4
           clrf dsco5

           movlw rxfifo0     ; init the fifo pointers
           movwf rxtail
           movwf rxhead

           bcf led           ; turn on test led (gnd) for 1 Sec
           movlw h'0A'
           movwf Iscratch
loopstrt   clrw              ; Approx. 100 mSec
           call wait
           clrwdt
           decfsz Iscratch,f
           b loopstrt

           movlw tmrdelay              ; init the timer
           movwf _tmr0

           movlw GIE+INTE+TOIE         ; enable interrupts
           movwf _intcon

           ; ensure dsctx is held low

           movlw h'17'                 ; Initialize Port A again
           movwf _porta
           bcf x10tx

           ; Turn off Led and enable CTS

           bsf _rp0                    ; switch banks for tris reg access
           movlw h'01'                 ; Init Port A - tristate bit  0
           movwf _trisa                ; Init Port A - bits  1, 2, 3, 4 as O/P
           bcf _rp0                    ; switch banks back to normal

           movlw "D"         ; O/P Power Up message "DSC Ok"
           call txloop
           movlw "S"
           call txloop
           movlw "C"
           call txloop
           movlw " "
           call txloop
           movlw "O"
           call txloop
           movlw "k"
           call txloop

           call crprompt

           bsf enkeyflg      ; short pin 10 -> 14 to disable keyin display
           btfsc enkey
           bcf enkeyflg

MainLoop   btfss stpsun
           b MainLoop0       ; no: skip
           bcf stpsun
           movlw "z"
           call txloop
           movf sunreg,w
           call prbyte
           call crprompt
MainLoop0  btfss dscout      ; Has there been a COS?
           b MainLoop1       ; no: skip
           btfss ctrlu
           b COS
           movlw "^"
           call txloop
           movlw "U"
           call txloop
           bcf ctrlu
COS        movlw CR          ; yes: o/p the COS
           call txloop
           movlw "<"
           call txloop
           movf dsco0,w
           call prbyte
           movf dsco1,w
           call prbyte
           movf dsco2,w
           call prbyte
           movf dsco3,w      ; DSC keypad input
           btfsc enkeyflg    ; bypass if not enabled
           call prbyte
           movf dsco4,w      ; DSC hidden input
           btfsc enkeyflg    ; bypass if not enabled
           call prbyte
           movf dsco5,w      ; DSC hidden input
           btfsc enkeyflg    ; bypass if not enabled
           call prbyte
           bcf dscout        ; clear flag for next loop
           call crprompt



; The fifo routine in the irq routine has a 1 byte overflow margin.
; CTS is cleared (to tell the PC to stop TX) 1 byte before the FIFO
; is full. The PC may take up to 1 byte before actually stopping,
; therefore, the FIFO IS full (HEAD = TAIL). The ctsflg test ensures
; a lock up condition doesn't occur because HEAD = TAIL is also a
; FIFO empty condition.


MainLoop1  movf rxtail,w     ; check for rx pending
           xorwf rxhead,w
           btfss ctsflg      ; skip rx check if FIFO is full
           skpz
           btfsc txflg       ; skip if the TX is ready
           b MainLoop

           btfss rstflg      ; has there been a soft reset request
           b MainLoop3       ; no:
           movlw "^"         ; yes:
           call txloop
           movlw "R"
           call txloop
           movlw CR          ; this CR is sent
           call txloop
           movlw CR          ; this CR is never sent, the _gie disables TX
           call txloop       ; it just adds extra time so we get the 1st CR
MainLoop4  btfsc txflg
           b MainLoop4
rst        bcf _gie          ; disable interrupt and wait for WD timeout
           b rst

MainLoop3  btfsc dsckeydn    ; is there a keypad O/P pending?
           b MainLoop        ; yes:

           movf rxbuf,w      ; no: get the rx byte
           xorlw CR          ; Check for a <CR>
           bnz MainLoop6
           btfss emerg       ; is there an emergency pending?
           b pcontloop       ; no
           b donumb1         ; yes

MainLoop6  btfss emerg       ; was there an emergency pending?
           b MainLoop7       ; no

           movlw "?"         ; Cancel Emergency key
           call txloop
           call crprompt
           bcf emerg

MainLoop7  movf rxbuf,w      ; get the rx byte
           xorlw ( h'15' )   ; flush a ctrl-U
           skpnz
           b contloop

MainLoop5  movf rxbuf,w      ; get the rx byte
           andlw h'E0'       ; is this a ctrl character
           skpz
           b MainLoop2       ; no: bypass ctrl filter
           movlw "^"         ; yes:
           call txloop
           movf rxbuf,w      ; get the next rx byte
           iorlw h'40'
           skpnz

MainLoop2  movf rxbuf,w      ; get the rx byte
           call txloop

           movf rxbuf,w      ; get the rx byte
           xorlw (h'16')     ; ctrl-V ; Output Version
           bnz chknumb

           movlw CR
           call txloop
           movlw "D"
           call txloop
           movlw "S"
           call txloop
           movlw "C"
           call txloop
           movlw " "
           call txloop
           movlw "P"
           call txloop
           movlw "C"
           call txloop
           movlw " "
           call txloop
           movlw "K"
           call txloop
           movlw "B"
           call txloop
           movlw "D"
           call txloop
           movlw " "
           call txloop
           movlw "3"
           call txloop
           movlw "v"
           call txloop
           movlw "A"
           call txloop
           b pcontloop

chknumb    bcf emerg
           clrf dsckey
           xorlw ( "1" ^ h'16' )     ;   1
           skpnz
           bsf row1
           xorlw ( "4" ^ "1" )       ;   4
           skpnz
           bsf row2
           xorlw ( "7" ^ "4" )       ;   7
           skpnz
           bsf row3
           xorlw ( "*" ^ "7" )       ;   *
           skpnz
           bsf row4
           xorlw ( "F" ^ "*" )       ;   F
           skpnz
           bsf row5
           xorlw ( "f" ^ "F" )       ;   f
           skpnz
           bsf row5
           xorlw ( h'06' ^ "f" )     ;   ctrl-F
           skpnz
           bsf row5
           skpnz
           bsf emerg
           movf dsckey,f
           bsf col1
           skpz
           b donumb

           clrf dsckey
           xorlw ( "2" ^ h'06' )     ;   2
           skpnz
           bsf row1
           xorlw ( "5" ^ "2" )       ;   5
           skpnz
           bsf row2
           xorlw ( "8" ^ "5" )       ;   8
           skpnz
           bsf row3
           xorlw ( "0" ^ "8" )       ;   0
           skpnz
           bsf row4
           xorlw ( "A" ^ "0" )       ;   A
           skpnz
           bsf row5
           xorlw ( "a" ^ "A" )       ;   a
           skpnz
           bsf row5
           xorlw ( h'01' ^ "a" )     ;   ctrl-A
           skpnz
           bsf row5
           skpnz
           bsf emerg
           movf dsckey,f
           bsf col2
           skpz
           b donumb

           clrf dsckey
           xorlw ( "3" ^ h'01' )     ;   3
           skpnz
           bsf row1
           xorlw ( "6" ^ "3" )       ;   6
           skpnz
           bsf row2
           xorlw ( "9" ^ "6" )       ;   9
           skpnz
           bsf row3
           xorlw ( "#" ^ "9" )       ;   #
           skpnz
           bsf row4
           xorlw ( "P" ^ "#" )       ;   P
           skpnz
           bsf row5
           xorlw ( "p" ^ "P" )       ;   p
           skpnz
           bsf row5
           xorlw ( h'10' ^ "p" )     ;   ctrl-P
           skpnz
           bsf row5
           skpnz
           bsf emerg
           movf dsckey,f
           bsf col3
           skpz
           b donumb

chkon      xorlw (h'0E' ^ h'10')     ;@test Led Test
           bz on                     ;@test if ctrl-N turn on test led
           xorlw (h'0F' ^ h'0E' )    ;@test if ctrl-O turn off test led
           bnz xvr                   ;@test
           bsf led                   ;@test turn off test led (Vdd)
           skpz                      ;@test
on         bcf led                   ;@test turn on test led (gnd)
pcontloop  call crprompt

contloop   incf rxtail,w             ; adjust the fifo pointer
           andlw fifomask            ; 4 byte FIFO
           movwf rxtail              ; store adjusted pointer

           xorwf rxhead,w            ; is the buffer empty?
           skpnz                     ; skip if not empty
           bcf ctsflg                ; clear the CTS flag when empty
           b MainLoop

donumb     btfsc emerg               ; is this an emergency?
           b contloop                ; yes: get confirmation character (CR)
donumb1    clrf dsctl                ; set keypad function timer
           movlw keydown             ; > 50mSec
           btfsc emerg               ; is this an emergency?
           movlw h'4F'               ; yes: 2 Sec
           movwf dscth               ; no; Set key down timer
           bsf dsckeydn              ; set the done flag
           bsf dsckpflg              ; set the start flag
           bcf emerg                 ; clear the emergency flag
           b pcontloop

xvr        xorlw (h'18' ^ h'0F')
           bnz sunchk
           movf flags,w
           xorlw h'20'
           movwf flags
           b pcontloop

sunchk     xorlw (h'1A' ^ h'18')     ;@test if ctrl-z start sun check
           bnz rxerror
           btfsc strtsun
           b rxerror
           bcf led                   ;@test turn on test led (gnd)
           clrw
           call wait
           clrf sunreg
           bsf  strtsun
           bsf led
           b pcontloop

rxerror    movlw CR          ; Output a <CR>
           call txloop
           movlw "?"
           call txloop
           b pcontloop

crprompt   movlw CR          ; Output a <CR>
           call txloop

prompt     movlw ">"         ; Output a >

txloop     btfsc txflg       ; Serial port Tx character
           goto txloop       ; wait until tx register is free
           movwf txbuf       ; send character
           bsf txflg         ; set Tx Flag
           return

prbyte     movwf Mscratch    ; Hex convertion adapted from the
                             ; Apple][+ prbyte routine
           swapf Mscratch,w  ; out high nibble first
           call prbyte1
           movf Mscratch,w   ; now low nibble
prbyte1    andlw h'0F'
           addlw h'F6'       ; 0..9->F6..FF ; A..F->0..5 ; A..F set C
           skpnc             ; skip 0..9
           addlw h'07'       ; A..F->7..C
           addlw h'3A'       ; 0..9->30..39 ; A..F->41..46
           b txloop

wait       movwf Mscratch    ; adapted from the Apple][+ wait routine
wait1      decfsz Mscratch,f
           b wait1
           addlw h'ff'
           skpz
           b wait
           return

           end

;*******************************************************************************
