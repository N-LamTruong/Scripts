Set objShell = WScript.CreateObject("WScript.Shell")

Do
    objShell.Run "cmd /c C:\Users\nguye\Desktop\Network.bat", 0, False
    WScript.Sleep(300000) ' Độ trễ 5p (300000 milliseconds)
Loop