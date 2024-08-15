

.cpu "w65c02"	


DMA_CTRL        =   $df00               ; dma control register
DMA_CTRL_START  =   $80                 ; start dma operation
DMA_CTRL_FILL   =   $04                 ; dma fill operation
DMA_CTRL_ENABLE =   $01                 ; dma engine enabled

DMA_STATUS      =   $df01               ; dma status register (read only)
DMA_STAT_BUSY   =   $80                 ; dma engine is busy

DMA_FILL_VALUE  =   $df01               ; byte value for fill operation

DMA_SRC_ADDR    =   $df04               ; dma source address
DMA_DST_ADDR    =   $df08               ; dma destination address
DMA_COUNT       =   $df0c               ; number of bytes to copy

bitmap_base     =   $22ac0              ; location of last line of bitmap

* = $7800

Start:

        lda #$c0                        ; set the bottom of the graphic screen for later use
        sta dest
        lda #$2a 
        sta dest+1
        lda #$02 
        sta dest+2

        pha                             ; store some registers before we set the interrupt
        phx 
        php 
        sei                             ; set the interrupt
        ldy $01                         ; get our current i/o setting and push to stack
        phy 

        ldx #240                        ; 240 lines of 320 bytes.
loop:


        stz $01                         ; set i/o to 0

        lda DMA_CTRL_ENABLE             ; set DMA to enable
        sta DMA_CTRL                    ; and store in dma register

        lda source                      ; load the source address of the bitmap data
        sta DMA_SRC_ADDR                ; and put into the DMA source register
        lda source+1
        sta DMA_SRC_ADDR+1
        lda source+2
        sta DMA_SRC_ADDR+2


        lda dest                        ; load the destination address for the dma
        sta DMA_DST_ADDR                ; and store in the dma register
        lda dest+1
        sta DMA_DST_ADDR+1
        lda dest+2
        sta DMA_DST_ADDR+2

        lda #$40                        ; store 320 bytes into the dma count register
        sta DMA_COUNT
        lda #$01
        sta DMA_COUNT+1
        stz DMA_COUNT+2

        lda #$81                        ; start the dma engine
        sta DMA_CTRL 


wait_dma:                               ; wait for dma to finish
        lda DMA_STATUS
        bmi wait_dma

        stz DMA_CTRL                    ; turn off the dma engine

        clc                             ; add 320 to the source data
        lda source
        adc #$40
        sta source
        lda source+1
        adc #$01
        sta source+1
        lda source+2
        adc #$00
        sta source+2

        sec                             ; subtract 320 from the dest target
        lda dest
        sbc #$40
        sta dest
        lda dest+1
        sbc #$01
        sta dest+1
        lda dest+2
        sbc #$00
        sta dest+2

        dex                             ; reduce x by one to countown 240 lines
        bne loop                        ; if not zero then loop

        pla                             ; restore the I/O control
        sta $01
        plp                             ; restore values back to before we stopped the interrupt
        plx 
        pla 
        cli                             ; clear the interrupt

        rts                             ; give control back to basic

source:     .byte   $00,$00,$00         ; pokel from basic for the start of pixel data
dest:       .byte   $00,$00,$00         ; set at the top of this program


