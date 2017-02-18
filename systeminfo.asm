.486
.model	flat, stdcall
option	casemap :none   ; case sensitive

include windows.inc
include kernel32.inc

includelib kernel32.lib

include systeminfo.inc


.code

GetNumCores PROC
	local sys :SYSTEM_INFO
	
	invoke GetSystemInfo, addr sys
	mov eax, sys.dwNumberOfProcessors

	ret
GetNumCores endp





End
