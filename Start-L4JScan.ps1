function Start-L4JScan {

    $javaInstalled = ((Get-ItemProperty 'C:\Program Files\*').Name -match "Java").length -gt 0

    if ($javaInstalled) {

        #Check if script is running as admin
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (!$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Host "`n`n**You should run this script as administrator to ensure the L4J detector can access all paths**`n`n"
            $privEsclRequested = (Read-Host "Would you like to attempt automatic priv-escl?")

            if (($privEsclRequested -match "yes") -or ($privEsclRequested -match "y")) {
                Start-Process powershell.exe -Verb "RunAs" -ArgumentList "-command cd '$PWD'; .\Start-L4JScan.ps1"
                exit
            }
        }

    $paths = @()
    do {
        $userInput = (Read-Host "Enter paths to scan one at a time (leave blank and hit enter when done)")
        if ($userInput -ne '') {$paths += $userInput}
    }
    until ($userInput -eq '')


        Write-Host -NoNewline "File to output to?: "
        $outFile = Read-Host

        java -jar .\log4j-detector-latest.jar $paths 2>&1 | Tee-Object -FilePath $outFile
    } 

    if (!$javaInstalled) {
            
            Write-Host "Java doesn't appear to be installed on this system.`nWould you like to install it?(type 'skip' to try to run L4J scanner anyway): " -NoNewline
            $yn = Read-Host 

            if (($yn -match 'yes') -or ($yn -match 'y')) {
                Write-Host "Installing JDK 17...`nPress enter to continue once the installer is finished."
                msiexec.exe /passive /i jdk-17_windows-x64_bin.msi
                Read-Host
                $javaInstalled = ((Get-ItemProperty 'C:\Program Files\*').Name -match "Java").length -gt 0
                if ($javaInstalled) {

                    Write-Host "Install complete. Press enter to close powershell and re-run this script"
                    Read-Host
                    Start-Process powershell.exe -ArgumentList "-command cd '$PWD'; .\Start-L4JScan.ps1"
                    exit
                    
                } else {
                    Write-Host "Automatic JDK install failed, try again manually using the .msi installer included.`nThis script will now terminate"
                    Start-Sleep -Seconds 5
                    exit
                }

            } elseif ($yn -match 'skip') { 
                
                $paths = @()
                do {
                    $userInput = (Read-Host "Enter paths to scan one at a time (leave blank and hit enter when done)")
                    if ($userInput -ne '') {$paths += $userInput}
                }
                until ($userInput -eq '')
                
                Write-Host -NoNewline "File to output to?: "
                $outFile = Read-Host

                java -jar .\log4j-detector-latest.jar $paths 2>&1 | Tee-Object -FilePath $outFile
            }
        }

}

function prerequsiteCheck {
    
    $preReq_JavaMsi = (Test-Path -Path .\jdk-17_windows-x64_bin.msi -PathType Leaf)

    $preReq_l4jDetector = (Test-Path -Path .\log4j-detector-latest.jar -PathType Leaf)
    if ($preReq_JavaMsi -and $preReq_l4jDetector) {

        Start-L4JScan
    } elseif (($preReq_JavaMsi -and !$preReq_l4jDetector) -or (!$preReq_JavaMsi -and !$preReq_l4jDetector)) {
        $downloadl4jJar = (Read-Host "Log4J Detector .jar is missing from local path, Would you like to attempt to download it?")

        if (($downloadl4jJar -match 'y') -or ($downloadl4jJar -match 'yes')) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile("https://github.com/mergebase/log4j-detector/raw/master/log4j-detector-latest.jar",".\log4j-detector-latest.jar")
            if (Test-Path .\log4j-detector-latest.jar) {
                Write-Output "Download Complete. Restarting Script"
                prerequsiteCheck
            } 
        } else {
            Write-Output "This script requires log4j Detector to function`nScript will now terminate"
            Start-Sleep -Seconds 5
            Exit
        } 
    } elseif (!$preReq_JavaMsi -and $preReq_l4jDetector) {
        $downloadJDK = (Read-Host "JDK .msi not detected in local path`nWould you like to attempt to download it or continue without it?`n(Type 'y' to download or 'skip' to continue without downloading)")
        if (($downloadJDK -match 'y') -or ($downloadJDK -match 'yes')) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            $wc = New-Object System.Net.WebClient
            Write-Output "Downloading File..."
            $wc.DownloadFile("https://download.oracle.com/java/17/archive/jdk-17.0.1_windows-x64_bin.msi",".\jdk-17_windows-x64_bin.msi")
            if (Test-Path .\jdk-17_windows-x64_bin.msi) {
                Write-Output "Download Complete. Restarting Script"
                prerequsiteCheck
            }
        } elseif ($downloadJDK -match 'skip') {
            Start-L4JScan
            Exit
        } else {
            Write-Output "Script will now terminate"
            Start-Sleep -Seconds 5
            Exit 
        }
    } 
}

prerequsiteCheck
