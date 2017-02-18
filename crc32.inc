

Crc32_FromFile	PROTO	:DWORD


; the one for sse 4.2 crc32 instruction is 0x1EDC6F41, so we cant use it with other polynomial :(
CRC32_POLY		equ 0EDB88320h

;FILEBUFFER_SIZE	equ 1024
;FILEBUFFER_SIZE	equ 4096
;FILEBUFFER_SIZE	equ 8192
FILEBUFFER_SIZE	equ 65536	; 64 kB


.data
	; build crc32 table with macros (adds 1kB to executable)
	; taken from drizz's crypto hash library
	align 16
	CRC32Table label dword
		i = 0
		crc = i
		WHILE i LT 256
			crc = i
			REPT 8
	    			crc = (crc shr 1) xor (CRC32_POLY * (crc and 1))
			ENDM
			DD crc
			i = i + 1
		ENDM
	
	