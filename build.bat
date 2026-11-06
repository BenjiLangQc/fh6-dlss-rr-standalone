@echo off
setlocal
rem Builds build\xinput1_3.dll (x64 Release) with the VS 2022 Build Tools.
rem Run fetch_deps.bat once first (MinHook).
set ROOT=%~dp0
set VSDEV="C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if not exist %VSDEV% set VSDEV="C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
call %VSDEV% >nul || exit /b 1

set B=%ROOT%build
if not exist "%B%\gen" mkdir "%B%\gen"
if not exist "%B%\obj" mkdir "%B%\obj"

rem ---- shaders -> headers
set DXC="C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\dxc.exe"
set SH=%ROOT%src\shaders
%DXC% -nologo -T cs_6_0 -E main -O3 -Fh "%B%\gen\rr_guides_cs.h" -Vn g_rr_guides_cs "%SH%\rr_guides.hlsl" >nul || goto :fail
rem raw-GI shaders: 4 brightness scales x 4 occlusion modes; *_s*_a* for the shared GI module, gi_conv_* replace the
rem game's GI temporal pass at pipeline creation (raw GI read from t20)
echo #pragma once> "%B%\gen\gi_raw_cs.h"
for %%S in (0 1 2 3) do for %%A in (0 1 2 3) do (
	%DXC% -nologo -T cs_6_0 -E main -O3 -D GI_SCALE_IDX=%%S -D GI_AO_IDX=%%A -Fh "%B%\gen\gi_raw_s%%S_a%%A.h" -Vn g_gi_raw_s%%S_a%%A "%SH%\gi_raw.hlsl" >nul || goto :fail
	echo #include "gi_raw_s%%S_a%%A.h">> "%B%\gen\gi_raw_cs.h"
	%DXC% -nologo -T cs_6_0 -E main -O3 -D GI_SCALE_IDX=%%S -D GI_AO_IDX=%%A -D RAW_REG=t20 -Fh "%B%\gen\gi_conv_s%%S_a%%A.h" -Vn g_gi_conv_s%%S_a%%A "%SH%\gi_raw.hlsl" >nul || goto :fail
	echo #include "gi_conv_s%%S_a%%A.h">> "%B%\gen\gi_raw_cs.h"
)
%DXC% -nologo -T cs_6_0 -E main -O3 -Fh "%B%\gen\gi_copy_cs.h" -Vn g_gi_copy_cs "%SH%\gi_copy.hlsl" >nul || goto :fail
echo #include "gi_copy_cs.h">> "%B%\gen\gi_raw_cs.h"

set INC=/I"%B%\gen" /I"%ROOT%src" /I"%ROOT%external\streamline\include" /I"%ROOT%external\minhook\include"
set CXXFLAGS=/nologo /c /O2 /MT /W3 /std:c++20 /EHsc /permissive- /DNDEBUG /D_CRT_SECURE_NO_WARNINGS /DUNICODE /D_UNICODE
set MH=%ROOT%external\minhook\src

pushd "%B%\obj"
del /q *.obj 2>nul
cl /nologo /c /O2 /MT /W3 %INC% "%MH%\hook.c" "%MH%\buffer.c" "%MH%\trampoline.c" "%MH%\hde\hde64.c" >nul || goto :failpop
cl %CXXFLAGS% %INC% "%ROOT%src\standalone.cpp" "%ROOT%src\xinput_proxy.cpp" "%ROOT%src\rr.cpp" "%ROOT%src\gi_bypass.cpp" || goto :failpop
link /nologo /DLL /DEF:"%ROOT%src\xinput1_3.def" /MAP:"%B%\xinput1_3.map" /OUT:"%B%\xinput1_3.dll" *.obj d3d12.lib dxgi.lib dxguid.lib user32.lib >nul || goto :failpop
popd

echo Built: %B%\xinput1_3.dll
exit /b 0

:failpop
popd
:fail
echo BUILD FAILED
exit /b 1
