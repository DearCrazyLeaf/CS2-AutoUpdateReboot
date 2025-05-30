@echo off
chcp 936 >nul
title CS2 服务器监控
cd /d "%~dp0"

rem 检查管理员权限
net session >nul 2>&1
if %errorLevel% == 0 (
    goto START
) else (
    echo 正在请求管理员权限...
    start "" /wait "AutoElevate.vbs"
    exit
)

:START
cls
echo ===== CS2 服务器监控 =====
echo.
:retry
echo 启动监控中...
PowerShell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Normal -Command ^
    "& {Set-ExecutionPolicy Bypass -Scope Process -Force; . '%~dp0服务器自动重启.ps1'}"

if %ERRORLEVEL% NEQ 0 (
    echo 监控异常退出，5秒后重试...
    ping 127.0.0.1 -n 6 > nul
    goto retry
) else (
    echo 监控正常退出
    timeout /t 3
    exit
)
