.486
;.xmm
.model flat, stdcall
option casemap :none   ; case sensitive

include windows.inc
include kernel32.inc

includelib kernel32.lib

include crc32.inc


.code

Crc32_FromFile PROC uses ebx edi esi pszFile :DWORD
	local pBuffer :DWORD
	local hFile :HANDLE
	local dwBytesRead :DWORD

	invoke GetProcessHeap
	push eax
	invoke HeapAlloc, eax, 0, FILEBUFFER_SIZE
	.if eax == 0
		ret
	.endif
	
	mov pBuffer, eax
	invoke CreateFile, pszFile, GENERIC_READ, FILE_SHARE_READ, NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN, NULL 
	cmp eax, INVALID_HANDLE_VALUE
	je @@fail
	
	mov hFile, eax	
	or ebx, 0FFFFFFFFh		;ebx is our crc32
	mov esi, offset CRC32Table
	
	@@crc32NextChunk:
	invoke ReadFile, hFile, pBuffer, FILEBUFFER_SIZE, addr dwBytesRead, NULL
	or eax, eax
	jz @@crc32Done
	mov edi, pBuffer
	mov ecx, dwBytesRead
	;prefetcht0 [esi+1024]
	jecxz @@crc32Done
	
	@@crc32NextByte:
	movzx edx, bl
	xor dl, BYTE PTR [edi]
	shr ebx, 8
	inc edi
	;add edi, 1
	xor ebx, DWORD PTR [esi + edx*4]
	dec ecx
	;sub ecx, 1	
	jnz @@crc32NextByte	
	jmp @@crc32NextChunk	
		
	
	@@crc32Done:
	; cleanup
	invoke CloseHandle, hFile
	pop eax
	invoke HeapFree, eax, 0, pBuffer
	mov eax, ebx
	xor eax, 0FFFFFFFFh
	ret

	@@fail:
	pop eax
	invoke HeapFree, eax, 0, pBuffer
	ret
Crc32_FromFile endp


End
