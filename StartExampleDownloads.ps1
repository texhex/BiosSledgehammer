<#
 Start Example Downloads v1.06
 Copyright © 2015-2017 Michael 'Tex' Hex 
 Licensed under the Apache License, Version 2.0. 

 https://github.com/texhex/BiosSledgehammer
#>

#This script requires PowerShell 4.0 or higher 
#requires -version 4.0

#Require full level Administrator
#requires -runasadministrator

#Guard against common code errors
Set-StrictMode -version 2.0

#Terminate script on errors 
$ErrorActionPreference = 'Stop'

#Import Module with some helper functions
Import-Module $PSScriptRoot\MPSXM.psm1 -Force



function Get-UserConfirm()
{
#from https://social.technet.microsoft.com/Forums/scriptcenter/en-US/3d8f242b-199b-4d4c-b973-0246ce1c065c/windows-powershell-tip-of-the-week-is-there-an-easy-way-to-display-and-process-confirmation?forum=ITCG
#by Shay Levi (https://social.technet.microsoft.com/profile/shay%20levi)

$caption = "BIOS Sledgehammer: Start Example Downloads"
$message = "This script will download BIOS and TPM update files from HP.com required for the examples in \Models. Ready to start?"

$yes = new-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Start download"
$no = new-Object System.Management.Automation.Host.ChoiceDescription "&No","Do not download, stop script"

$choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no)
$answer = $host.ui.PromptForChoice($caption,$message,$choices,1)

switch ($answer)
    {
        0 
        {
            return $true
            break
        }

        1 
        {
            return $false
            break
        }
    }
}


function Test-FolderStructure()
{
 param(
  [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
  [ValidateNotNullOrEmpty()]
  [string]$SearchPath
)
    if ( -not (Test-DirectoryExists "$SearchPath\Models") )
    {
        throw New-Exception -DirectoryNotFound "Path [$SearchPath\Models] does not exist"
    }

    if ( -not (Test-DirectoryExists "$SearchPath\PwdFiles") )
    {
        throw New-Exception -DirectoryNotFound "Path [$SearchPath\PwdFiles] does not exist"
    }

    if ( -not (Test-FileExists "$SearchPath\BiosSledgehammer.ps1") )
    {
        throw New-Exception -FileNotFound "File [$SearchPath\BiosSledgehammer.ps1] does not exist"
    }

}

function Remove-FileIfExists()
{
param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$Path
)
    if ( Test-FileExists -Path $Path )
    {
        try
        {
            #we allow the system half a second...
            Start-Sleep -Milliseconds 500

            Remove-Item -Path "$Path" -Force
        }
        catch
        {
            #Sometimes this does not work because AV or backup software is to eager to scan the file
            write-warning "Unable to delete file [$Path] - $($Error[0])"
        }
    }
}


function Start-DownloadFile()
{
param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$URL,

    [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$DownloadPath
)
    $file=Get-FileName($URL)

    #Ensure the files does not exist
    $tempFile="$DownloadPath\$file"
    Remove-FileIfExists $tempFile

    $webClient=New-Object "Net.WebClient"

    write-host "  Downloading from [$URL]"
    write-host "                to [$tempFile]... " -NoNewline

    $webClient.DownloadFile($URL, $tempFile)

    $webClient=$null

    write-host "Done"

    return $tempFile
}


function Invoke-AcquireHPFile()
{
param(
    [Parameter (Mandatory=$true)]
    [ValidateSet("SoftPaq", "ReleaseNotes")]
    [string]$Type,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$URL,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationPath,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$DownloadPath
)

    if ( $Type -eq "SoftPaq" )
    {
        write-host "  SoftPaq URL: $URL" 
    }
    else
    {
        write-host "  Release Notes URL: $URL" 
    }

    $destFilename="$DestinationPath\$(Get-FileName($URL))"

    if ( Test-FileExists -Path $destFilename )
    {
        write-host "  File already exists"
    }
    else
    {
        $tempFile=Start-DownloadFile -URL $URL -DownloadPath $DownloadPath

        if ( $Type -eq "SoftPaq" )
        {
            $SPName=Get-FileName -Path $tempFile -WithoutExtension
            $SPName=$SPName.ToUpper()

            write-host "  Extracting SoftPaq... " -NoNewline
            &$tempFile -e -s     
            Start-Sleep -Seconds 2 #just to be sure, sometimes it requires some extra time
            write-host "Done"

            #We are expecting the file to be present in C:\SWSetup\SPxxxx
            $SPExtractedPath="$UNPACK_FOLDER\$SPName"
          
            if ( -not (Test-DirectoryExists -Path $SPExtractedPath) )
            {
                throw New-Exception -FileNotFound "Unable to locate unpack folder [$SPExtractedPath]"
            }
            else
            {
                #now we need to copy the unpacked files
                write-host "  Copy from [$SPExtractedPath] to [$destFolder]... " -NoNewline
                $ignored=Get-ChildItem -Path $SPExtractedPath | Copy-Item -Destination $destFolder -Recurse -Container -Force
                write-host "Done"

                #Remove extract folder - this will sometimes fail because of backup or AV tools
                try 
                {
                    $ignored=Remove-Item -Path $SPExtractedPath -Recurse -Force
                }
                catch
                {
                    write-warning "Unable to remove temp extraction folder [$SPExtractedPath] - $($Error[0])"
                }
            }
        }
        #copy SPXXXX to destination        
        #Copy-Item -Path $tempFile -Destination $DestinationPath -Force
        Copy-FileToDirectory -Filename $tempFile -Directory $DestinationPath

        Remove-FileIfExists -Path $tempFile
        write-host "  File processed successfully"
    }
}


function Invoke-DownloadSettingsProcess()
{
param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$SettingsFile,

    [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$DownloadPath
)

    #Set-Variable TEMP_DOWNLOAD_FOLDER "$(Get-TempFolder)\TempDownload" –option ReadOnly -Force

    $destFolder=Get-ContainingDirectory($SettingsFile)

    $settings=Read-StringHashtable $SettingsFile

    if ($settings.ContainsKey("NoteURL"))
    {        
        $URL=$settings["NoteURL"]
        $type="ReleaseNotes"

        Invoke-AcquireHPFile -Type $type -URL $URL -DestinationPath $destFolder -DownloadPath $DownloadPath
    }

    if ($settings.ContainsKey("SPaqURL"))
    {
        $URL=$settings["SPaqURL"]
        $type="SoftPaq"

        Invoke-AcquireHPFile -Type $type -URL $URL -DestinationPath $destFolder -DownloadPath $DownloadPath
    }

}

######################################################
##Start here


Set-Variable CHECK_FILENAME "$PSScriptRoot\BiosSledgehammer.ps1" –option ReadOnly -Force
Set-Variable TEMP_DOWNLOAD_FOLDER "$(Get-TempFolder)\TempDownload" –option ReadOnly -Force
Set-Variable UNPACK_FOLDER "C:\SWSetup" –option ReadOnly -Force


if ( Get-UserConfirm )
{
    $ignored=Test-FolderStructure -SearchPath $PSScriptRoot

    #ensure the temp downloads folder exists
    $ignored=New-Item -Path $TEMP_DOWNLOAD_FOLDER -ItemType Directory -Force

    #scan for SPDownload.txt files
    $Files=Get-ChildItem -Path $PSScriptRoot -Filter "SPDownload.txt" -Recurse
    foreach ($file in $Files)
    { 
      $curFile=$file.Fullname
      write-host "File [$curFile]"
 
      Invoke-DownloadSettingsProcess -SettingsFile $curFile -DownloadPath $TEMP_DOWNLOAD_FOLDER  
    }

    write-host "Cleaning up $UNPACK_FOLDER..."
    #check if the UNPACK_FOLDER exists and if it's empty. If so, delete it
    if ( Test-DirectoryExists $UNPACK_FOLDER )
    {
        $count=(Get-ChildItem -Path $UNPACK_FOLDER -Directory | Measure-Object).Count
       
        if ( $count -eq 0 )
        {
            #Folder is empty
            $ignored=Remove-Item -Path $UNPACK_FOLDER -Force
        }
    }

    write-host "Cleaning up $TEMP_DOWNLOAD_FOLDER..."
    #try to delete the temp folder
    try
    {
        $ignored=Remove-Item -Path $TEMP_DOWNLOAD_FOLDER -Force -Recurse -Confirm:$false
    }
    catch
    {
        Write-Warning "Unable to delete folder [$TEMP_DOWNLOAD_FOLDER] - $($Error[0])"
    }
}

write-host "Script finished!"

