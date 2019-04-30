reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoConfigURL /t REG_SZ /d "http://webproxy.wlb2.nam.nsroot.net:8080/" /f 
ping -n 1 1.1.1.1 
start /d "C:\Program Files (x86)\Internet Explorer" iexplore.exe http://gdir.nam.nsroot.net/Globaldir_New/GDIR_Result_Detail.aspx?webGEID=1000387852
ping -n 3 1.1.1.1
