;* ======================================================================== *;
;*  This code is placed into the public domain by its author.               *;
;*  All copyright rights are hereby relinquished on the code and data in    *;
;*  this file.  -- Arnauld Chevallier, 2008                                 *;
;* ======================================================================== *;
            ROMW        16

;; ======================================================================== ;;
;;  VARIABLES IN SCRACTH RAM                                                ;;
;; ======================================================================== ;;
FRAME       EQU         $0102

TRKSCRACTH  ORG         $01DC, $01DC, "-RWBN"
G_FAD       RMB         1
REF_M       RMB         1
NOTE_A      RMB         1
NOTE_B      RMB         1
NOTE_C      RMB         1
REF_A       RMB         1
REF_B       RMB         1
REF_C       RMB         1
VOL_A       RMB         1
VOL_B       RMB         1
VOL_C       RMB         1
INSTR_A     RMB         1
INSTR_B     RMB         1
INSTR_C     RMB         1
COUNT_A     RMB         1
COUNT_B     RMB         1
COUNT_C     RMB         1
COUNT_M     RMB         1
COUNT_P     RMB         1
PAT         RMB         1

;; ======================================================================== ;;
;;  VARIABLES IN SYSTEM RAM                                                 ;;
;; ======================================================================== ;;
TRKSYSTEM   ORG         $035B, $035B, "-RWBN"
SONG        RMB         1
INS_PTR     RMB         1
POS_A       RMB         1
POS_B       RMB         1
POS_C       RMB         1

;; ======================================================================== ;;
;;  EXEC-friendly ROM header                                                ;;
;; ======================================================================== ;;
            ORG     $5000

ROMHDR:     BIDECLE ZERO            ; MOB picture base   (points to NULL list)
            BIDECLE ZERO            ; Process table      (points to NULL list)
            BIDECLE MAIN            ; Program start address
            BIDECLE ZERO            ; Bkgnd picture base (points to NULL list)
            BIDECLE ONES            ; GRAM pictures      (points to NULL list)
            BIDECLE TITLE           ; Cartridge title/date
            DECLE   $03C0           ; Flags:  No ECS title,
                                    ; run code after title, no clicks
ZERO:       DECLE   $0000           ; Screen border control
            DECLE   $0000           ; 0 = color stack, 1 = f/b mode
ONES:       DECLE   1, 1, 1, 1, 1   ; Color stack initialization

TITLE:      DECLE   108, "Tracker Demo", 0

;; ======================================================================== ;;
;;  MAIN                                                                    ;;
;; ======================================================================== ;;
MAIN        PROC

            MVII    #ISR,   R0      ; set our own ISR
            MVO     R0,     $100
            SWAP    R0
            MVO     R0,     $101

            EIS                     ; enable interrupts

            CALL    PRINT.FLS       ; overwrite title
            DECLE   7
            DECLE   $200 + 3*20 + 1
            DECLE   "Arnauld Chevallier", 0

            CALL    PRINT.FLS       ; overwrite copyright notice
            DECLE   7
            DECLE   $200 + 10*20 + 1
            DECLE   "   07 Sep. 2008   ", 0

            CALL    TRKINIT         ; initialize tracker

            CALL    TRKSNGINIT      ; initialize song
            DECLE   SONG00

@@spin      CALL    WAITVBL         ; wait for VBlank
            CALL    TRKPLAY         ; tick the player
            B       @@spin          ; spin forever

            ENDP

;; ======================================================================== ;;
;;  ISR           Simple ISR                                                ;;
;; ======================================================================== ;;
ISR         PROC

            MVO     R0,     $0020   ; hit $0020 to enable display

            MVI     FRAME,  R0      ; increment frame counter
            INCR    R0
            MVO     R0,     FRAME

            B       $1014           ; back into Exec

            ENDP

;; ======================================================================== ;;
;;  WAITVBL       Wait for next VBlank                                      ;;
;; ======================================================================== ;;
WAITVBL     PROC

            MVI     FRAME,  R0      ; R0 = current frame

@@wait      CMP     FRAME,  R0      ; wait for the next one
            BEQ     @@wait

            JR      R5

            ENDP

;; ======================================================================== ;;
;;  REQUIRED FILES                                                          ;;
;; ======================================================================== ;;
            INCLUDE "print.asm"
            INCLUDE "tracker.mac"
            INCLUDE "tracker.asm"
            INCLUDE "demosong.asm"

;; ======================================================================== ;;
;;  End of File:  trkdemo.asm                                               ;;
;; ======================================================================== ;;
