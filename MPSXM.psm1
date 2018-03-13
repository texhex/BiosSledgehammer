# Michael's PowerShell eXtension Module
# Version 3.27.1
# https://github.com/texhex/MPSXM
#
# Copyright © 2010-2018 Michael 'Tex' Hex 
# Licensed under the Apache License, Version 2.0. 
#
# Import this module in case it is located in the same folder as your script:
# Import-Module "$PSScriptRoot\MPSXM.psm1"
#
# In case you edit this file, new functions will not be found by the current PS session - use -Force in this case:
# Import-Module "$PSScriptRoot\MPSXM.psm1" -Force
#
#
# Before adding a new function, please see
# [Approved Verbs for Windows PowerShell Commands] http://msdn.microsoft.com/en-us/library/ms714428%28v=vs.85%29.aspx
#
# To run a PowerShell script from the command line, use
# powershell.exe [-NonInteractive] -ExecutionPolicy Bypass -File "C:\Script\DoIt.ps1"
#
#
# Useful PowerShell data types:
#
# #Array:
# $array = @()
#
# #Array with init:
# $array2= @(1,2,4,8,16)
#
# #Arrays are fixed size, so += something will create a new array. Use ArrayList if you plan to dynamically change it
# $arrayList = New-Object System.Collections.ArrayList
#
# #Hashtable (Key/Value pairs)
# $hashtable = @{}
#
# #Hashtable with init
# $hashtable2 = @{ Key1 = "Value 1"; Key2 = "Value2"; }
#
# #Ordered dictionary - works the same as hashtable but the order of the keys can be defined 
# $dictionary = [Ordered]@{ Key1 = "Value 1"; Key2 = "Value2"; }
#
#
# Common header for your script:
<#

#(Script description)
#(Your name)
#(Version of script)

#This script requires PowerShell 4.0 or higher 
#requires -version 4.0

#Guard against common code errors
Set-StrictMode -version 2.0

#Terminate script on errors 
$ErrorActionPreference = 'Stop'

#Import 
Import-Module "$PSScriptRoot\MPSXM.psm1" -Force

#>
#
#


#requires -version 4.0

#Guard against common code errors
#We do not use "Latest" because the rules are not documented
Set-StrictMode -version 2.0

#Terminate script on errors 
$ErrorActionPreference = 'Stop'


#Next major version notes:
# Get-StringIsNullOrWhiteSpace() should be deleted (replaced with Test-String)
# Get-StringHasData() should be deleted (replaced with Test-String)
# Get-RunningInISE() should be deleted (replaced with Test-InISE)
# Add-RegistryValue() should be be deleted (replaced with Set-RegistryValue)

Function Get-CurrentProcessBitness()
{
    
    #.SYNOPSIS
    #Returns information about the current powershell process.
    #
    #.PARAMETER Is64bit
    #Returns $True if the current script is running as 64-bit process.
    #
    #.PARAMETER Is32bit
    #Returns $True if the current script is running as 32-bit process.
    #
    #.PARAMETER IsWoW
    #Returns $True if the current script is running as 32-bit process on a 64-bit machine (Windows on Windows).
    #
    #.OUTPUTS
    #Boolean, depending on parameter

    [OutputType([bool])] 
    param (
        [Parameter(ParameterSetName = "32bit", Mandatory = $True)]
        [switch]$Is32bit,

        [Parameter(ParameterSetName = "WoW", Mandatory = $True)]
        [switch]$IsWoW,

        [Parameter(ParameterSetName = "64bit", Mandatory = $True)]
        [switch]$Is64bit
    )

    switch ($PsCmdlet.ParameterSetName)
    { 

        "64bit"
        {  
            $result = $false

            if ( [System.Environment]::Is64BitOperatingSystem) 
            {
                if ( [System.Environment]::Is64BitProcess ) 
                {
                    $result = $true
                }
            }

            return $result
        } 

        "32bit"
        {
            return !([System.Environment]::Is64BitProcess)  
        }

        "WoW"
        {
            #WoW is only support on 64-bit
      
            $result = $false 
            if ( [System.Environment]::Is64BitOperatingSystem) 
            {
                if ( Get-CurrentProcessBitness -Is32bit )
                {
                    #32-bit Process on a 64-bit machine -> WOW on
                    $result = $true
                }
            }

            return $result
        }

    } #switch

   
}


Function Get-OperatingSystemBitness()
{
    
    #.SYNOPSIS
    #Returns information about the current operating system
    #
    #.PARAMETER Is64bit
    #Returns $True if the current operating system is 64-bit
    #
    #.PARAMETER Is32bit
    #Returns $True if the current operating system is 32-bit 
    #
    #.OUTPUTS
    #Boolean, depending on parameter

    [OutputType([bool])] 
    param (
        [Parameter(ParameterSetName = "32bit", Mandatory = $True)]
        [switch]$Is32bit,

        [Parameter(ParameterSetName = "64bit", Mandatory = $True)]
        [switch]$Is64bit
    )

    switch ($PsCmdlet.ParameterSetName)
    { 

        "64bit"
        {  
            $result = $false

            if ( [System.Environment]::Is64BitOperatingSystem) 
            {
                $result = $true
            }

            return $result
        } 

        "32bit"
        {
            return !([System.Environment]::Is64BitOperatingSystem)  
        }

    } #switch
   
}


Function Get-StringIsNullOrWhiteSpace()
{
   
    #.SYNOPSIS
    #Returns true if the string is either $null, empty, or consists only of white-space characters (uses [Test-String -IsNullOrWhiteSpace] internally)
    #
    #.PARAMETER String
    #The string value to be checked
    #
    #.OUTPUTS
    #$true if the string is either $null, empty, or consists only of white-space characters, $false otherwise

    [OutputType([bool])] 
    param (
        [Parameter(Mandatory = $True, Position = 1)]
        [AllowEmptyString()] #we need this or PowerShell will complain "Cannot bind argument to parameter 'string' because it is an empty string." 
        [string]$string
    )

    return Test-String -IsNullOrWhiteSpace $string
}


Function Get-StringHasData()
{
   
    #.SYNOPSIS
    #Returns true if the string contains data (does not contain $null, empty or only white spaces). Uses [Test-String -HasData] internally.
    #
    #.PARAMETER string
    #The string value to be checked
    #
    #.OUTPUTS
    #$true if the string is not $null, empty, or consists only of white space characters, $false otherwise

    [OutputType([bool])] 
    param (
        [Parameter(Mandatory = $True, Position = 1)]
        [AllowEmptyString()] #we need this or PowerShell will complain "Cannot bind argument to parameter 'string' because it is an empty string." 
        [string]$string
    )

    return Test-String -HasData $string
}


Function Test-String()
<#
 -IsNullOrWhiteSpace:
   Helper function for [string]::IsNullOrWhiteSpace - http://msdn.microsoft.com/en-us/library/system.string.isnullorwhitespace%28v=vs.110%29.aspx
 

   Test-String "a" -IsNullorWhitespace #false
   Test-String $null -IsNullorWhitespace #$true
   Test-String "" -IsNullorWhitespace #$true
   Test-String " " -IsNullorWhitespace #$true
   Test-String "     " -IsNullorWhitespace #$true

 -HasData
   String is not IsNullOrWhiteSpace

 -Contains
   Standard Contains() or IndexOf

 -StartsWith
   Uses string.StartsWith() with different parameters
#> 
{   
    #.SYNOPSIS
    #Tests the given string for a condition 
    #
    #.PARAMETER String
    #The string the specified operation should be performed on
    #
    #.PARAMETER IsNullOrWhiteSpace
    #Returns true if the string is either $null, empty, or consists only of white-space characters.
    #
    #.PARAMETER HasData
    #Returns true if the string contains data (not $null, empty or only white spaces)
    #
    #.PARAMETER Contains
    #Returns true if string contains the text in SearchFor. A case-insensitive (ABCD = abcd) is performed by default. 
    #
    #.PARAMETER StartsWith
    #Returns true if the string starts with the text in SearchFor. A case-insensitive (ABCD = abcd) is performed by default. 
    #
    #.PARAMETER SearchFor
    #The string beeing sought
    #
    #.PARAMETER CaseSensitive
    #Perform an operation that respect letter casing, so [ABC] is different from [aBC]. 
    #
    #.OUTPUTS
    #bool

    [OutputType([bool])]  
    param (
        [Parameter(Mandatory = $false, Position = 1)] #false or we can not pass empty strings
        [string]$String = $null,

        [Parameter(ParameterSetName = "HasData", Mandatory = $true)]
        [switch]$HasData,

        [Parameter(ParameterSetName = "IsNullOrWhiteSpace", Mandatory = $true)]
        [switch]$IsNullOrWhiteSpace,
  
        [Parameter(ParameterSetName = "Contains", Mandatory = $true)]
        [switch]$Contains,

        [Parameter(ParameterSetName = "StartsWith", Mandatory = $true)]
        [switch]$StartsWith,

        [Parameter(ParameterSetName = "Contains", Position = 2, Mandatory = $false)] #$False or we can not pass an empty string in
        [Parameter(ParameterSetName = "StartsWith", Position = 2, Mandatory = $false)]         
        [string]$SearchFor,

        [Parameter(ParameterSetName = "Contains", Mandatory = $false)] 
        [Parameter(ParameterSetName = "StartsWith", Mandatory = $false)] #$False or we can not pass an empty string in
        [Switch]$CaseSensitive = $false
    )

    $result = $null

    switch ($PsCmdlet.ParameterSetName)
    {  
        "IsNullOrWhiteSpace"
        {
            if ([string]::IsNullOrWhiteSpace($String)) 
            {
                $result = $true
            }
            else
            {
                $result = $false
            }  
        }    

        "HasData"
        {
            $result = -not (Test-String -IsNullOrWhiteSpace $String)
        }    

        "Contains"
        {
            if ( Test-String -IsNullOrWhiteSpace $SearchFor)
            {
                $result = $false                
            }
            else
            {
                if ( $CaseSensitive ) 
                {
                    $result = $String.Contains($SearchFor)
                }
                else
                {
                    #from this answer on StackOverFlow: http://stackoverflow.com/a/444818/612954
                    # by JaredPar - http://stackoverflow.com/users/23283/jaredpar

                    #and just for reference: These lines do NOT work.
                    #Only this blog post finally told me what the correct syntax is: http://threemillion.net/blog/?p=331
                    #$index=$String.IndexOf($SearchFor, ([System.StringComparer]::OrdinalIgnoreCase))
                    #$index=$String.IndexOf($SearchFor, "System.StringComparison.OrdinalIgnoreCase")       
        
                    #We could also use [StringComparison]::CurrentCultureIgnoreCase but it seems OrdinalIgnoreCase does the job also
                    $result = ( $String.IndexOf($SearchFor, [StringComparison]::OrdinalIgnoreCase) ) -ge 0
                }
            }
        }

        "StartsWith"
        {
            
            if ( Test-String -IsNullOrWhiteSpace $SearchFor)
            {
                $result = $false                              
            }
            else
            {
                if ( $CaseSensitive ) 
                {
                    $result = $String.StartsWith($SearchFor)
                }
                else
                {
                    $result = $String.StartsWith($SearchFor, [StringComparison]::OrdinalIgnoreCase)
                }
            }
        }


    }
  
    return $result
}


#Yes, I'm aware of $env:TEMP but this will always return a 8+3 path, e.g. C:\USERS\ADMIN~1\AppData..."
#This function returns the real path without that "~" garbage

Function Get-TempFolder() 
{   
    #.SYNOPSIS
    # Returns a path to the temporary folder without any (8+3) paths in it. The path does not include a "\" at the end. 
    #
    #.OUTPUTS
    # Path to temporary folder without an ending "\"

    $temp = [System.IO.Path]::GetTempPath()
    if ( $temp.EndsWith("\") )
    {
        $temp = $temp.TrimEnd("\")
    }

    return $temp
}


Function Get-ModuleAvailable()
{
    <#
  .SYNOPSIS
  Returns true if the module exist; it uses a a method that is about 10 times faster then using Get-Module -ListAvailable

   .PARAMETER name
  The name of the module to be checked

  .OUTPUTS
  $true if the module is available, $false if not
#>
    [OutputType([bool])] 
    param(
        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
 
    #First check if the requested module is already available in this session
    if (-Not (Get-Module -name $name))
    {
        #The correct way would be to now use [Get-Module -ListAvailable] like this:
     
        #Creating the list of available modules takes some seconds; Therfore use a cache on module level:
        #if ($script:Test_MPXModuleAvailable_Cache -eq $null) {
        #   $script:Test_MPXModuleAvailable_Cache=Get-Module -ListAvailable | ForEach-Object {$_.Name}
        #}
        #if ($Test_MPXModuleAvailable_Cache -contains $name)     
        #{
        #  #module is available and will be loaded by PowerShell when requested
        #  return $true
        #} else { 
        #  #this module is not available
        # return $false      
        #}

        #However, this function is a performance killer as it reads every cmdlet, dll, and whatever
        #from any module that is available. 
        #
        #Therefore we will simply try to import the module using import-module on local level 
        #and then return if this has worked. This way, only the module requested is fully loaded.
        #Since we only load it to the local level, we make sure not to change the calling level
        #if the caller does not want that module to be loaded. 
        #
        #Given that the script (that has called us) will the use a cmdlet from the module,
        #the module is already loaded in the runspace and the next call to this function will be
        #a lot faster since get-module will then return $TRUE.

        $mod = Import-Module $name -PassThru -ErrorAction SilentlyContinue -Scope Local
        if ($mod -ne $null) 
        {
            return $true
        } 
        else 
        {
            return $false
        }

    }
    else
    { 
        #module is already available in this runspace
        return $true 
    }

} 


Function Get-ComputerLastBootupTime()
{
    <#
  .SYNOPSIS
  Returns the date and time of the last bootup time of this computer.

  .OUTPUTS
  DateTime (Kind = Local) that is the last bootup time of this computer
#>    
    [OutputType([datetime])] 
    #param(
    #)

    $obj = Get-CIMInstance Win32_OperatingSystem -Property "LastBootupTime" 
    return $obj.LastBootUpTime
}




Function Start-TranscriptTaskSequence()
{
    <#
  .SYNOPSIS
  If the scripts runs in MDT or SCCM, the transcript will be stored in the path LOGPATH defines. If not, C:\WINDOWS\TEMP is used.

  .PARAMETER NewLog
  When set, will create a log file every time a transcript is started 

  .OUTPUTS
  None
#>    
    param(
        [Parameter(Mandatory = $False)]
        [switch]$NewLog = $False
    )

    try
    {
        $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
        $logPath = $tsenv.Value("LogPath")
        Write-Verbose "Start-TranscriptTaskSequence: Running in task sequence, using folder [$logPath]"
    }
    catch
    {
        $logPath = $env:windir + "\temp"
        Write-Verbose "Start-TranscriptTaskSequence: This script is not running in a task sequence, will use [$logPath]"
    }

    $logName = Split-Path -Path $myInvocation.ScriptName -Leaf   
    Write-Verbose "Start-TranscriptTaskSequence: Using logfile $($logName)"
 
    if ( $NewLog ) 
    {
        Start-TranscriptIfSupported -Path $logPath -Name $logName -NewLog 
    }
    else
    {
        Start-TranscriptIfSupported -Path $logPath -Name $logName
    }

}


Function Start-TranscriptIfSupported()
{
    <#
  .SYNOPSIS
  Starts a transscript, but ignores if the host does not support it.

  .PARAMETER Path
  The path where to store the transcript. If empty, the %TEMP% folder is used.
  
  .PARAMETER Name
  The name of the log file. If empty, the file name of the calling script is used.

  .PARAMETER NewLog
  Create a new log file every time a transcript is started ([Name].log-XX.txt)

  .OUTPUTS
  None
#>    
    param(
        [Parameter(Mandatory = $False, Position = 1)]
        [string]$Path = $env:TEMP,

        [Parameter(Mandatory = $False, Position = 2)]
        [string]$Name,
  
        [Parameter(Mandatory = $False)]
        [switch]$NewLog = $False
    )

    if ( Test-String -IsNullOrWhiteSpace $Name )
    {
        $Name = Split-Path -Path $myInvocation.ScriptName -Leaf   
    }

    if ( -not (Test-DirectoryExists $Path) )
    {
        write-error "Logfile path [$Path] does not exist, defaulting to [$($env:TEMP)]" -ErrorAction Continue
        $Path = $env:TEMP
    }
 
    $logFileTemplate = "$($Name).log"
    $extension = "txt" #always use lower case chars only!
 
    #only needed if we need to add something
    $fileNameTail = ""

    if ( $NewLog )
    {
        #we need to create log file like <SCRIPTNAME.ps>-Log #001.txt
        $filter = "$($logFileTemplate)-??.$extension"

        [uint32]$value = 1

        #If the path does not exist, this line will crash with "A parameter can not be found that maches parameter FILE" which does not make any sense IMHO
        try
        {
            $existing_files = Get-ChildItem -Path $Path -File -Filter $filter -Force -ErrorAction Stop
        }
        catch
        {
            throw "Unable to list files in path [$Path] with filter [$filter]: $($_.Exception.Message)"            
        }
   
        #In case we get $null this means that no files were found. Nothing more to 
        if ( $existing_files -ne $null )
        {
            #at least one other file exists. Reorder so the log file with the highest name is at the end
            $existing_files = $existing_files | Sort-Object -Property "Name"
    
            #check if the result is one file or not
            if ( $existing_files -is [array] )
            {
                $temp = $existing_files[$existing_files.Count - 1].Name
            }
            else
            {
                $temp = $existing_files.Name
            }

            #now access the last object in the list
            $temp = $temp.ToLower()

            #cut the ".txt" part from the end
            $temp = $temp.TrimEnd(".$extension")
    
            #Extract the the last two digitis, e.g. "13"
            $curValueText = $temp.Substring($temp.Length - 2, 2)

            #convert to int so we can calculate with it. Maybe this will fail in which case we default to 99
            try
            {
                [uint32]$value = $curValueText
                #add one to the value
                $value++
            }
            catch
            { 
                $value = 99 
            }
    
            #Final check. If the value is > 99, use 99 anyway
            if ( $value -gt 99 )
            {
                $value = 99
            }

            #Done calculating $value
        }


        #Ensure that we have leading zeros if required
        $fileNameTail = "-{0:D2}" -f $value
    }


    $logFile = "$Path\$($logFileTemplate)$($filenameTail).$extension"

    try 
    {
        write-verbose "Trying to execute Start-Transcript for $logFile"
        Start-Transcript -Path $logfile
    }
    catch [System.Management.Automation.PSNotSupportedException]
    {
        # The current PowerShell Host doesn't support transcribing
        write-host "Start-TranscriptIfSupported: The current PowerShell host doesn't support transcribing; no log will be generated to [$logfile]"
    }
}


Function Stop-TranscriptIfSupported()
{
    <#
  .SYNOPSIS
  Stops a transscript, but ignores if the host does not support it.

  .OUTPUTS
  None
#>    

    try 
    {
        Stop-Transcript
    }
    catch [System.Management.Automation.PSNotSupportedException] 
    {
        write-host "Stop-TranscriptIfSupported WARNING: The current PowerShell host doesn't support transcribing. No log was generated."
    }
}


Function Show-MessageBox() 
{
    <#
  .SYNOPSIS
  Shows the message to the user using a message box.

  .PARAMETER Message
  The message to be displayed inside the message box.

  .PARAMETER Titel
  The title for the message box. If empty, the full script filename is used.

  .PARAMETER Critical
  Show an critical icon inside the message box. If not set, an information icon is used.

  .PARAMETER Huge
  Adds extra lines to the message to ensure the message box appears bigger.

  .OUTPUTS
  None
#>  
    param(
        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $False, Position = 2)]
        [string]$Titel,

        [Parameter(Mandatory = $False)]
        [switch]$Critical,

        [Parameter(Mandatory = $False)]
        [switch]$Huge
    )

    #make sure the assembly is loaded
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
  
    $type = [System.Windows.Forms.MessageBoxIcon]::Information
    if ( $Critical )
    {
        $type = [System.Windows.Forms.MessageBoxIcon]::Error
    }

    if ( Test-String -IsNullOrWhiteSpace $Titel ) 
    {
        $Titel = $myInvocation.ScriptName
    }

    if ( $Huge ) 
    {
        $crlf = "`r`n"    
        $crlf5 = "$crlf$crlf$crlf$crlf$crlf" 
        $Message = "$Message $crlf5$crlf5$crlf5$crlf5$crlf5$crlf5"
    }

    #display message box
    $ignored = [System.Windows.Forms.MessageBox]::Show($message, $Titel, 0, $type)
}


Function Get-RandomString()
#From http://stackingcode.com/blog/2011/10/27/quick-random-string
# by Adam Boddington
{ 
    <#
  .SYNOPSIS
  Returns a random string (only Aa-Zz and 0-9 are used).

  .PARAMETER Length
  The length of the string that should be generated.

  .OUTPUTS
  Generated random string.
#> 
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [int]$Length
    )
    $set = "abcdefghijklmnopqrstuvwxyz0123456789".ToCharArray()
    $result = ""
  
    for ($x = 0; $x -lt $Length; $x++) 
    {
        $result += $set | Get-Random
    }
  
    return $result
}



Function Read-StringHashtable() 
<#
 This is most basic way I could think of to represent a hash table with single string values as a file 

 ; Comment (INI style)
 # also understood as comment (PowerShell style)
 ;Still a comment
 ;Also this.

 Key1==Value1
 Key2==Value2
 ...
#>
{
    
    #.SYNOPSIS
    #Reads a hashtable from a file where the Key-Value pairs are stored as Key==Value
    #
    #.PARAMETER File
    #The file to read the hashtable from
    #
    #.OUTPUTS
    #Hashtable

    [OutputType([Hashtable])]  
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [string]$File
    )

    $result = @{}
    write-verbose "Reading hashtable from $file"

    if ( Test-Path $file )
    {     
        $data = Get-Content $file -Raw
        $lines = $data -split "`n" #we split at LF, not CR+LF in case someone has used the wrong line ending AGAIN

        if ( ($lines -eq $null) -or ($lines.Count -eq 0) )
        {
            #OK, this didn't worked. Maybe someone used pure CR?
            $lines = $data -split "`r"
        }
   
        foreach ($line in $lines) 
        {
            #just to make sure that nothing was left over 
            $line = $line -replace "´r", ""
            $line = $line -replace "´n", ""
            $line = $line.Trim()

            if ( !($line.StartsWith("#")) -and !($line.StartsWith(";")) -and !(Test-String -IsNullOrWhiteSpace $line) )
            {
                #this has to be a setting
                $setting = $line -split "=="

                if ( $setting.Count -ne 2 )
                {
                    throw New-Exception -InvalidFormat -Explanation "Error parsing [$line] as key-value pair - did you forgot to use '=='?"             
                }
                else
                {
                    $name = $setting[0].Trim()
                    $value = $setting[1].Trim()
            
                    #I'm unsure if this information is of any use
                    #write-verbose "Key-Value pair found: [$name] : [$value]"

                    if ( $result.ContainsKey($name) )
                    {
                        throw New-Exception -InvalidOperation "Can not add key [$name] (Value: $value) because a key of this name already exists"
                    }
                    else 
                    {
                        $result.Add($name, $value)
                    }
                }         
            }
        }
    }
    else
    {
        throw New-Exception -FileNotFound "The file [$file] does not exist or is not accessible"
    }
 
    return $result
}


Function ConvertTo-HumanizedBytesString()
#The verb "Humanize" is taken from this great project: [Humanizer](https://github.com/MehdiK/Humanizer)
#Idea from [Which Disk is that volume on](http://www.uvm.edu/~gcd/2013/01/which-disk-is-that-volume-on/) by Geoff Duke 
{
    <#
  .SYNOPSIS
  Returns a string optimized for readability.

  .PARAMETER bytes
  The value of bytes that should be returned as humanized string.

  .OUTPUTS
  A humanized string that is rounded (no decimal points) and optimized for readability. 1024 becomes 1kb, 179111387136 will be 167 GB etc. 
#>
    [OutputType([String])]  
    param (
        [Parameter(Mandatory = $True, Position = 1)]
        [AllowEmptyString()] 
        [int64]$bytes
    )

    #Better set strict mode on function scope than on module level
    Set-StrictMode -version 2.0

    #Original code was :N2 which means "two decimal points"
    if ( $bytes -gt 1pb ) { return "{0:N0} PB" -f ($bytes / 1pb) }
    elseif ( $bytes -gt 1tb ) { return "{0:N0} TB" -f ($bytes / 1tb) }
    elseif ( $bytes -gt 1gb ) { return "{0:N0} GB" -f ($bytes / 1gb) }
    elseif ( $bytes -gt 1mb ) { return "{0:N0} MB" -f ($bytes / 1mb) }
    elseif ( $bytes -gt 1kb ) { return "{0:N0} KB" -f ($bytes / 1kb) } 
    else { return "{0:N0} Bytes" -f $bytes } 

}


Function ConvertTo-Version()
{
    <#
  .SYNOPSIS
  Returns a VERSION object with the version number converted from the given text.

  .PARAMETER text
  The input string to be converted, e.g. 1.3.44.

  .PARAMETER RespectLeadingZeros
  Respect leading zeros by shifting the parts right, e.g. 1.02.3 becomes 1.0.2.3.

  .OUTPUTS
  A version object or $NULL if the text could not be parsed
#>
    [OutputType([System.Version])]  
    param(
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)]
        [string]$Text = "",

        [Parameter(Mandatory = $False, ValueFromPipeline = $True)]
        [switch]$RespectLeadingZeros = $false
    )   

    try
    {
        [version]$version = $Text
    }
    catch
    {
        $version = $null
    }

    if ( $version -ne $null) 
    {
        #when we are here, the version could be parsed 
        if ( $RespectLeadingZeros)
        {
            #Reminder: Version object defines Major.Minor.Build.Revision      

            #In case the version only contains a major version, there is nothing to take care of.
            #Whoever wants to have leading zeros for a major version respected should be killed. 
            if ( $version.Minor -gt -1 ) 
            {
                $verarray = @()
                $tokens = $Text.Split(".")         

                #always add the major version as is
                $verArray += [int]$tokens[0]

                if ( $tokens.Count -ge 2) 
                {
                    $minor = $tokens[1]
                    if ( $minor.StartsWith(0) )
                    {
                        #Add 0 as minor and the minor version as Build
                        $verArray += 0               
                    }
                    $verArray += [int]$minor

                    if ( $tokens.Count -ge 3) 
                    {
              
                        $build = $tokens[2]
                        if ( $build.StartsWith(0) ) 
                        {
                            $verArray += 0               
                        }
                        $verArray += [int]$build


                        if ( $tokens.Count -ge 4)
                        {
                            $revision = $tokens[3]
                            if ( $revision.StartsWith(0) ) 
                            { 
                                $verArray += 0                   
                            }
                            $verArray += [int]$revision
                        }
                    }
                }


                #Turn the array to a string
                $verString = ""
                foreach ($part in $verarray)
                {
                    $verString += "$part."
                }
                $verString = $verString.TrimEnd(".")


                #Given that version can only hold Major.Minor.Build.Revision, we need to check if we have four or less entries
                if ( $verArray.Count -ge 5 )
                {
                    throw New-Exception -InvalidArgument "Parsing given text resulted in a version that is incompatible with System.Version ($verString)"
                }
                else
                {                                 
                    $versionNew = New-Object System.Version $verarray
                    $version = $versionNew
                }


                #all done
            }
        }

    }

    return $version
} 


Function Exit-Context()
{
    <#
  .SYNOPSIS
  Will exit from the current context and sets an exit code. Nothing will be done when running in ISE.

  .PARAMETER ExitCode
  The number the exit code should be set to.

  .PARAMETER Force
  Will enfore full exit by using ENVIRONMENT.Exit()

  .OUTPUTS
  None
#>    
    param(
        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [int32]$ExitCode,

        [Parameter(Mandatory = $False)]
        [switch]$Force = $False
    )

    write-verbose "Exit-Context: Will exit with exit code $ExitCode"

    if ( Get-RunningInISE ) 
    {
        write-host "Exit-Context WARNING: Will NOT exit, because this script is running in ISE. Exit code: $ExitCode."
    }
    else 
    {
        #now what to do.... 
        #see https://www.pluralsight.com/blog/it-ops/powershell-terminating-code-execution

        if ( $Force )
        {
            #use the "nuclear way"...
            $ignored = [Environment]::Exit($ExitCode)
        }
   
        #This is also possible...
        #$host.SetShouldExit($returncode)  

        exit $ExitCode
    }
} 


Function Get-QuickReference()
{
    <#
  .SYNOPSIS
  Returns a quick reference about the given function or all functions in the module. The text returned includes function name, call syntax and parameters extracted from the function itself. 
  If you are on GitHub: the entire reference page was generated with it.

  .PARAMETER Name
  Name of the function or the module to generate a quick reference

  .PARAMETER Module
  Name specifies a module, a quick reference for all functions in the module should be generated 

  .PARAMETER SortByNoun
  If a module is given, the functions are sorted by verb (e.g. all Get-xxx together, all Set-xxx together). This can be changed to be sorted by Noun, the second part of a function.

  .PARAMETER Output
  If the output should be a string (default), CommonMark or the real objects

  .OUTPUTS
  String
#>
    param (
        [Parameter(Mandatory = $True, Position = 1)]
        [string]$Name,

        [Parameter(Mandatory = $False)]
        [ValidateSet('String', 'CommonMark', 'Objects')]
        [System.String]$Output = "String",

        [Parameter(Mandatory = $False)]
        [switch]$Module,

        [Parameter(Mandatory = $False)]
        [switch]$SortByNoun

    )
    $qrList = @()

    if ( -not $Module )
    {
        $functions = Get-Command $Name
    }
    else
    {
        $functions = Get-Command -Module $Name
    }


    foreach ($function in $functions)
    {
        #generate result object 
        $QuickRef = [PSObject]@{"Name" = ""; "Synopsis" = ""; "Syntax" = @(); "Parameter" = @(); }

        #We need to respect the order of the parameters in the list, so we can't use a hashtable
        #  $QuickRef.Parameter=@{}
        #Or an OrderedDictionary
        #  $QuickRef.Parameter=New-Object "System.Collections.Specialized.OrderedDictionary"
        #A normal generic dictionary will do
        #  $QuickRef.Parameter=New-Object "System.Collections.Generic.Dictionary[string,string]"
        $QuickRef.Parameter = New-Dictionary -StringPairs
      
        $functionName = $function.Name   
   
        $help = get-help $functionName

        $QuickRef.Name = $function.Name.Trim()
        $QuickRef.Synopsis = [string]$help.Synopsis.Trim() #aka "Description"
 
        ##################################
        # Syntax
        $syntax = $help.Syntax | Out-String   
        $syntax = $syntax.Trim()
   
        #check if we have more than one entry in syntax
        $syntaxTokens = $syntax.Split("`n")
        foreach ($syntaxToken in $syntaxTokens)
        {
            #most of the function do not support common params, so we leave this out
            $syntaxToken = $syntaxToken.Replace("[<CommonParameters>]", "")
            $syntaxToken = $syntaxToken.Trim()

            if ( $syntaxToken -ne "" ) 
            {
                $QuickRef.Syntax += $syntaxToken
            }
        }
   
        ##############################################
        # Parameters

        #parameters might be null
        if ( $help.parameters -ne $null  )
        {
            #Temp object which will be used to either store a single paramter or just the real parameter collection
            $params = @()

            #parameters can be a string ?!??!?!?!
            if ( $help.parameters -isnot [String] ) 
            {
                #the parameter can also be null
                if ( $help.parameters.parameter -ne $null )
                {
                    #When we are here, we might have one or more parameters
                    #I have no idea how to better check this, as (( -is [array] )) is not working          
                    try
                    {
                        #this will fail if there is only one parameter
                        $ignored = $help.parameters.parameter.Count             
                        $params = $help.parameters.parameter
                    }
                    catch
                    {
                        #Add the single parameter to our existing array
                        $params += $help.parameters.parameter
                    }
                }
            }

            #check every parameter (if any)
            foreach ($param in $params)              
            {
                $paramName = $Param.Name
     
                #we might suck at documentation and forgot the description
                try 
                {
                    $paramDesc = [string]$Param.Description.Text.Trim()
                }
                catch
                {
                    $paramDesc = "*!*!* PARAMETER DESCRIPTION MISSING *!*!*"
                }     
      
                $QuickRef.Parameter.Add($paramName, $paramDesc) 
            }

   
        } #params is null

        #Now we should have everything in our QuickRef object
        $qrList += $QuickRef

    } #foreach


    if ( $SortByNoun) 
    {
        #By default, get-help will return the functions names from a module sorted by Verb, but not the noun.
        #Given that some functions deal with the same nouns, it makes more sense to sort them by noun, then by verb.
        $objectCount = ($qrList | Measure-Object).Count

        if ( $objectCount -gt 1 )
        {            
            $dict = New-Dictionary -KeyType string -ValueType int

            for ($i = 0; $i -lt $qrList.Count; $i++) 
            {
                #We first need to reverse verb-noun to noun-verb
                $curFunction = $qrList[$i].Name
                $posHyphen = $curFunction.IndexOf("-")
                $sortName = ""

                if ( -not $posHyphen -ge 2)
                {
                    #function doesn't use a hypen, use as is
                    $sortName = $curFunction
                }
                else
                {
                    #Turn a function like "Get-Something" into "Something-Get"
                    $sortName = $curFunction.SubString($posHyphen + 1)
                    $sortName += "-"
                    $sortName += $curFunction.SubString(0, $posHyphen)        
                }

                $dict.Add($sortName, $i)
            }

            #Now sort the list based on the name
            $sortedList = $dict.GetEnumerator() | Sort-Object -Property "Key"

            #Create a new array with the original values in the new order
            $qrListTemp = @()
            foreach ($entry in $sortedList)
            {
                $qrListTemp += $qrList[$entry.Value]
            }

            #Replace the current qrList with the objects from this list
            $qrList = $qrListTemp
        }
    }

    #$qrList contains one or more objects we can use - check which output the caller wants
    switch ($Output)
    {
        "Objects"
        {
            return $qrList    
        }

        "CommonMark"
        {
            $txt = ""

            #github requires three back-ticks but this is an escape char for PS 
            $CODE_BLOCK_END = "``````" 
            $CODE_BLOCK_START = "$($CODE_BLOCK_END)powershell" 

            foreach ($qr in $qrList)
            {  
                $txt += "### $($qr.Name) ###`n"
                $txt += "$($qr.Synopsis)`n"
   
                #Syntax
                $txt += "$CODE_BLOCK_START`n"
                foreach ($syn in $qr.Syntax)
                {
                    $txt += "$($syn)`n"
                }          
                $txt += "$CODE_BLOCK_END`n"

                #Parameters (if any)
                foreach ($param in $qr.Parameter.GetEnumerator())
                {
                    #Syntax is: <List> <BOLD>NAME<BOLD> - Description
                    $txt += " - *$($param.Key)* - $($param.Value)`n"
                }
          
                $txt += "`n"
            }

            return $txt
        }

        "String"
        {
            $txt = ""

            foreach ($qr in $qrList)
            {  
                $txt += "( $($qr.Name) ) - $($qr.Synopsis)`n"
   
                $txt += "`n"
                foreach ($syn in $qr.Syntax)
                {
                    $txt += "  $($syn)`n"
                }          
                $txt += "`n"

                #Parameters (if any)
                foreach ($param in $qr.Parameter.GetEnumerator())
                {
                    #Syntax is: <List> <BOLD>NAME<BOLD> - Description
                    $txt += "  $($param.Key): $($param.Value)`n"
                }
          
                $txt += "`n"
            }

            return $txt
        }
    }

}


Function New-Dictionary()
{
    <#
  .SYNOPSIS
  Returns a dictionary that can be used like a hashtable (Key-Value pairs) but the pairs are not sorted by the key as in a hashtable

  .PARAMETER StringPairs
  Both the key and the value of the dictionary are strings. Accessing values using object[Key] is case-insensitve.

  .PARAMETER StringKey
  The key of the dictionary is of type string, the value is of type PSObject. Accessing values using object[Key] is case-insensitve.

  .PARAMETER KeyType
  Defines the type used for the key. Accessing values using object[Key] is NOT case-insensitve, it's case-sensitive.

  .PARAMETER ValueType
  Defines the type used for the value. 

  .OUTPUTS
  System.Collections.Generic.Dictionary
#>
    #No idea what I should write here. The line below makes PS say it does not know this type
    #[OutputType([System.Collections.Generic.Dictionary])]  

    param (
        [Parameter(ParameterSetName = "KeyAndValueString", Mandatory = $true)]
        [switch]$StringPairs,

        [Parameter(ParameterSetName = "KeyStringValuePSObject", Mandatory = $true)]
        [switch]$StringKey,

        [Parameter(ParameterSetName = "DefineType", Mandatory = $true)]
        [string]$KeyType,

        [Parameter(ParameterSetName = "DefineType", Mandatory = $true)]
        [string]$ValueType
    )
 
    #The important thing here that we need to create a dictionary that is case-insensitive
    #(StringComparer.InvariantCultureIgnoreCase) is slower than (StringComparer.OrdinalIgnoreCase) because it also replaces things (Straße becomes Strasse)
    #I have no idea how CurrentCultureIgnoreCase behaves

    $result = $null

    switch ($PsCmdlet.ParameterSetName)
    {    
        "KeyAndValueString"
        {  
            $result = New-Object -TypeName "System.Collections.Generic.Dictionary[string,string]" -ArgumentList @([System.StringComparer]::OrdinalIgnoreCase)
        }

        "KeyStringValuePSObject"
        {
            $result = New-Object "System.Collections.Generic.Dictionary[string,PSObject]" -ArgumentList @([System.StringComparer]::OrdinalIgnoreCase)
        }

        "DefineType"
        {
            $result = New-Object "System.Collections.Generic.Dictionary[$KeyType,$ValueType]"     
        }

    }
 
    return $result
}


Function New-Exception()
{
    <#
  .SYNOPSIS
  Generates an exception ready to be thrown, the expected usage is [throw New-Exception -(TypeOfException) "Explanation why exception is thrown"]

  .PARAMETER Explanation
  A description why the exception is thrown. If empty, a standard text matching the type of exception beeing generated is used

  .PARAMETER NoCallerName
  By default, the name of the function or script generating the exception is included in the explanation

  .PARAMETER InvalidArgument
  The exception it thrown because of a value does not fall within the expected range

  .PARAMETER InvalidOperation
  The exception is thrown because the operation is not valid due to the current state of the object

  .PARAMETER InvalidFormat
  The exception is thrown because one of the identified items was in an invalid format

  .PARAMETER FileNotFound
  The exception is thrown because a file can not be found/accessed 

  .PARAMETER DirectoryNotFound
  The exception is thrown because a directory can not be found/accessed 

  .OUTPUTS
  System.Exception
#>
    [OutputType([System.Exception])]  
    param (
        [Parameter(ParameterSetName = "InvalidArgumentException", Mandatory = $true)]
        [switch]$InvalidArgument,

        [Parameter(ParameterSetName = "InvalidOperationException", Mandatory = $true)]
        [switch]$InvalidOperation,

        [Parameter(ParameterSetName = "FormatException", Mandatory = $true)]
        [switch]$InvalidFormat,

        [Parameter(ParameterSetName = "FileNotFoundException", Mandatory = $true)]
        [switch]$FileNotFound,

        [Parameter(ParameterSetName = "DirectoryNotFoundException", Mandatory = $true)]
        [switch]$DirectoryNotFound,
  
        [Parameter(Mandatory = $false, Position = 1)]
        [string]$Explanation,

        [Parameter(Mandatory = $false)]
        [switch]$NoCallerName = $false
    )

    $exception = $null
    $caller = ""

    if ( -not $NoCallerName )
    {
        #No text was given. See if we can get the name of the caller
        try 
        { 
            $caller = (Get-PSCallStack)[1].Command  
        }
        catch
        { 
            $caller = "Unknown caller"    
        }

        $caller = "$($caller): "
    }


    switch ($PsCmdlet.ParameterSetName)
    {  
        "InvalidArgumentException"
        {
            if ( Test-String -IsNullOrWhiteSpace $Explanation)
            { 
                $Explanation = "Value does not fall within the expected range." 
            }

            $exception = New-Object System.ArgumentException "$caller$Explanation"
        }    

        "InvalidOperationException"
        {
            if ( Test-String -IsNullOrWhiteSpace $Explanation)
            { 
                $Explanation = "Operation is not valid due to the current state of the object."
            }

            $exception = New-Object System.InvalidOperationException "$caller$Explanation"
        }    

        "FormatException"
        {
            if ( Test-String -IsNullOrWhiteSpace $Explanation)
            { 
                $Explanation = "One of the identified items was in an invalid format."
            }
      
            $exception = New-Object System.FormatException "$caller$Explanation"
        }

        "FileNotFoundException"
        {
            if ( Test-String -IsNullOrWhiteSpace $Explanation)
            { 
                $Explanation = "Unable to find the specified file."
            }
            
            $exception = New-Object System.IO.FileNotFoundException "$caller$Explanation"
        }
    
        "DirectoryNotFoundException"
        {
            if ( Test-String -IsNullOrWhiteSpace $Explanation)
            { 
                $Explanation = "Attempted to access a path that is not on the disk."
            }
            
            $exception = New-Object System.IO.DirectoryNotFoundException "$caller$Explanation"
        }

    }
  
    return $exception
}


Function Test-Admin()
{
    <#
   .SYNOPSIS
   Determines if the current powershell is elevated (running with administrator privileges).
   
   .OUTPUTS
   bool
#>
    [OutputType([bool])] 
    #Code copied from http://boxstarter.org/
    #https://github.com/mwrock/boxstarter/blob/master/BoxStarter.Common/Test-Admin.ps1

    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal( $identity )
    return $principal.IsInRole( [System.Security.Principal.WindowsBuiltInRole]::Administrator )
}


function ConvertTo-DateTimeString()
{
    <#
  .SYNOPSIS
  Converts a DateTime to a string as definied by ISO 8601. The result will be in the format [2016-11-24 14:59:16.718+01:00] for local and [2016-11-19 14:24:09.718Z] for UTC values.

  .PARAMETER DateTime
  The DateTime to be converted to a string

  .PARAMETER UTC
  Convert the DateTime to UTC before converting it to a string.

  .PARAMETER ForceUTC
  Ignore the time zone/kind (Local, Unspecified, UTC) of the given DateTime and use it as if it were UTC already.

  .PARAMETER HideMilliseconds
  Do not include milliseconds in the result

  .OUTPUTS
  String
#>
    [OutputType([String])]  
    param (
        [Parameter(ParameterSetName = "ForceUTC", Mandatory = $true, Position = 1)]
        [Parameter(ParameterSetName = "ConvertUTC", Mandatory = $true, Position = 1)]
        [Parameter(ParameterSetName = "Default", Mandatory = $true, Position = 1)]    
        [DateTime]$DateTime,
  
        [Parameter(ParameterSetName = "ForceUTC", Mandatory = $false)]
        [Parameter(ParameterSetName = "ConvertUTC", Mandatory = $false)]
        [Parameter(ParameterSetName = "Default", Mandatory = $false)]   
        [switch]$HideMilliseconds,

        [Parameter(ParameterSetName = "ConvertUTC", Mandatory = $true)]
        [switch]$UTC,

        [Parameter(ParameterSetName = "ForceUTC", Mandatory = $true)]
        [switch]$ForceUTC
    )
  
    switch ($PsCmdlet.ParameterSetName)
    {  
        "Default"
        {
            $dt = $DateTime
        }

        "ConvertUTC"
        {
            if ( $UTC )
            {
                $dt = $DateTime.ToUniversalTime()
            }
        }

        "ForceUTC"
        {
            if ( $ForceUTC )
            {
                #$dt=[DateTime]::SpecifyKind($DateTime, "Utc")
                $dt = ConvertTo-UTC $DateTime -ForceUTC
            }
        }
    }

    #More about ISO 8601: https://en.wikipedia.org/wiki/ISO_8601
    #Also: https://xkcd.com/1179/
    $FORMAT_FULL = "yyyy'-'MM'-'dd HH':'mm':'ss'.'fffK" #K will be replaced with the timezone or Z if UTC
    $FORMAT_SHORT = "yyyy'-'MM'-'dd HH':'mm':'ssK"

    $formatString = $FORMAT_FULL

    if ( $HideMilliseconds )
    {
        $formatString = $FORMAT_SHORT
     
        #This could be used to set the milliseconds to zero.
        ##New-TimeSpan does not allow to define Milliseconds, so we use the .NET constructor
        #$timespan=New-Object System.TimeSpan(0,0,0,0,$dt.Millisecond)
        #$dt=$dt - $timespan
    }
   
    return $dt.ToString($formatString)
}


Function ConvertFrom-DateTimeString()
{
    <#
  .SYNOPSIS
  Converts a string (created by ConvertTo-DateTimeString() to a DateTime. If the given string contains a time zone (...+/-01:00),
  the DateTime is converted to local time. If the given string is in UTC (...Z), no conversion will take place.

  .PARAMETER DateTimeString
  The string to be converted to a DateTime

  .OUTPUTS
  DateTime
#>
    [OutputType([DateTime])]  
    param (
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$DateTimeString
    )

    #More about ISO 8601: https://en.wikipedia.org/wiki/ISO_8601
    #Also: https://xkcd.com/1179/
    $FORMAT_FULL = "yyyy'-'MM'-'dd HH':'mm':'ss'.'fffK" #K will be replaced with the timezone or Z if UTC
    $FORMAT_SHORT = "yyyy'-'MM'-'dd HH':'mm':'ssK"

    $formatString = $FORMAT_SHORT

    #We need to check if the string contains milliseconds or not so we can switch the format
    if ( $DateTimeString.Length -ge 20 )
    {
        if ( $DateTimeString.Substring(19, 1) -eq "." )
        {
            $formatString = $FORMAT_FULL      
        }
    }

    #AssumeLocal - If no time zone is specified in the parsed string, the string is assumed to denote a local time.     
    $dateTimeStyles = [System.Globalization.DateTimeStyles]::AssumeLocal
  
    #Check if the string ends with "Z", meaning UTC. In this case, we do not want it to be converted
    if ( $DateTimeString.EndsWith("Z") )
    {
        $dateTimeStyles = [System.Globalization.DateTimeStyles]::AdjustToUniversal
    }
  
    $dt = [DateTime]::ParseExact($DateTimeString, $formatString, [System.Globalization.CultureInfo]::InvariantCulture, $dateTimeStyles)
 
    return $dt
}


Function ConvertTo-UTC()
{
    <#
  .SYNOPSIS
  Converts a given DateTime to a Coordinated Universal Time (UTC) DateTime. 

  .PARAMETER DateTime
  The DateTime to be converted to UTC. A DateTime without time zone (Kind=Unspecified) is assumed to be in local time. Values already in UTC will be returned as is. 

  .PARAMETER ForceUTC
  Ignore the time zone/kind (Local, Unspecified, UTC) of the given DateTime and return the same date and time as the input as UTC

  .OUTPUTS
  DateTime
#>
    [OutputType([DateTime])]  
    param (
        [Parameter(Mandatory = $true, Position = 1)]
        [DateTime]$DateTime,
  
        [Parameter(Mandatory = $false)]
        [switch]$ForceUTC
    )

    if ( $ForceUTC )
    {
        return [DateTime]::SpecifyKind($DateTime, [DateTimeKind]::Utc)
    }
    else
    {
        switch ($DateTime.Kind)
        {  
            "Utc"
            {
                #That's easy
                return [DateTime]$DateTime
            }

            "Local"
            {
                return [DateTime]$DateTime.ToUniversalTime()
            }

            default #Unspecified
            {
                $dt = [DateTime]::SpecifyKind($DateTime, [DateTimeKind]::Local)
                return [DateTime]$dt.ToUniversalTime()
            }

        }
    }
}


Function ConvertFrom-UTC()
{
    <#
  .SYNOPSIS
  Converts a given Coordinated Universal Time (UTC) DateTime to local time.

  .PARAMETER DateTime
  The DateTime to be converted to local time from UTC. Inputs not in UTC will result in an exception.

  .OUTPUTS
  DateTime
#>
    [OutputType([DateTime])]  
    param (
        [Parameter(Mandatory = $true, Position = 1)]
        [DateTime]$DateTime
    )

    if ( $DateTime.Kind -eq [DateTimeKind]::Utc )
    {
        return $DateTime.ToLocalTime()
    }
    else
    {
        throw New-Exception -InvalidArgument "The given DateTime object must be in UTC"
    }
}


Function Get-TrimmedString()
{
    <#
  .SYNOPSIS
   Removes white-space characters from the given string. By default, it removes all leading and trailing white-spaces chracters.

  .PARAMETER String
  The string to be trimmed

  .PARAMETER StartOnly
  Only remove leading white-space chracters

  .PARAMETER EndOnly
  Only remove trailing white-space chracters

  .PARAMETER RemoveAll
  Removes all white-space chracters from the string

  .PARAMETER Equalize 
  Removes all leading and trailing white-space characters, then replace any character considered to be a white-space with the standard white-space character (U+0020)

  .PARAMETER RemoveDuplicates
  Removes all leading and trailing white-space characters, then replace any white-space duplicates with one white-space (U+0020); any non-standard white-space characters will also be replaced.


  .OUTPUTS
  string
#>
    [OutputType([string])]  
    param (
        #I have no idea why, but we need to reverse the order to make Get-Help return them in the correct order
        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = "RemoveAll")]
        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = "RemoveDuplicates")]  
        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = "Equalize")]
        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = "EndOnly")]
        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = "StartOnly")]
        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = "default")]    
        [string]$String = "", #not mandatory to allow passing an empty string

        [Parameter(Mandatory = $true, ParameterSetName = "StartOnly")]
        [switch]$StartOnly,

        [Parameter(Mandatory = $true, ParameterSetName = "EndOnly")]
        [switch]$EndOnly,

        [Parameter(Mandatory = $true, ParameterSetName = "Equalize")]
        [switch]$Equalize,

        [Parameter(Mandatory = $true, ParameterSetName = "RemoveDuplicates")]
        [switch]$RemoveDuplicates,

        [Parameter(Mandatory = $true, ParameterSetName = "RemoveAll")]
        [switch]$RemoveAll
    )

    switch ($PsCmdlet.ParameterSetName)
    {  
        "Default"
        {    
            return $String.Trim()
        }

        "StartOnly"
        {
            return $String.TrimStart()
        }

        "EndOnly"
        {
            return $String.TrimEnd()
        }

        "Equalize"
        {
            #Trim() uses internally the function Char.IsWhiteSpace so we should do the same
            $sb = New-Object System.Text.StringBuilder
        
            $chars = $String.Trim().ToCharArray()
            foreach ($char in $chars)
            {
                if ( [Char]::IsWhiteSpace($char) )
                {
                    [void]$sb.Append(" ") 
                }
                else
                {
                    [void]$sb.Append($char)
                }
            }
        
            return $sb.ToString()
        }

        "RemoveDuplicates"
        {        
            #Trim() uses internally the function Char.IsWhiteSpace so we should do the same
            $sb = New-Object System.Text.StringBuilder

            $lastCharWasWhiteSpace = $false
        
            $chars = $String.Trim().ToCharArray()            
            foreach ($char in $chars)
            {
                if ( [Char]::IsWhiteSpace($char) )
                {
                    if ( -not $lastCharWasWhiteSpace )
                    {
                        [void]$sb.Append(" ") 
                    }

                    $lastCharWasWhiteSpace = $true
                }
                else
                {
                    [void]$sb.Append($char)
                    
                    $lastCharWasWhiteSpace = $false
                }
            }
        
            return $sb.ToString()
        }

        "RemoveAll"
        {
            #Change anything that is considered as white-space by .NET to " " (U0020)
            $innerstring = Get-TrimmedString $String -Equalize
        
            #Now we can easily search for space and eliminate it
            return $innerstring.Replace(" ", "")
        }

    } #switch


} #function 


Function Add-RegistryValue()
{
    <#
  .SYNOPSIS
  Adds a value to the given registry path. Uses [Set-RegistryValue] internally.

  .PARAMETER Path
  The registry path, e.g. HKCU:\Software\TEMP\TSVARS

  .PARAMETER Name
  The name of the registry value 

  .PARAMETER Value
  The value 

  .PARAMETER REG_SZ
  The data will be written as REG_SZ

  .OUTPUTS
  None
#>  
    param(
        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $True, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $True, Position = 3)]
        [ValidateNotNull()]
        [string]$Value,

        [Parameter(Mandatory = $True)]
        [switch]$REG_SZ
    )

    if ( !(Test-Path $Path) ) 
    {
        $ignored = New-Item -Path $Path -Force 
    } 

    $ignored = New-ItemProperty -Path $path -Name $name -Value $value -PropertyType String -Force 
}


Function Set-RegistryValue()
{
    <#
  .SYNOPSIS
  Writes a registry value in the given registry path. 

  .PARAMETER Path
  The registry path, e.g. HKCU\Software\MPSXM\

  .PARAMETER Name
  The name of the registry value. If not defined, the (default) value is used

  .PARAMETER Value
  The value to be written

  .PARAMETER Type
  The data type used in the registry (REG_xx). If not specified, the type of the given value will be used to assign DWord, QWord or String.

  .OUTPUTS
  None
#>  
    param(
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Value,

        [Parameter(Mandatory = $false)]
        [Microsoft.Win32.RegistryValueKind]$Type = [Microsoft.Win32.RegistryValueKind]::Unknown
    )

    #Normal registry path just use ROOT\Path e.g. HKCU\Software\MPSXM. PowerShell (because it uses a provider) uses ROOT:\Path
    #Check if the fifth character is a ":" and if not, add it so PowerShell knows we want to write to the registry
    if ( ($Path.Substring(4, 1) -eq ":") )
    {
        $regPath = $Path    
    }
    else
    {
        $regPath = $Path.Insert(4, ":")
    }

    #Create the path if it does not exist
    if ( -not (Test-Path $regPath -PathType Container) ) 
    {
        $ignored = New-Item -Path $regPath -Force 
    } 

    #check if value name was given. If not, write to (default)
    if ( Test-String -IsNullOrWhiteSpace $Name )
    {
        #default values only support string, so we always convert to string
        $ignored = Set-Item -Path $regPath -Value $value.ToString()
    }
    else
    {
        if ( $Type -eq [Microsoft.Win32.RegistryValueKind]::Unknown )
        {
            #type was not given, figure it out ourselves
            #"String, ExpandString, Binary, DWord, MultiString, QWord, Unknown".
            if ( $Value -is [int]) 
            {
                $Type = [Microsoft.Win32.RegistryValueKind]::DWord
            }
            elseif ( $Value -is [long])
            {
                $Type = [Microsoft.Win32.RegistryValueKind]::QWord
            }
            else
            {
                $Type = [Microsoft.Win32.RegistryValueKind]::String
            }
        }
   
        $ignored = New-ItemProperty -Path $regPath -Name $name -Value $value -PropertyType $Type -Force 
    }
}



Function Get-RegistryValue()
{
    <#
  .SYNOPSIS
  Reads a registry value.

  .PARAMETER Path
  The registry path, e.g. HKCU\Software\MPSXM\

  .PARAMETER Name
  The name of the registry value to be read. If not defined, the (default) value is used

  .PARAMETER DefaultValue
  The value to return if name does not exist. If not defined, $null is returned if Name does not exist

  .OUTPUTS
  Varies
#>  
    param(
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        $DefaultValue = $null
    )

    #Normal registry path just use ROOT\Path e.g. HKCU\Software\MPSXM. PowerShell (because it uses a provider) uses ROOT:\Path
    #Check if the fifth character is a ":" and if not, add it so PowerShell knows we want to write to the registry
    if ( ($Path.Substring(4, 1) -eq ":") )
    {
        $regPath = $Path    
    }
    else
    {
        $regPath = $Path.Insert(4, ":")
    } 
 
    if ( -not (Test-Path $regPath -PathType Container) ) 
    {
        #Path does not exist, return default value
        return $DefaultValue
    }
    else
    {
        #This commands read ALL values from the path. No idea if this is bad or can be ignored.
        $regVals = Get-ItemProperty -Path $regPath
        if ( -not $regVals )
        {
            return $DefaultValue
        }
        else
        {
            #Was a name given? If not, use (default)
            if ( Test-String -IsNullOrWhiteSpace $Name)
            {
                $Name = "(default)"
            }   

            $regValue = Get-Member -InputObject $regVals -Name $Name
            if ( -not $regValue )
            {
                return $DefaultValue
            }
            else
            {
                #return the real value
                return $regVals.$Name
            }       
        }
    }

}


Function Get-FileName()
{
    <#
  .SYNOPSIS
  Returns the filename (with or without the extension) from a path string

  .PARAMETER Path
  The string path containing a filename, e.g. C:\Path\MyFile.txt

  .PARAMETER WithoutExtension
  Return the filename without extension (MyFile.txt would be returned as MyFile)

  .OUTPUTS
  String
#>  
    [OutputType([string])]  
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [Switch]$WithoutExtension = $false
    )
    if ( $WithoutExtension )
    {        
        return [System.IO.Path]::GetFileNameWithoutExtension($Path)
    }
    else
    {
        return [System.IO.Path]::GetFileName($Path)
    }
}


Function Get-ContainingDirectory()
{
    <#
  .SYNOPSIS
  Returns the directory containing the item defined in the path string

  .PARAMETER Path
  The string path e.g. C:\Path\MyFile.txt

  .OUTPUTS
  String
#>  
    [OutputType([string])]  
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    #The problem with this function is that it returns different results depending on if the path ends with "\" or not
  
    #When $Directory ends with "\", the return is the $Directory without "\"
    #If not, the return is the containing directory
  
    #Hence, we make sure the $Directory does not end with "\"
    $folder = Join-Path -Path $Path -ChildPath "\" #first add it in case the input was broken, e.g. ends with two "\"
    $folder = $folder.TrimEnd("\")

    return [System.IO.Path]::GetDirectoryName($folder)
}


Function Test-DirectoryExists()
{
    <#
  .SYNOPSIS
  Returns if a the given directory exists

  .PARAMETER Path
  The string path of a directory, e.g. C:\Windows

  .OUTPUTS
  boolean
#>  
    [OutputType([bool])]  
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )
    return Test-Path -Path $Path -PathType Container
}


Function Test-FileExists()
{
    <#
  .SYNOPSIS
  Returns if a the given file exists

  .PARAMETER Path
  The string path of the fiel , e.g. C:\Temp\MyFile.txt"

  .OUTPUTS
  boolean
#>  
    [OutputType([bool])]  
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )
    return Test-Path -Path $Path -PathType Leaf
}


Function Copy-FileToDirectory()
{
    <#
  .SYNOPSIS
  Copies a file to a directory, overwritting any existing copy

  .PARAMETER Filename
  The full path to a file, e.g. C:\Temp\Testfile.txt

  .PARAMETER Directory
  Path to the destination directory, e.g. C:\Windows\Temp
#>  
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Filename,

        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Directory
    )

    if ( -not (Test-FileExists $Filename) )
    {
        throw New-Exception -FileNotFound "The file [$Filename] does not exist"
    } 
 
    $dest = Join-Path -Path $Directory -ChildPath "\"

    if ( -not (Test-DirectoryExists $dest) )
    {
        throw New-Exception -DirectoryNotFound "The destination directory [$dest] does not exist"
    }

    $ignored = Copy-Item -Path $Filename -Destination $dest -Force
}


Function ConvertTo-Array()
{
    <#
  .SYNOPSIS
  Convert a single value or a list of objects to an array; this way (Array).Count or a ForEach() loop always works. An input of $null will result in an array with length 0.

  .PARAMETER InputObject
  A single object, a list of objects or $null
#>  
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $True)]
        $InputObject
    )

    #if it's null, return an empty array
    if ( $InputObject -eq $null )  
    {      
        $empty = @()
        
        #This rather strange syntax is needed because we want to return an empty array. 
        #Thank Ansgar Wiechers for the solution: http://stackoverflow.com/a/18477004
        return , $empty        
    }    
    else
    {
        #get the number of objects in the list      
        $count = ($InputObject| Measure-Object).Count
        $array = @()
        
        if ( $count -le 0 )
        {
            #same as above regarding empty array return
            return , $array
        }
        elseif ( $count -eq 1 )
        {
            #this extra step is required because elements with count 1 sometimes can not be retrieved by foreach
            $array += $InputObject
            return , $array
        }
        else
        {
            foreach ($item in $InputObject)
            {          
                $array += $item
            }
            return $array
        }
    }
}


Function Select-StringUnicodeCategory()
#This function is based on the work of Francois-Xavier Cat:
# http://www.lazywinadmin.com/2015/08/powershell-remove-special-characters.html
# https://github.com/lazywinadmin/PowerShell/blob/master/TOOL-Remove-StringSpecialCharacter/Remove-StringSpecialCharacter.ps1
#
#For a list of categories, see 
# https://en.wikipedia.org/wiki/Unicode_character_property#General_Category
#and
# https://docs.microsoft.com/en-us/dotnet/standard/base-types/character-classes-in-regular-expressions#SupportedUnicodeGeneralCategories
{
    <#
  .SYNOPSIS
  Selects (filters) characters based on their unicode category from the given string. [Select-StringUnicodeCategory "A B C 123" -IncludeLetter] would return "ABC"

  .PARAMETER String
  The string the operation should be performed on

  .PARAMETER IncludeLetter
  Include letter characters 

  .PARAMETER IncludeNumber
  Include number characters 

  .PARAMETER IncludeSpace
  Include the default space character (u0020)
  
  .PARAMETER IncludePunctuation
  Include punctuation characters

  .PARAMETER IncludeSymbol
  Include symbol characters
#>  
    [OutputType([string])] 
    param (
        [Parameter(Mandatory = $false, Position = 1)] #false or we can not pass empty strings
        [string]$String = "",

        [Parameter(Mandatory = $false)]
        [switch]$IncludeLetter,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeNumber,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeSpace,

        [Parameter(Mandatory = $false)]
        [switch]$IncludePunctuation,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeSymbol
    )

    $output = ""

    #RegEx description: Everything that is NOT (^) matching the unicode category (\p{}) will be replaced
    # L (Letter)
    # Nd (Decimal Numbers)
    # P (Punctuation) 
    # S (Symbol)
    # Zs (Space) => Not used as it also includes other "SPACE" charcaters - \u0020 is the "standard space" (ASCII)

    $regex = ""

    if ( $IncludeLetter ) { $regex += "\p{L}" }
    if ( $IncludeNumber ) { $regex += "\p{Nd}" }
    if ( $IncludePunctuation ) { $regex += "\p{P}" }
    if ( $IncludeSymbol ) { $regex += "\p{S}" }
 
    if ( $IncludeSpace ) { $regex += "\u0020" }

    #Check if anything was selected. If not, return an empty string
    if ( Test-String -HasData $regex )
    {
        #Finish the regex
        $regex = "[^$regex]"

        $output = $String -replace $regex
    }

   
    return $output
}


Function Remove-FileExact()
#HINT: As we use -LiteralPath this function will NOT process wildcards like * or ?
{
    <#
  .SYNOPSIS
  Deletes a file; no wildcards are accepted, the filename must be exact. Exact also means that an 8+3 alias is not allowed (Filena~1). If the file does not exist, no error is generated. 

  .PARAMETER Filename
  The full path to the file that should be deleted.
#> 
    param(
        [Parameter(Mandatory = $False)] #$False to allow empty strings
        [string]$Filename
    )

    if ( Test-String $Filename -HasData )
    {
        if ( (Test-FileExists $Filename) ) 
        {
            try 
            {
                #When using just -Path, sometimes this fails - See http://stackoverflow.com/questions/11586310/having-issue-removing-a-file-in-powershell
                Remove-Item -LiteralPath $Filename -Force -ErrorAction Stop
            }
            catch
            {
                write-error "Unable to delete [$Filename]: $($_.Exception.Message)"
            }
        }
    } 
}


#Changes 3.24

# This function is based on code from Jon Gurgul
# http://jongurgul.com/blog/get-stringhash-get-filehash/
Function Get-StringHash()
{
    #.SYNOPSIS
    #Returns the hash value of the given string using the given algorithm
    #
    #.PARAMETER String
    #The string to be hashed
    #
    #.PARAMETER HashName
    #The hash algorithm to be used. Defaults to SHA1
    #
    #.OUTPUTS
    #string
    [OutputType([string])] 
    param (
        [Parameter(Mandatory = $False, Position = 1)]
        [AllowEmptyString()] #we need this or PowerShell will complain "Cannot bind argument to parameter 'string' because it is an empty string." 
        [string]$String,

        [Parameter(Mandatory = $True, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]$HashName = "SHA1"
    )

    $StringBuilder = New-Object System.Text.StringBuilder
    
    [System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))| ForEach-Object {
        [void]$StringBuilder.Append($_.ToString("x2"))
    }

    return $StringBuilder.ToString()
}


Function Test-IsHashtable()
{

    #.SYNOPSIS
    #Returns if the parameter is a hash table or an ordered dictionary (which behave the same as hash tables )
    #
    #.PARAMETER InputObject
    #An object that is checked if it's a hash table
    #
    #.OUTPUTS
    #bool

    [OutputType([bool])] 
    param (
        [Parameter(Mandatory = $True, Position = 1)]
        [AllowNull()]  #We should be able to check if NULL if a hashtable (Else well get "Cannot bind argument to parameter 'InputObject' because it is null.")
        $InputObject
    ) 
  
    
    if ( $InputObject -eq $null )
    {
        return $false    
    }
    else 
    {
        if ( 
            ($InputObject -is [System.Collections.Hashtable]) -or
            ($InputObject -is [System.Collections.Specialized.OrderedDictionary]) 
        )
        {
            return $true
        }
        else
        {
            return $false
        }
    }  
}


Function ConvertFrom-JsonToHashtable()
{
    #.SYNOPSIS
    # Converts a string or contents of a file from JSON format to a hash table
    #
    #.PARAMETER String
    # A string in JSON format that should be converted to a hash table
    #
    #.PARAMETER File
    # A file path to a file that stores JSON data and that will be returned as hash table
    #
    #.OUTPUTS
    #Hashtable

    [OutputType([Hashtable])]  
    param(
        [Parameter(ParameterSetName = "String", Mandatory = $True, Position = 1, ValueFromPipeline = $True)]
        [string]$String,

        [Parameter(ParameterSetName = "File", Mandatory = $True, ValueFromPipeline = $True)]
        [string]$File
    )

    
    switch ($PsCmdlet.ParameterSetName)
    { 

        "String"
        {  
            if ($PSVersionTable.PSVersion.Major -lt 6)
            {
                #This code is based from this blog post by Kevin Marquette 
                #https://kevinmarquette.github.io/2016-11-06-powershell-hashtable-everything-you-wanted-to-know-about/?utm_source=blog&utm_medium=blog&utm_content=popref
                #Added by commands from Mathieu Isabel
                #https://unhandled.wordpress.com/2016/12/18/powershell-performance-tip-use-javascriptserializer-instead-of-convertto-json/

                Add-Type -AssemblyName System.Web.Extensions
                [void][Reflection.Assembly]::LoadWithPartialName("System.Web.Script.Serialization")
                $JSSerializer = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
                return [Hashtable] ($JSSerializer.Deserialize($String, 'Hashtable')) 
            }
            else
            {
                #PowerShell 6.0 and above support -AsHashtable
                return ConvertFrom-Json -InputObject $String -AsHashtable

            }
        }

        "File"
        {
            if ( Test-Path $File )
            {  
                #-Raw can handle UTF-8 files with or without BOM
                $jsonData = Get-Content $File -Raw
                
                return ConvertFrom-JsonToHashtable -String $jsonData
            }
            else
            {
                throw New-Exception -FileNotFound "The file [$file] does not exist or is not accessible"
            }
        }
    }
}


#The default enabled security protocols for HTTPS in .NET 4.0/4.5 (and hence PowerShell) are SecurityProtocolType.Tls|SecurityProtocolType.Ssl3
#These protocols are considered unsecure and many server have disabled them all together. Therefore, WebClient might not be able to communicate with them to HTTPS 
#This function will enable TLS 1.2 and disable older protocols but in a way that, if PowerShell support TLS 1.3, TLS 1.3 will still be enabled (forward-compatible)
#
#For more details:
#StackOverflow answer by Luke Hutton: https://stackoverflow.com/a/28333370
#.NET API Browser: https://docs.microsoft.com/en-us/dotnet/api/system.net.servicepointmanager.securityprotocol?view=netframework-4.7#System_Net_ServicePointManager_SecurityProtocol

function Set-HTTPSecurityProtocolSecureDefault()
{
    #.SYNOPSIS
    # Sets the default HTTPS protocol to TLS 1.2 (and any newer protocol) while disabling unsecure protocols (SSL 3.0, TLS 1.0 and TLS 1.1) in a forward-compatible style

    #Activate TLS 1.2
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]'Tls12'

    #Check if SSL 3.0 is enabled and if so, disable it
    if ( [System.Net.ServicePointManager]::SecurityProtocol -band [System.Net.SecurityProtocolType]'Ssl3' ) 
    {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bxor [System.Net.SecurityProtocolType]'Ssl3'   
    }

    #Check if TLS 1.0 is enabled and if so, disable it
    if ( [System.Net.ServicePointManager]::SecurityProtocol -band [System.Net.SecurityProtocolType]'Tls' ) 
    {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bxor [System.Net.SecurityProtocolType]'Tls'   
    }

    #Check if TLS 1.1 is enabled and if so, disable it
    if ( [System.Net.ServicePointManager]::SecurityProtocol -band [System.Net.SecurityProtocolType]'Tls11' ) 
    {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bxor [System.Net.SecurityProtocolType]'Tls11'   
    }

}

#Changes 3.27

Function Get-RunningInISE()
{
    #.SYNOPSIS
    # Returns if the current script is executed by Windows PowerShell ISE (uses Test-IsISE internally)
    #
    #.OUTPUTS
    # $TRUE if running in ISE, FALSE otherise
    #  
    [OutputType([bool])]    
    param()    
    
    return Test-IsISE
}


#From: http://stackoverflow.com/a/25224840
#      by kuujinbo (http://stackoverflow.com/users/604196/kuujinbo)
Function Test-IsISE()
{
    #.SYNOPSIS
    # Returns if the current script is executed by Windows PowerShell ISE
    #
    #.OUTPUTS
    # $TRUE if running in ISE, FALSE otherise
    #  
    [OutputType([bool])]    
    param()    
    
    try 
    {    
        return $psISE -ne $null
    }
    catch 
    {
        return $false
    }
}

Function Test-RunningInEditor()
{
    #.SYNOPSIS
    # Returns TRUE if the current script is executed by a editor (host) like ISE or Visual Studio Code
    #
    #.OUTPUTS
    # $TRUE if running in an editor host, FALSE otherise
    #  
    [OutputType([bool])]    
    param()    
    
    $result = $false

    try 
    {   
        $host = Get-Host

        if ( 
            ($host.Name -eq "Windows PowerShell ISE Host") -or
            ($host.Name -eq "Visual Studio Code Host") 
        )
        {

            $result = $true
        }

    }
    catch 
    {
        $result = $false
    }
    
    return $result
}

