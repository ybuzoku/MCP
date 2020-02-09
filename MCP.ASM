;Version 2, Date of file write start: 11/01/2020
;NAME OF PROJECT: MCP - Minimal Control Program
;NAME OF AUTHOR: Yll Buzoku 
;Loads an application file of a disk and transfers control to it!
;More or less a bootsector program loader
;Remains in real mode, end user application must jump beyond.
;DOES NOT SET A20!
;Is compatible with the IBM PC  
;PLEASE BE CAREFUL WHEN INPUTTING VALUES, THERE IS NO BOUNDS CHECKING!

CODE 	SEGMENT
	ASSUME	CS:CODE, DS:CODE, ES:CODE, SS:CODE
	ORG	07C00h
;	ORG	100h	;DEBUG MODE
MAIN	PROC	NEAR
prog_init:
	jmp short start
   	nop
;-----------------------------------------------Tables----------------------------------------------
    osname: db 'MCP 2.0 '	
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
	cld			;Clear Direction flag	
;Debug mode
;	jmp short z1	; TEMP TEMP TEMP TEMP TEMP TEMP TEMP TEMP TEMP
;Debug mode
	cli			;Pause external interrupts
	xor ax, ax		;Nullify ax
	mov ss, ax		;Set the stack segment to null
	mov sp, 07C00h 		;set up stack here
	mov ds, ax		;Ensure all segment regs point to same segment
	mov es, ax		;Ditto...
	sti			;Reenable external interrupts
	
;Sets up Int 20h and clears the variable area, useful for reentries

	mov bx, 4*20h	;Move IVT entry into bx, Int 20h and 1Bh to recall OS
	mov word ptr es:[bx], offset start	;Int 20h offset
	mov word ptr es:[bx + 2], ax		;Segment

z1:	
	mov cx, 15	;Zero vars, buffer area and prog var
;	mov di, offset var1
	mov di, 0500h	;var1
	rep stosb	;Clear the area, di points to tail of prog (prog + 1)

z2:
	mov cx, 03h
	mov si, offset prompt
z21:
	lodsb			;Bring char into al, inc si
	call print		;Print
	loop z21
;Get program name (char)
	xor ax, ax		;Function to listen for that keystroke
	int 16h			;Get the keystroke!

	mov di, offset lst	;Move the start of the string into di
	mov cl, lstl		;lstl = length of list
	repne scasb
	je z3			;Char input is in list,proceed, else reset
fail:
	mov al, 07h		;beep
	call print		;print the beep, obviously
	int 20h			;Fail, restart
z3:	
	call print		;print program name/char

;	mov [050Eh], al ;Save al into memory for usage later, progvar
;For some reason, MASM 2.0 doesnt like it. MANUAL ENCODING TIME:
	db 0A2h
	dw 050Eh

	xor bp, bp		;use bp as a argument counter
z4:
	xor ax, ax
	int 16h			;Await a space key
	cmp al, 20h		;compare against a space key
	jne z4			;not equal, keep waiting
	call print 		;print the space key

k0:
;	mov di, offset buff	;point to head of buffer
	mov di, 050Ah		;buff

KEYB	PROC	NEAR
k1:
	xor ax, ax
	int 16h
	call print		;print char which has been keyed in
	
	push di			;save di, ie the increment into buffer
	mov di, offset ascii
	mov bx, di		;move bx to point at the base of the table
	mov cx, asciil + 1	;table length + 1 for scasb reasons, grr
	repne scasb		;Loop and compare to find a char from table
	jnz fail		;Char overflow, doesnt match to anything in list

;	lea ax, [di - bx]	;Calculate the offset into the table
	dec di			;Dec becuase scas overincrements di
	sub di, bx		;subtract from di the base of the table
	mov ax, di		;ax now contains the offset into the table
	pop di			;Bring back the position into the buffer
	cmp cx, 3		;Check if cx is on the ctrl key section
	jle ctrlkey
	stosb			;Store the digit into the buffer
	jmp k1			;Repeat
ctrlkey:
	dec cx			;cx = 1, enter key pressed
	jz eparse
	dec cx
	jz parse
;cx = 0, backspace
	call print		;print the backspace char
	dec di			;return to previous char position in buffer
	jmp k1
KEYB	ENDP
PWAY	PROC	NEAR
;This will take whats in the buffer and parse it, then zero the buffer
;in prep for the next var entry. Zeroing allows for less than a full
;address or number to be entered!
eparse:
;		Push the desired value onto the stack,
;		but use the real value of bp in proc :D
	mov ax, 4
	push ax	
	jmp short p1
parse:	
	push bp		;save to stack number of args entered
p1:
;	mov di, offset var1
	mov di, 0500h	;offset var1

	shl bp, 1	;multiply by 2
	add di, bp	;Point di to appropriate var in varspace

k4:
	xor dx, dx	;Nullify dx in preparation to recieve the word
	xor cl, cl	;Set cl to 0
;	mov si, offset bufft
	mov si, 050Dh	;offset bufft
	std		;Change the direction of string reads
k5:
	xor ax, ax	;Nullify ax to prepare it for usage each time
	lodsb		;mov byte into al and dec si
	shl ax, cl	;cl starts as being zero, then left shifting
	add dx, ax	;add the digit to dx
	add cl, 4	;Add 4 to cl to shift by 1 hex place value per pass
	cmp cl, 10h	;Have we gone 4 times?
	jne k5		;If not, go again!

	cld		;Restore direction of string ops
	mov word ptr [di], dx	;Store the value in the appropriate var

;Nullify the buffer in anticipation of the next entry
	mov cx, 2
;	mov di, offset buff
	mov di, 050Ah	;buff
	xor ax, ax		;buffer entry, null word
	rep stosw

	pop bp		;pop count of arguments entered
	inc bp		;increase count of entered arguments
	cmp bp, 05h	;Check number of arguments entered against max
	je prog_sel	;Jump to prog exec if key was enter
	jmp k0		;Get next argument
PWAY	ENDP

prog_sel:
;	int 03h		;breakpoint 
;	mov al, byte ptr [050Eh]	;prog
;MASM 2.0 at it again!
	db 0A0h
	dw 050Eh
	mov di, offset lst
	scasb
	je d1
	scasb
	je tedit
	scasb
	je j1	;jump prog
	scasb
	je sr	;read from disk
	scasb
	je sw	;write
	int 20h		;TO BE REMOVED
;------------------------------Data Area/Proc Area---------------------------	
	
			;ASCII converted Arguments/Recommended usage
lst	db	'dejlw'
lstl	equ	$ - lst
ascii	db	"0123456789abcdef", 08h, 20h, 0Dh ;b/space, enter
asciil	equ	$ - ascii
prompt	db	0Ah, 0Dh, 3Eh	;3Eh = >
;var1	equ	0500h		;Segment
;var2	equ	0502h		;Offset
;var3	equ	0504h		;Drive number
;var4	equ	0506h		;LBA number
;var5	equ	0508h		;Number of sectors
;buff	equ	050Ah		;4 key keyboard buffer
;bufft	equ	050Dh		;Split to avoid using lea above 
;prog	equ	050Eh		;Selected program
;----------------------------------------------------------------------------
MAIN	ENDP

;-------------------------------Procs------------------------------
TEDIT	PROC	NEAR
;	mov ds, word ptr [0500h]	;var1
;Manual encoding required
	db 8Eh
	db 1Eh
	dw 0500h

;	mov di, word ptr [0502h]	;var2
	db 8Bh
	db 3Eh
	dw 0502h
;	mov al, byte ptr [0505h]	;var3 - 1
	db 0A0h
	dw 0505h
	stosb	;store low byte
	int 20h	;return to OS
TEDIT	ENDP
FRJMP	PROC	NEAR
j1:
;	mov es, word ptr [0500h];bring the transfer segment into es, var1
	db 8Eh
	db 06h
	dw 0500h
;	mov bx, word ptr [0502h];bring the transfer offset into bx, var2
	db 8Bh
	db 1Eh
	dw 0502h
	push es		;push new cs onto stack
	push bx		;push new ip onto stack
	db	0CBh	;CB=opcode for far return
;MASM sucks for far jumps, so manually encoding the instruction seems 
;nice, simple and quick way to deal with this for now! Yay?
FRJMP	ENDP
DUMP 	PROC 	NEAR
;Takes in var1:var2 as Segment:Offset of byte to dump. 
;Destroys DS, SI, AH, BX
d1:
;	mov si, word ptr [0500h]	;var1
;	mov ds, si
	db 8Eh
	db 1Eh
	dw 0500h
;	mov si, word ptr [0502h]	;var2
	db 8Bh
	db 36h
	dw 0502h
	lodsb		;load value at DS:SI into AL
	
	mov dl, al	;copy al into dl
	and ax, 00F0h	;get the high nybble of the digit
	and dx, 000Fh	;get the low nybble of the digit
	mov cl, 4	;shift counter
	shr ax, cl	;shift one hex place value right

;	mov bp, ax	;mov digit into bp for the proc
	call char
;	mov bp, dx
	mov ax, dx
	call char
	int 20h

CHAR	PROC	NEAR
;	lea di, [offset ascii + bp]	;point to table with bp offset
;	lodsb		;load into al the desired char
	mov bx, offset ascii
	xlatb
	call print	;print digit pointed to by di
	ret
CHAR	ENDP
DUMP	ENDP

DISKIO	PROC	NEAR
;Converts addresses from LBA to CHS addressing and r/w to/from disk/mem
;Warning, ax, bx, cx, dx destroyed
;Return:
;CL - Sector number, CH - Cylinder number, DH - Head number
;----------Reference Equations----------
;C = LBA / (HPC x SPT)
;H = (LBA / SPT) mod HPC
;S = (LBA mod SPT) + 1
;---------------------------------------
sw:		
	mov bx, 0300h		;write subfunction for disk writing
	push bx			;save for later, into ah
	jmp short s1		;jump to program ep
sr:
	mov bx, 0200h		;read subfunction for disk reading
	push bx			;save for later, into ah
s1:				;Program Entry Point
;Sector and Head value
;	mov bp, word ptr [0506h];Save the word var into bp, var4
	db 8Bh
	db 2Eh
	dw 0506h
	mov ax, bp		;mov LBA into ax to get head and sec num
	div byte ptr [sectrc]	;divide ax by the low byte of sectrc
	inc ah			;increment the remainder to get sectors
	mov cl, ah		;save the remainder in its ret register
	xor ah, ah		;nullify the remainder for the next part
	div byte ptr [numhed]	;divide ax by the low byte of numhed
	mov dh, ah		;ah is now head. Move into dh
;Cylinder
	mov ax, word ptr [numhed]	;mov numhead into ax
	mul word ptr [sectrc]	;multiply ax by sec/trc
				;ax contains the product of the multiplication
				;by product. dx SHOULD be 0, hopefully
	xchg bp, ax		;switch bp and ax so that we can divide them
	div bp			;Divide them here!
	mov ch, al		;Save the result in ch

	mov si, 10h		;use si as a fail loop counter
;	mov es, word ptr [0500h] ;move segment into seg reg for int13h, var1
	db 8Eh
	db 06h
	dw 0500h
;	mov bx, word ptr [0502h] ;move offset into reg for int13h, var2
	db 8Bh
	db 1Eh
	dw 0502h
;ADDRESSES INCREMENTED BY 1 TO ALLOW TYPING OF 2 RATHER THAN 4 DIGITS!
;	mov dl, byte ptr [0505h] ;move drive number into reg for int13h, var3
	db 8Ah
	db 16h
	dw 0505h
	pop ax			;bring subfunction into ah
;	mov al, byte ptr [0509h] ;move number of sectors into al, var5
	db 0A0h
	dw 0509h
	mov bp, ax		;save to bp to use in loop
s2:
	mov ax, bp		;bring back after disk reset
	int 13h			;fire away disk IO!
	jnc s3			;disk activity was a success! Exit.

	xor ah, ah		;Disk Reset function
	int 13h			;Reset the disk
	dec si			;decrement the counter
	jnz s2			;loop till si is zero or the function works

	mov al, "X"		;Error indicator symbol, program failed
	call print		;Print char
	xor ax, ax		;Int 16 subfunction
	int 16h			;Await that keypress!
s3:		
	int 20h			;Use OS API function :D 
DISKIO	ENDP
PRINT	PROC	NEAR
;Assume char to be printed is in AL
	mov ah, 0Eh		;Int 10h Function
	mov bx, 0007h		;bh=page number, bl=colour/attribs
	int 10h			;call function
	ret			;return to caller
PRINT	ENDP

	ORG 	07DFEh	;07C00h + 01FEh bytes 
    	db 	055h	;Bootsector signature
    	db 	0AAh
CODE	ENDS
	END	prog_init
