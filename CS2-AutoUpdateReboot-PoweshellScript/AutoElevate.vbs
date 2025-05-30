Set objShell = CreateObject("Shell.Application")
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objFile = objFSO.GetFile(WScript.ScriptFullName)
strPath = objFSO.GetParentFolderName(objFile.Path)
objShell.ShellExecute "cmd.exe", "/c """ & strPath & "\启动监控.cmd""", "", "runas", 1
