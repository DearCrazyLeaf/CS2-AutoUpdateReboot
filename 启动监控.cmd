@echo off
chcp 936 >nul
title CS2 ���������
cd /d "%~dp0"

rem ������ԱȨ��
net session >nul 2>&1
if %errorLevel% == 0 (
    goto START
) else (
    echo �����������ԱȨ��...
    start "" /wait "AutoElevate.vbs"
    exit
)

:START
cls
echo ===== CS2 ��������� =====
echo.
:retry
echo ���������...
PowerShell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Normal -Command ^
    "& {Set-ExecutionPolicy Bypass -Scope Process -Force; . '%~dp0�������Զ�����.ps1'}"

if %ERRORLEVEL% NEQ 0 (
    echo ����쳣�˳���5�������...
    ping 127.0.0.1 -n 6 > nul
    goto retry
) else (
    echo ��������˳�
    timeout /t 3
    exit
)
