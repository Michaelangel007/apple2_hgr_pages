; ============================================================
; BOOT_SECTOR should be defined before including this file!!!!
; ============================================================
;
; By Michaelangel007
; Copyleft 2025
;
; Draw one 8x8 glyph on every $2000 bytes
;    HGR  Page  Glyph
;    "0"   $00   0
;     1    $20   1
;     2    $40   2
;    "3"   $60   3
;    "4"   $80   4
;    "5"   $A0   5
;    "6"   LCA   1 (mini 4x4)
;    "7"   LCB   2 (mini 4x4)
;    "8a"  $E0   E (mini 4x4)
;    "8b"  $F0   F (mini 4x4)
;
; See:
; * https://github.com/Michaelangel007/apple2_fantavision_reloaded
; * https://github.com/Michaelangel007/apple2_hgr_font_tutorial

zSrc        = $3C ; MON.A1
zDst        = $42 ; MON.A4
Temp        = $FF

Status      = $7D0 ; VTAB 24, HTAB 1 = $7D0

KEYBOARD    = $C000
KEYSTROBE   = $C010
Squeeker    = $C030 ; Technically a speaker but who are we kidding here. This is no SID chip.

GR          = $C050
TEXT        = $C051
FULL        = $C052
MIX         = $C053
PAGE1       = $C054
PAGE2       = $C055
HIRES       = $C057

; Bank2   Bank1   First Access, Second Access
; C080    C088    Read RAM,     Write protect
; C081    C089    Read ROM,     Write enable
; C082    C08A    Read ROM,     Write protect
; C083    C08B    Read RAM,     Write enable
ROMIN2      = $C082
LCBANK2     = $C080
LCBANK1     = $C088
LCBANKB     = $C083 ; Read RAM, Write enable -- Must be LOAD x2
LCBANKA     = $C08B ; Read RAM, WRite enable -- Must be LOAD x2

DRIVE_OFF   = $C088 ; Motor Off

        ORG $0800

Main
  DO BOOT_SECTOR
        DB {End+255-*}/256  ; Tell PROM to read 2 sectors
        STA DRIVE_OFF,X     ; Turn drive off
  ELSE
        DB $EA
        DS 3, $EA  
  FIN
        LDA PAGE1
        LDA MIX
        LDA GR
        LDA HIRES

        LDA LCBANKB
        LDA LCBANKB

        LDX #NumGlyphs-1
NextGlyph
        STX Temp
        LDX Temp
        LDA Glyphs,X
        LDY Pages, X  ; Dst Hi
        LDX #0        ; Dst Lo
        JSR CopyGlyph
        LDX Temp
        DEX
        BPL NextGlyph

        LDA LCBANKA
        LDA LCBANKA
        LDA #'A'  ; Src
        LDY #$D0  ; Dst - LC Bank 1
        LDX #0        ; Dst Lo
        JSR CopyGlyph

SwitchBanks
        JSR GetKey
        CMP #$9B    ; ESC exit
        BNE Test0
        LDA PAGE1
        LDA TEXT
Done    LDA ROMIN2
        LDA ROMIN2
        RTS

Test0   CMP #"0"    ; ROM
        BNE Test1
        STA Status
        JSR Done
        JMP SwitchBanks

Test1   CMP #"1"    ; LC Bank 1
        BNE Test2
        STA Status
        LDA LCBANK1
        LDA LCBANK1
        JMP SwitchBanks

Test2   CMP #"2"    ; LC Bank 2
        BNE Beep
        STA Status
        LDA LCBANK2
        LDA LCBANK2
        JMP SwitchBanks

Beep    JSR SoftBeep
        JMP SwitchBanks

; Copy Linear to HGR layout
CopyGlyph
        STX zDst+0
        STY zDst+1

        SEC         ; Find font glyphs offset
        SBC #'0'    ; Glyphs start at '0' 
        ASL         ; Glyphs are 1x8
        ASL
        ASL

        CLC
;        ADC #<Font ; Page Aligned so redundant
        STA zSrc+0
        LDA #>Font
        STA zSrc+1

        LDX #8      ; Glyph is 1x8
        LDY #0
_Copy
        LDA (zSrc),Y
        STA (zDst),Y

        INY         ; C Case1     C Case0
        CLC         ; 0 1xxxxxxx  0 0xxxxxxx
        ROL         ; 1 xxxxxxx0  0 xxxxxxx0 if high-bit palette set, extend to next byte first pixel
        LDA #0      ; 1 00000000  0 00000000
        ROL         ; 0 00000001  0 00000000 zero out next byte to make first 7x8 pixels easier to read
Extend  STA (zDst),Y
        DEY

        INC zSrc    ; Can't use INY as that would move the destination
        LDA zDst+1
        CLC
        ADC #$04    ; move to next scanline
        STA zDst+1

        DEX         ; Glyph is 1x8
        BNE _Copy
        RTS

GetKey  LDA KEYBOARD
        BPL GetKey
        STA KEYSTROBE
        RTS

RamWait SEC
_Wait2  PHA
_Wait3  SBC #1
        BNE _Wait3
        PLA
        SBC #1
        BNE _Wait2
        RTS
SoftBeep
        LDY #$20
SoftCycle
        LDA #$02
        JSR RamWait     ; Since LC RAM may be banked in
        STA Squeeker
        LDA #$24
        JSR RamWait
        STA Squeeker
        DEY
        BNE SoftCycle
        RTS

Glyphs   ASC '0', '1', '2', '3', '4', '5', 'B', 'E'
Pages    DB  $00, $20, $40, $60, $80, $A0, $D0, $E0
NumGlyphs = * - Pages

         DS \,$00
;            0   1   2   3   4   5   6   7 ; Hex Asc Dst
Font    DB $1E,$33,$33,$33,$33,$33,$1E,$00 ; $30  0 $00
        DB $0C,$0E,$0F,$0C,$0C,$0C,$3F,$00 ; $31  1 $20
        DB $1E,$3F,$33,$38,$1C,$0E,$3F,$00 ; $32  2 $40
        DB $1E,$3F,$30,$1E,$30,$3F,$1E,$00 ; $33  3 $60
        DB $38,$3C,$36,$33,$3F,$30,$30,$00 ; $34  4 $80
        DB $3F,$3F,$03,$1F,$30,$3F,$1E,$00 ; $35  5 $A0
        DB $00,$00,$00,$00,$00,$00,$00,$00 ; $36  6
        DB $00,$00,$00,$00,$00,$00,$00,$00 ; $37  7
        DB $00,$00,$00,$00,$00,$00,$00,$00 ; $38  8
        DB $00,$00,$00,$00,$00,$00,$00,$00 ; $39  9
        DB $00,$00,$00,$00,$00,$00,$00,$00 ; $3A  :
        DB $00,$00,$00,$00,$00,$00,$00,$00 ; $3B  ;
        DB $00,$00,$00,$00,$00,$00,$00,$00 ; $3C  <
        DB $00,$00,$00,$00,$00,$00,$00,$00 ; $3D  :
        DB $00,$00,$00,$00,$00,$00,$00,$00 ; $3E  >
        DB $00,$00,$00,$00,$00,$00,$00,$00 ; $3F  ?
        DB $00,$00,$00,$00,$00,$00,$00,$00 ; $40  @

; Due to 3 overlapping memory regions ($E0-$$EF pages)
; We use mini-glyphs split into top/bottom halves:
;
; Page  Glyph  "A"    "B"     "E"
; $C0    1     Bank1
; $D0    2            Bank2
; $E0     E    Bank1  Bank2   LC
; $F0    F                    LC

;     1248 Hex Hi
; 12480000 Hex Lo
; 01234567 Pixels
; 
; x        $01
; x        $01
; x        $01
; x        $01
;      xxx $E0   was F0
;      xxx $E0   was 30
;      x   $A0   was 10
;      xxx $E0   was F0
; 
;  xx      $06
;    x     $08
;   x      $04
;  xxx     $0E
;      xxx $E0
;      xx  $60
;      x   $20
;      xxx $E0
; 
;      xxx $E0
;      xx  $E0
;      x   $A0
;      xxx $E0
; xxxx     $0F
; x        $01
; xx       $03
; x        $01
        DB $01,$01,$01,$01,$E0,$60,$20,$E0 ; $41  A $C0,$E0   1/E
        DB $06,$08,$04,$0E,$E0,$60,$20,$E0 ; $42  B $D0,$E0   2/E
        DB $00,$00,$00,$00,$00,$00,$00,$00 ; $43  C
        DB $00,$00,$00,$00,$00,$00,$00,$00 ; $44  D
        DB $E0,$60,$20,$E0,$0F,$01,$03,$01 ; $45  E $E0,$F0   E/F

; Alt.
;     1248 Hex Hi
; 12480000 Hex Lo
; 01234567 Pixels
; 
;       xx $C0
;       xx $C0
;       xx $C0
;       xx $C0
; xxxx     $0E
; xx       $06
; x        $02
; xxxx     $0E
;
;     x xx $D0
;       x  $40
;      x   $20
;     xxx  $70
;
;  xxx     $0E
;  xx      $06
;  x       $02
;  xxx     $0E
;
;     xxxx $F0
;     x    $10
;     xx   $30
;     x    $10

End
