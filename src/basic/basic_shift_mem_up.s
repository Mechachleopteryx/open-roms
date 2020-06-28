// #LAYOUT# STD *       #TAKE
// #LAYOUT# *   BASIC_0 #TAKE
// #LAYOUT# *   *       #IGNORE


basic_shift_mem_up_and_relink:
	// Shift memory up from OLDTXT
	// X bytes.

	// NOTE: Pointers need to be reduced by one, due to the way
	// the copyroutine works, so we do that here.
	// Work out end point of destination
	txa
	clc
	adc VARTAB+0
	sta memmove__dst+0
	lda VARTAB+1
	adc #0
	sta memmove__dst+1
	lda memmove__dst+0
	sec
	sbc #1
	sta memmove__dst+0
	lda memmove__dst+1
	sbc #0
	sta memmove__dst+1

	// End point of source is just current end of BASIC text
	lda VARTAB+0
	sec
	sbc #1
	sta memmove__src+0
	lda VARTAB+1
	sbc #0
	sta memmove__src+1

	// Work out size of region to copy
	lda VARTAB+0
	sec
	sbc OLDTXT+0
	sta memmove__size+0	
	lda VARTAB+1
	sbc OLDTXT+1
	sta memmove__size+1
	
	// jsr printf
	// .text "TOP OF BASIC = $"
	// .byte $f1,<VARTAB,>VARTAB
	// .byte $f0,<VARTAB,>VARTAB
	// .byte $0d
	// .text "SHIFTING UP $"
	// .byte $f1,<memmove__size,>memmove__size
	// .byte $f0,<memmove__size,>memmove__size
	// .text " BYTES FROM $"
	// .byte $f1,<memmove__src,>memmove__src
	// .byte $f0,<memmove__src,>memmove__src
	// .text " TO $"
	// .byte $f1,<memmove__dst,>memmove__dst
	// .byte $f0,<memmove__dst,>memmove__dst
	// .byte $0d,0
	
	// To make life simple for the copy routine that lives in RAM,
	// we have to adjust the end pointers down one page and set Y to the low
	// byte of the copy size.
	lda memmove__src+0
	sec
	sbc memmove__size+0
	sta memmove__src+0
	lda memmove__src+1
	sbc #0
	sta memmove__src+1

	lda memmove__dst+0
	sec
	sbc memmove__size+0
	sta memmove__dst+0
	lda memmove__dst+1
	sbc #0
	sta memmove__dst+1

	// Now make exit easy, by being able to check for zero on size high byte when done
	inc memmove__size+1	
	
	// Then set Y to the number offset required
	ldy memmove__size+0
	iny

	stx __tokenise_work3
	
	// jsr printf
	// .text "REVISED BOUNDS $"
	// .byte $f1,<memmove__size,>memmove__size
	// .byte $f0,<memmove__size,>memmove__size
	// .text " BYTES FROM $"
	// .byte $f1,<memmove__src,>memmove__src
	// .byte $f0,<memmove__src,>memmove__src
	// .text " TO $"
	// .byte $f1,<memmove__dst,>memmove__dst
	// .byte $f0,<memmove__dst,>memmove__dst
	// .byte $0d,0
	
	// Do the copy
	jsr shift_mem_up
	
	// Now fix the pointer to the next line
	
	// First, we need to point the current BASIC line
	// pointer to itself, so that we can add the shift
	// to make it end up pointing to the next line
	ldy #0

	lda OLDTXT+0

#if CONFIG_MEMORY_MODEL_60K
	ldx #<OLDTXT+0
	jsr poke_under_roms
#else // CONFIG_MEMORY_MODEL_38K || CONFIG_MEMORY_MODEL_46K || CONFIG_MEMORY_MODEL_50K
	sta (OLDTXT),y
#endif

	iny
	lda OLDTXT+1

#if CONFIG_MEMORY_MODEL_60K
	jsr poke_under_roms
#else // CONFIG_MEMORY_MODEL_38K
	sta (OLDTXT),y
#endif
	
relink_up_next_line:

	// XXX reuse code from cmd_old
	
	// Advance pointer by tokenise_word3 bytes
	ldy #0

#if CONFIG_MEMORY_MODEL_60K
	ldx #<OLDTXT+0
	jsr peek_under_roms
#elif CONFIG_MEMORY_MODEL_46K || CONFIG_MEMORY_MODEL_50K
	jsr peek_under_roms_via_OLDTXT
#else // CONFIG_MEMORY_MODEL_38K
	lda (OLDTXT),y
#endif

	sta memmove__dst+0
	clc
	adc __tokenise_work3
	sta memmove__src+0
	iny
	php

#if CONFIG_MEMORY_MODEL_60K
	jsr peek_under_roms
	cmp #$00
#elif CONFIG_MEMORY_MODEL_46K || CONFIG_MEMORY_MODEL_50K
	jsr peek_under_roms_via_OLDTXT
#else // CONFIG_MEMORY_MODEL_38K
	lda (OLDTXT),y
#endif

	sta memmove__dst+1
	plp
	adc #0
	sta memmove__src+1

	// jsr printf
	// .text "LINE ADDR = $"
	// .byte $f1,<OLDTXT,>VARTAB
	// .byte $f0,<OLDTXT,>VARTAB
	// .text $d,"  BEFORE = $"
	// .byte $f1,<memmove__dst,>memmove__dst
	// .byte $f0,<memmove__dst,>memmove__dst
	// .text ",  AFTER = $"
	// .byte $f1,<memmove__src,>memmove__src
	// .byte $f0,<memmove__src,>memmove__src
	// .byte $d
	// .byte 0
	
	// Write memmove__src back to current line pointer
	ldy #0
	lda memmove__src+0

#if CONFIG_MEMORY_MODEL_60K
	ldx #<OLDTXT+0
	jsr poke_under_roms
#else // CONFIG_MEMORY_MODEL_38K
	sta (OLDTXT),y
#endif

	iny
	lda memmove__src+1

#if CONFIG_MEMORY_MODEL_60K
	jsr poke_under_roms
#else // CONFIG_MEMORY_MODEL_38K
	sta (OLDTXT),y
#endif
	
relink_up_loop:	
	// Now advance pointer to the next line,
	lda memmove__src+0
	sta OLDTXT+0
	lda memmove__src+1
	sta OLDTXT+1

	// Have we run out of lines to patch?
	jsr peek_line_pointer_null_check
	bcs relink_up_next_line

	rts
