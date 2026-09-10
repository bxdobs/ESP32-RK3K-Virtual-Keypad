;***********************************************************************
;                 PIC16C84 Header File
;
;          Date:  12 Dec 1994
;           For:  MPASM
;
;*********************************************************************

; PIC Working Registers
   CBLOCK 0x00
      _ind0
      _tmr0
      _pcl
      _status
      _fsr
      _porta
      _portb
   ENDC

   CBLOCK 0x08
      _eedata
      _eeadr
      _pclath
      _intcon
   ENDC

_option  set   0x01
_trisa   set   0x05
_trisb   set   0x06
_eecon1  set   0x08
_eecon2  set   0x09

OPTION_REG set 0x81
TRISA set 0x85
TRISB set 0x86
EECON1 set 0x88
EECON2 set 0x89

; Bit Definitions
BIT0 equ 0x01
BIT1 equ 0x02
BIT2 equ 0x04
BIT3 equ 0x08
BIT4 equ 0x10
BIT5 equ 0x20
BIT6 equ 0x40
BIT7 equ 0x80

; Porta Bits
#define     _ra0     _porta,0
#define     _ra1     _porta,1
#define     _ra2     _porta,2
#define     _ra3     _porta,3
#define     _ra4     _porta,4

#define     _tocki   _porta,4

; Portb bits
#define     _rb0     _portb,0
#define     _rb1     _portb,1
#define     _rb2     _portb,2
#define     _rb3     _portb,3
#define     _rb4     _portb,4
#define     _rb5     _portb,5
#define     _rb6     _portb,6
#define     _rb7     _portb,7

#define     _int     _portb,0

; STATUS Reg Bits
#define     _carry   _status,0
#define     _c       _status,0
#define     _dc      _status,1
#define     _z       _status,2
#define     _zero    _status,2
#define     _pd      _status,3
#define     _to      _status,4
#define     _rp0     _status,5
#define     _rp1     _status,6
#define     _irp     _status,7

; INTCON Reg Bits
#define     _rbif  _intcon,0
#define     _intf  _intcon,1
#define     _toif  _intcon,2
#define     _rbie  _intcon,3
#define     _inte  _intcon,4
#define     _toie  _intcon,5
#define     _peie  _intcon,6
#define     _gie   _intcon,7

RBIF  equ h'01' ; RB4-7 IRQ Flag (write 0 clears)  1 = IRQ pending
INTF  equ h'02' ; IRQ Flag (write 0 clears)        1 = IRQ pending
TOIF  equ h'04' ; Timer IRQ Flag (write 0 clears)  1 = IRQ pending
RBIE  equ h'08' ; RB4-7 External Interrupt Enable  1 = enable
INTE  equ h'10' ; External Interrupt Enable (RB0)  1 = enable
TOIE  equ h'20' ; Timer Overflow Interupt Enable   1 = enable
PEIE  equ h'40' ; EEProm Write Interrupt Enable    1 = enable
GIE   equ h'80' ; Global Interrupt Enable          1 = enable

; OPTION Reg
#define     _ps0    option,0
#define     _ps1    option,1
#define     _ps2    option,2
#define     _psa    option,3
#define     _rte    option,4
#define     _rts    option,5
#define     _intedg option,6
#define     _rbpu   option,7

PS02    equ h'00'  ; Timer Prescaler Value 1 : 2
PS04    equ h'01'  ; Timer Prescaler Value 1 : 4
PS08    equ h'02'  ; Timer Prescaler Value 1 : 8
PS10    equ h'03'  ; Timer Prescaler Value 1 : 16
PS20    equ h'04'  ; Timer Prescaler Value 1 : 32
PS40    equ h'05'  ; Timer Prescaler Value 1 : 64
PS80    equ h'06'  ; Timer Prescaler Value 1 : 128
PSFF    equ h'07'  ; Timer Prescaler Value 1 : 256

WD01    equ h'00'  ; Watchdog Prescaler Value 1 : 1
WD02    equ h'01'  ; Watchdog Prescaler Value 1 : 2
WD04    equ h'02'  ; Watchdog Prescaler Value 1 : 4
WD08    equ h'03'  ; Watchdog Prescaler Value 1 : 8
WD10    equ h'04'  ; Watchdog Prescaler Value 1 : 16
WD20    equ h'05'  ; Watchdog Prescaler Value 1 : 32
WD40    equ h'06'  ; Watchdog Prescaler Value 1 : 64
WD80    equ h'07'  ; Watchdog Prescaler Value 1 : 128

PS0     equ h'01'  ; Prescaler function bit 0
PS1     equ h'02'  ; Prescaler function bit 1
PS2     equ h'04'  ; Prescaler function bit 2
PSA     equ h'08'  ; Prescaler assignmet bit 1 = WDT  0 = Timer
RTE     equ h'10'  ; RA4 Timer increment edge 1 = hi->lo 0 = lo->hi
RTS     equ h'20'  ; Timer source 1 = RA4  0 = Internal
INTEDG  equ h'40'  ; IRQ edge 1 = lo->hi 0 = hi->lo
RBPU    equ h'80'  ; Port B Pull-ups  1 = disable  0 = enable

; EECON1 Reg
#define     _rd      _eecon1,0
#define     _wr      _eecon1,1
#define     _wren    _eecon1,2
#define     _wrerr   _eecon1,3
#define     _eeif    _eecon1,4

EERD    equ  h'01' ; Start EEprom read
EEWR    equ  h'02' ; Start EEprom write
WREN    equ  h'04' ; EEprom write enable         1 = enable
WRERR   equ  h'08' ; EEprom write error          1 = error
EEIF    equ  h'10' ; EEprom write complete flag  1 = complete

_ResetVector   set   0x00
_IntVector     set   0x04

W  equ   0
w  equ   0
F  equ   1
f  equ   1

TRUE  equ   1
true  equ   1
FALSE equ   0
false equ   0

YES   equ   1
yes   equ   1
NO    equ   0
no    equ   0

LSB   equ   0
MSB   equ   7


;       Fuse Configurations

_CP_ON                       EQU     H'3FEF'       ; 0 xxxx
_CP_OFF                      EQU     H'3FFF'       ; 1 xxxx
_PWDT_ON                     EQU     H'3FFF'       ; x 1xxx
_PWDT_OFF                    EQU     H'3FF7'       ; x 0xxx
_WDT_ON                      EQU     H'3FFF'       ; x x1xx
_WDT_OFF                     EQU     H'3FFB'       ; x x0xx
_LP_OSC                      EQU     H'3FFC'       ; x xx00
_XT_OSC                      EQU     H'3FFD'       ; x xx01
_HS_OSC                      EQU     H'3FFE'       ; x xx10
_RC_OSC                      EQU     H'3FFF'       ; x xx11
