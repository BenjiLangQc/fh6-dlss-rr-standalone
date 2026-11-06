@echo off
rem Fetches MinHook at the commit the mod was built and tested with.
rem (Streamline headers are already committed under external\streamline.)
setlocal
set EXT=%~dp0external
if not exist "%EXT%" mkdir "%EXT%"

if not exist "%EXT%\minhook\include\MinHook.h" (
	git clone https://github.com/TsudaKageyu/minhook "%EXT%\minhook" || exit /b 1
	git -C "%EXT%\minhook" checkout 8af6b4acae5a9388fd742b56fa79ece89d96f823 || exit /b 1
)

echo Dependencies ready.
