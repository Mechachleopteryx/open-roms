basic_main_loop:

	;; XXX - Check if direct or program mode, and get next line of input
	;; the appropriate way.
	;; XXX - For now, it is hard coded to direct mode
	
	;; Read a line of input
	ldx #$00
read_line_loop:	
	jsr $ffcf 		; KERNAL CHRIN
	bcs read_line_loop
	
	cmp #$0d
	beq got_line_of_input
	;; Not carriage return, so try to append to line so far
	cpx #80
	bcc +
	;; Report STRING TOO LONG error (Compute's Mapping the 64 p93)
	ldx #22
	jmp basic_do_error
*
	sta basic_input_buffer,x
	inx
	jmp read_line_loop

got_line_of_input:

	;; Store length of input buffer ready for tokenising
	stx tokenise_work1

	;; Strip leading spaces from the line
remove_leading_spaces:	
	lda $0200
	cmp #$20
	bne +
	ldx #1
rsl_l1:	lda $0200,x
	sta $01ff,x
	inx
	cpx tokenise_work1
	bne rsl_l1

	;; Reduce length of input by one
	dec tokenise_work1
	;; Stop trying to rim if we run out of input
	bne remove_leading_spaces
*	
	;; Do printing of the new line
	lda #$0d
	jsr $ffd2

	jsr tokenise_line	

	;; Has the user entered a line of BASIC beginning with a number?
	lda $0200
	cmp #$30
	bcc not_a_line
	cmp #$39
	bcs not_a_line

	;; Yes, the line begins with a number.
	;; Parse the line number and check validity
	inc $d020

	;; injest_number follows tokenise_work1 as the offset into the line,
	;; so remember the line length somewhere else for now.
	lda tokenise_work1
	sta tokenise_work2
	lda #$00
	sta tokenise_work1
	
	jsr injest_number

	lda tokenise_work1
	sta $0427
	
	
not_a_line:	
	
	jsr ready_message

	jmp basic_main_loop
