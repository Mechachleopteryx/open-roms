;; #LAYOUT# M65 KERNAL_C #TAKE
;; #LAYOUT# *   *        #IGNORE


; Routine takes many ideas from TWW/CTR proposal, see here:
; - http://codebase64.org/doku.php?id=base:scanning_the_keyboard_the_correct_and_non_kernal_way


m65_scnkey:

	; Initialize work variables for scanning the keyboard

	lda M65_KB_PRESSED+0
	sta M65_KB_PRESSED_OLD+0
	lda M65_KB_PRESSED+1
	sta M65_KB_PRESSED_OLD+1
	lda M65_KB_PRESSED+2
	sta M65_KB_PRESSED_OLD+2

	jsr m65_scnkey_init_pressed

	;
	; Scan the whole keyboard, store results in memory
	;

	ldx #$08

	lda #%01111111
	and KBSCN_BUCKY
	sta M65_KB_BUCKY

	stx KBSCN_SELECT                   ; no loop here, for performance and accuracy purposes
	lda KBSCN_PEEK
	eor #$FF                           ; let bit 1 mean 'pressed', not the otherwise
	sta M65_KB_COLSCAN+8

	dex
	stx KBSCN_SELECT
	lda KBSCN_PEEK
	eor #$FF
	sta M65_KB_COLSCAN+7

	dex
	stx KBSCN_SELECT
	lda KBSCN_PEEK
	eor #$FF
	sta M65_KB_COLSCAN+6

	dex
	stx KBSCN_SELECT
	lda KBSCN_PEEK
	eor #$FF
	sta M65_KB_COLSCAN+5

	dex
	stx KBSCN_SELECT
	lda KBSCN_PEEK
	eor #$FF
	sta M65_KB_COLSCAN+4

	dex
	stx KBSCN_SELECT
	lda KBSCN_PEEK
	eor #$FF
	sta M65_KB_COLSCAN+3

	dex
	stx KBSCN_SELECT
	lda KBSCN_PEEK
	eor #$FF
	sta M65_KB_COLSCAN+2

	dex
	stx KBSCN_SELECT
	lda KBSCN_PEEK
	eor #$FF
	sta M65_KB_COLSCAN+1

	dex
	stx KBSCN_SELECT
	lda KBSCN_PEEK
	eor #$FF
	sta M65_KB_COLSCAN+0

	;
	; Calculate SHIFT / VENDOR / CTRL / ALT / NO SCROLL / CAPS LOCK status
	;

	lda SHFLAG
	sta LSTSHF                         ; needed for SHIFT+VENDOR support

	stx SHFLAG                         ; .X is $00 here

	lda M65_KB_BUCKY
	beq m65_scnkey_bucky_done
	dex                                ; index into kb_matrix_bucky_shflag

	; FALLTROUGH

m65_scnkey_bucky_loop:

	inx
	asr                                ; ASR preserves most significant bit, but in our case it is 0
	bcc @1

	; Bucky key pressed

	tay
	lda kb_matrix_bucky_shflag, x
	ora SHFLAG
	sta SHFLAG
	tya
@1:
	bne m65_scnkey_bucky_loop

	; FALLTROUGH

m65_scnkey_bucky_done:

	; Set KEYTAB vector

	lda KEYLOG+1
	bne @1
	jsr m65_scnkey_set_keytab          ; KEYLOG routine on zeropage? most likely vector not set
	bra m65_scnkey_keytab_set_done
@1:
	jsr (KEYLOG)

m65_scnkey_keytab_set_done:

	;
	; Scan the keyboard matrix stored in memory to determine which keys were pressed
	;

	lda M65_KB_COLSCAN+0               ; no loop here - for performance purposes
	ora M65_KB_COLSCAN+1
	ora M65_KB_COLSCAN+2
	ora M65_KB_COLSCAN+3
	ora M65_KB_COLSCAN+4
	ora M65_KB_COLSCAN+5
	ora M65_KB_COLSCAN+6
	ora M65_KB_COLSCAN+7
	ora M65_KB_COLSCAN+8
	+beq m65_scnkey_try_joystick       ; branch if no key was pressed

	ldx #$08

	; FALLTROUGH

m65_scnkey_loop:

	lda M65_KB_COLSCAN, x
@8:	
	asl                                ; no loop here, for performance resons
	bcc @7

	ldy #$07
	jsr m65_scnkey_add_pressed
@7:
	asl
	bcc @6

	ldy #$06
	jsr m65_scnkey_add_pressed
	beq @0
@6:
	asl
	bcc @5

	ldy #$05
	jsr m65_scnkey_add_pressed
	beq @0
@5:
	asl
	bcc @4

	ldy #$04
	jsr m65_scnkey_add_pressed
	beq @0
@4:
	asl
	bcc @3

	ldy #$03
	jsr m65_scnkey_add_pressed
	beq @0
@3:
	asl
	bcc @2

	ldy #$02
	jsr m65_scnkey_add_pressed
	beq @0
@2:
	asl
	bcc @1

	ldy #$01
	jsr m65_scnkey_add_pressed
	beq @0
@1:
	asl
	bcc @0

	ldy #$00
	jsr m65_scnkey_add_pressed
@0:
	dex
	bpl m65_scnkey_loop

	;
	; Analyze currently and previously pressed keys
	;

	; First select the new keys

	lda M65_KB_PRESSED+0
	jsr m65_scnkey_compare_with_old
	jsr m65_scnkey_add_if_new_valid

	lda M65_KB_PRESSED+1
	jsr m65_scnkey_compare_with_old
	jsr m65_scnkey_add_if_new_valid

	lda M65_KB_PRESSED+2
	jsr m65_scnkey_compare_with_old
	jsr m65_scnkey_add_if_new_valid

	; If we have more than one key - consider it a jam

	lda M65_KB_PRESSED_NEW+1
	bpl m65_scnkey_jam

	; If we have exactly one new key - this is our key to output

	ldy M65_KB_PRESSED_NEW+0
	bpl m65_scnkey_got_key

	; No new key - check if the last one is still pressed

	ldy LSTX
	cpy M65_KB_PRESSED+0
	beq m65_scnkey_try_repeat
	cpy M65_KB_PRESSED+1
	beq m65_scnkey_try_repeat
	cpy M65_KB_PRESSED+2
	beq m65_scnkey_try_repeat

	; Nope, previous key is not pressed

	; FALLTROUGH

m65_scnkey_try_joystick:

	lda M65_JOYCRSR
	cmp #$02
	beq m65_scnkey_try_joy2
	cmp #$01
	bne m65_scnkey_no_keys

	; FALLTROUGH

m65_scnkey_try_joy1:

	lda #$FF
	sta CIA1_PRA                       ; disconnect all the rows to prevent keyboard interference

	lda CIA1_PRB
	bra m65_scnkey_try_joy_common

m65_scnkey_try_joy2:

	lda CIA1_PRA

	; FALLTROUGH

m65_scnkey_try_joy_common:

	and #%00001111                     ; filter out anything but joystick movement
	beq m65_scnkey_no_keys             ; branch if no joystick movement detected

	; Decode joystick event using appropriate matrix

	ldy #$03
@1:
	cmp kb_matrix_joy_status, y
	beq @2
	dey
	bpl @1

	; Not found

	bra m65_scnkey_no_keys
@2:
	; Found joystick movement

	lda kb_matrix_joy_keytab_lo, y
	sta KEYTAB+0
	lda kb_matrix_joy_keytab_hi, y
	sta KEYTAB+1
	lda kb_matrix_joy_keytab_idx, y
	tay

	; FALLTROUGH

m65_scnkey_got_key: ; .Y should now contain the key offset in matrix pointed by KEYTAB

	cpy LSTX
	beq m65_scnkey_try_repeat          ; branch if the same key as previously
	sty LSTX

	; Reset key repeat counters

	lda #CONFIG_KEY_DELAY
	sta DELAY

	; FALLTROUGH

m65_scnkey_output_key:

	;
	; Output selected key to the keyboard buffer
	;

	; Check if we have free space in the keyboard buffer

	lda NDX
	cmp XMAX
	+bcs scnkey_buffer_full

	; Reinitialize secondary counter

	lda #$03
	sta KOUNT

	; Check if KEYTAB is valid

	lda KEYTAB+1
	beq m65_scnkey_no_keys

	; Retrieve the PETSCII code

	lda (KEYTAB), y

	; FALLTROUGH

m65_scnkey_got_petscii:

	; Put the key into the keyboard buffer

	beq m65_scnkey_no_keys             ; branch if we have no PETSCII code for this key
	ldy NDX
	sta KEYD, y
	inc NDX

	; FALLTROUGH

m65_scnkey_done:

	rts

m65_scnkey_pla_jam:

	pla
	pla
	pla

	; FALLTROUGH

m65_scnkey_jam:

	jsr m65_scnkey_init_pressed

	; FALLTROUGH

m65_scnkey_no_keys:

	; Mark no key press

	lda #$80
	sta LSTX
	rts

m65_scnkey_try_repeat:

!ifndef CONFIG_KEY_REPEAT_ALWAYS {

	; Check whether we should repeat keys - first the flag, afterwards hardcoded list

	lda RPTFLG
	bmi m65_scnkey_handle_repeat           ; branch if we should repeat always

	tya
	ldx #(__kb_matrix_alwaysrepeat_end - kb_matrix_alwaysrepeat - 1)
@1:
	cmp kb_matrix_alwaysrepeat, x
	beq m65_scnkey_handle_repeat
	dex
	bpl @1
	bmi m65_scnkey_done

	; FALLTROUGH

m65_scnkey_handle_repeat:

} ; no CONFIG_KEY_REPEAT_ALWAYS

	; Countdown before first repeat

	lda DELAY
	beq @1
	dec DELAY

	rts
@1:
	; Countdown before subsequent repeats

	lda KOUNT
	beq m65_scnkey_output_key          ; if second counter is also 0, we can repeat the key
	dec KOUNT

	rts



m65_scnkey_add_pressed:

	; Add pressed key to the 'M65_KB_PRESSED' list, first preserve .A

	pha

	; Make space on the list

	lda M65_KB_PRESSED+2
	+bpl m65_scnkey_pla_jam            ; branch if too many keys pressed
	lda M65_KB_PRESSED+1
	sta M65_KB_PRESSED+2
	lda M65_KB_PRESSED+0
	sta M65_KB_PRESSED+1

	; Store key scan code

	sty M65_KB_PRESSED+0
	txa
	asl
	asl
	asl
	adc M65_KB_PRESSED+0               ; Carry already cleared by ASL
	sta M65_KB_PRESSED+0

	; Restore .A and uit

	pla
	rts

m65_scnkey_compare_with_old:

	; Compare key index with the ones from previous scan

	cmp M65_KB_PRESSED_OLD+0
	beq @1
	cmp M65_KB_PRESSED_OLD+1
	beq @1
	cmp M65_KB_PRESSED_OLD+2
@1:
	rts

m65_scnkey_add_if_new_valid:

	beq @1
	cmp #$FF                           ; invalid key code
	beq @1
	
	; Filter-out SHIFT, VENDOR, etc.

	cmp #$0F                           ; left SHIFT
	beq @1
	cmp #$34                           ; right SHIFT
	beq @1
	cmp #$3A                           ; CONTROL
	beq @1
	cmp #$3D                           ; VENDOR
	beq @1
	cmp #$40                           ; NO SCROLL
	beq @1
	cmp #$42                           ; ALT
	beq @1

	; New, valid key index

	ldx M65_KB_PRESSED_NEW+1
	stx M65_KB_PRESSED_NEW+2
	ldx M65_KB_PRESSED_NEW+0
	stx M65_KB_PRESSED_NEW+1
	sta M65_KB_PRESSED_NEW+0
@1
	rts
