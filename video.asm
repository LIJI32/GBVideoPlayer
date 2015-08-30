; Before trying to read this file, read the technical document explaining how it
; works. When this referring to clocks in this file, it refers to "logical" CPU
; clocks, which is the result of a division by 4, Since every Z80 instruction has
; a CPI which is a multiple of 4.
;
; Generally speaking, once video playback has started, the HL register is used as
; a global which always points to the current video position in the ROM.

INCLUDE "gbhw.asm"

MBC5_bank_low EQU $2000
MBC5_bank_high EQU $3000
video_data_start EQU $4000

current_bank EQU $80
frame_repeat EQU $83
current_frame_start EQU $84
current_frame_start_bank EQU $86
hl_backup EQU $88
is_row_back_reference EQU $8A

current_music_pause EQU $90
music_pointer EQU $91
done_flag EQU $93

SECTION "VBlank", ROM0[$40]
    jp VBlank

SECTION "HBlank", ROM0[$48]
; Once the LCD controller starts "rendering" a line, we start a loop to change
; rLY (the Y scrolling of the background). On 8MHz Game Boy Z80, the controller
; "renders" 8 pixels per such loop iteration, which, on a Game Boy Color, allows
; us to control 20 (160/8) logical pixels per row. Later, another trick will let
; us effectively double this resolution to 40 pixels per row, while additionally
; improving the color resolution.
HBlank:
    ; Needs 31 clocks exactly before the loop starts

    ; This is for row-back-reference compression, which is currently disabled in
    ; the encoder.
    ld a, b ; 1
    ldh [hl_backup], a ; 2
    ld a, c ; 1
    ldh [hl_backup + 1], a ; 2

    ; Not sure how or why, but this routine gets called 145 times
    ; per frame instead of 144. The addional call is not rLY=144.
    ; Until I figure out which LY value is being used twice (or,
    ; which LY value greater than 144 is being used), we skip the
    ; last line so HL won't go out of sync with frame starts.
    ldh a, [rLY] ; 3
    xor $8F ; 2

    jr z, SkipLine ; 2 (If false)
    ld c, $42 ; 2

    ; 16 Nops
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

; Loop begins here
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
    ld a, [hli]
    ld [c], a
SwitchBankIfNeeded:
    ldh a, [is_row_back_reference]
    and a
    jr z, .keepHL
    ; These 4 lines are for row-back-reference compression
    ldh a, [hl_backup]
    ld h, a
    ldh a, [hl_backup + 1]
    ld l, a
.keepHL
    ; If hl >= $7FC0, we need to switch bank
    push hl
    ld de, -$7FC0
    add hl, de
    jr nc, .noNewBank

    ; Increase current bank and reset HL to its start.
    ld c, current_bank
    ld a, [c]
    inc c
    ld l, a
    ld a, [c]
    ld h,a
    inc hl
    ld a, h
    ld [MBC5_bank_high], a
    ld [c], a
    dec c
    ld a, l
    ld [MBC5_bank_low], a
    ld [c], a
    ld hl, video_data_start
    pop de ; Faster than increasing SP
    reti
.noNewBank
    pop hl
SkipLine:
    reti

SECTION "Header", ROM0[$100]

Start::
    di
    jp _Start

SECTION "Home", ROM0[$150]

_Start::
    ; Increase the CPU speed from 4MHz to 8MHz to allow greater resolution
    ld a, 1
    ldh [rKEY1], a
    stop

    ; Init the stack
    ld sp, $fffe

    ; Other inits
    call LCDOff
    call LoadGraphics
    call InitSound
    call CreateMap
    call CreateAttributeMap

    ; Start Playing
    jp InitVideo

WaitFrame::
    ldh a, [rLY]
    and a
    jr nz, WaitFrame
    ; Fall through

WaitVBlank::
    ldh a, [rLY]
    cp 145
    jr nz, WaitVBlank
    ret

LCDOff::
    call WaitVBlank
    ldh a, [rLCDC]
    and $7F
    ldh [rLCDC], a
    ret

LCDOn::
    di
    ldh a, [rLCDC]
    or $80
    ldh [rLCDC], a
    call WaitVBlank
    xor a
    ldh [rIF], a
    reti

InitSound::
    xor a
    ldh [rNR10], a
    ld a, $80
    ldh [rNR11], a
    ldh [rNR21], a
    ld a, $20
    ldh [rNR32], a

; Make the waveform square.
    ld a, $FF
    ld hl, $FF30

    ld b, $8
.loop
    ld [hli], a
    dec b
    jr nz, .loop

    xor a
    ld b, $8
.loop2
    ld [hli], a
    dec b
    jr nz, .loop2
    ret

LoadGraphics::
    ; Copy the two and only tiles we use. Each tile is split into two rectangles
    ; sized 8 * 4 pixels; the first one uses colors 0 and 1, and the second uses
    ; colors 2 and 3.
    ld de, $8000
    ld b, PixelStructureEnd - PixelStructure
    ld hl, PixelStructure
.loop
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, .loop
    ret

CreateMap::
    ; Create a map where even lines use tile 0, and odd lines use 1. This will
    ; produce a map of 4-pixel lines in colors 0, 1, 2, 3 looped.
    ld hl, $9800
    ld a, 0
    ld c, 16
    xor a
.loopY
    ld b, 32
.loopX
    ld [hli], a
    dec b
    jr nz, .loopX
    xor 1
    dec c
    jr nz, .loopY
    ret

CreateAttributeMap::
    ; Give each 2 lines of tiles a different palettes. Finally, this will create
    ; a map of 32 4-pixel lines, each with a different color.
    ld a, 1
    ldh [rVBK], a
    ld hl, $9800
    ld a, 7
    ld c, 16
.loopY
    ld b, 32
.loopX
    ld [hli], a
    dec b
    jr nz, .loopX
    ld a, c
    rra
    dec a
    dec c
    jr nz, .loopY
    ret

PixelStructure::
    db %11111111
    db %11111111
    db %11111111
    db %11111111
    db %11111111
    db %11111111
    db %11111111
    db %11111111
    db %00000000
    db %11111111
    db %00000000
    db %11111111
    db %00000000
    db %11111111
    db %00000000
    db %11111111

    db %11111111
    db %00000000
    db %11111111
    db %00000000
    db %11111111
    db %00000000
    db %11111111
    db %00000000
    db %00000000
    db %00000000
    db %00000000
    db %00000000
    db %00000000
    db %00000000
    db %00000000
    db %00000000

PixelStructureEnd::

InitFrame:
    ; Debug routine: Saves frame offsets to a 128 element array at $D000
    ;ldh a, [$82]
    ;ld e, a
    ;inc a
    ;ldh [$82], a
    ;sla e
    ;ld d, $D0

    ;ld a, h
    ;ld [de], a
    ;inc de
    ;ld a, l
    ;ld [de], a

    ldh a, [frame_repeat]
    and a ;Should we repeat the previous frame?
    jr z, .NewFrame

    ; Decrease repeat count
    dec a
    ldh [frame_repeat], a

    ; Restore HL and bank
    ldh  a,[current_frame_start]
    ld h, a
    ldh a, [current_frame_start + 1]
    ld l, a
    ldh a, [current_frame_start_bank]
    ldh [current_bank], a
    ld [MBC5_bank_low], a
    ldh a, [current_frame_start_bank + 1]
    ldh [current_bank + 1], a
    ld [MBC5_bank_high], a
    jr .LoadPalettes

.NewFrame
    ; A full frame starts with a repeat count byte. The right-most bit in this
    ; byte is always 1, so the count itself is a 7-bit number. Since frame data
    ; bytes (actual pixels) are always odd, we use the right-most bit to detect
    ; frame starts in row-back-reference encoding.
    ld a, [hli]
    srl a
    ldh [frame_repeat], a
    and a
    jr z, .LoadPalettes
    ; We have a non-zero repeat, we should save our position for later use.
    ld a, h
    ldh [current_frame_start], a
    ld a, l
    ldh [current_frame_start + 1], a
    ldh a, [current_bank]
    ldh [current_frame_start_bank], a
    ldh a, [current_bank + 1]
    ldh [current_frame_start_bank + 1], a

    ; The repeat byte is followed by an array of 32 colors for this frame.
.LoadPalettes
    ld a, $80
    ldh [rBGPI], a
    ld b, 64
.loop
    ld a, [hli]
    ldh [rBGPD], a
    dec b
    jr nz, .loop
    ; Reuse SwitchBankIfNeeded from the HBlank interrupt. In Z80, it is safe to
    ; use RETI in a non-interrupt handler.
    jp SwitchBankIfNeeded

VBlank:
    call HandleMusic
    ; Alternate the X scrolling between 4 and 0. This will offset our 8-pixel
    ; blocks by 4 pixels every other frame. Together with the high latency of
    ; the Game Boy screen, smart encoding of the subframes will effectively
    ; increase the resolution to 40 * 144, and increase the effective number of
    ; colors per frame to 528, thanks to color blending.
    ldh a, [rSCX]
    xor 4
    ldh [rSCX], a
    ; If SCX is zero, this is a new frame (not a sub frame), run the init procedure.
    call z, InitFrame
.noNewFrame
    reti

InitVideo:
    ; Select bank
    ld a, 1
    ld [MBC5_bank_low], a
    ldh [current_bank], a
    xor a
    ld [MBC5_bank_high], a
    ldh [current_bank + 1], a

    ; Init variables
    ldh [$82], a ; Used by debug procedure
    ldh [frame_repeat], a
    ldh [is_row_back_reference], a
    ldh [current_music_pause], a
    ldh [done_flag], a

    ; Init the music pointer
    ld a, Music >> 8
    ldh [music_pointer + 1], a
    ld a, Music & $FF
    ldh [music_pointer], a

    ; Clear pending interrupts
    ldh [rIF], a

    ; Enable interrupts
    ld a, 3
    ldh [rIE], a
    ld a, 32
    ldh [rSTAT], a

    ; Set SCX to 4 (This will be overwritten by the call to VBlank)
    ld a, $4
    ldh [rSCX], a
    ld hl, video_data_start
    ; Init
    call VBlank
    ; We miss the first HBlank
    ld hl, video_data_start + 1 + $40 + $14 ; repeat byte + palette + first row
    ; Enable LCD
    call LCDOn

; The main loop. HL will point to either a frame start, or a row start
Main:
    xor a
    ldh [is_row_back_reference], a
    halt
_Main:
    ; A frame start will always start with an odd byte. A row start will start
    ; with an even byte if and only if it is a back-referencing-row.
    ld a, [hl]
    bit 0, a
    jr nz, Main
    ; This code will never run, as back-referencing-rows are disabled in the encoder.
    rra
    ld [MBC5_bank_high], a
    inc hl
    ld a, [hli]
    ld [MBC5_bank_low], a
    ld a, [hli]
    ld d, a
    ldh [is_row_back_reference], a ; Always non-zero
    ld a, [hli]
    ld b, h
    ld c, l
    ld l, a
    ld h, d
    halt
    ldh a, [current_bank]
    ld [MBC5_bank_low], a
    ldh a, [current_bank + 1]
    ld [MBC5_bank_high], a
    jr _Main

HandleMusic:
    ; The music system is a simple array of 2-byte items. The first byte is a
    ; pointer to HRAM (which includes our sound registers) and second byte is a
    ; value that should be written into this pointer.
    ; We also define two variables in the HRAM: current_music_pause, which will
    ; stop this loop when it's non-zero, and cause an n-frame pause in the music
    ; until the next byte is written. The second variable, done_flag, will color
    ; the entire screen black, and halt music and video playback.
    ; This function will never return without writing to one of these variables!
    push hl
    ldh a, [music_pointer + 1]
    ld h, a
    ldh a, [music_pointer]
    ld l, a

.loop
    ldh a, [done_flag]
    and a
    jr nz, StopPlaying
    ldh a, [current_music_pause]
    and a
    jr nz, .exit

    ld a, [hli]
    ld c, a
    ld a, [hli]
    ld [c], a
    jr .loop

.exit
    dec a
    ldh [current_music_pause], a
    ld a, h
    ldh [music_pointer + 1], a
    ld a, l
    ldh [music_pointer], a
    pop hl
    ret

StopPlaying:
    ; Make everything black
    ld a, $80
    ldh [rBGPI], a
    ld b, 64
    xor a, a
.loop
    ldh [rBGPD], a
    dec b
    jr nz, .loop
    ldh [rIE], a
    di
    halt

Music::
db current_music_pause, 45 ; Delay the music for 45 frames, for syncing with video
INCBIN "music.gbm"
db current_music_pause, 60 ; Let the video finish after the music is done
db done_flag, $01 ; Turn off everything

; The video data should be appended to this ROM after linking.