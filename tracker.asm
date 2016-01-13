;* ======================================================================== *;
;*  These routines are placed into the public domain by their author.  All  *;
;*  copyright rights are hereby relinquished on the routines and data in    *;
;*  this file.  -- Arnauld Chevallier, 2008                                 *;
;* ======================================================================== *;

;; ======================================================================== ;;
;;  TRKINIT       Global tracker initialization                             ;;
;;  TRKSNGINIT    Song initialization                                       ;;
;;  TRKSNGINIT.1  Alternate entry point                                     ;;
;;  TRKPLAY       Ticks the tracker and updates the PSG                     ;;
;;                                                                          ;;
;;  TRKPATINIT    (internal) Pattern initialization                         ;;
;;  TRKCHUPD      (internal) Updates a channel                              ;;
;;  TRKPSGUPD     (internal) Updates the PSG                                ;;
;;                                                                          ;;
;;  AUTHOR                                                                  ;;
;;      Arnauld Chevallier <a_chevallier AT yahoo.com>                      ;;
;;                                                                          ;;
;;  REVISION HISTORY                                                        ;;
;;      07-Sep-2008 Initial Revision                                        ;;
;;                                                                          ;;
;;  INPUTS for TRKINIT                                                      ;;
;;      none                                                                ;;
;;                                                                          ;;
;;  INPUTS for TRKSONGINIT                                                  ;;
;;      R5    Pointer to invocation record, followed by return address      ;;
;;            Song base address            1 DECLE                          ;;
;;                                                                          ;;
;;  INPUTS for TRKSONGINIT.1                                                ;;
;;      R1    Song base address                                             ;;
;;                                                                          ;;
;;  INPUTS for TRKPLAY                                                      ;;
;;      none                                                                ;;
;;                                                                          ;;
;;  CODESIZE                                                                ;;
;;      524 words                                                           ;;
;; ======================================================================== ;;

;; ======================================================================== ;;
;;  VARIABLES IN SCRATCH RAM USED BY THESE ROUTINES                         ;;
;; ======================================================================== ;;
; TRKSCRACTH  ORG         $01DC ; (or anywhere else)
; G_FAD       RMB         1
; REF_M       RMB         1
; NOTE_A      RMB         1
; NOTE_B      RMB         1
; NOTE_C      RMB         1
; REF_A       RMB         1
; REF_B       RMB         1
; REF_C       RMB         1
; VOL_A       RMB         1
; VOL_B       RMB         1
; VOL_C       RMB         1
; INSTR_A     RMB         1
; INSTR_B     RMB         1
; INSTR_C     RMB         1
; COUNT_A     RMB         1
; COUNT_B     RMB         1
; COUNT_C     RMB         1
; COUNT_M     RMB         1
; COUNT_P     RMB         1
; PAT         RMB         1

;; ======================================================================== ;;
;;  VARIABLES IN SYSTEM RAM USED BY THESE ROUTINES                          ;;
;; ======================================================================== ;;
; TRKSYSTEM   ORG         $035B ; (or anywhere else)
; SONG        RMB         1
; INS_PTR     RMB         1
; POS_A       RMB         1
; POS_B       RMB         1
; POS_C       RMB         1

;; ======================================================================== ;;
;;  CONSTANTS USED BY THESE ROUTINES                                        ;;
;; ======================================================================== ;;
RF2POS      EQU     ((POS_A - REF_A)   AND $FFFF)
POS2NT      EQU     ((POS_A - NOTE_A)  AND $FFFF)
POS2IN      EQU     ((INSTR_A - POS_A) AND $FFFF)
IN2PER      EQU     (($01F0 - INSTR_A) AND $FFFF)
PER2CN      EQU     ((COUNT_A - $01F4) AND $FFFF)
V2V         EQU     (($01FB - VOL_A)   AND $FFFF)

;; ======================================================================== ;;
;;  TRKSNGINIT    Song initialization                                       ;;
;; ======================================================================== ;;
TRKSNGINIT  PROC

            MVI@    R5,     R1          ; read song address
@@1         MVO     R1,     SONG        ; save song address

            ADDI    #2,     R1          ; read pointer to instruments
            MVI@    R1,     R1
            MVO     R1,     INS_PTR     ; and save it

            CLRR    R0                  ; initialize variables
            MVO     R0,     REF_M
            MVO     R0,     COUNT_M
            MVO     R0,     PAT
            NOP
            MVO     R0,     REF_A
            MVO     R0,     REF_B
            MVO     R0,     REF_C

            COMR    R0
            MVO     R0,     COUNT_A
            MVO     R0,     COUNT_B
            MVO     R0,     COUNT_C

            MVII    #1,     R0
            MVO     R0,     G_FAD       ; default global volume fading

            ENDP

;; ======================================================================== ;;
;;  TRKPATINIT    Pattern initialization                                    ;;
;; ======================================================================== ;;
TRKPATINIT  PROC

            MVI     SONG,   R4
            INCR    R4
            MVI@    R4,     R2          ; R2 = address of 1st pattern
            INCR    R4
            MVI     PAT,    R0          ; R0 = position in patterns order table
            ADDR    R0,     R4

            MVI@    R4,     R1          ; R1 = pattern number
            TSTR    R1
            BPL     @@pat_ok            ; end of patterns ? ...

            CMPI    #$F000, R1          ; ... yes : stop replay ?
            BEQ     TRKINIT

@@restart   ADDR    R1,     R0          ; ... no : jump to restart position ...
            ADDR    R1,     R4
            DECR    R4
            MVI@    R4,     R1          ; ... and read again

@@pat_ok    INCR    R0                  ; increment position
            MVO     R0,     PAT         ; in patterns order table

            SLL     R1,     2           ; R4 = R1 * 4 + R2
            MOVR    R1,     R4          ; (beginning of pattern's details)
            ADDR    R2,     R4

            MVI@    R4,     R0          ; init. pattern counter
            MVO     R0,     COUNT_P

            MVI@    R4,     R0          ; init. position for each channel
            MVO     R0,     POS_A
            MVI@    R4,     R0
            MVO     R0,     POS_B
            MVI@    R4,     R0
            MVO     R0,     POS_C

            JR      R5
            ENDP

;; ======================================================================== ;;
;;  TRKINIT       Global tracker initialization                             ;;
;; ======================================================================== ;;
TRKINIT     PROC

            MVII    #$38,   R0          ; 'Enable Noise/Tone' register
            MVO     R0,     $01F8

            CLRR    R0

            MVO     R0,     SONG        ; no song

            MVII    #$01F0, R4          ; clear channels periods / low
            MVO@    R0,     R4          ; $01F0
            MVO@    R0,     R4          ; $01F1
            MVO@    R0,     R4          ; $01F2

            INCR    R4                  ; clear channels periods / hi
            MVO@    R0,     R4          ; $01F4
            MVO@    R0,     R4          ; $01F5
            MVO@    R0,     R4          ; $01F6

            MVII    #$01FB, R4          ; clear volumes
            MVO@    R0,     R4          ; $01FB
            MVO@    R0,     R4          ; $01FC
            MVO@    R0,     R4          ; $01FD

            JR      R5
            ENDP

;; ======================================================================== ;;
;;  TRKPLAY       Ticks the tracker and updates the PSG                     ;;
;; ======================================================================== ;;
TRKPLAY     PROC
            PSHR    R5

            MVI     SONG,   R4          ; R4 = song base address
            TSTR    R4                  ; is a song actually playing ?
            BEQ     @@done

            MVI     COUNT_M,R0          ; ... yes : increment global music counter
            INCR    R0
            MVO     R0,     COUNT_M

            MVI     REF_M,  R0          ; refresh notes ?
            DECR    R0
            BPL     @@notes_ok

            MVI@    R4,     R0          ; ... yes : read speed
            MVO     R0,     REF_M

            MVII    #REF_A, R3          ; refresh note for each channel
            CALL    TRKCHUPD
            MVII    #REF_B, R3
            CALL    TRKCHUPD
            MVII    #REF_C, R3
            CALL    TRKCHUPD

            MVI     COUNT_P,R0          ; decrement pattern counter
            DECR    R0
            MVO     R0,     COUNT_P
            BNEQ    @@upd_psg           ; jump to next pattern ?

            CALL    TRKPATINIT          ; ... yes
            B       @@upd_psg

@@notes_ok  MVO     R0,     REF_M

@@upd_psg   MVII    #NOTE_A,R3          ; update PSG for each channel
            CALL    TRKPSGUPD
            MVII    #NOTE_B,R3
            CALL    TRKPSGUPD
            MVII    #NOTE_C,R3
            CALL    TRKPSGUPD

@@done      PULR    PC
            ENDP

;; ======================================================================== ;;
;;  TRKCHUPD      Updates a channel                                         ;;
;; ======================================================================== ;;
TRKCHUPD    PROC
            PSHR    R5

            MVI@    R3,     R0          ; (R3 = REF_x)
            SUBI    #$10,   R0
            BMI     @@ch_new

            MVO@    R0,     R3
            PULR    PC

@@ch_new    ADDI    #RF2POS,R3          ; read pos
            MVI@    R3,     R4
            MVI@    R4,     R0          ; read data

            MOVR    R0,     R1          ; extra data to read ? ...
            BPL     @@data_ok

            MVI@    R4,     R2          ; ... yes : R2 = new instrument
            ADDI    #POS2IN,R3
            MVO@    R2,     R3          ; save it
            SUBI    #POS2IN,R3

@@data_ok   MVO@    R4,     R3          ; update pos

            SWAP    R0                  ; save note
            SUBI    #POS2NT,R3
            ANDI    #$7F,   R0
            BEQ     @@skip_sav

            MVO@    R0,     R3

@@skip_sav  ADDI    #3,     R3          ; new refresh value (R3 = REF_x)
            MVO@    R1,     R3

            ANDI    #$F,    R1          ; new volume
            ADDI    #3,     R3          ; (R3 = VOL_x)
            MVO@    R1,     R3

            TSTR    R0                  ; if note = 0,
            BEQ     @@ch_ok             ; don't reset counter

            ADDI    #6,     R3          ; (R3 = COUNT_x)
            CLRR    R0                  ; reset counter
            MVO@    R0,     R3

@@ch_ok     PULR    PC
            ENDP

;; ======================================================================== ;;
;;  TRKPSGUPD     Updates the PSG                                           ;;
;; ======================================================================== ;;
TRKPSGUPD   PROC

            MVI@    R3,     R1          ; read note

            ADDI    #12,    R3          ; (R3 = COUNT_x)
            MVI@    R3,     R2          ; read channel counter -> R2
            CMPI    #$FF,   R2          ; prevents loop after $FF
            BEQ     @@cnt_ok

            INCR    R2                  ; increment counter
            MVO@    R2,     R3
            DECR    R2

@@cnt_ok    CMPI    #85,    R1          ; drum ?
            BGE     @@drum

;; ------------------------------------------------------------------------ ;;
;;  Standard instrument                                                     ;;
;; ------------------------------------------------------------------------ ;;
            SUBI    #3,     R3          ; (R3 = INSTR_x)
            MVI@    R3,     R4          ; R4 = pointer to instrument
            ADD     INS_PTR,R4

            PSHR    R2                  ; apply pitch effect
            ANDI    #3,     R2
            ADD@    R4,     R2
            ADD@    R2,     R1

            ADDI    #@@nt-1,R1          ; read period from notes table
            MVI@    R1,     R0          ; R0 = period

            ADDI    #84,    R1          ; read vibrato amplitude for this note
            MVI@    R1,     R1          ; R1 = vibrato amplitude

            MVI@    R4,     R2          ; R2 = type of vibrato for this channel
            CMPI    #1,     R2
            BLT     @@vibr0             ; no vibrato ?
            BEQ     @@low_vibr          ; low vibrato ?

            CMPI    #2,     R2
            BGT     @@apply_vb          ; high vibrato --> amplitude unchanged

            SLR     R1                  ; medium vibrato --> 1/2 amplitude
            INCR    PC

@@low_vibr  SLR     R1,     2           ; low vibrato --> 1/4 amplitude

@@apply_vb  MVI     COUNT_M,R2          ; apply vibrato
            ANDI    #7,     R2          ; according to current step
            ADDI    #@@v_tb,R2          ; (i.e. COUNT_M % 8)
            MVI@    R2,     PC

@@v_tb      DECLE   @@vibr1, @@vibr2    ; vibrato processing index
            DECLE   @@vibr0, @@vibr3
            DECLE   @@vibr4, @@vibr3
            DECLE   @@vibr0, @@vibr2

@@vibr1     SUBR    R1,     R0          ; - amplitude
            B       @@vibr0

@@vibr2     SLR     R1                  ; - 1/2 amplitude
            SUBR    R1,     R0
            B       @@vibr0

@@vibr3     SLR     R1                  ; + 1/2 amplitude
            ADDR    R1,     R0
            INCR    PC

@@vibr4     ADDR    R1,     R0          ; + amplitude

@@vibr0     ADDI    #IN2PER,R3          ; write period
            MVO@    R0,     R3          ; (low)
            SWAP    R0
            ADDI    #4,     R3
            MVO@    R0,     R3          ; (high)
            ADDI    #PER2CN,R3

            PULR    R0                  ; R0 = channel counter / 2
            SLR     R0

@@env       MVI@    R4,     R4          ; R4 = pointer to envelope

            ADD@    R4,     PC          ; apply speed of envelope
            SLR     R0
            SLR     R0
            SLR     R0

            MOVR    R0,     R1          ; get volume from envelope
            SLR     R0,     2
            ADDR    R0,     R4
            MVI@    R4,     R0
            ANDI    #3,     R1
            ADDI    #@@e_tb,R1
            MVI@    R1,     PC

@@e_tb      DECLE   @@env0, @@env1
            DECLE   @@env2, @@env3

@@env1      SWAP    R0
            B       @@env3

@@env0      SWAP    R0

@@env2      SLR     R0,     2
            SLR     R0,     2

@@env3      ANDI    #$F,    R0

            SUBI    #6,     R3          ; (R3 = VOL_x)
            SUB@    R3,     R0          ; get volume from song
            SUB     G_FAD,  R0          ; apply global volume fading
            BPL     @@upd_vol

            CLRR    R0

@@upd_vol   ADDI    #V2V,   R3          ; apply new volume
            MVO@    R0,     R3

            JR      R5                  ; return

;; ------------------------------------------------------------------------ ;;
;;  Drum                                                                    ;;
;; ------------------------------------------------------------------------ ;;
;;  WARNING: drums are currently supported on channel A only                ;;
;; ------------------------------------------------------------------------ ;;
@@drum      CMPI    #8,     R2          ; end of drum ?
            BGE     @@end_drum

            SUBI    #85-3*4,R1          ; get pointer to drum data
            ADD     INS_PTR,R1
            MVI@    R1,     R4
            SLL     R2,     2
            ADDR    R2,     R4

            MVI@    R4,     R0          ; tone period
            MVO     R0,     $01F0
            SWAP    R0
            MVO     R0,     $01F4

            MVI@    R4,     R0          ; noise period
            MVO     R0,     $01F9

            MVI@    R4,     R0          ; enable tone / noise
            MVO     R0,     $01F8

            MVI@    R4,     R0          ; volume
            SUB     G_FAD,  R0
            BPL     @@drum_vol

@@end_drum  CLRR    R0

@@drum_vol  MVO     R0,     $01FB

            JR      R5

;; ======================================================================== ;;
;;  Periods of the 84 defined notes                                         ;;
;;  (from C-1 to B-7)                                                       ;;
;; ======================================================================== ;;
@@nt        DECLE   $0D5C, $0C9D, $0BE7, $0B3C, $0A9B, $0A02, $0973, $08EB
            DECLE   $086B, $07F2, $0780, $0714, $06AE, $064E, $05F4, $059E
            DECLE   $054D, $0501, $04B9, $0475, $0435, $03F9, $03C0, $038A
            DECLE   $0357, $0327, $02FA, $02CF, $02A7, $0281, $025D, $023B
            DECLE   $021B, $01FC, $01E0, $01C5, $01AC, $0194, $017D, $0168
            DECLE   $0153, $0140, $012E, $011D, $010D, $00FE, $00F0, $00E2
            DECLE   $00D6, $00CA, $00BE, $00B4, $00AA, $00A0, $0097, $008F
            DECLE   $0087, $007F, $0078, $0071, $006B, $0065, $005F, $005A
            DECLE   $0055, $0050, $004C, $0047, $0043, $0040, $003C, $0039
            DECLE   $0035, $0032, $0030, $002D, $002A, $0028, $0026, $0024
            DECLE   $0022, $0020, $001E, $001C

;; ======================================================================== ;;
;;  Vibrato amplitude for each note above                                   ;;
;;  (30% of an half-tone)                                                   ;;
;; ======================================================================== ;;
            DECLE   $003B, $0038, $0035, $0032, $002F, $002C, $002A, $0028
            DECLE   $0025, $0023, $0021, $001F, $001E, $001C, $001A, $0019
            DECLE   $0018, $0016, $0015, $0014, $0013, $0012, $0011, $0010
            DECLE   $000F, $000E, $000D, $000C, $000C, $000B, $000A, $000A
            DECLE   $0009, $0009, $0008, $0008, $0007, $0007, $0007, $0006
            DECLE   $0006, $0006, $0005, $0005, $0005, $0004, $0004, $0004
            DECLE   $0004, $0003, $0003, $0003, $0003, $0003, $0003, $0002
            DECLE   $0002, $0002, $0002, $0002, $0002, $0002, $0002, $0002
            DECLE   $0001, $0001, $0001, $0001, $0001, $0001, $0001, $0001
            DECLE   $0001, $0001, $0001, $0001, $0001, $0001, $0001, $0001
            DECLE   $0001, $0001, $0001, $0000

            ENDP

;; ======================================================================== ;;
;;  End of File:  tracker.asm                                               ;;
;; ======================================================================== ;;
