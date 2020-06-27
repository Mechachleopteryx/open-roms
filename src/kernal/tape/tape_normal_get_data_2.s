// #LAYOUT# STD *        #TAKE
// #LAYOUT# M65 KERNAL_1 #TAKE
// #LAYOUT# *   *        #IGNORE

//
// Tape (normal) helper routine - data block (backup) reading
//


#if CONFIG_TAPE_NORMAL && !CONFIG_TAPE_NO_ERROR_CORRECTION


tape_normal_get_data_2:

	// First check if there is a need to read anything

	lda PTR1
	beq tape_normal_get_data_2_log_checksum

	// Read sync of the block
	
	ldy #$09
	jsr tape_normal_sync
	bcs tape_normal_get_data_2_done              // Carry already set, will indicate error
	jsr tape_normal_get_marker

	// FALLTROUGH

tape_normal_get_data_2_loop:

	// Check if there are missing bytes to read
	lda PTR1
	cmp PTR2
	beq tape_normal_get_data_2_log_checksum      // branch if no more errors to correct

	// Read missing bytes

	jsr tape_normal_get_byte
	bcc tape_normal_get_data_2_loop_byte_OK

	// Problem reading a byte - just skip it

	bcs tape_normal_get_data_2_loop_advance

tape_normal_get_data_2_loop_byte_OK:

	jsr load_cmp_log_MEMUSS
	beq tape_normal_get_data_2_loop_from_log     // branch if byte from the log

	jsr tape_normal_get_marker
	bcs tape_normal_get_data_2_log_checksum      // branch if end of blocks
	bcc tape_normal_get_data_2_loop_advance


tape_normal_get_data_2_loop_from_log:

	// This is a byte from the log

	jsr tape_normal_get_marker
	bcs !+

	lda INBIT
	ldy #$00
#if ROM_LAYOUT_M65
	jsr tape_normal_byte_store
#else
	sta (MEMUSS), y
#endif
!:
	jsr tape_normal_update_checksum

	// FALLTROUGH

tape_normal_get_data_2_loop_advance:

	// Advance pointer
#if !HAS_OPCODES_65CE02
	jsr lvs_advance_MEMUSS
#else
	inw MEMUSS+0
#endif

	jmp tape_normal_get_data_2_loop


tape_normal_get_data_2_log_checksum:

	lda PTR1
	cmp PTR2
	bne tape_normal_get_data_2_done              // Carry already set

	// Validate checksum

	lda RIPRTY
	cmp #$01                                     // sets Carry if checksum verification fails

	// FALLTROUGH

tape_normal_get_data_2_done:

	rts


load_cmp_log_MEMUSS:

	ldx PTR2
	lda STACK+0, x
	cmp MEMUSS+0
	bne !+

	lda STACK+1, x
	cmp MEMUSS+1
	bne !+

	// MEMUSS matches address from the log

	inc PTR2
	inc PTR2
	lda #$00                                     // to set Zero flag
!:
	rts


#endif