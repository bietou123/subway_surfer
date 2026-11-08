@echo off
setlocal EnableDelayedExpansion
rem ---------------------------------------------------------------------------
rem ASCII-only on purpose: cmd.exe parses BOM-less batch files with the system
rem ANSI code page, so any non-ASCII line would be split or garbled. Chinese
rem documentation lives in README.md instead.
rem ---------------------------------------------------------------------------

echo ============================================================
echo   Subway Surfer APK builder  (aapt + javac + d8 + zipalign)
echo ============================================================
echo.

rem ---------------------------------------------------------------------------
rem 0. Paths
rem ---------------------------------------------------------------------------
set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%apk_project"
set "BUILD_DIR=%SCRIPT_DIR%build"
set "OUT_APK=%SCRIPT_DIR%subway_surfer.apk"
set "OUT_APK_SIGNED=%SCRIPT_DIR%subway_surfer_signed.apk"
set "OUT_APK_ALIGNED=%SCRIPT_DIR%subway_surfer_aligned.apk"
set "KEYSTORE=%SCRIPT_DIR%debug.keystore"

rem ---------------------------------------------------------------------------
rem 1. Java toolchain
rem ---------------------------------------------------------------------------
echo [1/8] Checking Java toolchain...
where java >nul 2>&1
if errorlevel 1 (
    echo [ERROR] java not found. Install a JDK and add it to PATH.
    goto :ERROR
)
for /f "tokens=*" %%v in ('java -version 2^>^&1') do (
    echo       %%v
    goto :JAVA_OK
)
:JAVA_OK

where javac >nul 2>&1
if errorlevel 1 (
    echo [ERROR] javac not found. Install a full JDK, not just a JRE.
    goto :ERROR
)
echo       javac OK
echo.

rem ---------------------------------------------------------------------------
rem 2. Locate Android SDK
rem ---------------------------------------------------------------------------
echo [2/8] Locating Android SDK...

if defined ANDROID_HOME (
    set "SDK_ROOT=%ANDROID_HOME%"
    goto :SDK_FOUND
)
if defined ANDROID_SDK_ROOT (
    set "SDK_ROOT=%ANDROID_SDK_ROOT%"
    goto :SDK_FOUND
)

for %%P in (
    "%LOCALAPPDATA%\Android\Sdk"
    "%USERPROFILE%\AppData\Local\Android\Sdk"
    "C:\Android\Sdk"
    "C:\Android\android-sdk"
    "C:\Program Files\Android\android-sdk"
    "D:\Android\Sdk"
    "D:\Android\android-sdk"
) do (
    if exist "%%~P\build-tools" (
        set "SDK_ROOT=%%~P"
        goto :SDK_FOUND
    )
)

echo [ERROR] Android SDK not found.
echo         Install Android Studio or the command-line tools,
echo         or set ANDROID_HOME / ANDROID_SDK_ROOT.
goto :ERROR

:SDK_FOUND
echo       SDK_ROOT = %SDK_ROOT%

rem Pick the highest build-tools version available.
set "BUILD_TOOLS="
for /f "tokens=*" %%d in ('dir /b /ad "%SDK_ROOT%\build-tools" 2^>nul') do (
    set "BUILD_TOOLS=%SDK_ROOT%\build-tools\%%d"
)
if not defined BUILD_TOOLS (
    echo [ERROR] build-tools directory is empty. Install Build-Tools via SDK Manager.
    goto :ERROR
)
echo       build-tools = %BUILD_TOOLS%

rem Prefer android-34, fall back to the highest installed platform.
set "ANDROID_JAR="
for %%v in (34 33 32 31 30 29 28 27 26 25 24 23 22 21) do (
    if not defined ANDROID_JAR (
        if exist "%SDK_ROOT%\platforms\android-%%v\android.jar" (
            set "ANDROID_JAR=%SDK_ROOT%\platforms\android-%%v\android.jar"
            set "PLATFORM_VER=%%v"
        )
    )
)
if not defined ANDROID_JAR (
    echo [ERROR] No android.jar found. Install at least one Platform via SDK Manager.
    goto :ERROR
)
echo       android.jar  = %ANDROID_JAR%  (API %PLATFORM_VER%)
echo.

set "AAPT=%BUILD_TOOLS%\aapt.exe"
set "D8=%BUILD_TOOLS%\d8.bat"
set "ZIPALIGN=%BUILD_TOOLS%\zipalign.exe"
set "APKSIGNER=%BUILD_TOOLS%\apksigner.bat"

rem ---------------------------------------------------------------------------
rem 3. Build directory
rem ---------------------------------------------------------------------------
echo [3/8] Preparing build directory...
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
mkdir "%BUILD_DIR%\obj"
mkdir "%BUILD_DIR%\dex"
mkdir "%BUILD_DIR%\apk_raw"
echo       %BUILD_DIR%
echo.

rem ---------------------------------------------------------------------------
rem 4. aapt: compile resources and generate R.java
rem ---------------------------------------------------------------------------
echo [4/8] Compiling resources (aapt)...
if not exist "%AAPT%" (
    echo [ERROR] %AAPT% not found.
    goto :ERROR
)

"%AAPT%" package -f -m ^
    -S "%PROJECT_DIR%\res" ^
    -A "%PROJECT_DIR%\assets" ^
    -M "%PROJECT_DIR%\AndroidManifest.xml" ^
    -I "%ANDROID_JAR%" ^
    -J "%BUILD_DIR%\obj" ^
    -F "%BUILD_DIR%\apk_raw\resources.ap_"

if errorlevel 1 (
    echo [ERROR] aapt failed while compiling resources.
    goto :ERROR
)
echo       R.java generated
echo.

rem ---------------------------------------------------------------------------
rem 5. javac: compile Java sources
rem ---------------------------------------------------------------------------
echo [5/8] Compiling Java sources (javac)...
set "JAVA_SOURCES=%PROJECT_DIR%\src\com\subwaysurfer\game\MainActivity.java"
set "R_JAVA=%BUILD_DIR%\obj\com\subwaysurfer\game\R.java"

javac -source 8 -target 8 ^
    -encoding UTF-8 ^
    -classpath "%ANDROID_JAR%" ^
    -d "%BUILD_DIR%\obj" ^
    "%JAVA_SOURCES%" "%R_JAVA%"

if errorlevel 1 (
    echo [ERROR] javac failed.
    goto :ERROR
)
echo       .class files generated
echo.

rem ---------------------------------------------------------------------------
rem 6. d8: convert class files to DEX
rem ---------------------------------------------------------------------------
echo [6/8] Converting to DEX (d8)...
if not exist "%D8%" (
    echo [ERROR] %D8% not found.
    goto :ERROR
)

set "CLASS_FILES="
for /r "%BUILD_DIR%\obj" %%f in (*.class) do (
    set "CLASS_FILES=!CLASS_FILES! "%%f""
)

call "%D8%" --output "%BUILD_DIR%\dex" --lib "%ANDROID_JAR%" !CLASS_FILES!

if errorlevel 1 (
    echo [ERROR] d8 failed.
    goto :ERROR
)
echo       classes.dex generated
echo.

rem ---------------------------------------------------------------------------
rem 7. Package the APK
rem ---------------------------------------------------------------------------
echo [7/8] Packaging APK...

copy /y "%BUILD_DIR%\apk_raw\resources.ap_" "%OUT_APK%" >nul

"%AAPT%" add "%OUT_APK%" -C "%BUILD_DIR%\dex" classes.dex >nul 2>&1
if errorlevel 1 (
    pushd "%BUILD_DIR%\dex"
    "%AAPT%" add "%OUT_APK%" classes.dex
    popd
)

if errorlevel 1 (
    echo [ERROR] Failed to add classes.dex to the APK.
    goto :ERROR
)
echo       Unsigned APK: %OUT_APK%
echo.

rem ---------------------------------------------------------------------------
rem 8. Sign and align
rem ---------------------------------------------------------------------------
echo [8/8] Aligning and signing...

rem zipalign FIRST: it rewrites the archive, which would invalidate a v2/v3
rem signature. Sign the aligned package after this step.
if exist "%ZIPALIGN%" (
    if exist "%OUT_APK_ALIGNED%" del "%OUT_APK_ALIGNED%"
    "%ZIPALIGN%" -f 4 "%OUT_APK%" "%OUT_APK_ALIGNED%"
    if errorlevel 1 (
        echo [ERROR] zipalign failed.
        goto :ERROR
    )
    copy /y "%OUT_APK_ALIGNED%" "%OUT_APK%" >nul
    del "%OUT_APK_ALIGNED%"
    echo       zipalign OK
) else (
    echo       [warn] zipalign.exe not found, package stays unaligned
)

rem Generate a debug keystore on first run. Passwords are the public Android
rem debug defaults; this is for local installs, not for store distribution.
if not exist "%KEYSTORE%" (
    echo       Generating debug keystore...
    keytool -genkeypair -keystore "%KEYSTORE%" ^
        -alias androiddebugkey ^
        -keyalg RSA -keysize 2048 ^
        -validity 10000 ^
        -storepass android -keypass android ^
        -dname "CN=Android Debug,O=Android,C=US" >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] keytool failed. Check your JDK installation.
        goto :ERROR
    )
    echo       debug.keystore created
)

if exist "%APKSIGNER%" (
    call "%APKSIGNER%" sign ^
        --ks "%KEYSTORE%" ^
        --ks-pass pass:android ^
        --key-pass pass:android ^
        --ks-key-alias androiddebugkey ^
        --out "%OUT_APK_SIGNED%" ^
        "%OUT_APK%"
    if errorlevel 1 goto :TRY_JARSIGNER
    echo       Signed with apksigner
    goto :SIGNED
)

:TRY_JARSIGNER
jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 ^
    -keystore "%KEYSTORE%" ^
    -storepass android -keypass android ^
    -signedjar "%OUT_APK_SIGNED%" ^
    "%OUT_APK%" androiddebugkey

if errorlevel 1 (
    echo [ERROR] jarsigner failed.
    goto :ERROR
)
echo       Signed with jarsigner

:SIGNED

copy /y "%OUT_APK_SIGNED%" "%OUT_APK%" >nul
del "%OUT_APK_SIGNED%" >nul 2>&1
del "%OUT_APK_SIGNED%.idsig" >nul 2>&1

echo.
echo ============================================================
echo   Build succeeded
echo   Output: %SCRIPT_DIR%subway_surfer.apk
echo ============================================================
echo.
echo   Install with: adb install -r subway_surfer.apk
echo.
goto :END

:ERROR
echo.
echo ============================================================
echo   [BUILD FAILED] See the errors above.
echo ============================================================
echo.
if /i not "%~1"=="--no-pause" pause
exit /b 1

:END
if /i not "%~1"=="--no-pause" pause
exit /b 0
