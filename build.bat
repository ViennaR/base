::set R_VERSION=R-3.2.2
::set R_VERSION=R-devel
set R_VERSION=%1

::set WIN=32
::set WIN=64
set WIN=%2

::globals
set SOURCEDIR=%~dp0
mkdir ..\\BUILD
cd ..\\BUILD
set BUILDDIR=%CD%
COPY %SOURCEDIR%\%R_VERSION%.tar.gz %R_VERSION%.tar.gz

echo "SOURCEDIR: %SOURCEDIR%"
echo "BUILDDIR: %BUILDDIR%"

:: Set name of target
set R_NAME=%R_VERSION%-win%WIN%
set R_HOME=%BUILDDIR%/%R_NAME%
set TMPDIR=%TEMP%

:: For the multi-arch installer
set HOME32=%BUILDDIR%/%R_VERSION%-win32

:: Add rtools executables in path
set PATH=C:\rtools\bin;%PATH%

:: Clean up
rm -f %R_HOME%/*.log
rm -Rf %R_HOME%

:: Copy sources
tar -xf %R_VERSION%.tar.gz
mv %R_VERSION% %R_NAME%
set XR_HOME=%R_HOME:\=/%
set XHOME32=%HOME32:\=/%
sed -e "s|@win@|%WIN%|" -e "s|@home@|%XR_HOME%|" -e "s|@home32@|%XHOME32%|" %SOURCEDIR%\files\MkRules.local.in > %R_HOME%/src/gnuwin32/MkRules.local

:: Copy libraries
cp -R %SOURCEDIR%\libcurl %R_HOME%\libcurl
cp -R %SOURCEDIR%\Tcltk\Tcl%WIN% %R_HOME%\Tcl
cp -R %SOURCEDIR%\extsoft %R_HOME%\extsoft
cp %SOURCEDIR%\files\curl-ca-bundle.crt %R_HOME%\etc\curl-ca-bundle.crt

:: Temporary fix for cairo stack
mkdir %BUILDDIR%\%R_NAME%\cairo
cp -R %SOURCEDIR%\cairo\lib\x64 %R_HOME%\cairo\win64
cp -R %SOURCEDIR%\cairo\lib\i386 %R_HOME%\cairo\win32
xcopy /s "%SOURCEDIR%\cairo\include\cairo" "%R_HOME%\cairo\win32"
xcopy /s "%SOURCEDIR%\cairo\include\cairo" "%R_HOME%\cairo\win64"

sed -i "s/-lcairo -lpixman-1 -lpng -lz/-lcairo -lfontconfig -lfreetype -lpng -lpixman-1 -lexpat -lharfbuzz -lbz2 -lz/" %R_HOME%/src/library/grDevices/src/cairo/Makefile.win

:: Remove BOM from this file
sed -i "1s/^\xEF\xBB\xBF//" %R_HOME%/src/gnuwin32/installer/CustomMsg.iss

:: Mark output as experimental
::sed -i "s/Under development (unstable)/EXPERIMENTAL/" %R_HOME%/VERSION
::echo cat('R-experimental') > %R_HOME%/src/gnuwin32/fixed/rwver.R
sed -i "s/Unsuffered Consequences/Blame Jeroen/" %R_HOME%/VERSION-NICK

:: Add rtools 'make' to the user path
echo PATH="C:\Rtools\bin;${PATH}" > %R_HOME%/etc/Renviron.site
sed -i "s/ETC_FILES = Rprofile.site/ETC_FILES = Renviron.site Rprofile.site/" %R_HOME%/src/gnuwin32/installer/Makefile

:: Switch dir
cd %R_HOME%/src/gnuwin32

:: Download 'extsoft' directory
:: make rsync-extsoft

:: Build 32bit R version only
IF "%WIN%"=="32" (
make 32-bit > %BUILDDIR%/32bit.log 2>&1 && cd %SOURCEDIR%
exit /b %errorlevel%
)

:: Build 64bit version + installer
make distribution > %BUILDDIR%/distribution.log 2>&1
if %errorlevel% neq 0 exit /b %errorlevel%

make check-all > %BUILDDIR%/check.log 2>&1
if %errorlevel% neq 0 exit /b %errorlevel%

:: Get the actual version name
call %R_HOME%\src\gnuwin32\cran\target.cmd

:: Copy files to ship in the distribution
cp %R_HOME%/SVN-REVISION %BUILDDIR%/
cp %R_HOME%/src/gnuwin32/cran/%target%-win.exe %BUILDDIR%/
cp %R_HOME%/src/gnuwin32/cran/md5sum.txt %BUILDDIR%/
cp %R_HOME%/src/gnuwin32/cran/NEWS.%target%.html %BUILDDIR%/
cp %R_HOME%/src/gnuwin32/cran/CHANGES.%target%.html %BUILDDIR%/
cp %R_HOME%/src/gnuwin32/cran/README.%target% %BUILDDIR%/
cp %R_HOME%/src/gnuwin32/cran/target.cmd %BUILDDIR%/

:: TODO: use %target% instead of %R_VERSION%
IF "%R_VERSION%"=="R-devel" (
cp %R_HOME%/src/gnuwin32/cran/rdevel.html %BUILDDIR%/
) ELSE IF "%R_VERSION%"=="R-patched" (
cp %R_HOME%/src/gnuwin32/cran/rpatched.html %BUILDDIR%/
) ELSE IF "%R_VERSION:~0,3%"=="R-3" (
cp %R_HOME%/src/gnuwin32/cran/index.html %BUILDDIR%/
cp %R_HOME%/src/gnuwin32/cran/rw-FAQ.html %BUILDDIR%/
cp %R_HOME%/src/gnuwin32/cran/release.html %BUILDDIR%/
) ELSE (
echo "Unknown build type: %R_VERSION%"
exit /b 1
)

:: Done
cd %SOURCEDIR%
