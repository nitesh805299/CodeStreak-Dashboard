Option Explicit

Dim shell, scriptPath, command

Set shell = CreateObject("WScript.Shell")
scriptPath = Replace(WScript.ScriptFullName, "refresh-all-hidden.vbs", "refresh-all.ps1")

command = "powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptPath & """ -BackgroundWorker"
shell.Run command, 0, False
