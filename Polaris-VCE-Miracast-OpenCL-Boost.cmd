
@echo off
setlocal EnableExtensions

set "FFMPEG=%~dp0ffmpeg.exe"
if not exist "%FFMPEG%" (
    echo [ERROR] ffmpeg.exe was not found next to this script.
    echo Download an FFmpeg FULL build with OpenCL support:
    echo https://github.com/BtbN/FFmpeg-Builds/releases OR https://www.gyan.dev/ffmpeg/builds/
    echo Extract it and place ffmpeg.exe file in the same folder as this script.
    pause
    exit /b 1
)

echo =============================================================
echo Polaris VCE / Miracast OpenCL Boost
echo =============================================================
echo Running a tiny OpenCL workload at 1 frame per second.
echo No output file is created. No driver or registry settings are changed.
echo Press q in this window to stop. Ctrl+C also works.
echo.

"%FFMPEG%" -hide_banner -loglevel info -stats -init_hw_device opencl=ocl:,device_type=gpu -filter_hw_device ocl -re -f lavfi -i "testsrc2=size=64x36:rate=1" -vf "format=nv12,hwupload,avgblur_opencl=sizeX=1:sizeY=1,hwdownload,format=nv12" -an -f null NUL

set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
    echo.
    echo [ERROR] FFmpeg exited with code %RC%.
    echo Verify that FFmpeg includes OpenCL and the AMD OpenCL GPU is available.
    pause
)
exit /b %RC%
