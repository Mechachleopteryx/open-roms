;; #LAYOUT# STD *        #TAKE
;; #LAYOUT# CRT KERNAL_1 #TAKE
;; #LAYOUT# M65 KERNAL_1 #TAKE
;; #LAYOUT# *   *        #IGNORE

;
; Tape (turbo) part of the LOAD routine
;

; Initially based on routine by enthusi/Onslaught, found here:
; - https://codebase64.pokefinder.org/doku.php?id=base:turbotape_loader_source
; but heavily reworked since then. Still, original authors deserve credits!


!ifdef CONFIG_TAPE_TURBO {


!ifndef CONFIG_TAPE_AUTODETECT {

load_tape_turbo:

} else {

load_tape_auto:
}

	jsr tape_ditch_verify              ; only LOAD is supported, no VERIFY

	; Prepare for sound effects
	jsr tape_clean_sid

	; Start playing
	jsr tape_common_prepare_cia
	jsr tape_ask_play
!ifdef CONFIG_TAPE_HEAD_ALIGN {
	jsr tape_prepare_reading
}

	; FALLTROUGH

!ifdef CONFIG_TAPE_AUTODETECT {

load_tape_turbo_takeover:             ; entry point for normal->turbo takeover

	jsr tape_common_autodetect
	+bcc load_tape_normal_takeover
}

	; FALLTROUGH

load_tape_turbo_header:

	; Read file header; structure described here:
	; - https://www.luigidifraia.com/c64/docs/tapeloaders.html#turbotape64
	;
	; 1 byte           - file type (0 = data, odd value = relocatable, even value = non-relocatable)
	; 2 bytes          - start address
	; 2 bytes          - end address + 1
	; 1 byte           - if $B0 (tape timing) contained at the time of saving
	;                    (we skip this one to match normal system header)
	; 16 bytes         - filename, padded with 0x20

	jsr tape_turbo_sync_header
!ifdef CONFIG_TAPE_AUTODETECT {
	+bcs load_tape_normal_takeover   ; failure, probably not a turbo tape file
}
	ldy #$00
	sta (TAPE1), y                     ; store header type
	iny

	; FALLTROUGH

load_tape_turbo_header_loop:

	jsr tape_turbo_get_byte
	sta (TAPE1), y
	iny
	cpy #$05
	bne @1
	jsr tape_turbo_get_byte            ; tape timing - skip this one
@1:
	cpy #$C0                           ; header is 192 bytes long in total
	bne load_tape_turbo_header_loop

	; For non-relocatable files, override secondary address
	ldy #$00                           ; XXX optimize out for 65C02
	lda (TAPE1), y
	beq @2
	and #$01
	bne @2
	lda #$01                           ; XXX for 65C02 just set the bit with one instruction
	sta SA
@2:
	; Handle the header

	jsr tape_clean_sid
	jsr tape_handle_header
	bcs load_tape_turbo_header         ; if name does not match, look for other header

	; FALLTROUGH

load_tape_turbo_payload:

	; Copy helper byte store routine to RAM, provide default memory mapping

	ldx #(__tape_turbo_bytestore_size - 1)
@3:
	lda tape_turbo_bytestore_source, x
	sta __tape_turbo_bytestore, x
	dex
	bpl @3

	lda CPU_R6510
	sta __tape_turbo_bytestore_defmap

	; Initial checksum value

	lda #$00
	sta PRTY

	; Read file payload
@4:
	jsr tape_turbo_sync_payload
!ifdef CONFIG_TAPE_AUTODETECT {
	bcs @4
}

	; FALLTROUGH

load_tape_turbo_loop:

	jsr tape_turbo_get_byte
	jsr __tape_turbo_bytestore         ; like 'sta (MEMUSS),y' - but under I/O

	eor PRTY                           ; handle checksum
	sta PRTY

	; Advance MEMUSS (see Mapping the C64, page 36)
!ifndef HAS_OPCODES_65CE02 {
	jsr lvs_advance_MEMUSS
} else {
	inw MEMUSS+0
}
	jsr lvs_check_EAL
	bne load_tape_turbo_loop

	; Get the checksum
	jsr tape_turbo_get_byte
	tax

	; Silence audio
	jsr tape_clean_sid

	; Verify the checksum
	cpx PRTY
	+beq tape_load_success
	jmp tape_load_error
}
