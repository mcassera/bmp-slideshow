

.cpu "w65c02"	


DMA_CTRL        =   $df00                       ; dma control register
DMA_CTRL_START  =   $80                         ; start dma operation
DMA_CTRL_FILL   =   $04                         ; dma fill operation
DMA_CTRL_ENABLE =   $01                         ; dma engine enabled

DMA_STATUS      =   $df01                       ; dma status register (read only)
DMA_STAT_BUSY   =   $80                         ; dma engine is busy

DMA_FILL_VALUE  =   $df01                       ; byte value for fill operation

DMA_SRC_ADDR    =   $df04                       ; dma source address
DMA_DST_ADDR    =   $df08                       ; dma destination address
DMA_COUNT       =   $df0c                       ; number of bytes to copy

bitmap_base     =   $22ac0                      ; location of bitmap


Start:

*=$c0								; Set up buffer for Kernel communication
	.dsection zp						; Define position for zp (zero page)
	.cerror * > $cf, "Too many Zero page variables"

* = $7800


        .include "api.asm"		                        ; This is the Kernel API for communication

SetupKernel:							; Set up the API to work with

	.section zp						; Zero page section $c0 to $c8
event:	.dstruct	kernel.event.event_t
        .send

init_events:
        lda #<event
        sta kernel.args.events
        lda #>event
        sta kernel.args.events+1

        lda #kernel.args.timer.FRAMES		; set the Timer to Frames
        ora #kernel.args.timer.QUERY		; and query what frame we're on
        sta kernel.args.timer.units		; store in units parameter
        jsr kernel.Clock.SetTimer		; jsr to Kernel routine to get current frame
        adc #$01				; add 1 to Accumulator for next frame
        sta kernel.args.timer.absolute		; store in timer.absolute paramter
        sta kernel.args.timer.cookie		; saved as a cookie to the kernel (same as frame number)
        lda #kernel.args.timer.FRAMES		; set the Timer to Frames
        sta kernel.args.timer.units		; store in units parameter
        jsr kernel.Clock.SetTimer		; jsr to Kernel routine to set timer


handle_events:
        lda kernel.args.events.pending		; Peek at the queue to see if anything is pending
        bpl handle_events			; Nothing to do
        jsr kernel.NextEvent			; Get the next event.
        bcc dispatch			        ; run dispatch
        jmp handle_events			; go and check for another event        

dispatch:
        lda event.type				; get the event type from Kernel
        cmp #kernel.event.timer.EXPIRED		; is the event timer.EXPIRED?
        beq UpdateScreen			; run the screen update
        jmp handle_events

UpdateScreen:
        pha                                     ; store some registers before we set the interrupt
        phx 
        php 
        sei                                     ; set the interrupt
        ldy $01                                 ; get our current i/o setting and push to stack
        phy 



        lda #$c0                                ; set the bottom of the graphic screen for later use
        sta dest
        lda #$2a 
        sta dest+1
        lda #$02 
        sta dest+2

        ldx #240                                ; 240 lines of 320 bytes.
loop:
        stz $01                                 ; set i/o to 0
        lda DMA_CTRL_ENABLE                     ; set DMA to enable
        sta DMA_CTRL                            ; and store in dma register
        lda source                              ; load the source address of the bitmap data
        sta DMA_SRC_ADDR                        ; and put into the DMA source register
        lda source+1
        sta DMA_SRC_ADDR+1
        lda source+2
        sta DMA_SRC_ADDR+2
        lda dest                                ; load the destination address for the dma
        sta DMA_DST_ADDR                        ; and store in the dma register
        lda dest+1
        sta DMA_DST_ADDR+1
        lda dest+2
        sta DMA_DST_ADDR+2
        lda #$40                                ; store 320 bytes into the dma count register
        sta DMA_COUNT
        lda #$01
        sta DMA_COUNT+1
        stz DMA_COUNT+2
        lda #$81                                ; start the dma engine
        sta DMA_CTRL 

wait_dma:                                       ; wait for dma to finish
        lda DMA_STATUS
        bmi wait_dma
        stz DMA_CTRL                            ; turn off the dma engine

        clc                                     ; add 320 to the source data
        lda source
        adc #$40
        sta source
        lda source+1
        adc #$01
        sta source+1
        lda source+2
        adc #$00
        sta source+2

        sec                                     ; subtract 320 from the dest target
        lda dest
        sbc #$40
        sta dest
        lda dest+1
        sbc #$01
        sta dest+1
        lda dest+2
        sbc #$00
        sta dest+2

        dex                                     ; reduce x by one to countown 240 lines
        bne loop                                ; if not zero then loop

        pla                                     ; restore the I/O control
        sta $01
        plp                                     ; restore values back to before we stopped the interrupt
        plx 
        pla 
        cli  

        rts                                     ; give control back to basic

source:     .byte   $00,$00,$00                 ; pokel from basic for the start of pixel data
dest:       .byte   $00,$00,$00                 ; set at the top of this program


