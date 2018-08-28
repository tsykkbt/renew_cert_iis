@echo off
set url=https://www.example.com/pfx/
set passwd=password
set cn=*.example.com
set file1=fullchain.pfx
set file2=fullchain.live.pfx
set file3=iiscnfg.xml
set site=/lm/w3svc/1

setlocal ENABLEDELAYEDEXPANSION

echo * DownloadFile
wget %url%%file1% --no-check-certificate -N

echo * CheckFile
set timestamp1=
set timestamp2=
for %%a in (%file1%) do set timestamp1=%%~ta
for %%b in (%file2%) do set timestamp2=%%~tb
if "%timestamp1%" == "%timestamp2%" (
    echo Not Renew Cert
) else (
    if "%timestamp1%" gtr "%timestamp2%" (
        echo Renew Cert

        echo * Import Cert
        certutil -f -p %passwd% -importpfx %file1%
        copy %file1% %file2% > nul

        echo * SSL CertHash
        set n=0
        for /f "tokens=2,* usebackq" %%a in ( `certutil -store -v my %cn%^| findstr /c:"Cert ハッシュ(sha1)"` ) do (
          set CERTHASH[!n!]=%%b
          set /a n=n+1
        )
        set n=0
        for /f "tokens=1,2 usebackq" %%a in ( `certutil -store -v my %cn%^| findstr /c:"この日以前: "` ) do (
          set CERTDATE[!n!]=%%b
          set /a n=n+1
        )
        set n=0
        set t1=0000/00/00
        set t2=0000/00/00
        :BEGIN
        call set it=%%CERTDATE[!n!]%%
        if defined it (
          if !t1! leq !it! (
            set t2=!t1!
            set n2=!n1!
            set t1=!it!
            set n1=!n!
          ) else (
            if !t2! leq !it! (
              set t2=!it!
              set n2=!n!
            )
          )
          set /a n=n+1
          goto BEGIN
        )
        call set NEWHASH=%%CERTHASH[%n1%]: =%%
        call set OLDHASH=%%CERTHASH[%n2%]: =%%
        echo NEWHASH=%NEWHASH% [NotAfter: %t1%]
        echo OLDHASH=%OLDHASH% [NotAfter: %t2%]

        echo * Export Settings
        del /q %file3% 2> nul
        iiscnfg /export /f %file3% /sp %site% /inherited /children

        echo * Rewrite CertHash
        mfind /W /E8 /%OLDHASH%/%NEWHASH%/l %file3%

        echo * Import Setting
        iiscnfg /import /f %file3% /sp %site% /dp %site% /inherited /children
        del /q %file3% 2> nul

        echo * Restart IIS
        iisweb /start w3svc/1
        del %file2%
        copy %file1% %file2% > nul
    ) else (
        echo Not Renew Cert
    )
)
