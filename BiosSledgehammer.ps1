<#
 BIOS Sledgehammer
 Copyright (c) 2015-2019 Michael 'Tex' Hex 
 Licensed under the Apache License, Version 2.0. 

 https://github.com/texhex/BiosSledgehammer
#>

# Activate verbose output:
# .\BiosSledgehammer.ps1 -Verbose

# Wait 30 seconds at the end of the script
# .\BiosSledgehammer.ps1 -WaitAtEnd

# Activate UEFI Boot mode for the current model (for MBR2GPT.exe)
# .\BiosSledgehammer.ps1 -ActivateUEFIBoot

[CmdletBinding()]
param(
    [Parameter(Mandatory = $False)]
    [switch]$WaitAtEnd = $False,

    [Parameter(Mandatory = $False)]
    [switch]$ActivateUEFIBoot = $False
)


#Script version
$scriptversion = "6.0.1-BETA"

#This script requires PowerShell 4.0 or higher 
#requires -version 4.0

#Guard against common code errors
Set-StrictMode -version 2.0

#Require full level Administrator
#requires -runasadministrator

#Import Module with some helper functions
Import-Module $PSScriptRoot\MPSXM.psm1 -Force

#Verbose output in case the script dies early
Write-Verbose "BIOS Sledgehammer $scriptVersion starting"

#----- ACTIVATE DEBUG MODE WHEN RUNNING IN ISE -----
$DebugMode = Test-RunningInEditor
if ( $DebugMode )
{
    $VerbosePreference_BeforeStart = $VerbosePreference
    $VerbosePreference = "Continue"
    Clear-Host
}
#----DEBUG----

#Log the output and ensure this function also writes verbose output if it's activated
Start-TranscriptTaskSequence -NewLog -Verbose:$VerbosePreference


#This banner was taken from http://chris.com/ascii/index.php?art=objects/tools
#region BANNER
$banner = @"

            _
    jgs   ./ |   
         /  /    BIOS Sledgehammer Version @@VERSION@@
       /'  /     Copyright (c) 2015-2019 Michael 'Tex' Hex
      /   /      
     /    \      https://github.com/texhex/BiosSledgehammer
    |      ``\   
    |        |                                ___________________
    |        |___________________...-------'''- - -  =- - =  - = ``.
   /|        |                   \-  =  = -  -= - =  - =-   =  - =|
  ( |        |                    |= -= - = - = - = - =--= = - = =|
   \|        |___________________/- = - -= =_- =_-=_- -=_=-=_=_= -|
    |        |                   ``````-------...___________________.'
    |________|   
      \    /     This is *NOT* sponsored/endorsed by HP or Intel.  
      |    |     This is *NOT* an official HP or Intel tool.
    ,-'    ``-,   
    |        |   Use at your own risk.
    ``--------'   
"@
#endregion

#Show banner
$banner = $banner -replace "@@VERSION@@", $scriptversion
Write-Host $banner


#Configure with temp folder to use
Set-Variable TEMP_FOLDER (Get-TempFolder) -option ReadOnly -Force
#When using a different folder, do not use a trailing backslash ("\")
#Set-Variable TEMP_FOLDER "C:\TEMP" -option ReadOnly -Force

#Configure which BCU version to use 
Set-Variable BCU_EXE_SOURCE "$PSScriptRoot\BCU-4.0.26.1\BiosConfigUtility64.exe" -option ReadOnly -Force
#for testing if the arguments are correctly sent to BCU
#Set-Variable BCU_EXE "$PSScriptRoot\BCU-4.0.24.1\EchoArgs.exe" -option ReadOnly -Force

#For performance issues (AV software that keeps scanning EXEs from network) we copy BCU locally
#The file will be deleted when the script finishes
Set-Variable BCU_EXE "" -Force

#Configute which ISA00075 version to use
Set-Variable ISA75DT_EXE_SOURCE "$PSScriptRoot\ISA75DT-1.0.3.215\Intel-SA-00075-console.exe" -option ReadOnly -Force

#Path to password files (need to have the extension *.bin)
Set-Variable PWDFILES_PATH "$PSScriptRoot\PwdFiles" -option ReadOnly -Force

#Will store the currently used password file (copied locally)
#The file will be deleted when the script finishes
Set-Variable CurrentPasswordFile "" -Force

#Path to model files
Set-Variable MODELS_PATH "$PSScriptRoot\Models" -option ReadOnly -Force

#Path to shared files
Set-Variable SHARED_PATH "$PSScriptRoot\Shared" -option ReadOnly -Force


#Common exit codes
Set-Variable ERROR_SUCCESS_REBOOT_REQUIRED 3010 -option ReadOnly -Force
Set-Variable ERROR_RETURN 666 -option ReadOnly -Force




function Test-Environment()
{
    Write-Host "Verifying environment..." -NoNewline

    try
    {
        if ( -not (OperatingSystemBitness -Is64bit) ) 
        {
            throw "A 64-bit Windows is required"
        }

        if ( (Get-CurrentProcessBitness -IsWoW) )
        {
            throw  "This can not be run as a WoW (32-bit on 64-bit) process"
        }

        if ( -not (Test-FileExists $BCU_EXE_SOURCE) ) 
        {
            throw "BiosConfigUtility [$BCU_EXE_SOURCE] not found"
        }

        if ( -not (Test-DirectoryExists $PWDFILES_PATH) ) 
        {
            throw "Folder for password files [$PWDFILES_PATH] not found"
        }

        if ( -not (Test-DirectoryExists $MODELS_PATH) )
        {
            throw "Folder for model specific files [$MODELS_PATH] not found"
        }

        if ( -not (Test-DirectoryExists $SHARED_PATH) )
        {
            throw "Folder for shared files [$SHARED_PATH] not found"
        }

        if ( -not (Test-DirectoryExists $TEMP_FOLDER) )
        {
            throw "TEMP folder [$TEMP_FOLDER] not found"
        }

        $Make = (Get-CimInstance Win32_ComputerSystem -OperationTimeoutSec 10).Manufacturer
        
        if ( (Test-String $Make -StartsWith "HP") -or (Test-String $Make -StartsWith "Hewlett") )
        {
            #All seems to be fine
        }
        else
        {
            throw "Unsupported manufacturer [$Make]"
        }                                                                    

        Write-Host "  Success"

        return $true
        
    }
    catch
    {
        Write-Host "  Failed!"
        throw $_
    }

}


function Test-BiosCommunication()
{  
    Write-Host "Verifying BIOS Configuration Utility (BCU) can communicate with BIOS." 

    Write-Host "  Trying to read Universally Unique Identifier (UUID)..." -NoNewline

    #Most models use "Universally Unique Identifier (UUID)"  
    #At least the ProDesk 600 G1 uses the name "Enter UUID"  
    #Raynorpat (https://github.com/raynorpat): My 8560p here uses "Universal Unique Identifier(UUID)", not sure about other older models...
    $UUIDNames = @("Universally Unique Identifier (UUID)", "Enter UUID", "Universal Unique Identifier(UUID)")
  
    if ( (Test-BiosValueRead $UUIDNames) )
    {
        Write-Host "  Success"
        return $true
    }
    else
    {
        Write-Host "  Failed."

        #Some revision of older models (e.g. 8x0 G1) might have a BIOS bug. 
        #In these cases, BCU never returns UUID, although everything else works fine. 
        #We try to read "Serial Number" or "S/N" in these cases

        Write-Host "  Trying to read Serial Number (S/N)..." -NoNewline
       
        $SNNames = @("Serial Number", "S/N")
       
        if ( (Test-BiosValueRead $SNNames) )
        {
            Write-Host "  Success"
            return $true
        }
        else
        {
            Write-Host "  Failed."
            throw "BCU is unable to communicate with BIOS, can't continue."
        }
    }

}

function Test-BiosValueRead()
{
    #Returns TRUE if any of the given BIOS values return something useful (something else than an empty string)
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ValueNames
    )
    $result = $false

    #Remove -Silent in order to see what this command does
    $testvalue = Get-BiosValue -Names $ValueNames -Silent
    
    if ( -not (Test-String -IsNullOrWhiteSpace $testvalue) ) 
    {
        $result = $true
    }

    return $result
}

function Test-BiosValueSupported()
{
    #Retruns TRUE if the given value is supported by the BIOS
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$ValueName
    )
    $testvalue = $null
    
    #Remove -Silent in order to see what this command does
    $testvalue = Get-BiosValue -Name $ValueName -Silent
    
    if ( $null -eq $testvalue ) 
    {
        $result = $false
    }
    else
    {
        $result = $true
    }

    return $result
}


function Get-ModelFolder()
{
    param(
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$ModelsFolder
    )   

    $compSystem = Get-CimInstance Win32_ComputerSystem -OperationTimeoutSec 10    
    
    $Model = Get-PropertyValueSafe $compSystem "Model" ""
    $SKU = Get-PropertyValueSafe $compSystem "SystemSKUNumber" ""

    Write-HostSection "Locate Model Folder"
    Write-Host "Searching [$ModelsFolder]"
    
    if ( Test-String -HasData $SKU )
    {
        Write-Host "  for SKU [$SKU] or [$Model]..."
    }
    else
    {
        Write-Host "      for [$Model]..."    
    }
    
    $result = $null

    #get all folders
    $folders = Get-ChildItem -Path $ModelsFolder -Directory -Force

    #Try is to locate a folder matching the SKU number
    if ( Test-String -HasData $SKU )
    {
        Write-Host "  Searching for SKU folder..."
        foreach ($folder in $folders) 
        {
            $name = $folder.Name.ToUpper()
    
            if ( $name -eq $SKU.ToUpper() )
            {
                $result = $folder.FullName
                Write-Host "    Matching folder: [$result]"
                break
            }
        }
        if ( $null -eq $result ) { Write-Host "    No folder found" }
    }
        
    #Try is to locate a folder matching EXACTLY the model name  
    if ( $null -eq $result )
    {
        Write-Host "  Searching for exactly matching folder for this model..."
        foreach ($folder in $folders) 
        {
            $name = $folder.Name.ToUpper()

            if ( $name -eq $Model.ToUpper() )
            {
                $result = $folder.FullName
                Write-Host "    Matching folder: [$result]"
                break
            }
        }
        if ( $null -eq $result ) { Write-Host "    No folder found" }
    }

    #Try a partitial model name search
    if ( $null -eq $result )
    {
        Write-Host "  Searching for partially matching folder..."
     
        foreach ($folder in $folders) 
        {
            $name = $folder.Name
        
            if ( Test-String $Model -Contains $name )
            {
                $result = $folder.FullName
                Write-Host "    Matching folder: [$result]"
                break
            }
        }
    }
    if ( $null -eq $result ) { Write-Host "    No folder found" }


    if ( $null -ne $result )
    {
        Write-Host "Model folder is [$result]"
    }
    else
    {
        throw "A matching model folder was not found in [$ModelsFolder]. This model [$Model] (SKU $SKU) is not supported by BIOS Sledgehammer."
    }

    Write-HostSection -End "Model Folder"
    return $result
}


function Get-ModelSettingsFile()
{
    param(
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$ModelFolder,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Name        
    )   

    $fileName = $null

    #First check for a direct file
    $checkFile = "$($ModelFolder)\$($Name)"
    Write-Host "Reading settings from [$checkFile]..."
    
    if ( Test-FileExists $checkFile ) 
    {
        #File found, use it
        $fileName = $checkFile
    }
    else
    {
        #Not found, check if a shared file exists
        $sharedFileName = "Shared-$($Name)"
        $checkFile = "$($ModelFolder)\$($sharedFileName)"

        Write-Host "Not found, looking for shared file [$sharedFilename] in same directory..."

        if ( Test-FileExists $checkFile ) 
        {            
            #Shared file exists, try to read it to get the folder name
            Write-Host "  Shared file found"
            $settings = Read-StringHashtable $checkFile

            if ( -not ($settings.ContainsKey("Directory")) )
            {
                throw "Shared file [$checkFile] is missing Directory setting"
            }
            else
            {
                $checkPath = Join-Path -Path $SHARED_PATH -ChildPath $settings.Directory

                if ( -not (Test-DirectoryExists $checkPath) )
                {
                    throw "Directory [$checkPath] specified in [$checkFile] does not exist"
                }                   
                else
                {
                    #Given folder exists, does the file also exist?
                    $checkFile = Join-Path -Path $checkPath -ChildPath $Name

                    if ( -not (Test-FileExists $checkFile) ) 
                    {
                        throw "Settings file [$Name] not found in shared directory [$checkPath]"
                    }
                    else
                    {
                        Write-Host "Using settings from [$checkFile]"
                        $FileName = $checkFile                        
                    }
                    
                }
            }

        }
        else
        {
            #Shared file does also not exist
            $fileName = $null
        }        
    }

    if ( $null -eq $fileName )
    {
        Write-Host "No settings file was found"
    }

    return $fileName
}


function Get-UpdateFolder()
{
    param(
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$SettingsFilePath,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Name             
    )   

    $baseFolder = Get-ContainingDirectory -Path $SettingsFilePath
    
    $folder = Join-Path -Path $baseFolder -ChildPath $Name

    if ( Test-DirectoryExists $folder )
    {
        return $folder
    }
    else
    {
        throw "Folder [$folder] does not exist"
    }

}



function ConvertTo-DescriptionFromBCUReturncode()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Errorcode
    )
 
    $Errorcode = $Errorcode.Trim()
 
    #I should cache this. 
    $lookup =
    @{ 
        "0" = "Success"; "1" = "Not Supported"; "2" = "Unknown"; "3" = "Timeout"; "4" = "Failed"; "5" = "Invalid Parameter"; "6" = "Access Denied";
        "10" = "Valid password not provided"; "11" = "Config file not valid"; "12" = "First line in config file is not the BIOSConfig";
        "13" = "Failed to change setting"; "14" = "BCU not ready to write file."; "15" = "Command line syntax error."; "16" = "Unable to write to file or system";
        "17" = "Help is invoked"; "18" = "Setting is unchanged"; "19" = "Setting is read-only"; "20" = "Invalid setting name"; "21" = "Invalid setting value";
        "23" = "Unable to connect to HP BIOS WMI namespace"; "24" = "Unable to connect to HP WMI namespace."; "25" = "Unable to connect to PUBLIC WMI namespace";
        "30" = "Password file error"; "31" = "Password is not F10 compatible"; "32" = "Platform does not support Unicode passwords"; "33" = "No settings to apply found in Config file"; 

        "32769" = "Extended error";
    }

    if ( $lookup.ContainsKey("$ErrorCode") )
    {
        $result = $lookup[$ErrorCode]
    }
    else
    {
        $result = "Undocumented error code"
    }

    return $result
}


function ConvertTo-ResultFromBCUOutput()
{
    param(
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$BCUOutput
    )

    $props = @{"Returncode" = [int]-1; "ReturncodeText" = [string]"Unknown"; "Changestatus" = [string]"Unknown"; "Message" = [string]"Unknown" }
    $result = New-Object -TypeName PSObject -Property $props

    Write-Verbose "=== BCU Result ==============================="
    Write-Verbose $BCUOutput.Trim()
    Write-Verbose "=============================================="

    try
    {
        [xml]$xml = $BCUOutput

        $info_node = Select-Xml "//Information" $xml
        $setting_node = Select-Xml "//SETTING" $xml
        $error_node = Select-Xml "//ERROR" $xml
        $success_node = Select-Xml "//SUCCESS" $xml

        #For password changes, the return value needs to be pulled from the Information node.
        #If we also have a setting node, this will overwrite this anyway.
        if ( $null -ne $info_node ) 
        {
            $result.Returncode = [string]$xml.BIOSCONFIG.Information.translated
        }  

        #Try to get the data from the SETTING node
        if ( $null -ne $setting_node ) 
        {        
            #This should be zero to indicate everything is OK
            $result.Returncode = [string]$xml.BIOSCONFIG.SETTING.returnCode
            $result.Changestatus = [string]$xml.BIOSCONFIG.SETTING.changeStatus
            $result.Message = "OK"
        }
     
        #if there is an error node, we get the message from there
        if ( $null -ne $error_node ) 
        {
            #The error message is in the first error node
            $result.Message = [string]$error_node[0].Node.Attributes["msg"].'#text'
         
            #The error code is inside the LAST error node
            $result.Returncode = [string]$error_node[$error_node.Count - 1].Node.Attributes["real"].'#text'
        }
        else
        {
            #If no ERROR node exists, we can check for SUCCESS Nodes
            if ( $null -ne $success_node ) 
            {          
                #Check if this a single node or a list of nodes
                try 
                {
                    $success_node_count = $success_node.Count
                }
                catch 
                {
                    $success_node_count = 0
                }
            
                #If we have more than one node, use the last SUCCESS node
                if ( $success_node_count -gt 0 ) 
                {
                    #the message is in the last SUCCESS node
                    $result.Message = [string]$success_node[$success_node.Count - 1].Node.Attributes["msg"].'#text'
                }
                else
                {
                    #single node
                    $result.Message = [string]$success_node.Node.Attributes["msg"].'#text'
                }
            }
        }

    }
    catch
    {
        throw "Error trying to parse BCU output: $($error[0])"
    }

    #Try to get something meaningful from the return code
    $result.ReturncodeText = ConvertTo-DescriptionFromBCUReturncode $result.Returncode

    return $result
}


function Get-BiosValue()
{
    param(
        [Parameter(Mandatory = $True, ParameterSetName = "SingleValue")]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $True, ParameterSetName = "NameArray")]
        [array]$Names,

        [Parameter(Mandatory = $False, ParameterSetName = "SingleValue")]
        [Parameter(Mandatory = $False, ParameterSetName = "NameArray")]
        [switch]$Silent = $False
    )

    $result = $null

    switch ($PsCmdlet.ParameterSetName)
    {  
        "SingleValue"
        {
            if (-not ($Silent)) { Write-Host "Reading BIOS setting [$Name]..." }

            try
            {
                #Try to get a single value

                #Starting with BCU 4.0.21.1, a call to /GetValue will cause BCU to write a 
                #single text file with the name of the setting to the current working directory. 
                #We change the current directory to TEMP to avoid any issues.
                $previousLocation = Get-Location         
                Set-Location $($TEMP_FOLDER) | Out-Null
         
                $output = &$BCU_EXE /GetValue:""$Name"" | Out-String

                Set-Location $previousLocation -ErrorAction SilentlyContinue | Out-Null

         
                Write-Verbose "Read BIOS value: Result from BCU ============="
                Write-Verbose $output.Trim()
                Write-Verbose "=============================================="

                [xml]$xml = $output
     
                #This is the actual value
                $result = $xml.BIOSCONFIG.SETTING.VALUE.InnerText

                #This should be zero to indicate everything is OK
                $returncode = $xml.BIOSCONFIG.SETTING.returnCode

                Write-Verbose "Value: $result"
                Write-Verbose "Return code: $returncode"

                if ($returncode -ne 0) 
                {
                    if (-not ($Silent)) { Write-Host "    Get-BiosValue failed. Return code was $returncode" }
                    $result = $null
                }
                else
                {
                    if (-not ($Silent)) { Write-Host "    Setting read: [$result]" }
                }
            }
            catch
            {
                if ( $Silent ) 
                { 
                    #even if we are silent, we will at least write the information with verbose
                    Write-Verbose "    Get-BiosValue failed! Error:" 
                    Write-Verbose $error[0] 
                }
                else
                {
                    Write-Host "    Get-BiosValue failed! Error:" 
                    Write-Host $error[0] 
                }
                $result = $null
            }
        }

        "NameArray"
        {
            Write-Verbose "Reading BIOS setting using different setting names"

            $result = $null

            foreach ($Name in $Names)
            {
                Write-Verbose "   Trying using setting name [$Name]..."
        
                $value = Get-BiosValue -Name $Name -Silent:$Silent

                if ( $null -ne $value ) 
                {
                    #We have a result
                    $result = $value
                    break
                }
            }
      
        }

    }
 
    return $result
}


function Set-BiosPassword()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $False)]
        [ValidateNotNullOrEmpty()]
        [string]$ModelFolder,
  
        [Parameter(Mandatory = $True, ValueFromPipeline = $False)]
        [ValidateNotNullOrEmpty()]
        [string]$PwdFilesFolder,

        [Parameter(Mandatory = $False, ValueFromPipeline = $False)]
        [string]$CurrentPasswordFile = ""
    )

    $result = $null
    
    Write-HostSection -Start "Set BIOS Password"

    $settingsFile = Get-ModelSettingsFile -ModelFolder $ModelFolder -Name "BIOS-Password.txt"
     
    if ( $settingsFile -ne $null ) 
    {
        $settings = Read-StringHashtable $settingsFile

        if ( -not ($settings.ContainsKey("PasswordFile")) ) 
        {
            throw "Configuration file is missing [PasswordFile] setting"
        }
        
        $newPasswordFile = $settings["PasswordFile"]
        $newPasswordFile_FullPath = ""
        $newPasswordFile_Exists = $false

        #check if the file exists, given that it is not empty
        if ( $newPasswordFile -ne "")
        {
            $newPasswordFile_FullPath = "$PwdFilesFolder\$newPasswordFile"

            if ( Test-FileExists $newPasswordFile_FullPath )
            {
                $newPasswordFile_Exists = $true   
            }
            else
            {
                throw "New password file [$newPasswordFile_FullPath] does not exist"
            }
        }
        else
        {
            #if the new password is empty it automatically "exists"
            $newPasswordFile_Exists = $true
        }


        if ( $newPasswordFile_Exists ) 
        {
            Write-Host " Desired password file is [$newPasswordFile_FullPath]" 
         
            $noChangeRequired = $false

            #Check if there is the special case that the computer is using no password and this is also requested
            if ( $CurrentPasswordFile -eq $newPasswordFile )
            {
                $noChangeRequired = $True
            }
            else
            {
                #now we need to split the parameter to their file name
                $filenameOnly_Current = ""
                if ( $CurrentPasswordFile -ne "" )
                {
                    $filenameOnly_Current = Split-Path -Leaf $CurrentPasswordFile
                }

                $filenameOnly_New = ""
                if ( $newPasswordFile -ne "" )
                {
                    $filenameOnly_New = Split-Path -Leaf $newPasswordFile
                }
         
                #if the filenames match, no change is required
                if ( $filenameOnly_Current.ToLower() -eq $filenameOnly_New.ToLower() )
                {
                    $noChangeRequired = $True
                }
                else
                {
                    #Passwords do not match, we need to change them
                    $noChangeRequired = $False

                    Write-Host " Changing password using password file [$CurrentPasswordFile]..." 

                    if ( Test-String -HasData $CurrentPasswordFile )
                    {
                        #BCU expects an empty string if the password should be set to empty, so we use the parameter directly
                        $output = &$BCU_EXE /nspwdfile:""$newPasswordFile_FullPath"" /cspwdfile:""$CurrentPasswordFile"" | Out-String
                    }
                    else
                    {
                        #Currently using an empty password
                        $output = &$BCU_EXE /nspwdfile:""$newPasswordFile_FullPath"" | Out-String
                    }

                    #Let this function figure out what this means     
                    $bcuResult = ConvertTo-ResultFromBCUOutput $output
     
                    Write-Verbose "  Message: $($bcuResult.Message)"
                    Write-Verbose "  Return code: $($bcuResult.Returncode)"
                    Write-Verbose "  Return code text: $($bcuResult.ReturncodeText)"

                    if ( $bcuResult.Returncode -eq 0 ) 
                    {
                        Write-Host "Password was changed"
                        $result = $newPasswordFile_FullPath
                    }
                    else
                    {
                        Write-Warning "   Changing BIOS password failed with message: $($bcuResult.Message)" 
                        Write-Warning "   BCU return code [$($bcuResult.Returncode)]: $($bcuResult.ReturncodeText)" 
                    }

                    #all done

                }
            }

            if ( $noChangeRequired )
            {
                Write-Host "BIOS is already set to configured password file, no change required."
            }
        } #new password file exists           
        
    }
   
    Write-HostSection -End "Set BIOS Password"
    return $result
}

	  
function Set-BiosValue()
{
    #Returns: -1 = Error, 0 = OK, was already set, 1 = Setting changed
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$name,

        [Parameter(Mandatory = $false, ValueFromPipeline = $True)]  
        [string]$value = "",

        [Parameter(Mandatory = $False, ValueFromPipeline = $True)]
        [string]$PasswordFile = "",

        [Parameter(Mandatory = $False, ValueFromPipeline = $True)]
        [switch]$Silent = $False
    )

    $result = -1

    #check for replacement values
    #if ( ($value.Contains("@@COMPUTERNAME@@")) ) 
    if ( Test-String $value -Contains "@@COMPUTERNAME@@" )
    {
        $value = $value -replace "@@COMPUTERNAME@@", $env:computername
        if (-Not $Silent) { Write-Host " Update BIOS setting [$name] to [$value] (replaced)..." -NoNewline }
    }
    else
    {
        #no replacement
        if (-Not $Silent) { Write-Host " Update BIOS setting [$name] to [$value]..." -NoNewline }
    }
 
    #If verbose output is activated, this line will make sure that the next call to write-verbose will be on a new line
    Write-Verbose " "
  

    #Reading a value is way faster then setting it, so we should try to read the value first.
    #However, Get-BIOSValue for settings that can have several option (e.g. Enable/Disable),
    #BCU returns something like "Disable, *Enable" where the * stands for the current value.
    #I habe no idea if we can rework the parsing of Get-BiosValue without risking to break something
    #Hence, right now we set each value directly.
    #
    #$curvalue=Get-BiosValue -name $name -Silent
 
    try
    {
        #IMPORTANT! HP expects a single argument for /setvalue, but also a ",".
        #This "," causes PowerShell to put the value into the NEXT argument!
        #Therefore it must be escapced using "`,".
        if ( Test-String -IsNullOrWhiteSpace $passwordfile )
        {          
            #No password defined
            Write-Verbose "   Will not use a password file" 
            $output = &$BCU_EXE /setvalue:"$name"`,"$value" | Out-String
        }
        else
        {        
          
            Write-Verbose "   Using password file $passwordfile" 
            $output = &$BCU_EXE /setvalue:"$name"`,"$value" /cpwdfile:"$passwordFile" | Out-String 
        }

        #Get a parsed result
        $bcuResult = ConvertTo-ResultFromBCUOutput $output
     
        Write-Verbose "   Message: $($bcuResult.Message)"
        Write-Verbose "   Change status: $($bcuResult.Changestatus)"
        Write-Verbose "   Return code: $($bcuResult.Returncode)"
        Write-Verbose "   Return code text: $($bcuResult.ReturncodeText)"

        if ( ($bcuResult.Returncode -eq 18) -and ($bcuResult.Message = "skip") ) 
        {
            if (-Not $Silent) { Write-Host "  Done (was already set)" }
            $result = 0
        } 
        else 
        {        
            if ($bcuResult.Returncode -eq 0) 
            {
                if (-Not $Silent) { Write-Host "  Done" }
                $result = 1
            }
            else
            {
                if (-Not $Silent) 
                {
                    Write-Host " " #to create a new line
                    Write-Warning "   Update BIOS setting failed with status [$($bcuResult.Changestatus)]: $($bcuResult.Message)" 
                    Write-Warning "   Return code [$($bcuResult.Returncode)]: $($bcuResult.ReturncodeText)" 
                }

                $result = -1
            }
        }    
    }
    catch
    {
        #this should never happen
        Write-Host " " #to create a new line
        throw "Update BIOS setting fatal error: $($error[0])"
        $result = -1
    }
 
    return $result
}


function Set-BiosValuesByDictionary()
{
    #Returns: -1 = Error, 0 = OK but no changes, 1 = at least one setting was changed
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        $Dictionary,

        [Parameter(Mandatory = $False, ValueFromPipeline = $True)]
        [string]$Passwordfile = ""
    )

    $result = 0

    foreach ($entry in $Dictionary.Keys) 
    {
        $name = $Entry.ToString()
        $value = $Dictionary[$Name]
        $changed = Set-BiosValue -name $name -value $value -passwordfile $Passwordfile
     
        #Because the data in the Dictionary are specifc for a model, we expect that each and every change works
        if ( ($changed -lt 0) ) 
        {
            throw "Changing BIOS Setting [$name] to [$value] failed!"
            $result = -1
            break
        }
        else
        {
            #Set-BiosValue will return 0 if the setting was already set to and +1 if the setting was changed
            $result += $changed
        }
     
    }

    #just to make sure that we do not report more than expected
    if ( $result -gt 1 )
    {
        $result = 1
    }

    return $result
}


function Test-BiosPasswordFiles() 
{
    param(
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$PwdFilesFolder
    )   

    Write-HostSection -Start "Determine BIOS Password"

    #We test each password file by trying to write the Asset tag. If it works, we know we got the right password.
    #
    #Most models call this Asset tag "Asset Tracking Number" but some models (e.g. Pro Desk 500 G2.5)
    #call it indeed "Asset Tag" - https://github.com/texhex/BiosSledgehammer/issues/70
    #
    #Therefore, we first need to know which asset BIOS value to use

    Write-Host "Checking which asset value setting name this device supports..."

    $assetSettingNameList = @("Asset Tracking Number", "Asset Tag")
    $assetSettingName = ""

    ForEach ($testSettingName in $assetSettingNameList)
    {
        Write-Host "  Testing setting name [$testSettingName]..."
        
        if ( Test-BiosValueSupported -ValueName $testSettingName )
        {
            Write-Host "  Setting is supported, will use it for write tests"
            $assetSettingName = $testSettingName
            break
        }
    }
    
    #If no matching asset name was found, break the script 
    if ( -not (Test-String -HasData $assetSettingName) )
    {
        throw "No supported asset value BIOS setting was found for testing BIOS password files"
    }
    

    #Now that we know how the asset tag BIOS setting is called, we can start checking for password files
    Write-Host "Testing BIOS password files from [$PwdFilesFolder]..."

    $files = @()

    #Read all files that exist and sort them directly
    $pwd_files = Get-ChildItem -Path $PwdFilesFolder -File -Force -Filter "*.bin" | Sort-Object
  
    #Always add an empty password as first option
    $files += ""

    #Add files to our internal array
    ForEach ($pwdfile in $PWD_FILES) 
    {
        $files += $pwdfile.FullName 
    }

    $oldAssettag = Get-BiosValue -Name $assetSettingName -Silent
    Write-Host "Original asset value: [$oldAssettag]"

    $testvalue = Get-RandomString 14
    Write-Host "Asset value used for testing: [$testvalue]"
  
    $matchingPwdFile = $null

    ForEach ($file in $files) 
    {       
        Write-Host "Trying to write asset value using password file [$file]..."

        $result = Set-BiosValue -Name $assetSettingName -Value $testvalue -Passwordfile $file -Silent

        if ( ($result -ge 0) ) 
        {
            Write-Host "Success; password file is [$file]!"
            
            Write-Host "Restoring original asset value"        
            $ignored = Set-BiosValue -Name $assetSettingName -Value $oldAssettag -Passwordfile $file -Silent

            $matchingPwdFile = $file
            break
        }     
    }

    #Check if we were able to locate a password file
    if ( $null -eq $matchingPwdFile )
    {
        throw "The folder [$PwdFilesFolder] does not contain a BIOS password file this device accepts"
    }
      
    Write-HostSection -End "Determine BIOS Password"

    return $matchingPwdFile
}


#Special version for BIOS Version data
#It replaces the first character of a BIOS Version "F" with "1" if necessary. This is needed for older models like 2570p or 6570b:
#   http://h20564.www2.hp.com/hpsc/swd/public/detail?sp4ts.oid=5212930&swItemId=ob_173031_1&swEnvOid=4060#tab-history
#Also checks if the version begins with "v" and removes it (e.g. ProDesk 600 G1)
function ConvertTo-VersionFromBIOSVersion()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [string]$Text
    )  
 
    $Text = $Text.Trim() 
    $Text = $Text.ToUpper()

    #Very old devices use F.xx instead of 1.xx
    if ( Test-String $Text -StartsWith "F." )
    {
        $Text = $Text.Replace("F.", "1.")
    }

    #Some models report "v" before the version
    if ( Test-String $Text -StartsWith "V" )
    {
        $Text = $Text.Replace("V", "")
    }
 
    #Issue 50 (https://github.com/texhex/BiosSledgehammer/issues/50):
    #Newer BIOS versions (e.g. EliteBook 830 G5) use the version string "1.00.05" that will crash 
    #if the -RespectLeadingZeros parameter is used as the resulting version would be 1.0.0.0.5
    #
    #Therefore, check if the version only contains a single "." (dot) (= two tokens) and
    #only use -RespectLeadingZeros in that case
    
    if ( ($Text.Split('.').Length) -eq 2 )        
    {
        [version]$curver = ConvertTo-Version -Text $Text -RespectLeadingZeros
    }
    else
    {
        #The version string contains more than one dot (.), try to parse the version as is
        [version]$curver = ConvertTo-Version -Text $Text
    }

    return $curver
}



function Get-BIOSVersionDetails()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$RawData
    )
   
    #This function will not raise an fatal error if the BIOS data could not be parsed.
    #We will leave it to the caller if non-parsed version data should be fatal or not.
    #
    #Typical examples of bios data are:
    #SBF13 F.64
    #68ISB Ver. F.53        
    #L01 v02.53  10/20/2014
    #N02 Ver. 02.07  01/11/2016
    #L83 Ver. 01.34 
    #Q78 ver. 01.00.05 01/25/2018
    #02.17
    #1.06.00

    Write-Verbose "Trying to parse raw BIOS data [$RawData]"

    [version]$maxversion = "99.99" 
    $biosData = [Ordered]@{"Raw" = ""; "Family" = "Unknown"; "VersionText" = $maxversion.ToString(); "Version" = $maxversion; "Parsed" = $false; }

    #Just to be sure, trim the data 
    $biosData.Raw = $RawData.Trim()
         
    #Normally, we expect at least two tokens: FAMILY VERSION but there is the case of the ProDesk 400 G2.5 
    #which just reports "VERSION" (e.g. 2.17) - https://github.com/texhex/BiosSledgehammer/issues/70
    #This means, we need to check if we can't split on whitespace and if so, we expect the result to be just a normal version

    $tokens = $biosData.Raw.Split(" ")

    if ( ($null -eq $tokens) )
    {
        Write-Verbose "   Tokenizing raw BIOS data failed!"
    }
    else
    {
        if ( $tokens.Count -eq 1 )
        {
            Write-Verbose "   Raw BIOS data does not containing any whitespace, assuming it only contains the BIOS version"
            $biosData.VersionText = $tokens[0].Trim()
        }
        else
        {            
            #We expect to have at least two elements FAMILY VERSION
            if ( $tokens.Count -ge 2 )
            {       
                $biosData.Family = $tokens[0].Trim()
                Write-Verbose "   BIOS Family: $($biosData.Family)"

                #Now we need to check if we have exactly two or more tokens            
                #If there are exactly two tokens, we have FAMILY VERSION
                if ( $tokens.Count -eq 2 ) 
                {
                    $biosData.VersionText = $tokens[1].Trim()
                }
                else
                {
                    #We have more than exactly two tokens: it can be FAMILY VER VERSION or FAMILY VER VERSION DATE or FAMILY vVERSION DATE
                    #Check if the second part is "Ver."
                    if ( Test-String ( $tokens[1].Trim().ToUpper() ) -StartsWith "VER" )
                    {
                        #Use third token as version as the second is "VER"
                        $biosData.VersionText = $tokens[2].Trim()
                    } 
                    else 
                    {
                        #The second token is not "VER", so it has to be the version
                        $biosData.VersionText = $tokens[1].Trim()
                    }
                }
            }
        }
    }


    #Do we have something to parse or not
    if ( (Test-String -HasData $biosData.VersionText) )
    {
        Write-Verbose "   BIOS Version text/raw: $($biosData.VersionText)"

        #use special ConvertTo-Version version that respects special version numbers that some models report
        [version]$curver = ConvertTo-VersionFromBIOSVersion -Text $biosData.VersionText
        if ( $null -eq $curver )
        {
            Write-Verbose "   Converting [$($biosData.VersionText)] to a VERSION object failed!"
        }
        else
        {
            $biosdata.Version = $curver            
            $biosdata.Parsed = $true

            Write-Verbose "   BIOS Version: $($biosData.Version.ToString())"
        }
    }
    else
    {
        Write-Verbose "   BIOS data could not be parsed!"
    }
        
    return $biosData 
}


function Get-VersionTextAndNumerical()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$VersionText,

        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [version]$VersionObject
    )

    return "$VersionText  (Numerical: $($VersionObject.ToString()))"
}


function Copy-PasswordFileToTemp()
{
    param(
        [Parameter(Mandatory = $false)]
        [string]$SourcePasswordFile
    ) 
    $result = ""
 
    #A password file variable can be empty (=empty password), no error in this case
    if ( Test-String -HasData $SourcePasswordFile )
    {
        $result = Copy-FileToTemp -SourceFilename $SourcePasswordFile
    }

    return $result
}


function Copy-FileToTemp()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceFilename
    )

    $filenameonly = Get-FileName $SourceFilename

    #This line can cause issues later on. On some system this will be a path with "~1" in it and this can cause Remove-Item do freak out. 
    #$newfullpath="$env:temp\$filenameonly"
 
    $newfullpath = "$($TEMP_FOLDER)\$filenameonly"

    Copy-Item -Path $SourceFilename -Destination $newfullpath -Force -ErrorAction Stop

    return $newfullpath
}

function Copy-Folder()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Source,

        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination,

        #Required if the files should be copied, not the structure (see below)
        [switch]$Flatten
    )

    try
    {
        #In general folder copy is simple: SOURCE to DEST, done.
        #However, if you want to copy the content of a subfolder to a folder where        
        #a folder with the same name as defined in source exist, PS will just copy 
        #it to that folder as a subfolder (not the content to the root)

        #That's why the Flatten switch is there. It will take the contents 
        #from Source and copy it to the root of destination 
        
        #Make sure the paths end with \ (Normal) or \* (Flatten)
        if ( $Flatten )
        {
            $Source = Join-Path -Path $Source -ChildPath "\*"  
        }
        else
        {
            $Source = Join-Path -Path $Source -ChildPath "\"  
        }
        
        #Destination always ends with \
        $Destination = Join-Path -Path $Destination -ChildPath "\"

        Write-Host "Copying [$Source] "
        Write-Host "     to [$Destination] ..."            

        Copy-Item -Path $Source -Destination $Destination -Force -Recurse -ErrorAction Stop
        
        Write-Host "Done"
    }
    catch
    {
        throw "Unable to copy from [$source] to [$dest]: $($error[0])"
    }
}



function Update-BiosSettings()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $False)]
        [ValidateNotNullOrEmpty()]
        [string]$ModelFolder,
  
        [Parameter(Mandatory = $False, ValueFromPipeline = $False)]
        [string]$PasswordFile = ""
    )

    $displayText = "BIOS Settings"
 
    Write-HostSection -Start $displayText
    
    $result = Update-BiosSettingsEx -ModelFolder $ModelFolder -Filename "BIOS-Settings.txt" -PasswordFile $PasswordFile -IgnoreNonExistingConfigFile 

    Write-HostSection -End $displayText

    return $result
}

function Set-UEFIBootMode()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $False)]
        [ValidateNotNullOrEmpty()]
        [string]$ModelFolder,
  
        [Parameter(Mandatory = $False, ValueFromPipeline = $False)]
        [string]$PasswordFile = ""
    )

    $displayText = "Activate UEFI Boot Mode"

    Write-HostSection -Start $displayText

    $result = Update-BiosSettingsEx -ModelFolder $ModelFolder -Filename "Activate-UEFIBoot.txt" -PasswordFile $PasswordFile

    Write-HostSection -End $displayText

    return $result
}


function Update-BiosSettingsEx()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $False)]
        [ValidateNotNullOrEmpty()]
        [string]$ModelFolder,
      
        [Parameter(Mandatory = $True, ValueFromPipeline = $False)]
        [ValidateNotNullOrEmpty()]
        [string]$Filename,

        [Parameter(Mandatory = $False, ValueFromPipeline = $False)]
        [string]$PasswordFile = "",
  
        [Parameter(Mandatory = $False, ValueFromPipeline = $False)]
        [ValidateNotNullOrEmpty()]
        [switch]$IgnoreNonExistingConfigFile
    )

    $result = -1

    $configFileFullPath = Get-ModelSettingsFile -ModelFolder $ModelFolder -Name $Filename

    if ( $configFileFullPath -ne $null )
    {
        $configFileExists = Test-FileExists $ConfigFileFullPath
    }
    else
    {
        $configFileExists = $false
    }

        
    #Define we can change settings or not
    $change_settings = $false

    if ( $configFileExists ) 
    {
        $change_settings = $true
    }
    else
    {
        if ( $IgnoreNonExistingConfigFile )
        {
            $result = 0               
        } 
        else
        {
            throw "Setting file [$Filename] was not found"
            $result = -1
        }
    }


    if ( $change_settings )
    {
        #Try to read the setting file
        $settings = Read-StringHashtable $ConfigFileFullPath -AsOrderedDictionary

        if (  ($settings.Count -lt 1) ) 
        {
            Write-Warning "Setting file ($ConfigFileFullPath) is empty"
        } 
        else
        {
            #Inform which password we use
            Write-Host "Using password file [$PasswordFile]" 

            #Apply settings
            $changeresult = Set-BiosValuesByDictionary -Dictionary $settings -Passwordfile $PasswordFile

            if ( $changeresult -lt 0 ) 
            {
                #Something went wrong applying our settings
                throw "Applying BIOS Setting failed!"
            }
       
            if ( $changeresult -eq 1 )
            {
                #Since this message will appear each and every time, I'm unsure if it should remain or not
                Write-Host "One or more BIOS setting(s) have been changed. A restart is recommended to activated them."
            }

            $result = $changeresult
        }
    }

    return $result
}


function Update-BiosFirmware()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $False)]
        [ValidateNotNullOrEmpty()]
        [string]$ModelFolder,

        [Parameter(Mandatory = $True, ValueFromPipeline = $False)]
        [ValidateNotNullOrEmpty()]
        $BiosDetails,

        [Parameter(Mandatory = $False, ValueFromPipeline = $False)]
        [string]$PasswordFile = ""
    )
 
    #HPQFlash requires oledlg.dll which is by default not included in WinPE (see http://tookitaway.co.uk/tag/hpbiosupdrec/)
    #No idea if we should check for this file if we detect HPQFlash and WinPE. 

    $result = $false

    Write-HostSection "BIOS Update"
    $settingsFile = Get-ModelSettingsFile -ModelFolder $ModelFolder -Name "BIOS-Update.txt"

    if ( $null -ne $settingsFile )
    {
        #Check if the BIOS data was parsed
        if ( -not $BIOSDetails.Parsed) 
        {
            throw "BIOS data could not be parsed, unable to check if update is required"
        }

        $details = Read-StringHashtable $settingsFile

        if ( -not($details.ContainsKey("Version")) -or -not($details.ContainsKey("Command"))  ) 
        {
            throw "Settings file is missing Version or Command settings"
        } 
        else
        {       
            $versionDesiredText = $details["version"]

            #use special ConvertTo-Version version 
            [version]$versionDesired = ConvertTo-VersionFromBIOSVersion -Text $versionDesiredText

            if ( $null -eq $versionDesired ) 
            {
                throw "Unable to parse [$versionDesiredText] as a version"
            }
            else
            {
                Write-Host "Current BIOS Version: $(Get-VersionTextAndNumerical $BIOSDetails.VersionText $BIOSDetails.Version)"
                Write-Host "Desired BIOS Version: $(Get-VersionTextAndNumerical $versionDesiredText $versionDesired)"

                if ( $versionDesired -le $BIOSDetails.Version ) 
                {
                    Write-Host "BIOS update not required"
                    $result = $false
                }
                else
                {
                    Write-Host "BIOS update required!"

                    #------ BIOS-Update-BIOS-Settings.txt -----------------
                    #Maybe we need to apply BIOS settings to allow the BIOS update (e.g. changing "Lock BIOS Version" setting )
                    $displayText = "BIOS settings for BIOS update"

                    Write-HostSection -Start $displayText
                    $ignored = Update-BiosSettingsEx -ModelFolder $ModelFolder -Filename "BIOS-Update-BIOS-Settings.txt" -PasswordFile $PasswordFile -IgnoreNonExistingConfigFile                                                        
                    Write-HostSection -End $displayText -NoEmptyLineAtEnd
                    #-----------------------------------------------

                    #Continue BIOS update
                    $updateFolder = Get-UpdateFolder -SettingsFilePath $settingsFile -Name "BIOS-$versionDesiredText"

                    #check if we need to pass a firmware file based on the BIOS Family
                    $firmwareFile = ""
                    $biosFamily = $BiosDetails.Family

                    Write-Host "BIOS family is [$biosFamily]"
                    if ( $details.ContainsKey($biosFamily) )
                    {
                        #Entry exists
                        $firmwareFile = $details[$biosFamily]
                        Write-Host "  Found firmware file entry for the current BIOS family: [$firmwarefile]"                
                    } 

                    $returncode = Invoke-UpdateProgram -Settings $details -SourcePath $updateFolder -PasswordFile $PasswordFile -FirmwareFile $firmwareFile           
     
                    if ( ($returnCode -eq 0) -or ($returnCode -eq 3010) )
                    {
                        Write-Host "BIOS update success"
                        $result = $true
                    }
                    else
                    {
                        $result = $null

                        if ( $null -eq $returnCode )
                        {
                            throw "Running BIOS update program failed"
                        }
                        else
                        {
                            throw "BIOS update failed, update program returned code $($returnCode)"
                        }
                    }

              
                    #update done
                }
            }
        }
    }

    Write-HostSection -End "BIOS Update"
    return $result
}


function Get-TPMDetails()
{
    Write-Verbose "Trying to get TPM data..."
    <# 
    More about TPM Data:
    http://en.community.dell.com/techcenter/b/techcenter/archive/2015/12/09/retrieve-trusted-platform-module-tpm-version-information-using-powershell
    http://en.community.dell.com/techcenter/enterprise-client/w/wiki/11850.how-to-change-tpm-modes-1-2-2-0
    http://www.dell.com/support/article/de/de/debsdt1/SLN300906/en
    http://h20564.www2.hp.com/hpsc/doc/public/display?docId=emr_na-c05192291
  #>

    # HP:
    #   ID 1229346816 = IFX with Version 6.40 = TPM 1.2
    # Dell:
    #   ID 1314145024 = NTC with Version 1.3 = TPM 2.0
    #   ID 1464156928 = WEC with Version 5.81 = TPM 1.2
  
    [version]$maxversion = "99.99"
    $TPMData = [PSObject]@{"ManufacturerId" = "Unknown"; "VersionText" = $maxversion.ToString(); "Version" = $maxversion; "SpecVersionText" = $maxversion.ToString(); "SpecVersion" = $maxversion; "Parsed" = $false; }

    try
    {
        $tpm = Get-CimInstance Win32_Tpm -Namespace root\cimv2\Security\MicrosoftTpm

        $TPMData.ManufacturerId = [string]$tpm.ManufacturerId
   
        $TPMData.VersionText = $tpm.ManufacturerVersion
        $TPMData.Version = ConvertTo-Version $tpm.ManufacturerVersion
   
        #SpecVersion is reported as "1.2, 2, 3" which means "TPM 1.2, revision 2, errata 3"
        #I'm pretty sure we only need to first part    
        $specTokens = $tpm.SpecVersion.Split(",")
   
        $TPMData.SpecVersionText = $specTokens[0]
        $TPMData.SpecVersion = ConvertTo-Version $specTokens[0]
 
        $TPMData.Parsed = $true
    }
    catch
    {
        Write-Verbose "Getting TPM data error: $($error[0])"
    }

    return $TPMData 
}


function Invoke-BitLockerDecryption()
{
    Write-Host "Checking BitLocker status..."

    $bitLockerActive = $false

    #we better save this all with a try-catch
    try
    {
        #Because we do not know if we can access the BitLocker module, we check the status using WMI/CMI
        $encryptableVolumes = Get-CimInstance "Win32_EncryptableVolume" -Namespace "root/CIMV2/Security/MicrosoftVolumeEncryption"
                      
        $systemdrive = $env:SystemDrive
        $systemdrive = $systemdrive.ToUpper()

        Write-Verbose "Testing if system drive $($systemdrive) is BitLocker encrypted"

        if ( $null -ne $encryptableVolumes ) 
        {
            foreach ($volume in $encryptableVolumes)
            {
                Write-Verbose "Checking volume $($volume.DeviceID)"

                #There might be drives that are BitLocker encrypted but do not have a drive letter.
                #The system drive will always have a drive letter, so we can simply rule them out.
                #This should be the fix for issue #43 - https://github.com/texhex/BiosSledgehammer/issues/43
                if ( $null -ne $volume.DriveLetter )
                {

                    if ( $volume.DriveLetter.ToUpper() -eq $systemdrive )
                    {           
                        Write-Verbose "Found entry for system drive"
                               
                        #The property ProtectionStatus will also be 0 if BitLocker was just suspended, so we can't use this property.
                        #We go for EncryptionMethod which will report 0 if no BitLocker encryption is used

                        #As @GregoryMachin reported, some versions of Windows do not have this property at all so need to make sure to have access to it
                        #See https://github.com/texhex/BiosSledgehammer/issues/21
                        if ( Get-Member -InputObject $volume -Name "EncryptionMethod" -Membertype Properties )
                        {
                            #Some computers reported NULL/NIL as the output, so we need to make sure it's uint32 what is returned
                            #See https://msdn.microsoft.com/en-us/library/windows/desktop/aa376434(v=vs.85).aspx
                            if ( $volume.EncryptionMethod -is [uint32] )
                            {
                                if ( $volume.EncryptionMethod -ne 0 )
                                {
                                    $bitLockerActive = $true
                                    Write-Host "BitLocker is active for system drive ($systemdrive)!"
                                }                        
                                else
                                {
                                    Write-Verbose "BitLocker is not used"
                                }
                            }
                        }
                    }

                }
            }
        }


        if ( $bitLockerActive )
        {
            Write-Host "BitLocker is active for the system drive, starting automatic decryption process..."

            #Check if we can auto descrypt the volume by using the BitLocker module
            $module_avail = Get-ModuleAvailable "BitLocker"

            if ( $module_avail )
            {                            
                $header = "Automatic BitLocker Decryption"
                $text = "To perform the update, BitLocker needs to be fully decrypted"
                $footer = "You have 20 seconds to press CTRL+C to prevent this."

                Write-HostFramedText -Heading $header -Text $text -Footer $footer -NoDoubleEmptyLines:$true                          
                Start-Sleep -Seconds 20

                Write-Host "Starting decryption (this might take some time)..."
                $ignored = Disable-BitLocker -MountPoint $systemdrive
				
                #wait three seconds to avoid that we check the status before the decryption has started
                Start-Sleep -Seconds 3 
				

                #Now wait for the decryption to complete
                Do
                {
                    $bitlocker_status = Get-BitLockerVolume -MountPoint $systemdrive

                    $percentage = $bitlocker_status.EncryptionPercentage
                    $volumestatus = $bitlocker_status.VolumeStatus

                    #We can not check for .ProtectionStatus because this turns to OFF as soon as the decyryption starts
                    #if ( $bitlocker_status.ProtectionStatus -ne "Off" )
                              
                    #During the process, the status is "DecryptionInProgress"
                    if ( $volumestatus -ne "FullyDecrypted" )
                    {
                        Write-Host "  Decryption in progress, $($Percentage)% remaining ($volumestatus). Waiting 15 seconds..."
                        Start-Sleep -Seconds 15
                    }
                    else
                    {
                        Write-Host "  Decryption finished!"
                                 
                        #Just to be sure
                        Start-Sleep -Seconds 5

                        $bitLockerActive = $false
                        break
                    }

                } while ($true)

            }
            else
            {
                Write-Error "Unable to decrypt the volume, BitLocker PowerShell module not found"
            }
        } 
        else
        {
            Write-Host "BitLocker is not in use for the system drive"
        }
    }
    catch
    {
        Write-Error "BitLocker Decryption error: $($error[0])"
        $bitLockerActive = $true #just to be sure
    }


    #We return TRUE if no BitLocker is in use
    if ( -not $bitLockerActive )
    {
        return $true
    }
    else
    {
        return $false
    }
}


function Update-TPMFirmware()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $False)]
        [ValidateNotNullOrEmpty()]
        [string]$ModelFolder,

        [Parameter(Mandatory = $True, ValueFromPipeline = $False)]
        [ValidateNotNullOrEmpty()]
        $TPMDetails,

        [Parameter(Mandatory = $False, ValueFromPipeline = $False)]
        [string]$PasswordFile = ""
    )

    Write-HostSection "TPM Update"

    $result = $false

    $updateFile = Get-ModelSettingsFile -ModelFolder $ModelFolder -Name "TPM-Update.txt"

    if ( $null -ne $updatefile ) 
    {
        if ( -not ($TPMDetails.Parsed) ) 
        {
            throw "TPM not found or unable to parse data, unable to check if update is required"
        }
    
        $settings = Read-StringHashtable $updatefile

        if ( !($settings.ContainsKey("SpecVersion")) -or !($settings.ContainsKey("FirmwareVersion")) -or !($settings.ContainsKey("Command"))  ) 
        {
            throw "Configuration file is missing SpecVersion, FirmwareVersion or Command settings"
        }

        #5.0: Ensure that UpgradeFirmwareSelection==ByTPMConfig is set which is required and the only supported setting 
        if ( -not ($settings.ContainsKey("UpgradeFirmwareSelection")) ) 
        {
            throw "Configuration file is missing UpgradeFirmwareSelection setting"
        }
        else
        {            
            if ( ($settings["UpgradeFirmwareSelection"] -ne "ByTPMConfig") )
            {
                throw "Configuration file error: UpgradeFirmwareSelection is not set to ByTPMConfig"
            }
        }
          
        #Check if a Manufacturer was given. If so, we need to check if it matches the vendor of this machine
        $manufacturerOK = $true
      
        if ( $settings.ContainsKey("Manufacturer") )
        {       
            $tpmManufacturer = $settings["Manufacturer"]

            Write-Host "TPM manufacturer ID of this device: $($TPMDetails.ManufacturerId)"
            Write-Host "TPM manufacturer ID required......: $tpmManufacturer"

            #Yes, I'm aware this are numbers, but the day they will use chars this line will save me some debugging
            if ( $tpmManufacturer.ToLower() -ne $TPMDetails.ManufacturerId.ToLower() )
            {
                Write-Warning "  TPM manufacturer IDs do not match, unable to update TPM"
                $manufacturerOK = $false
            }
            else
            {
                Write-Host "  TPM manufacturer IDs match"
            }         
        }
        else
        {
            Write-Host "Manufacturer not defined in configuration file, will not check TPM manufacturer ID"
        }
  
        if ( $manufacturerOK )
        {
            #Get TPM Spec and firmwarwe version from settings
            $tpmSpecDesiredText = $settings["SpecVersion"]
            $tpmSpecDesired = ConvertTo-Version $tpmSpecDesiredText

            if ( $null -eq $tpmSpecDesired ) 
            {
                throw "Unable to convert value of SpecVersion [$tpmSpecDesiredText] to a version!"
            }

            #Check TPM spec version
            $updateBecauseTPMSpec = $false
            Write-Host "Current TPM Spec: $(Get-VersionTextAndNumerical $TPMDetails.SpecVersionText $TPMDetails.SpecVersion)"
            Write-Host "Desired TPM Spec: $(Get-VersionTextAndNumerical $tpmSpecDesiredText $tpmSpecDesired)"  

            if ( $TPMDetails.SpecVersion -lt $tpmSpecDesired )
            {
                Write-Host "  TPM Spec is lower than desired, update required"            
                $updateBecauseTPMSpec = $true
            }
            else
            {
                Write-Host "  TPM Spec version matches or is newer"
            }

            #Verify firmware version
            $firmwareVersionDesiredText = $settings["FirmwareVersion"]
            $firmwareVersionDesired = ConvertTo-Version $firmwareVersionDesiredText

            if ( $null -eq $firmwareVersionDesired ) 
            {
                throw "Unable to convert value of FirmwareVersion [$firmwareVersionDesiredText] to a version!"
            }
                        
            $updateBecauseFirmware = $false
            Write-Host "Current TPM firmware: $(Get-VersionTextAndNumerical $TPMDetails.VersionText $TPMDetails.Version)"
            Write-Host "Desired TPM firmware: $(Get-VersionTextAndNumerical $firmwareVersionDesiredText $firmwareVersionDesired)"

            if ( $TPMDetails.Version -lt $firmwareVersionDesired )
            {
                Write-Host "  Firmware version is lower than desired, update required"            
                $updateBecauseFirmware = $true
            }
            else
            {
                Write-Host "  Firmware version matches or is newer"
            }

            Write-Host "Update check result:"
            Write-Host "  Update required because of TPM Spec....: $updateBecauseTPMSpec"
            Write-Host "  Update required because of TPM firmware: $updateBecauseFirmware"
             
            if ( -not ($updateBecauseTPMSpec -or $updateBecauseFirmware) )
            {
                Write-Host "No update necessary"
                $result = $false
            }
            else
            {
                Write-Host "TPM update required!"
                      
                #We might need to stop here, depending on the BitLockerStatus
                $continueTPMUpgrade = $false

                #In case of update scenarios, the operator can decide to just pause BitLocker encrpytion and does not want to have it fully decrypt
                $ignoreBitLocker = $settings["IgnoreBitLocker"]
                                                  
                if ( $ignoreBitLocker -eq "Yes") 
                {
                    Write-Host "BitLocker status is ignored, will continue without checking BitLocker"
                    $continueTPMUpgrade = $true
                }
                else
                {
                    #Now we have everything we need, but we need to check if the SystemDrive (C:) is full decrypted. 
                    #BitLocker might not be using the TPM , but I think the TPM update simply checks if its ON or not. If it detects BitLocker, it fails.
                    $BitLockerDecrypted = Invoke-BitLockerDecryption

                    if ($BitLockerDecrypted)
                    {
                        $continueTPMUpgrade = $true                                
                    }
                    else
                    {
                        throw "BitLocker is in use, TPM update not possible"
                    }
                }
                                           
                #DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG 
                #$continueTPMUpgrade=$true
                #DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG 
                      
                if ($continueTPMUpgrade)
                {                
                    #------ TPM-Update-BIOS-Settings.txt -----------------
                    #Maybe we have a BIOS that requires BIOS settings to allow the TPM update, e.g. TXT and SGX for G3 Models with BIOS 1.16 or higher                                                                                                                                              
                    $displayText = "BIOS settings for TPM update"

                    Write-HostSection -Start $displayText
                    $ignored = Update-BiosSettingsEx -ModelFolder $ModelFolder -Filename "TPM-Update-BIOS-Settings.txt" -PasswordFile $PasswordFile -IgnoreNonExistingConfigFile                                                        
                    Write-HostSection -End $displayText -NoEmptyLineAtEnd
                    #-----------------------------------------------
      
                    #Get the folder we need to copy locally
                    $sourceFolder = Get-UpdateFolder -SettingsFilePath $updateFile -Name "TPM-$firmwareVersionDesiredText"

                    #Check if an extra source folder was specified. 
                    $extraFilesFolder = $null
                    $additionalDirectory = $settings["AdditionalFilesDirectory"] 
                    if ( Test-String $additionalDirectory -HasData )
                    {
                        $extraFilesFolder = Join-Path -Path $sourceFolder -ChildPath $additionalDirectory
                    }

                    ###########################
                    #Update process starts here 
                    ###########################
                    $returnCode = Invoke-UpdateProgram -Settings $settings -SourcePath $sourcefolder -ExtraFilesPath $extraFilesFolder -SpecVersion $tpmSpecDesiredText -PasswordFile $PasswordFile

                    if ( ($returnCode -eq 0) -or ($returnCode -eq 3010) )
                    {
                        Write-Host "TPM update success"
                        $result = $true
                    }
                    else
                    {
                        $result = $null

                        if ( $null -eq $returnCode )
                        {
                            throw "Running TPM update program failed"
                        }
                        else
                        {
                            $returnCodeText = ConvertTo-DescriptionFromTPMConfigReturncode $returncode
                            throw "TPM update failed: $($returnCodeText) (Return code $($returnCode))"
                        }
                    }
                                                                        
                }                            
            }                                
        }        
    }

    Write-HostSection -End "TPM Update"
    return $result
}

function ConvertTo-DescriptionFromTPMConfigReturncode()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Errorcode
    )
 
    $Errorcode = $Errorcode.Trim()
 
    $lookup =
    @{ 
        "0" = "Success"; "128" = "Invalid command line option(s)"; "256" = "No BIOS support"; "257" = "No TPM firmware bin file";
        "258" = "Failed to create HP_TOOLS partition"; "259" = "Failed to flash the firmware"; "260" = "No EFI partition (for GPT)";
        "261" = "Bad EFI partition"; "262" = "Cannot create HP_TOOLS partition because the maximum number of partitions has been reached";
        "263" = "Not enough space partition - the size of the firmware binary file is greater than the free space of EFI or HP_TOOLS partition";
        "264" = "Unsupported operating system"; "265" = "Elevated (administrator) privileges are required"; "273" = "Not supported chipset";
        "274" = "No more firmware upgrade is allowed"; "275" = "Invalid firmware binary file"; 
        "290" = "BitLocker is currently enabled"; "291" = "Unknown BitLocker status"; 
        "292" = "WinMagic encryption is currently enabled"; "293" = "WinMagic SecureDoc is currently enabled";
        "296" = "No system information"; 
        "305" = "Intel TXT is currently enabled"; "306" = "VTx is currently enabled"; "307" = "SGX is currently enabled"
        "1602" = "User canceled the operation"; 
        "3010" = "Success - reboot required"; "3011" = "Success rollback"; "3012" = "Failed rollback";       
    }

    if ( $lookup.ContainsKey("$ErrorCode") )
    {
        $result = $lookup[$ErrorCode]
    }
    else
    {
        $result = "Undocumented error code"
    }

    return $result
}

function Invoke-UpdateProgram()
{
    param(
        [Parameter(Mandatory = $False)]
        [string]$Name = "",

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$Settings,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath,

        [Parameter(Mandatory = $False)]
        [string]$ExtraFilesPath = "",
    
        [Parameter(Mandatory = $False)]
        [string]$FirmwareFile = "",

        [Parameter(Mandatory = $False)]
        [string]$SpecVersion = "",

        [Parameter(Mandatory = $False)]
        [string]$PasswordFile = "",

        [Parameter(Mandatory = $False)]
        [switch]$NoOutputRedirect = $false
    )

    $result = $null
    Write-Verbose "Invoke-UpdateProgram() started"
    

    Write-Host "Checking if the computer is on AC or DC (battery) power..."    
    
    #Checking the property might fail with the message "The property 'BatteryStatus' cannot be found on this object. Verify that the property exists."    
    try
    {        
        $batteryStatus = $null
        
        #see https://msdn.microsoft.com/en-us/library/aa394074(v=vs.85).aspx
        $batteryStatus = (Get-CimInstance Win32_Battery -ErrorAction Stop).BatteryStatus
        # "-ErrorAction Stop" is required to turn any error into a catchable error
    }
    catch
    {
        Write-Host "Querying CIM for Win32_Battery.BatteryStatus failed ($($error[0])), assuming this computer has no battery."
    }

    $batteryOK = $false    
    if ( $null -eq $batteryStatus )
    {
        #No battery found, ignoring state 
        $batteryOK = $true
    }
    else
    {
        #On Battery (1), Critical (5), Charging and Critical (9)
        if ( ($batteryStatus -eq 1) -or ($batteryStatus -eq 5) -or ($batteryStatus -eq 9) )
        {
            throw "This device is running on battery or the battery is at a critically low level. The update will not be started to prevent possible firmware corruption."
        }
        else
        {
            $batteryOK = $true
        }
    }

    
    if ( $batteryOK ) 
    {
        Write-Host "  Battery status is OK or no battery present."

        if ( Test-String -HasData $Name)
        {
            Write-Host "::: Preparing launch of update executable - $name :::"
        }
        else
        {
            Write-Host "::: Preparing launch of update executable :::"
        }

        $localFolder = Copy-FolderForExec -SourceFolder $SourcePath -ExtraFilesFolder $ExtraFilesPath -DeleteFilter "*.log"

        #Some HP tools require full paths for the firmware file or they will not work, especially TPMConfig64.exe
        #Therefore append the local path to the firmware if one is set
        $localFirmwareFile = $FirmwareFile
        if ( Test-String $localFirmwareFile -HasData)
        {
            $localFirmwareFile = Join-Path -Path $localFolder -ChildPath $localFirmwareFile
        }

        #Get the parameters together.
        #The trick with the parameters array is courtesy of SAM: http://edgylogic.com/blog/powershell-and-external-commands-done-right/
        $params = Get-ArgumentsFromHastable -Hashtable $Settings -PasswordFile $PasswordFile -FirmwareFile $localFirmwareFile -SpecVersion $SpecVersion
 
        #Get the exe file
        $exeFileName = $Settings["command"]        
        $exeFileLocalPath = "$localFolder\$exeFileName"               

        $result = Invoke-ExeAndWaitForExit -ExeName $exeFileLocalPath -Parameter $params -NoOutputRedirect:$NoOutputRedirect
               
        #always try to grab the log file
        $ignored = Write-HostFirstLogFound -Folder $localFolder
        
        Write-Host "::: Launching update executable finished :::"
    }
    
    Write-Verbose "Invoke-UpdateProgram() ended"
    return $result
}

function Copy-FolderForExec()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceFolder,

        [Parameter(Mandatory = $False )]
        [string]$ExtraFilesFolder = "",

        [Parameter(Mandatory = $False)]
        [string]$DeleteFilter = ""
    )

    Write-Verbose "Copy-FolderForExec() started"

    #When using $env:temp, we might get a path with "~" in it
    #Remove-Item does not like these path, no idea why...
    $dest = Join-Path -Path $($TEMP_FOLDER) -ChildPath (Split-Path $SourceFolder -Leaf)

    #If it exists, kill it
    if ( (Test-DirectoryExists $dest) )
    {
        try
        {
            Remove-Item $dest -Force -Recurse -ErrorAction Stop
        }
        catch
        {
            throw "Unable to clear folder [$dest]: $($error[0])"
        }
    }

    #Make sure source exists
    if ( -not (Test-DirectoryExists $SourceFolder) ) 
    {
        throw "Folder [$SourceFolder] not found!"
    }

    #Make sure DEST ends with \
    $dest = Join-Path -Path $dest -ChildPath "\"

    #Copy main content
    Copy-Folder -Source $SourceFolder -Destination $dest

    #Copy secondary files  (if required)
    if ( Test-String $ExtraFilesFolder -HasData )
    { 
        if ( -not (Test-DirectoryExists $ExtraFilesFolder) ) 
        {
            throw "Folder [$ExtraFilesFolder] not found!"
        }        
        #We want to have the firmware files directly in the root, therefore use -Flatten
        Copy-Folder -Source $ExtraFilesFolder -Destination $dest -Flatten
    }

    #now check if we should delete something after copying it
    if ( $DeleteFilter -ne "" )
    {
        Write-Host "Deleting [$DeleteFilter] in target folder"
        try
        {
            $files = Get-ChildItem $dest -File -Include $deleteFilter -Recurse -Force -ErrorAction Stop
            foreach ($file in $files)
            {
                Write-Host "  Found $($file.Fullname), deleting"
                Remove-FileExact -Filename $file.Fullname 
            }
                     
        }
        catch
        {
            throw "Error while deleting from [$dest]: $($error[0])"
        }
    }

    #We return the destination path without the \
    return $dest.TrimEnd("\")    
}


function Get-ArgumentsFromHastable()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$Hashtable,

        #Replace parameter @@PASSWORD_FILE@@
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)]
        [string]$PasswordFile = "",

        #Replace parameter @@FIRMWARE_FILE@@
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)]
        [string]$FirmwareFile = "",

        #Replace parameter @@SPEC_VERSION@@
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)]
        [string]$SpecVersion = ""
    )
 
    $params = @()

    #20 parameters max should be enough
    For ($i = 1; $i -lt 21; $i++) 
    {
        if ( ($Hashtable.ContainsKey("Arg$i")) )
        {
            $params += $Hashtable["Arg$i"]
        }
        else
        {
            break
        }
    }

    #now check for replacement strings
    #We need to use a for loop since a foreach will not change the array
    for ($i = 0; $i -lt $params.length; $i++) 
    {
        if ( Test-String $params[$i] -Contains "@@PASSWORD_FILE@@" )
        {
            if ( $PasswordFile -eq "" ) 
            {
                #if no password is set, delete this paramter
                $params[$i] = ""
            }
            else
            {
                $params[$i] = $params[$i] -replace "@@PASSWORD_FILE@@", $PasswordFile    
            }
        }
       
        if ( Test-String $params[$i] -Contains "@@FIRMWARE_FILE@@" )
        {
            if ( $FirmwareFile -eq "" ) 
            {
                #if no firmware is set, delete this paramter
                $params[$i] = ""
            }
            else
            {
                $params[$i] = $params[$i] -replace "@@FIRMWARE_FILE@@", $FirmwareFile    
            }
        }

        if ( Test-String $params[$i] -Contains "@@SPEC_VERSION@@" )
        {
            if ( $SpecVersion -eq "" ) 
            {
                #if not set, delete this parameter
                $params[$i] = ""
            }
            else
            {
                $params[$i] = $params[$i] -replace "@@SPEC_VERSION@@", $SpecVersion    
            }
        }

    }

    #finally copy the arguments together and leave any empty elements out
    $paramsFinal = @() 
    foreach ($param in $params) 
    {
        if ( -not (Test-String -IsNullOrWhiteSpace $param) )
        {
            $paramsFinal += $param
        }
    }
    
    return $paramsFinal  
}

function Invoke-ExeAndWaitForExit()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$ExeName,

        [Parameter(Mandatory = $False, ValueFromPipeline = $True)]
        [array]$Parameter = @(),

        [Parameter(Mandatory = $False)]
        [switch]$NoOutputRedirect = $false
    )

    $result = -1
  
    Write-Host "Starting: "
    Write-Host "  $ExeName"
    Write-Host "  $Parameter"
 
    try
    {
        #Version 1
        #We can not use this command because this will not return the exit code. 
        #Also, most HP update tools do not return anything to stdout at all.
        #$output=&$ExeName $Parameter

        #Version 2, gets exit code but no standard output
        #$runResult=Start-Process $ExeName -Wait -PassThru -ArgumentList $Parameter
        #$result=$runResult.ExitCode         

        #Version 3, hopefully the last...
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $ExeName
        $startInfo.Arguments = $Parameter
    
        $startInfo.UseShellExecute = $false #else redirected streams do not work

        if ( $NoOutputRedirect )
        {
            Write-Verbose "StdOut and StdError redirection disabled"
        }
        else
        {
            $startInfo.RedirectStandardError = $true
            $startInfo.RedirectStandardOutput = $true
        }
        
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $startInfo
        $proc.Start() | Out-Null

        #LAUNCH HERE
        $proc.WaitForExit()
    
        #Get result code
        $result = $proc.ExitCode
    
        $stdOutput = ""
        $stdErr = ""

        if ( -not $NoOutputRedirect )
        {
            $stdOutput = $proc.StandardOutput.ReadToEnd()
            $stdErr = $proc.StandardError.ReadToEnd()
        }

        Write-Host "  Done, return code is $result"

        $stdOutput = Get-TrimmedString $stdOutput
        $stdErr = Get-TrimmedString $stdErr
    
        Write-Host "--- Output ---"
        if ( Test-String -HasData $stdOutput )
        {        
            Write-Host $stdOutput        
        }
    
        if ( Test-String -HasData $stdErr )
        {                
            Write-Host "--- Error(s) ---"
            Write-Host $stdErr        
        }
        Write-Host "--------------"

        #now check if the EXE is still running in the background
        #We need to remove the extension because get-process does not list .EXE
        $execheck = [io.path]::GetFileNameWithoutExtension($ExeName)
    
        Write-Host "  Waiting 10 seconds before checking if the process is still running..."
        Start-Sleep -Seconds 10

        Do
        {
            $check = Get-Process "$execheck*" -ErrorAction SilentlyContinue
            if ( $check )
            {
                Write-Host "   [$execheck] is still runing, waiting 10 seconds..."
                Start-Sleep -Seconds 10
            }
            else
            {
                Write-Host "   [$execheck] is no longer running, waiting 5 seconds to allow cleanup..."
                Start-Sleep -Seconds 5
                break
            }                                                                                
        } while ($true)
     
     
        Write-Host "  Start of [$ExeName] done"
    }
    catch
    {
        $result = $null
        throw "Starting failed! Error: $($error[0])"
    }

    return $result               
}

function Write-HostFirstLogFound()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Folder,

        [Parameter(Mandatory = $False, ValueFromPipeline = $True)]
        [string]$Filter = "*.log"
    )

    Write-Host "Checking for first file matching [$filter] in [$folder]..."

    $logfiles = Get-ChildItem -Path $Folder -File -Include $filter -Recurse -Force 

    if ( $null -eq $logfiles )
    {
        Write-Host "  No file found!"
    }
    else
    {
        $filename = $logFiles[0].FullName   
   
        $content = Get-Content $filename -Raw

        if ( Test-String $content -IsNullOrWhiteSpace )
        {
            Write-Host "  File $filename is empty!"
        } 
        else
        {
            Write-HostOutputFromProgram -Name $filename -Content $content    
        }
   
    }

}


function Update-MEFirmware()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $False)]
        [ValidateNotNullOrEmpty()]
        [string]$ModelFolder
    )

    Write-HostSection "Management Engine (ME) Update"
    $result = $false

    $settingsFile = Get-ModelSettingsFile -ModelFolder $ModelFolder -Name "ME-Update.txt"

    if ( $null -ne $settingsFile )    
    {    
        #Read the settings file so we have everything later on
        $settings = Read-StringHashtable $settingsFile

        #Now start the Intel tool
        Write-Host "Starting SA-00075 discovery tool to get ME data..."
  
        #We use the XML output method, so the tool will generate a file called [DEVICENAME].xml.    
        $xmlFilename = "$TEMP_FOLDER\$($env:computername).xml"
 
        #If a file by the name already exists, delete it
        $ignored = Remove-Item -Path $xmlFilename -Force -ErrorAction SilentlyContinue
    
        try
        {
            $runToolResult = &"$ISA75DT_EXE_SOURCE" --delay 0 --writefile --filepath $TEMP_FOLDER | Out-String
        }
        catch
        {
            throw "Launching [$ISA75DT_EXE_SOURCE] failed; error: $($error[0])"
        }
    
        #Output console output to make sure we have something in the log even if the XML parsing fails
        Write-HostOutputFromProgram -Name "Discovery Tool Output" -Content $runToolResult

        Write-Host "Processing XML result [$xmlFilename]..."        

        if ( -not (Test-FileExists $xmlFilename) ) 
        {
            throw "SA-00075 discovery tool XML output file not found"
        }
        else
        {
            $MEData = @{"VersionText" = "0.0.0"; "VersionParsed" = $false; "Provisioned" = "Unknown"; "DriverInstalled" = $false }

            try 
            {
                $xmlContent = Get-Content $xmlFilename -Raw
                [xml]$xml = $xmlContent

                $MEData.VersionText = $xml.System.ME_Firmware_Information.ME_Version

                #In some cases, the Intel tool will report "Unknown" for the version. 
                #If this happens, no ME update is possible
                if ($MEData.VersionText.ToUpper() -ne "UNKNOWN")
                {
                    $MEData.Version = ConvertTo-Version -Text $MEData.VersionText
                    $MEData.VersionParsed = $true
                }
                
                #IS75DT 1.0.3 does no longer contain the entry SKU in the XML. Still in the normal output though...
                $MEData.Provisioned = $xml.System.ME_Firmware_Information.ME_Provisioning_State

                if ( $xml.System.ME_Firmware_Information.ME_Driver_Installed -eq "True" )
                {
                    $MEData.DriverInstalled = $true
                }    
                             
                Write-Host "XML processing finished"
            }
            catch
            {
                throw "Unable to parse SA-00075 discovery XML file; error: $($error[0])"
            }
                 
                        
            if ( -not $MEData.VersionParsed )
            {
                $errorMessage = "The SA-00075 detection tool was unable to determine the installed ME firmware version, no update possible"

                #When we are here, the Intel SA tool was unable to get the version of the ME or the return was invalid (which is unlikely).
                #Common causes: the BIOS allows disabling the ME, an external kill switch was used, or something is really b0rken.                
                #Check if we should ignore ME detection errors and if so, we just inform the user and continue

                $ignoreMEDetectionError = $settings["IgnoreMEDetectionError"]

                if ( $ignoreMEDetectionError -eq "Yes" )
                {
                    #Alright, ignore this error
                    Write-Host $errorMessage
                    Write-Host "IgnoreMEDetectionError setting active, ignoring error and continuing"
                    $result = $false
                }
                else
                {
                    throw $errorMessage
                }                    
            }
            else
            {                    
                $versionDesiredText = $settings["version"]
                [version]$versionDesired = ConvertTo-Version -Text $versionDesiredText

                if ( $null -eq $versionDesired ) 
                {
                    throw "Unable to parse configured version [$versionDesiredText] as a version"
                }
                else
                {
                    Write-Host "ME Driver is installed.....: $($MEData.DriverInstalled)"
                    Write-Host "Current ME firmware version: $($MEData.Version)"
                    Write-Host "Desired ME firmware version: $($versionDesired)"
                    
                    if ( $versionDesired -le $MEData.Version ) 
                    {
                        Write-Host "  ME firmware update not required"
                        $result = $false
                    }
                    else
                    {
                        Write-Host "  ME update required!"
                            
                        <#
                         All ME firmware downloads from HP advise that the driver needs to be installed before:                            
                         "Intel Management Engine Components Driver must be installed before this package is installed."

                         The Intel detection tool has the element "ME_Driver_Installed" which we also read into $MEData.DriverInstalled
                         True/False value if the MEI driver is present on the computer"
                            
                         Therefore we will only execute the update if a driver was detected.
                        #>

                        if ( -not $MEData.DriverInstalled )
                        {
                            throw "Unable to start ME firmware update, Management Engine Interface (MEI) driver not detected!"
                        }
                        else
                        {
                            Write-Host "The ME update will take some time, please be patient."
                                
                            $updateFolder = Get-UpdateFolder -SettingsFilePath $settingsFile -Name "ME-$versionDesiredText"

                            $returnCode = Invoke-UpdateProgram -Settings $settings -SourcePath $updatefolder -FirmwareFile "" -PasswordFile "" -NoOutputRedirect
                                                        
                            if ( ($returnCode -eq 0) -or ($returnCode -eq 3010) )
                            {
                                Write-Host "ME update success"
                                $result = $true
                            }
                            else
                            {
                                $result = $null

                                if ( $null -eq $returnCode )
                                {
                                    throw "ME update failed"
                                }
                                else
                                {
                                    throw "ME update failed, update program returned code $($returnCode)"
                                }
                            }

                            #All done
                        }
                    }
                }    
            }                            
                                                                        
        }        
    }

 
    Write-HostSection -End "ME Update"
    
    return $result
}


function Write-HostSection()
{
    param(
        [Parameter(Mandatory = $False, ValueFromPipeline = $False)]
        [string]$Start = "",

        [Parameter(Mandatory = $False, ValueFromPipeline = $False)]
        [string]$End = "",

        [Parameter(Mandatory = $False, ValueFromPipeline = $False)]
        [switch]$NoEmptyLineAtEnd
    )

    $charlength = 65
    $output = ""
 
    if ( Test-String -HasData $Start )
    {
        $output = "***** $Start *****"
        $len = $charlength - ($output.Length)
    
        if ( $len -gt 0 ) 
        {
            $output += '*' * $len
        }
    }
    else
    {
        if ( Test-String -HasData $End )
        {
            Write-Host "Section -$($End)- finished"
        }
        
        $output = '*' * $charlength    
    }

    Write-Host $output

 
    #Add a single empty line if this is an END section
    if ( Test-String -HasData $End )
    {
        #Only write the empty line if NoEmptyLine is NOT set (=False)
        if ( $NoEmptyLineAtEnd -eq $False )
        {
            Write-Host "   "
        }
    }

}


function Get-StringWithBorder()
{
    param(
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)]
        [string]$Text = ""
    )

    $linewidth = 70 
    $char = "#"

    if ( $Text -ne "" )
    {
        $startOfLine = " $char$char "
        $endOfLine = "  $char$char"

        $line = "$startOfLine $Text"
   
        $len = $linewidth - ($line.Length) - ($startOfLine.Length + 1)   
        $line += " " * $len 
   
        $line += $endOfLine
    }
    else
    {
        $line = " $($char * ($linewidth-2))"
    }

    return $line
}


function Write-HostFramedText()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Heading,

        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        $Text,

        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Footer,
  
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)]
        [switch]$NoDoubleEmptyLines = $false

    )

    Write-Host " "
    if (!$NoDoubleEmptyLines) { Write-Host " " }
    Write-Host (Get-StringWithBorder)
    if (!$NoDoubleEmptyLines) { Write-Host (Get-StringWithBorder -Text " ") }
    Write-Host (Get-StringWithBorder -Text $Heading.ToUpper())
    Write-Host (Get-StringWithBorder -Text " ")
    if (!$NoDoubleEmptyLines) { Write-Host (Get-StringWithBorder -Text " ") }
 
    if ( ($Text -is [system.array]) )
    {
        foreach ($item in $text)
        {
            Write-Host (Get-StringWithBorder -Text "$($item.ToString())")
        }
        Write-Host (Get-StringWithBorder -Text " ")
    }
    else
    {
        if ( $Text -ne "" )
        {
            Write-Host (Get-StringWithBorder -Text "$($Text.ToString())")
            Write-Host (Get-StringWithBorder -Text " ")
        }
    }

    if (!$NoDoubleEmptyLines) { Write-Host (Get-StringWithBorder -Text " ") }
    Write-Host (Get-StringWithBorder -Text "$Footer")
    if (!$NoDoubleEmptyLines) { Write-Host (Get-StringWithBorder -Text " ") }
    Write-Host (Get-StringWithBorder)
    Write-Host " "
    if (!$NoDoubleEmptyLines) { Write-Host " " }
}


function Write-HostPleaseRestart()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Reason
    )

    Write-HostFramedText -Heading "Restart required" -Text $Reason -Footer "Please restart the computer as soon as possible."
}


function Write-HostOutputFromProgram()
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [string]$Content
    )

    if ( Test-String -IsNullOrWhiteSpace $content )
    {
        $Content = " (No content) "
    }

    Write-HostSection "::BEGIN:: $Name"   
    Write-Host $Content
    Write-HostSection "::END:: $Name"
}


##########################################################################
##########################################################################
##########################################################################

if ( -not $DebugMode ) 
{
    $header = "This script might alter your firmware and/or BIOS settings"
    $text = ""
    $footer = "You have 15 seconds to press CTRL+C to stop it."

    Write-HostFramedText -Heading $header -Text $text -Footer $footer -NoDoubleEmptyLines:$true

    Start-Sleep 15
}

 

#set returncode to error by default
$returncode = $ERROR_RETURN

try 
{
    #verify that our environment is ready
    Test-Environment | Out-Null

    #For performance reasons, copy the BCU to TEMP
    $BCU_EXE = Copy-FileToTemp $BCU_EXE_SOURCE

    #Test BCU can communicate with BIOS
    Test-BiosCommunication | Out-Null
  
    #We need to do the following in the correct order
    #
    #(1) BIOS Update - Because a possible TPM update requires an updated BIOS     
    #(2) ME Update - Because some BIOS version recommand an ME firmware update, e.g. for the ProDesk 600 G2 - https://ftp.hp.com/pub/softpaq/sp78001-78500/sp78294.html    
    #(3a) TPM BIOS Changes - Modern systems do not allow an TPM Update in case SGX or TXT is activated    
    #(3b) TPM Update - Because some settings might require a newer TPM firmware    
    #(4) BIOS Password change - Because some BIOS settings (TPM Activation Policy for example) will not work until a password is set    
    #(5) BIOS Settings

    Write-Host "Collecting system information..."

    $compSystem = Get-CimInstance Win32_ComputerSystem -OperationTimeoutSec 10

    $Model = Get-PropertyValueSafe $compSystem "Model" ""
    $SKU = Get-PropertyValueSafe $compSystem "SystemSKUNumber" ""
    $computername = $env:computername

    Write-Host " "
    Write-Host "  Name.........: $computername"
    Write-Host "  Model........: $Model"
    Write-Host "  SKU..........: $SKU"

    ########################################
    #Retrieve and parse BIOS version 

    #We could use a direct call to BCU, but this does not work for old models
    #because it includes the data like this: "L01 v02.53  10/20/2014"
    #This breaks the XML parsing from Get-BiosValue because BCU does not escape the slash   
    #So we get the data directly from Windows 
    $BIOSRaw = (Get-CimInstance Win32_Bios).SMBIOSBIOSVersion
  
    #replace $NULL in case we were unable to retireve the data
    if ( $null -eq $BIOSRaw ) 
    { 
        $BIOSRaw = "Failed" 
    }
    $BIOSDetails = Get-BIOSVersionDetails $BIOSRaw

    Write-Host "  BIOS (Raw)...: $BIOSRaw"

    if ( !($BIOSDetails.Parsed) )
    {
        Write-Warning "BIOS Data could not be parsed!"
    }
    else
    {
        Write-Host "  BIOS Family..: $($BIOSDetails.Family)"
        Write-Host "  BIOS Version.: $(Get-VersionTextAndNumerical $BIOSDetails.VersionText $BIOSDetails.Version)"
    }


    ########################################
    #Retrieve and parse TPM data

    $TPMDetails = Get-TPMDetails
    if ( !($TPMDetails.Parsed) ) 
    {
        Write-Host "  No TPM found or data could not be parsed."
    } 
    else
    {
        Write-Host "  TPM Vendor...: $($TPMDetails.ManufacturerId)"
        Write-Host "  TPM Firmware.: $(Get-VersionTextAndNumerical $TPMDetails.VersionText $TPMDetails.Version)"
        Write-Host "  TPM Spec.....: $(Get-VersionTextAndNumerical $TPMDetails.SpecVersionText $TPMDetails.SpecVersion)"
    }
    Write-Host " "


    #Locate Model folder
    $modelfolder = Get-ModelFolder -ModelsFolder $MODELS_PATH
        
    #Now search for the password
    $foundPwdFile = Test-BiosPasswordFiles -PwdFilesFolder $PWDFILES_PATH
      
    #Copy the password file locally 
    #IMPORTANT: If we later on change the password this file in TEMP will be deleted!
    #           Never set $CurrentPasswordFile to a file on the source!
    $CurrentPasswordFile = Copy-PasswordFileToTemp -SourcePasswordFile $foundPwdFile
                
    #Now we have everything ready to make changes to this system
    
    #If ActivateUEFIBoot is set, we only perform this change and nothing else
    if ( $ActivateUEFIBoot )
    {
        ########################
        #Switch UEFI Boot mode

        $uefiModeSwitched = Set-UEFIBootMode -ModelFolder $modelfolder -PasswordFile $CurrentPasswordFile

        $returncode = 0
    }
    else
    {
        ########################
        #Normal process 

        $biosUpdated = $false
        $biosUpdated = Update-BiosFirmware -Modelfolder $modelfolder -BIOSDetails $BIOSDetails -PasswordFile $CurrentPasswordFile

        if ( $biosUpdated ) 
        {
            #A BIOS update was done. Stop and continue later on
            $ignored = Write-HostPleaseRestart -Reason "A BIOS update was performed."                       
            $returncode = $ERROR_SUCCESS_REBOOT_REQUIRED
        }
        else 
        {
            #ME update/check                    
            $mefwUpdated = $false                     
            $mefwUpdated = Update-MEFirmware -Modelfolder $modelfolder

            if ( $mefwUpdated )
            {
                $ignored = Write-HostPleaseRestart -Reason "A ME firmware update was performed."              
                $returncode = $ERROR_SUCCESS_REBOOT_REQUIRED
            }
            else
            {
                #TPM Update
                $tpmUpdated = $false
                $tpmUpdated = Update-TPMFirmware -Modelfolder $modelfolder -TPMDetails $TPMDetails -PasswordFile $CurrentPasswordFile

                if ( $tpmUpdated )
                {
                    $ignored = Write-HostPleaseRestart -Reason "A TPM update was performed."              
                    $returncode = $ERROR_SUCCESS_REBOOT_REQUIRED
                }
                else
                {                     
                    #BIOS Password update
                    $updatedPasswordFile = Set-BiosPassword -ModelFolder $modelFolder -PwdFilesFolder $PWDFILES_PATH -CurrentPasswordFile $CurrentPasswordFile

                    if ( $null -ne $updatedPasswordFile )
                    {
                        #File has changed - remove old password file
                        $ignored = Remove-FileExact -Filename $CurrentPasswordFile
                        $CurrentPasswordFile = Copy-PasswordFileToTemp -SourcePasswordFile $updatedPasswordFile
                    }

                    #Apply BIOS Settings
                    $settingsApplied = Update-BiosSettings -ModelFolder $modelfolder -PasswordFile $CurrentPasswordFile

                    if ( ($settingsApplied -lt 0) )
                    {
                        Write-Warning "Applying BIOS settings completed with errors"
                    }

                    $returncode = 0

                    <#
                        Here we could normaly set the REBOOT_REQUIRED variable if BCU reports changes, but BCU 
                        does also report changes if a string value (e.g. Ownership Tag) is set to the *SAME*
                        value as before. 
                 
                        if ( $settingsApplied -ge 1 )
                        {
                          $ignored=Write-HostPleaseRestart -Reason "BIOS settings have been changed."   
                          $returncode=$ERROR_SUCCESS_REBOOT_REQUIRED
                        }
                        else
                        {
                          #no changes for BIOS setting
                          $returncode=0
                        }
                    #>                                    

                }
                
            }
            
        }
             
    }
        

    #MAIN PROCESS
    
    

}
catch
{
    Write-Error "$($_.Exception.Message)`n$($_.InvocationInfo.PositionMessage)`n$($_.ScriptStackTrace)" -Category OperationStopped
    #Not used right now: `n$($_.Exception.StackTrace)

    $returncode = $ERROR_RETURN
}


#Clean up
$ignored = Remove-FileExact -Filename $CurrentPasswordFile
$ignored = Remove-FileExact -Filename $BCU_EXE

Write-Host "BIOS Sledgehammer finished, return code $returncode."
Write-Host "Thank you, please come again!"

if ( $DebugMode ) 
{
    #set it back to old value
    $VerbosePreference = $VerbosePreference_BeforeStart
}
else
{
    if ( $WaitAtEnd )
    {
        Write-Host "Waiting 30 seconds..."
        Start-Sleep -Seconds 30
    }
}

# Stop logging
Stop-TranscriptIfSupported


Exit-Context $returncode

#ENDE 