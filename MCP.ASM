;DATE OF FILE WRITE BEGIN: 09/01/20
;NAME OF PROJECT: MCP - Minimal Control Program
;NAME OF AUTHOR: Yll Buzoku 
;Loads an application file of a disk and transfers control to it!
;More or less a bootsector program loader
;Remains in real mode, end user application must jump beyond.
;DOES NOT SET A20!
;Is compatible with the IBM PC 
;Is so bloody basic, its not even an OS. Its barely a layer above Int 13h. 
;PLEASE BE CAREFUL WHEN INPUTTING VALUES, THERE IS NO BOUNDS CHECKING!

CODE 	SEGMENT
	ASSUME	CS:CODE, DS:CODE, ES:CODE, SS:CODE
	ORG	07C00h
MAIN	PROC	NEAR
prog_init:
	jmp short start
   	nop
;-----------------------------------------------Tables----------------------------------------------
    osname: db 'SCPDOSV1'

    ;Start of BIOS Parameter Block

    bypsec: dw 0200h     ;bytes per sector (200h=512)                  M
    secpcl: db 01h       ;sectors per cluster                          A
    ressec: dw 0001h     ;reserved sectors                             G
    numFAT: db 02h       ;number of FATs                               I
    nortdr: dw 00E0h     ;number of root directory entries             C
    nosect: dw 0B40h     ;number of sectors (1440 sectors per side)    N
    medesc: db 0F0h      ;media descriptor (f0=FDD)                    U
    FATsec: dw 0009h     ;number of sectors per FAT                    M
    sectrc: dw 0009h     ;number of sectors/tracks                     B
    numhed: dw 0002h     ;number of read/write heads                   E
    numhid: dd 00000000h ;number of hidden sectors                     R
    nsecfs: dd 00000000h ;number of "huge" sectors in the FS (FAT)     S

    ;End of BPB

    ldrvnu: db 00h       ;logical drive number, 80h=first HDD, 00h=1st FDD
    res1:   db 00h       ;reserved sector 1, BS reserved, used in boot
    extsig: db 29h       ;Extended boot signature (29h = EBPB signature)

    ;Start of Extended BPB
    sernum: dd 1C2A0D0Fh       ;serial number of drive
    vollbl: db 'NO NAME    '  ;default volume label name
    fstype: db 'FAT12   '     ;file system type
	
;---------------------------------------------------------------------------------------------------

start: 
	cli				;Pause external interrupts
	xor ax, ax		;Nullify ax
	mov ss, ax		;Set the stack segment to null
	mov sp, 07C00h 	;set up stack here
	mov ds, ax		;Ensure all segment regs point to same segment
	mov es, ax		;Ditto...
	sti				;Reenable external interrupts

	push dx			;push dx to be used for at the end
	mov al, 03h		;Selecting a video mode that works on MDA/VGA
	int 10h 		;Set video mode!
	mov si,	offset welcm	;Select welcome message
	call write		;Write message
	mov si,	offset segm	;Select segment input message
	call write		;Write message
	call keyb		;Call keyboard proc
	mov word ptr [jmpseg], dx	;mov dx into memory
	mov si, offset offm	;Select offset input message
	call write		;Write message
	call keyb		;Call keyboard proc
	mov word ptr [jmpoff], dx	;mov dx into memory
	mov si, offset dskm	;Select Starting Sector message
	call write		;Write message
	call keyb		;Call keyboard proc
	mov word ptr [strtsec], dx	;mov dx into memory
	mov si, offset sizem	;Select Number of sector message
	call write		;Write message
	call keyb		;Call keyboard proc
	mov word ptr [numsec], dx	;mov dx into memory
	mov si, offset lodm	;move load message offset to be written
	call write		;Write Loading message

;-----------------Calculate the CHS rep of the Logical sector provided----------
	pop bx			;bring the saved drive number back into bx
	mov bp, word ptr [strtsec]	;mov into bp, starting sector, saves for later
;Sectors	
	mov ax, bp		;mov into ax for modding
	div byte ptr [sectrc]	;divide ax by sectrc, the low byte portion
	inc ah			;inc remainder to get Sectors
	mov cl, ah		;move the sector into cl as needed, Int13h
;Cylinder
	mov ax, word ptr [numhed] ;move the number of heads into ax
	mul word ptr [sectrc]	;multiply ax by sec/trck
				;ax contains the product of the multiplication
				;by product, dx is now zero, hopefully
	xchg bp, ax		;switch ax and bp
	div bp			;can divide by bp now
	mov ch, al		;move the result into ch, Int13h
;Head
	mov ax, bp		;move bp into ax to be divided
	div byte ptr [sectrc]	;divide ax by sectrc, the low byte portion
	xor ah, ah		;nullify the remainder
	div byte ptr [numhed]	;work out now modulo heads per cylinder
	mov dh, ah		;move the remainder into dh as needed, Int13h
	
;-------Reference equations-------
;C = LBA ö (HPC x SPT) -> ch
;H = (LBA ö SPT) mod HPC -> dh
;S = (LBA mod SPT) + 1 -> cl
;---------------------------------

;----------Int 13h usage----------
;cl = Start Sector
;ch = Start Cylinder
;dh = Start Head
;al = # of sectors
;ah = 02, read sectors to ES:BX
;---------------------------------
	mov si, 10h			;loop counter for attempts
	mov dl, bl			;move the saved drive number into dl
	mov es, word ptr [jmpseg]	;move the segment into the seg reg
	mov bx, word ptr [jmpoff]	;move the offset into BX
	mov ax, word ptr [numsec]	;move the number of sectors into al
read_dsk:
	mov ah, 02h			;Int 13h subfunction
	int 13h				;READ DISK!
	jnc prog_end			;success! Jump to end!
	xor ah, ah			;Disk reset 
	int 13h				;Reset disk!
	dec si				;decrease loop counter
	jnz read_dsk			;Try again until counter 0

	mov si, offset failm		;fail message prep
	call write			;write it
	xor ax, ax			;int 16h subfunction
	int 16h				;wait for keypress
	int 19h				;reset the machine
prog_end:
	mov bp, bx			;save bx in bp, write destroys bx
	mov si, offset jmpm		;prepare jump message
	call write			;write!
	xor ax, ax			;int 16h subfunction
	int 16h				;wait for keypress

;	jmp far ptr es:bx		;JUMP AWAY! :D 		
	push es				;push new cs onto stack
	push bp				;push new ip onto stack
	db	0CBh			;CB=opcode for far return
;MASM sucks for far jumps, so manually encoding the instruction seems
;the best way to deal with this for now! Yay?

;------------------------------Data Area/Proc Area---------------------------	
	
welcm	db	"Welcome to M/CP", 0Ah, 0Dh, 0	;Welcome message
segm	db	"? SEG> ", 0				;Give load segment
offm	db	0Ah, 0Dh, "? OFF> ",0		;Give load offset
dskm	db	0Ah, 0Dh, "? LSctrStrt> ",0	;Which logical sector to start at?
sizem	db	0Ah, 0Dh, "? # Sctrs> ",0	;Number of sectors to copy
lodm	db	0Ah, 0Dh, "Loading...",0	;Copying
jmpm	db	" Done. Strike a key to jmp...", 0
failm	db	" Failed. Strike a key to reset...",0

jmpseg	dw	0000
jmpoff	dw	0000
strtsec	dw	0000
numsec	dw	0000
buff	db	4 dup(?)	;4 key keyboard buffer 
MAIN	ENDP

;-------------------------------Procs------------------------------
KEYB	PROC	NEAR
;Warning, destroys ax, bx, cx, dx, si, di,
;Warning, this function doesnt do bounds checking.
;ALL INPUT MUST BE DONE IN lower case
;Return:
;DX - Contains the prepared word for storage
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
k1:
	cli			;Ensure all memory writes go the right way
	mov di, offset buff	;Point di to the buffer
	mov cx, 4		;Will do this 4 times
	mov bx, 0007		;Int 10h properties bh=page, bl=colour 
k2:
	xor ax, ax		;Int 16 subfunction 0
	int 16h			;Wait for keypress and store ASCII=al, SC=ah
	mov ah, 0Eh		;Int 10h TTY print subfunction
	int 10h			;Echo char (in al) to screen
	sub al, 30h		;Bring the digit down, 30h=ASCII 0
	cmp al, 0Ah		;If its less than 0Ah, then we have a num digit
	jl k3			;Avoid alpha conversion
	sub al, 27h		;Bring alpha down to its correct value 
k3:
	stosb			;Move al into the buffer and inc buffer ptr
	dec cx			;Decrease cx
	jnz k2			;Keep gwarning till cx is zero
k4:
	xor dx, dx		;Nullify dx in preparation for the word
	dec di			;let di point to the tail of buff and not past
	push di			;Push di to put it into si
	pop si			;Take the tail of buff into si
	std			;Change direction of string read (right to left)
k5:
	xor ax, ax		;Nullify ax to prepare it for usage each time
	lodsb			;mov byte into al and dec si
	shl ax, cl		;cl starts as being zero
	add dx, ax		;add the digit to dx
	add cl, 4		;Add 4 to cl, to shift by 4 bits per pass
	cmp cl, 10h		;have we gone 4 times?
	jne k5			;If not, go again!
k6:
	cld			;Return direction to correct
	ret			;Return to sender!
KEYB	ENDP

WRITE	PROC	NEAR
;Warning, destroys registers ax and bx
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
write_start:
	lodsb			;move into al the value pointed at by ds:si and inc si
	test al, al		;should we exit (if al = 0)
	jz ret_write	;al=0, exit!
	mov ah, 00eh	;TTY output
	mov bx, 00007h 	;colour
	int 10h			;print char
	jmp write_start ;go again!

ret_write:
	ret				;return to next instruction
WRITE	ENDP

	ORG 	07DFEh	;07C00h + 01FEh bytes 
    	db 	055h	;Bootsector signature
    	db 	0AAh
CODE	ENDS
	END	prog_init
