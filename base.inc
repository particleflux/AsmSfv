include windows.inc

uselib MACRO	libname
	include libname.inc
	includelib	libname.lib
ENDM

uselib user32
uselib kernel32
uselib comctl32	;  progressbar + listview
uselib comdlg32	; file open dlg
uselib masm32	; GetCL
uselib advapi32	; registry
uselib shell32		; drag & drop

DlgProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
SearchForFile PROTO
InitListViewColumns PROTO :HWND
ParseSfv PROTO 
ThreadCalculate PROTO :DWORD
ListViewCustomDraw PROTO :DWORD
ListViewSubclassProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
ReadSettings PROTO


IDV_VERSION 				equ 1
IDI_ICON					equ 2
IDD_MAINDLG 			equ 101
IDD_ABOUT				equ 1022

IDC_FILE 				equ 1001
IDC_BROWSE 			equ 1003
IDC_FILELIST				equ 1005
IDC_CHECK				equ 1006
IDC_PROGRESS			equ 1009
IDC_ABOUT				equ 1010
IDC_STATS_TOTAL			equ 1011
IDC_STATS_GOOD			equ 1012
IDC_STATS_BAD			equ 1013
IDC_STATS_MISSING		equ 1014
IDC_STATS_TIME			equ 1015
IDC_OPTION_EXPLORER  	equ 1016
IDC_OPTION_THREADS 	equ 1018
IDC_OPTION_AUTOCHECK	equ 1019

TIMER_AUTOCHECK		equ 1

LPARAM_FILE_UNKNOWN	equ 0
LPARAM_FILE_LOST		equ 1
LPARAM_FILE_BAD			equ 2
LPARAM_FILE_GOOD		equ 3


WM_THREAD_DONE	equ WM_APP + 1

MAX_THREADS		equ 32
MAX_FNAME			equ 1024


.data
	szOfnFilter		db "SFV Files (*.sfv)",0,"*.sfv",0,"All Files (*.*)",0,"*.*",0,0
	szOfnTitle			db "Select SFV file to verify",0
	
	szFormatCrc32		db "%08x",0
	szFormatStatsTotal		db "Total Files: %d", 0
	szFormatStatsGood		db "Good Files: %d", 0
	szFormatStatsLost		db "Lost Files: %d", 0
	szFormatStatsBad		db "Bad Files: %d", 0
	szFormatStatsTime		db "Time needed: %lum %lus %lums",0
	szFormatNum				db "%d",0
	szFormatDw				db "%lu",0
	szFormatCommand			db 34,"%s",34," ",34,"%%1",34,0
	
	; key names for settings
	szSettingsKey			db "Software\AsmSfv",0
	szSettingNumThreads	db "numThreads",0
	szSettingNoAutoCheck	db "noAutoCheck",0
	szAppName			db "AsmSfv",0
	szSfvExt			db ".sfv",0
	szIconAppend			db ",0",0
	szSfvFileDesc			db "Simple File Verification Files",0
	
	
	;listview column names
	szColFile				db "Filename",0
	szColCrc				db "Listed CRC",0
	szColActualCrc			db "Actual CRC",0
	szColStatus			db "Status",0
	
	szStatusProcessing		db "processing",0
	szStatusGood			db "good",0
	szStatusBad			db "bad",0
	szStatusLost			db "missing",0
	
	; error messages
	szError				db "Error",0
	szErrNoFile			db "No SFV file given!",0
	szErrWrongFile		db "This is no SFV file :(",0
	
	dwMsInMinute			dd 60000
	dwMsInS				dd 1000

.data?
	hWndMain			dd ?
	hInstance				dd ?
	dwNumThreads		dd ?
	dwExtRegged			dd ?
	dwDontAutoCheck			dd ?
	dwNextFile			dd ?		; index of next file to process in listview
	hHeap				dd ?
	
	dwFilesTotal			dd ?
	dwFilesGood			dd ?
	dwFilesBad			dd ?
	dwFilesLost			dd ?
	
	dwIsSfv			dd ?
	
	szSfvFile			db MAX_FNAME dup(?)
	
	prevWndProc		WNDPROC ?
	
	
	align 8
	pcFrequency 		dq ?
	pcStartCount 		dq ?
	pcEndCount  		dq ?
	pcAvailable 		db ?
