@echo off
set url=https://www.example.com/pfx/
set passwd=password
set file1=fullchain.pfx
set file2=fullchain.live.pfx
set cn=*.example.com

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
        for /f "tokens=2,* usebackq" %%a in ( `certutil -store my %cn%^| findstr /c:"Cert ハッシュ(sha1)"` ) do (
          set CERTHASH[!n!]=%%b
          set /a n=n+1
        )
        set n=0
        for /f "tokens=1,2 usebackq" %%a in ( `certutil -store my %cn%^| findstr /c:"この日以前: "` ) do (
          set CERTDATE[!n!]=%%b
          set /a n=n+1
        )
        set n=0
        set t1=0000/00/00
        set t2=0000/00/00
        :BEGIN
        call set dt=%%CERTDATE[!n!]%%
        if defined dt (
          if !t1! leq !dt! (
            set t2=!t1!
            set n2=!n1!
            set t1=!dt!
            set n1=!n!
          ) else (
            if !t2! leq !dt! (
              set t2=!dt!
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

        echo * Rewrite CertHash
        %SystemRoot%\System32\inetsrv\appcmd.exe renew binding /oldcert:%OLDHASH% /newcert:%NEWHASH%
        echo Update done
    ) else (
        echo Not Renew Cert
    )
)
