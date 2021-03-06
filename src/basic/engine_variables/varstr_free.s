;; #LAYOUT# STD *       #TAKE
;; #LAYOUT# *   BASIC_0 #TAKE
;; #LAYOUT# *   *       #IGNORE

;
; Releases back memory used by string
;
; Input:
; - DSCPNT+0           - string size
; - DSCPNT+1, DSCPNT+2 - pointer to string
;


varstr_free:

	; Check the string size - do not do anything if 0

	lda DSCPNT+0
	bne @1
	rts
@1:
	; Check if string is above FRETOP (in string area)

	jsr helper_cmp_fretop
	bcs varstr_free_no_checks

	; No, it does not belong to string area - quit

	rts

varstr_free_no_checks: ; entry point to be used when it is clear that string is not empty and above FRETOP

	; Check if this is the lowest string

	bne varstr_free_inside

	; This is the lowest string - so just increase FRETOP, this way
	; the garbage collector will not be needed that quickly

	jsr helper_FRETOP_up                         ; free the string data

!ifndef HAS_OPCODES_65CE02 {

	lda #$02                                     ; free the back-pointer
	sta DSCPNT+0
	jmp helper_FRETOP_up

} else { ; HAS_OPCODES_65CE02

	inw FRETOP                                   ; free the back-pointer
	inw FRETOP

	rts
}

varstr_free_inside:

	; This is not the lowest string; mark it as free
	; First preserve the string size, it will make it easier for the garbage collector

	; Increase DSCPNT+1/+2 to point to the back-pointer minus 1

	dec DSCPNT+0

	clc
	lda DSCPNT+1
	adc DSCPNT+0
	sta DSCPNT+1
	bcc @2
	inc DSCPNT+2
@2:
	; Put the size-1, garbage collector will make use of this value

	lda DSCPNT+0
	ldy #$00

!ifdef CONFIG_MEMORY_MODEL_60K {
	ldx #<DSCPNT+1
	jsr poke_under_roms
} else { ; CONFIG_MEMORY_MODEL_38K || CONFIG_MEMORY_MODEL_46K || CONFIG_MEMORY_MODEL_50K
	sta (DSCPNT+1), y
}

	; Now fill-in the back-pointer with 0's

	tya
	iny

!ifdef CONFIG_MEMORY_MODEL_60K {
	jsr poke_under_roms
} else { ; CONFIG_MEMORY_MODEL_38K || CONFIG_MEMORY_MODEL_46K || CONFIG_MEMORY_MODEL_50K
	sta (DSCPNT+1), y
}

	iny

!ifdef CONFIG_MEMORY_MODEL_60K {
	jmp poke_under_roms
} else { ; CONFIG_MEMORY_MODEL_38K || CONFIG_MEMORY_MODEL_46K || CONFIG_MEMORY_MODEL_50K
	sta (DSCPNT+1), y
	rts
}
