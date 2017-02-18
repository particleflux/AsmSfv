.486
.model	flat, stdcall
option	casemap :none   ; case sensitive

include base.inc
include crc32.inc
include fileassociation.inc
include systeminfo.inc
include about.inc


.code
start:
	invoke GetModuleHandle, NULL
	mov	hInstance, eax
	
	invoke RtlZeroMemory, offset szSfvFile, sizeof szSfvFile
	invoke GetProcessHeap
	mov hHeap, eax
	
	invoke InitCommonControls
	
	invoke ReadSettings
	
	invoke DialogBoxParam, hInstance, 101, 0, ADDR DlgProc, 0
	invoke ExitProcess, eax
; -----------------------------------------------------------------------

DlgProc proc uses ebx edi esi hWin :DWORD, uMsg :DWORD, wParam :DWORD, lParam :DWORD
	local hKey :DWORD
	local szBuff[MAX_FNAME] :BYTE
	local szCmdBuff[MAX_FNAME] :BYTE

	.if uMsg == WM_NOTIFY
		mov edx, lParam
		
		.if [edx].NMHDR.idFrom == IDC_FILELIST
			mov ecx, [edx].NMHDR.code
			
			.if ecx == NM_CUSTOMDRAW
				invoke ListViewCustomDraw, lParam
				invoke SetWindowLong, hWin, DWL_MSGRESULT, eax
				mov eax, 1
				ret 
			.endif
		.endif

	.elseif uMsg == WM_THREAD_DONE
		; start next thread if any left
		invoke SendDlgItemMessage, hWndMain, IDC_PROGRESS, PBM_STEPIT, 0, 0
		
		
		mov eax, dwNextFile	
		
		.if eax < dwFilesTotal
			; start next thread, thread param is file index
			invoke CreateThread, NULL, 0, ThreadCalculate, eax, 0, 0
			invoke CloseHandle, eax
			inc dwNextFile
		.else
			; update time stats
			.if pcAvailable != 0
				invoke QueryPerformanceCounter, addr pcEndCount
				
				mov ecx, DWORD PTR [pcStartCount]
				sub DWORD PTR [pcEndCount], ecx
				mov ecx, DWORD PTR [pcStartCount + 4]
				sbb DWORD PTR [pcEndCount + 4], ecx
				; duration now stored in pcEndCount
				
				finit
				fild pcEndCount
				fild pcFrequency
				fdiv
				mov DWORD PTR [pcEndCount], 1000
				fild pcEndCount
				fmul
				fistp pcEndCount
				
				mov eax, DWORD PTR [pcEndCount]
				mov edx, DWORD PTR [pcEndCount+4]
				xor edi, edi
				.if eax > 60 *1000
					;minutes
					div dwMsInMinute	; div edx:eax , result in eax, edx=remainder
					mov edi, eax	;minutes in edi
				.else
					mov edx, eax
				.endif
				.if edx > 1000
					;seconds
					mov eax, edx
					xor edx,edx
					div dwMsInS		; eax == seconds, edx == ms
				.else
					xor eax, eax
				.endif
				invoke wsprintf, addr szBuff, offset szFormatStatsTime, edi, eax, edx
				invoke SendDlgItemMessage, hWin, IDC_STATS_TIME, WM_SETTEXT, 0, addr szBuff
				
			.endif
			
			invoke GetDlgItem, hWin, IDC_CHECK
			invoke EnableWindow, eax, TRUE
			
		.endif
		
	.elseif uMsg == WM_COMMAND
		mov eax, wParam
        		mov edx, wParam
        		shr edx, 16
		
		.if dx == BN_CLICKED
			.if  ax == IDC_BROWSE
				invoke SearchForFile
				invoke ParseSfv
				
			 .elseif ax  == IDC_CHECK
			 	.if dwIsSfv != 1
			 		xor eax,eax
			 		ret
			 	.endif
			 	
			 	; check strlen(szSfvFile) and abort if empty
			 	invoke lstrlen, offset szSfvFile
			 	.if eax != 0
			 		mov dwFilesGood, 0
					mov dwFilesBad, 0
					mov dwFilesLost, 0
			 
					 .if pcAvailable != 0
						invoke QueryPerformanceCounter, addr pcStartCount
					.endif
			 
					; TODO if running cancel, else start calculation threads
					invoke GetDlgItem, hWin, IDC_CHECK
					invoke EnableWindow, eax,FALSE
					
					mov ebx, dwNumThreads
					xor ebx, ebx
					
					.while ebx < dwNumThreads
						invoke CreateThread, NULL, 0, ThreadCalculate, ebx, 0, 0
						invoke CloseHandle, eax
						inc ebx
					.endw
					
					mov dwNextFile, ebx
					
				.else
					invoke MessageBox, hWin, offset szErrNoFile, offset szError, MB_OK or MB_ICONERROR
				.endif
			
			.elseif ax == IDC_OPTION_EXPLORER
				invoke SendDlgItemMessage, hWin, IDC_OPTION_EXPLORER, BM_GETCHECK, 0, 0
				.if eax == BST_CHECKED
					invoke GetModuleFileName, hInstance, addr szBuff, sizeof szBuff 
					invoke wsprintf, addr szCmdBuff, offset szFormatCommand, addr szBuff
					invoke lstrcat, addr szBuff, offset szIconAppend
					invoke FA_RegisterExtension, offset szSfvExt, offset szAppName, offset szSfvFileDesc, addr szBuff, addr szCmdBuff 
				.else
					invoke FA_UnregisterExtension, offset szSfvExt, NULL
				.endif
			
			.elseif ax == IDC_OPTION_AUTOCHECK
				invoke SendDlgItemMessage, hWin, IDC_OPTION_AUTOCHECK, BM_GETCHECK, 0, 0
				.if eax == BST_CHECKED
					mov dwDontAutoCheck, 1
				.else
					mov dwDontAutoCheck, 0
				.endif
				
				; save in registry				
				invoke RegCreateKeyEx, HKEY_CURRENT_USER, offset szSettingsKey, 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, addr hKey, NULL
				.if eax == ERROR_SUCCESS
					invoke RegSetValueEx, hKey, offset szSettingNoAutoCheck, 0, REG_DWORD, offset dwDontAutoCheck, 4
					invoke RegCloseKey, hKey
				.endif				
				
			.elseif ax == IDC_ABOUT
				invoke DialogBoxParam, hInstance, IDD_ABOUT, hWin, ADDR AboutDlgProc, 0
			.endif
			
		.elseif dx == EN_CHANGE
			.if ax == IDC_OPTION_THREADS
				invoke RtlZeroMemory, addr szBuff, sizeof szBuff
				invoke SendDlgItemMessage, hWin, IDC_OPTION_THREADS, WM_GETTEXT, sizeof szBuff, addr szBuff
				invoke atodw, addr szBuff
				mov dwNumThreads, eax
			.endif
		.endif
	
	.elseif uMsg == WM_INITDIALOG
		mov eax, hWin
		mov hWndMain, eax
		
		; load icon
		invoke LoadIcon, hInstance, IDI_ICON
      		invoke SendMessage, hWin, WM_SETICON, ICON_BIG, eax
		
		; init listview headers
		invoke GetDlgItem, hWin, IDC_FILELIST
		push eax
		invoke InitListViewColumns, eax
		
		; subclass listview
		pop eax
		invoke SetWindowLong, eax, GWL_WNDPROC,  ListViewSubclassProc
		mov prevWndProc, eax
		
		
		invoke SendDlgItemMessage, hWndMain, IDC_PROGRESS, PBM_SETSTEP, 1, 0
		
		invoke wsprintf, addr szBuff, offset szFormatNum, dwNumThreads
		invoke SendDlgItemMessage, hWin, IDC_OPTION_THREADS, WM_SETTEXT, 0, addr szBuff 
		
		; TODO load and display version info in titlebar

		.if dwExtRegged == 0
			mov eax, BST_UNCHECKED
		.else
			mov eax, BST_CHECKED
		.endif
		invoke SendDlgItemMessage, hWin, IDC_OPTION_EXPLORER, BM_SETCHECK, eax, 0
		
		.if dwDontAutoCheck == 0
			mov eax, BST_UNCHECKED
		.else
			mov eax, BST_CHECKED
		.endif
		invoke SendDlgItemMessage, hWin, IDC_OPTION_AUTOCHECK, BM_SETCHECK, eax, 0
		
		invoke QueryPerformanceFrequency, addr pcFrequency
		mov pcAvailable, al
		
		;load stuff from cmdline if any
		invoke GetCL, 1, addr szSfvFile 
		.if eax == 1
			invoke SendDlgItemMessage, hWin, IDC_FILE, WM_SETTEXT, NULL, addr szSfvFile
			invoke ParseSfv
			
			; create a timer here and do this on timer
			.if dwDontAutoCheck == 0
				invoke SetTimer, hWin, TIMER_AUTOCHECK, 500, 0
			.endif
		.endif
		
		
		
	.elseif uMsg == WM_TIMER
		.if wParam == TIMER_AUTOCHECK
			invoke KillTimer, hWin, TIMER_AUTOCHECK
			mov edx, BN_CLICKED
			shl edx, 16
			mov dx, IDC_CHECK
			invoke PostMessage, hWin, WM_COMMAND, edx, 0
		.endif
		
	.elseif uMsg == WM_CLOSE
		invoke EndDialog,hWin,0
	.endif

	xor	eax,eax
	ret
DlgProc	endp


ListViewSubclassProc PROC hWin :DWORD, uMsg :DWORD, wParam :DWORD, lParam :DWORD
	.if uMsg == WM_DROPFILES
		invoke DragQueryFile, wParam, 0, addr szSfvFile, MAX_FNAME
		invoke SendDlgItemMessage, hWndMain, IDC_FILE, WM_SETTEXT, NULL, addr szSfvFile
		invoke ParseSfv
	.endif
	
	invoke CallWindowProc, prevWndProc, hWin, uMsg, wParam, lParam
	ret
ListViewSubclassProc endp


ReadSettings PROC
	local hKey :HANDLE
	local dwSize :DWORD

	invoke FA_IsExtensionRegistered, offset szSfvExt, offset szAppName
	mov dwExtRegged, eax
	
	invoke GetNumCores
	mov dwNumThreads, eax
	
	mov dwDontAutoCheck, 0
	invoke RegCreateKeyEx, HKEY_CURRENT_USER, offset szSettingsKey, 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, addr hKey, NULL
	.if eax == ERROR_SUCCESS
		mov dwSize, 4
		invoke RegQueryValueEx, hKey, addr szSettingNoAutoCheck, 0, NULL, offset dwDontAutoCheck, addr dwSize
		
		mov dwSize, 4
		invoke RegQueryValueEx, hKey, addr szSettingNumThreads, 0, NULL, offset dwNumThreads, addr dwSize


		
		invoke RegCloseKey, hKey
	.endif 
	
		
	ret
ReadSettings endp


SearchForFile PROC
	local ofn :OPENFILENAME
	
	invoke RtlZeroMemory, addr ofn, sizeof OPENFILENAME
	mov ofn.lStructSize, sizeof OPENFILENAME
	mov eax, hInstance
	mov ofn.hInstance, eax
	mov ofn.lpstrFile, offset szSfvFile
	mov ofn.nMaxFile, MAX_FNAME
	mov ofn.lpstrTitle, offset szOfnTitle
	mov ofn.Flags, OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST or OFN_LONGNAMES or OFN_EXPLORER
	mov ofn.lpstrFilter, offset szOfnFilter
	
	invoke GetOpenFileName, addr ofn
	or eax,eax		 ; nothing selected??
	jz abort_open	; if so ->exit
	
	invoke SendDlgItemMessage, hWndMain, IDC_FILE, WM_SETTEXT, NULL, addr szSfvFile
	
	abort_open:
	ret
SearchForFile endp


InitListViewColumns PROC hWndListView :HWND
	local lvc :LVCOLUMN
	
	invoke RtlZeroMemory, addr lvc, sizeof LVCOLUMN
	mov lvc.imask, LVCF_TEXT or LVCF_SUBITEM or LVCF_WIDTH or LVCF_FMT
	mov lvc.fmt, LVCFMT_LEFT
	
	mov lvc.iSubItem, 0
	mov lvc.lx, 500
	mov lvc.pszText, offset szColFile
	invoke SendMessage, hWndListView, LVM_INSERTCOLUMN, 0, addr lvc
	
	mov lvc.fmt, LVCFMT_CENTER
	
	mov lvc.iSubItem, 1
	mov lvc.lx, 70
	mov lvc.pszText, offset szColCrc
	invoke SendMessage, hWndListView, LVM_INSERTCOLUMN, 1, addr lvc
	
	mov lvc.iSubItem, 2
	mov lvc.lx, 70
	mov lvc.pszText, offset szColActualCrc
	invoke SendMessage, hWndListView, LVM_INSERTCOLUMN, 2, addr lvc
	
	mov lvc.iSubItem, 3
	mov lvc.lx, 70
	mov lvc.pszText, offset szColStatus	
	invoke SendMessage, hWndListView, LVM_INSERTCOLUMN, 3, addr lvc

	invoke SendMessage, hWndListView, LVM_SETEXTENDEDLISTVIEWSTYLE, 0, LVS_EX_FULLROWSELECT or LVS_EX_HEADERDRAGDROP or LVS_EX_GRIDLINES or LVS_EX_DOUBLEBUFFER
	invoke SendMessage, hWndListView, LVM_SETCOLUMNWIDTH, 3,LVSCW_AUTOSIZE_USEHEADER
	
	ret
InitListViewColumns endp


ParseSfv PROC uses ebx edi esi
	local pBuffer :DWORD
	local dwBytesRead :DWORD
	local lvi :LVITEM
	local szLine[MAX_FNAME] :BYTE
	local szCrc[16] :BYTE
	
	mov dwIsSfv, 1
	invoke lstrlen, offset szSfvFile
	.if eax < 5
		;error no file given
		ret
	.endif
	
	sub eax, 4
	mov edi, offset szSfvFile
	add edi, eax
	invoke lstrcmpi, addr szSfvExt, edi
	.if eax != 0
		; no sfv ext error and return
		mov dwIsSfv, 0
		invoke MessageBox, hWndMain, offset szErrWrongFile, offset szError, MB_OK or MB_ICONERROR
		ret
	.endif
	
	mov dwFilesTotal, 0
	invoke RtlZeroMemory, addr lvi, sizeof LVITEM
	invoke SendDlgItemMessage, hWndMain, IDC_FILELIST, LVM_DELETEALLITEMS, 0, 0
	
	invoke CreateFile, addr szSfvFile,GENERIC_READ,FILE_SHARE_READ, NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN, NULL
	.if eax == INVALID_HANDLE_VALUE
		ret
	.endif
	
	mov ebx, eax	; save file handle in ebx
	invoke GetFileSize, eax, NULL
	push eax
	invoke HeapAlloc, hHeap, 0, eax
	.if eax == 0
		invoke CloseHandle, ebx
		ret
	.endif
	mov pBuffer, eax
	pop edx
	invoke ReadFile, ebx, pBuffer, edx, addr dwBytesRead, NULL  
	invoke CloseHandle, ebx
	
	mov ecx, dwBytesRead
	mov esi, pBuffer
	cld
	
	@@inputloop:
	or ecx, ecx
	jz @@cleanup
	; eat whitespace
	mov edi, esi
	mov al, ' '		; only need to eat space, tab not allowed
	repe scasb
	;mov esi, edi
	
	mov al, BYTE PTR [edi-1]
	cmp al, ';'
	je @@eatComment
	
	; find end of line (or EOF => ecx is zero then)
	mov al, 10	; LF
	repne scasb
	dec edi
	mov BYTE PTR [edi], 0
	push edi		; edi is end of line
	
	; delete CR if any
	mov al, BYTE PTR [edi-1]
	cmp al, 13 	; CR
	jne @F
	mov BYTE PTR [edi-1], 0
	
	@@:	
	dec edi
	mov al, BYTE PTR [edi]
	cmp al, ' '
	jne @B	
	
	
	@@:
	push ecx
	inc edi
	invoke lstrcpyn, addr szCrc, edi, sizeof szCrc
	dec edi
	mov BYTE PTR [edi], 0
	invoke lstrcpyn, addr szLine, esi, MAX_FNAME
	
	; now szCrc contains crc and szLine contains filename
	mov eax, dwFilesTotal
	mov lvi.iItem, eax
	mov lvi.imask, LVIF_TEXT
	mov lvi.iSubItem, 0
	lea eax, szLine
	mov lvi.pszText, eax
	invoke SendDlgItemMessage, hWndMain, IDC_FILELIST, LVM_INSERTITEM, 0, addr lvi
	
	mov lvi.iSubItem, 1
	lea eax, szCrc
	mov lvi.pszText, eax
	invoke SendDlgItemMessage, hWndMain, IDC_FILELIST, LVM_SETITEM, 0, addr lvi
	
	inc dwFilesTotal
	
	pop ecx
	jmp @@nextLine
	
	@@eatComment:
	mov al, 10	;LF
	repne scasb
	mov esi, edi
	jmp @@inputloop
	
	@@nextLine:
	pop esi	; pop start of next line, see push edi 
	inc esi
	jmp @@inputloop
	
		
	@@cleanup:
	invoke SendDlgItemMessage, hWndMain, IDC_FILELIST, LVM_SETCOLUMNWIDTH, 3,LVSCW_AUTOSIZE_USEHEADER
	invoke wsprintf, addr szLine, offset szFormatStatsTotal, dwFilesTotal
	invoke SendDlgItemMessage, hWndMain, IDC_STATS_TOTAL, WM_SETTEXT, 0, addr szLine
	invoke SendDlgItemMessage, hWndMain, IDC_PROGRESS, PBM_SETRANGE32, 0, dwFilesTotal
	invoke HeapFree, hHeap, 0, pBuffer	
	ret
	
	@@sfvInvalid:
	ret
ParseSfv endp


ThreadCalculate PROC uses ebx edi dwIndex:DWORD
	local szFullPath[MAX_FNAME] :BYTE
	local szFilename[MAX_FNAME] :BYTE
	local lvi :LVITEM
	local wfd :WIN32_FIND_DATA
	local szListedCrc[16] :BYTE
	local szCrc[16] :BYTE
	
	xor ebx, ebx
	; fetch name of next file and get full path
	invoke lstrcpyn, addr szFullPath, offset szSfvFile, MAX_FNAME
	std	; rep goes backwards
	lea edi, szFullPath
	invoke lstrlen, addr szFullPath
	mov ecx, eax
	add edi, eax
	mov al, '\'
	repne scasb 
	add edi, 2
	mov BYTE PTR [edi], 0
	
	invoke RtlZeroMemory, addr lvi, sizeof LVITEM
	mov eax, dwIndex
	mov lvi.iItem, eax
	mov lvi.imask, LVIF_TEXT
	mov lvi.cchTextMax, MAX_FNAME
	lea edx, szFilename
	mov lvi.pszText, edx 
	invoke SendDlgItemMessage, hWndMain, IDC_FILELIST, LVM_GETITEM, 0, addr lvi
	
	invoke lstrcat, addr szFullPath, addr szFilename
	
	mov lvi.iSubItem, 3
	mov lvi.pszText, offset szStatusProcessing
	invoke SendDlgItemMessage, hWndMain, IDC_FILELIST, LVM_SETITEM, 3, addr lvi
	invoke SendDlgItemMessage, hWndMain, IDC_FILELIST, LVM_ENSUREVISIBLE, dwIndex, FALSE
	
	invoke FindFirstFile, addr szFullPath, addr wfd
	.if eax == INVALID_HANDLE_VALUE
		mov lvi.iSubItem, 3
		mov lvi.pszText, offset szStatusLost
		invoke SendDlgItemMessage, hWndMain, IDC_FILELIST, LVM_SETITEM, 3, addr lvi
		inc DWORD PTR dwFilesLost	
		mov ebx, LPARAM_FILE_LOST	
	.else
		invoke FindClose, eax
		
		mov lvi.cchTextMax, sizeof szListedCrc
		lea eax, szListedCrc
		mov lvi.pszText,  eax
		mov lvi.iSubItem, 1
		invoke SendDlgItemMessage, hWndMain, IDC_FILELIST, LVM_GETITEM, 1, addr lvi
		
		invoke Crc32_FromFile, addr szFullPath
		invoke wsprintf, addr szCrc, offset szFormatCrc32, eax
		
		invoke lstrcmpi, addr szListedCrc, addr szCrc 
		.if eax == 0
			mov lvi.pszText, offset szStatusGood
			inc DWORD PTR dwFilesGood
			mov ebx, LPARAM_FILE_GOOD
		.else
			mov lvi.pszText, offset szStatusBad
			inc DWORD PTR dwFilesBad
			mov ebx, LPARAM_FILE_BAD
		.endif
		
		mov lvi.iSubItem, 3
		invoke SendDlgItemMessage, hWndMain, IDC_FILELIST, LVM_SETITEM, 3, addr lvi
		
		mov lvi.iSubItem, 2
		lea eax, szCrc
		mov lvi.pszText, eax 
		invoke SendDlgItemMessage, hWndMain, IDC_FILELIST, LVM_SETITEM, 2, addr lvi
	.endif
	
	; set lparam to our color code
	mov lvi.imask, LVIF_PARAM
	mov lvi.iSubItem, 0
	mov lvi.lParam, ebx
	invoke SendDlgItemMessage, hWndMain, IDC_FILELIST, LVM_SETITEM, 0, addr lvi
	
	; reuse fullpath buffer for stat strings
	invoke wsprintf, addr szFullPath, offset szFormatStatsGood, dwFilesGood
	invoke SendDlgItemMessage, hWndMain, IDC_STATS_GOOD, WM_SETTEXT, 0, addr szFullPath
	invoke wsprintf, addr szFullPath, offset szFormatStatsBad, dwFilesBad
	invoke SendDlgItemMessage, hWndMain, IDC_STATS_BAD, WM_SETTEXT, 0, addr szFullPath	
	invoke wsprintf, addr szFullPath, offset szFormatStatsLost, dwFilesLost
	invoke SendDlgItemMessage, hWndMain, IDC_STATS_MISSING, WM_SETTEXT, 0, addr szFullPath
	
	invoke SendMessage, hWndMain, WM_THREAD_DONE, 0, 0

	xor eax, eax
	ret
ThreadCalculate endp


ListViewCustomDraw PROC lParam :DWORD
	;local plvcd :NMLVCUSTOMDRAW
	mov ecx, lParam
	
	.if [ecx.NMLVCUSTOMDRAW.nmcd.dwDrawStage] == CDDS_PREPAINT
		mov eax, CDRF_NOTIFYITEMDRAW
		ret
	.elseif  [ecx.NMLVCUSTOMDRAW.nmcd.dwDrawStage] == CDDS_ITEMPREPAINT || [lParam.NMLVCUSTOMDRAW.nmcd.dwDrawStage] == CDDS_SUBITEM
		.if [ecx.NMLVCUSTOMDRAW.nmcd.lItemlParam] == LPARAM_FILE_BAD
			mov [ecx.NMLVCUSTOMDRAW.clrTextBk], 000ccccffh	; 0x00bbggrr
		.elseif [ecx.NMLVCUSTOMDRAW.nmcd.lItemlParam] == LPARAM_FILE_GOOD
			mov [ecx.NMLVCUSTOMDRAW.clrTextBk], 000aaffaah	; 0x00bbggrr
		.elseif [ecx.NMLVCUSTOMDRAW.nmcd.lItemlParam] == LPARAM_FILE_LOST
			mov [ecx.NMLVCUSTOMDRAW.clrTextBk], 000aaffffh	; 0x00bbggrr
		.endif
		mov eax, CDRF_NEWFONT
		ret
	.endif
	
	mov eax, CDRF_DODEFAULT
	ret
ListViewCustomDraw endp



end start
