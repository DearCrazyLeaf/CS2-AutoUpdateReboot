# 新增：禁用控制台快速编辑模式以防止窗口操作导致暂停
try {
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;

    public class ConsoleConfig {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr GetStdHandle(int nStdHandle);

        [DllImport("kernel32.dll")]
        public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

        [DllImport("kernel32.dll")]
        public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);

        public const int STD_INPUT_HANDLE = -10;
        public const uint ENABLE_QUICK_EDIT_MODE = 0x0040;
        
        public static void DisableQuickEdit() {
            IntPtr handle = GetStdHandle(STD_INPUT_HANDLE);
            uint mode = 0;
            if (GetConsoleMode(handle, out mode)) {
                mode &= ~ENABLE_QUICK_EDIT_MODE;
                SetConsoleMode(handle, mode);
            }
        }
    }
"@
    [ConsoleConfig]::DisableQuickEdit()
}
catch {
    Write-Host "注意：无法禁用快速编辑模式，请避免点击窗口以防止程序暂停" -ForegroundColor Yellow
}

# 用户配置区域
$targetProcessName = "cs2" #这里默认进程是cs2,如果想要检测其他的进程请替换！（后面不带.exe）
$launchBatPath = "" #这里填写你的服务器启动bat脚本文件路径
$updateScriptPath = "" #这里填写服务器更新脚本的路径，如果不需要更新功能可以留空
$checkInterval = 5
$maxRetry = 3

# 脚本运行参数
$lastCheck = [datetime]::Now
$retryCount = 0
$lastLaunchTime = $null

# 控制台颜色设置
$host.UI.RawUI.ForegroundColor = "White"
Clear-Host

Write-Host "=== CS2 服务器自动监控 ===" -ForegroundColor Cyan
Write-Host "监控程序: " -NoNewline; Write-Host $targetProcessName -ForegroundColor Yellow
Write-Host "启动脚本: " -NoNewline; Write-Host $launchBatPath -ForegroundColor Yellow
Write-Host "更新脚本: " -NoNewline; Write-Host $(if($updateScriptPath){"$updateScriptPath"}else{"未设置"}) -ForegroundColor Yellow
Write-Host "检查间隔: " -NoNewline; Write-Host "$checkInterval 秒" -ForegroundColor Yellow
Write-Host "最大重试: " -NoNewline; Write-Host $maxRetry -ForegroundColor Yellow
Write-Host "`n提示：关闭窗口即可停止监控`n" -ForegroundColor Cyan

function Update-Status {
    param($message, $color = "White")
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] " -NoNewline -ForegroundColor DarkGray
    Write-Host $message -ForegroundColor $color
}

function Test-TargetRunning {
    try {
        $process = Get-Process -Name $targetProcessName -ErrorAction Stop
        Write-Debug "检测到进程 $targetProcessName 正在运行"
        return $true
    }
    catch {
        Write-Debug "未检测到进程 $targetProcessName"
        return $false
    }
}

function Start-UpdateScript {
    param (
        [string]$scriptPath
    )
    try {
        if ([string]::IsNullOrEmpty($scriptPath)) {
            return $true
        }

        Update-Status "正在执行更新脚本..." "Yellow"
        $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$scriptPath`"" -WorkingDirectory (Split-Path $scriptPath -Parent) -WindowStyle Normal -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Update-Status "更新脚本执行完成" "Green"
            return $true
        } else {
            Update-Status "更新脚本执行失败" "Red"
            return $false
        }
    }
    catch {
        Update-Status "更新脚本执行异常: $_" "Red"
        return $false
    }
}

function Start-LauncherScript {
    try {
        # 先执行更新脚本
        if (-not (Start-UpdateScript -scriptPath $updateScriptPath)) {
            throw "更新脚本执行失败"
        }

        Update-Status "正在启动服务..." "Yellow"
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$launchBatPath`"" -WorkingDirectory (Split-Path $launchBatPath -Parent) -WindowStyle Minimized
        $script:lastLaunchTime = [datetime]::Now
        return $true
    }
    catch {
        return $false
    }
}

Update-Status "监控已启动..." "Green"

$lastProcessState = $false

while ($true) {
    $currentProcessState = Test-TargetRunning
    
    if ($currentProcessState -ne $lastProcessState) {
        if ($currentProcessState) {
            Update-Status "检测到目标程序已启动" "Green"
        } else {
            Update-Status "检测到目标程序已停止" "Yellow"
        }
        $lastProcessState = $currentProcessState
    }

    if ((-not $currentProcessState) -and ([datetime]::Now - $lastCheck).TotalSeconds -ge $checkInterval) {
        $isRunning = Test-TargetRunning
        
        if (-not $isRunning) {
            try {
                Update-Status "未检测到目标程序..." "Yellow"
                
                if ($lastLaunchTime -and (([datetime]::Now - $lastLaunchTime).TotalSeconds -lt 10)) {
                    Update-Status "重启冷却中..." "DarkYellow"
                    $lastCheck = [datetime]::Now
                    continue
                }

                if (Start-LauncherScript) {
                    Update-Status "启动脚本已触发" "Green"
                    $retryCount = 0
                    $lastCheck = [datetime]::Now.AddSeconds($checkInterval * 2)
                }
                else {
                    throw "启动失败"
                }
            }
            catch {
                $retryCount++
                Update-Status "启动失败 (重试 $retryCount/$maxRetry)" "Red"
                  if ($retryCount -ge $maxRetry) {
                    Update-Status "达到最大重试次数，停止监控" "Magenta"
                    exit 1
                }
            }
        }
        $lastCheck = [datetime]::Now
    }

    Start-Sleep -Milliseconds 300
}