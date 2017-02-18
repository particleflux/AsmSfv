.486
.model flat, stdcall
option casemap :none   ; case sensitive

include windows.inc
include kernel32.inc
include user32.inc
include gdi32.inc
include masm32.inc

includelib kernel32.lib
includelib user32.lib
includelib gdi32.lib
includelib masm32.lib


BOUNCE_TIMER	equ 1234

;bitmask for curdir
DIR_UP 		equ 1
DIR_LEFT	equ 2


.data
	szCredits		db "AsmSfv v1.1",10
				db "by Stefan Linke",10,10
				db "With the raw power of assembly :)",10,10
%				db "built &@Date &@Time",0
					
	
.data?
	clientRect		RECT <>
	bouncingRect	RECT <>
	dwCurDir		dd ?
	myBrush		HBRUSH 	?

.code

AboutDlgProc PROC hWin :DWORD, uMsg :DWORD, wParam :DWORD, lParam :DWORD
	local ps :PAINTSTRUCT

	
	.if uMsg== WM_PAINT
		invoke BeginPaint, hWin, addr ps
		mov ebx, eax
		
		invoke GetClientRect, hWin, addr clientRect
		;invoke GetClientRect, hWin, addr bouncingRect
		
		invoke DrawText, ebx, offset szCredits, -1, addr bouncingRect, DT_CENTER or DT_NOPREFIX or DT_CALCRECT
		mov ecx, bouncingRect.top
		add ecx, eax
		mov bouncingRect.bottom, ecx 
		
		invoke SetBkMode, ebx, TRANSPARENT
		invoke SetTextColor, ebx, 00000ff00h
		invoke DrawText, ebx, offset szCredits, -1, addr bouncingRect, DT_CENTER or DT_NOPREFIX
		
		invoke EndPaint, hWin, addr ps
		
	.elseif uMsg== WM_CTLCOLORDLG
		mov eax, myBrush
		ret
	.elseif uMsg== WM_TIMER
		mov ebx, dwCurDir
		.if ebx & DIR_UP
			.if bouncingRect.top > 0
				dec bouncingRect.top
			.else
				xor ebx, DIR_UP
				invoke MessageBeep,0FFFFFFFFh
			.endif
		.else
			mov eax, clientRect.bottom
			.if bouncingRect.bottom < eax
				inc bouncingRect.top
			.else
				or ebx, DIR_UP
				invoke MessageBeep,0FFFFFFFFh
			.endif
		.endif
		
		.if ebx & DIR_LEFT
			.if bouncingRect.left > 0
				dec bouncingRect.left
			.else
				xor ebx, DIR_LEFT
				invoke MessageBeep,0FFFFFFFFh
			.endif
		.elseif
			mov eax, clientRect.right
			.if bouncingRect.right < eax
				inc bouncingRect.left
			.else
				or ebx, DIR_LEFT
				invoke MessageBeep,0FFFFFFFFh
			.endif
		.endif

		mov dwCurDir, ebx
		
		invoke InvalidateRect, hWin, 0,TRUE
	
	
	.elseif uMsg == WM_INITDIALOG
		; load icon
		invoke GetModuleHandle, NULL
		invoke LoadIcon, eax, 2
      		invoke SendMessage, hWin, WM_SETICON, ICON_BIG, eax
		
		invoke RtlZeroMemory, addr bouncingRect, sizeof RECT
		
		invoke GetTickCount
		invoke nseed, eax
		
		invoke nrandom, 75
		mov bouncingRect.left, eax
		invoke nrandom, 75
		mov bouncingRect.top, eax
			
		invoke GetStockObject, BLACK_BRUSH
		mov myBrush, eax
			
		;invoke SendDlgItemMessage, hWin, 1023, WM_SETTEXT, 0, offset szTextTemplate
		invoke SetTimer, hWin, BOUNCE_TIMER, 25, 0
		
		
	.elseif uMsg == WM_CLOSE
		invoke KillTimer, hWin, BOUNCE_TIMER
		invoke DeleteObject, myBrush
		invoke EndDialog,hWin,0
	.endif

	xor	eax,eax
	ret
AboutDlgProc endp




End
