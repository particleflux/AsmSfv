.486
.model flat, stdcall
option casemap :none   ; case sensitive

include windows.inc
include kernel32.inc
include advapi32.inc

includelib kernel32.lib
includelib advapi32.lib


include fileassociation.inc



.data
	szCmdKey	db "shell\open\command",0
	szIconKey		db "DefaultIcon",0


.code


; registers a file extension with an appplication
; pszExt: extension with .
FA_RegisterExtension PROC pszExt:LPCSTR, pszAppName :LPCSTR, pszFileDesc :LPCSTR, pszIconPath :LPCSTR, pszCommand :LPCSTR
	local hKey :HANDLE
	local hKey1 :HANDLE

	.if pszExt == NULL || pszAppName == NULL || pszCommand == NULL
		mov eax, FA_ERROR_PARAMETER
		ret
	.endif
	
	; create ext key
	invoke RegCreateKeyEx, HKEY_CLASSES_ROOT, pszExt, 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, addr hKey, NULL
	.if eax != ERROR_SUCCESS
		mov eax, FA_ERROR_FAILED
		ret
	.endif 
	
	invoke lstrlen, pszAppName
	inc eax 
	invoke RegSetValueEx, hKey, NULL, 0, REG_SZ, pszAppName, eax
	mov ebx, eax
	invoke RegCloseKey, hKey
	.if ebx != ERROR_SUCCESS		
		mov eax, FA_ERROR_FAILED
		ret
	.endif  

	; create app key
	invoke RegCreateKeyEx, HKEY_CLASSES_ROOT, pszAppName, 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, addr hKey, NULL
	.if eax != ERROR_SUCCESS
		mov eax, FA_ERROR_FAILED
		ret
	.endif
	
	.if pszFileDesc != NULL
		invoke lstrlen, pszFileDesc
		inc eax
		invoke RegSetValueEx, hKey, NULL, 0, REG_SZ, pszFileDesc, eax
	.endif
	
	; set command
	invoke RegCreateKeyEx, hKey, offset szCmdKey, 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, addr hKey1, NULL
	invoke lstrlen, pszCommand
	inc eax
	invoke RegSetValueEx, hKey1, NULL, 0, REG_SZ, pszCommand, eax
	invoke RegCloseKey, hKey1
	 
	; set icon
	.if pszIconPath != NULL
		invoke RegCreateKeyEx, hKey, offset szIconKey, 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, addr hKey1, NULL

		invoke lstrlen, pszIconPath
		inc eax
		invoke RegSetValueEx, hKey1, NULL, 0, REG_SZ, pszIconPath, eax
		invoke RegCloseKey, hKey1
	.endif
	
	
	invoke RegCloseKey, hKey	
	

	xor eax, eax
	ret
FA_RegisterExtension endp



FA_UnregisterExtension PROC pszExt :LPCSTR, pszAppName :LPCSTR
	local hKey :HANDLE

	.if pszExt == NULL
		mov eax, FA_ERROR_PARAMETER
		ret
	.endif

	; just delete app name in .ext key, could delete app key also but who cares ;P
	invoke RegCreateKeyEx, HKEY_CLASSES_ROOT, pszExt, 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, addr hKey, NULL
	.if eax != ERROR_SUCCESS
		mov eax, FA_ERROR_FAILED
		ret
	.endif 
	
	invoke RegSetValueEx, hKey, NULL, 0, REG_SZ, NULL, 0
	invoke RegCloseKey, hKey
	
	xor eax, eax
	ret
FA_UnregisterExtension endp


; check wether extension is registered to given appname
FA_IsExtensionRegistered PROC pszExt :LPCSTR, pszAppName :LPCSTR
	local hKey :HANDLE
	local szBuff[128] :BYTE
	local dwSize :DWORD

	.if pszExt == NULL || pszAppName == NULL
		mov eax, FA_ERROR_PARAMETER
		ret
	.endif
	
	invoke RegCreateKeyEx, HKEY_CLASSES_ROOT, pszExt, 0, NULL, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, addr hKey, NULL
	.if eax != ERROR_SUCCESS
		mov eax, FA_ERROR_FAILED
		ret
	.endif 
	
	;get default key value and compare to pszAppName
	xor ebx, ebx
	mov dwSize, sizeof szBuff
	invoke RegQueryValue, hKey, NULL, addr szBuff, addr dwSize
	.if eax == ERROR_SUCCESS
		invoke lstrcmp, addr szBuff, pszAppName
		.if eax == 0
			mov ebx, 1
		.endif
	.endif	
	
	invoke RegCloseKey, hKey	
	
	mov eax, ebx
	ret
FA_IsExtensionRegistered endp


End
