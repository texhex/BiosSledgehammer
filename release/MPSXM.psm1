# Michael's PowerShell eXtension Module
# Version 3.15.0
# https://github.com/texhex/MPSXM
#
# Copyright © 2010-2016 Michael 'Tex' Hex 
# Licensed under the Apache License, Version 2.0. 
#
# Import this module like this in case it is locatd in the same folder as your script
# Import-Module "$PSScriptRoot\MPSXM.psm1"
#
# In case you edit this file, new functions will not be found by the current PS session. Use -Force in this case.
# Import-Module "$PSScriptRoot\MPSXM.psm1" -Force
#
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

# Before adding a new function, please see
# [Approved Verbs for Windows PowerShell Commands] http://msdn.microsoft.com/en-us/library/ms714428%28v=vs.85%29.aspx
# 
# To run a PowerShell script from the command line, use
# powershell.exe [-NonInteractive] -ExecutionPolicy Bypass -File "C:\Script\DoIt.ps1"


#requires -version 4.0

#Guard against common code errors
#We do not use "Latest" because the rules are not documented
Set-StrictMode -version 2.0

#Terminate script on errors 
$ErrorActionPreference = 'Stop'



function Get-CurrentProcessBitness()
{
<#
  .SYNOPSIS
  Returns information about the current powershell process.

  .PARAMETER Is64bit
  Returns $True if the current script is running as 64-bit process.

  .PARAMETER Is32bit
  Returns $True if the current script is running as 32-bit process.

  .PARAMETER IsWoW
  Returns $True if the current script is running as 32-bit process on a 64-bit machine (Windows on Windows).

  .OUTPUTS
  Boolean, depending on parameter
#>
[OutputType([bool])] 
param (
  [Parameter(ParameterSetName="64bit",Mandatory=$True)]
  [switch]$Is64bit,

  [Parameter(ParameterSetName="32bit",Mandatory=$True)]
  [switch]$Is32bit,

  [Parameter(ParameterSetName="WoW",Mandatory=$True)]
  [switch]$IsWoW
)

  switch ($PsCmdlet.ParameterSetName)
  { 

    "64bit"
    {  
       $result=$false

       if ( [System.Environment]::Is64BitOperatingSystem) 
       {
          if ( [System.Environment]::Is64BitProcess ) 
          {
             $result=$true
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
      
      $result=$false 
      if ( [System.Environment]::Is64BitOperatingSystem) 
      {
         if ( Get-CurrentProcessBitness -Is32bit )
         {
            #32-bit Process on a 64-bit machine -> WOW on
            $result=$true
         }
      }

      return $result
    }

  } #switch

   
}


function Get-OperatingSystemBitness()
{
<#
  .SYNOPSIS
  Returns information about the current operating system

  .PARAMETER Is64bit
  Returns $True if the current operating system is 64-bit

  .PARAMETER Is32bit
  Returns $True if the current operating system is 32-bit 

  .OUTPUTS
  Boolean, depending on parameter
#>
[OutputType([bool])] 
param (
  [Parameter(ParameterSetName="64bit",Mandatory=$True)]
  [switch]$Is64bit,

  [Parameter(ParameterSetName="32bit",Mandatory=$True)]
  [switch]$Is32bit
)

  switch ($PsCmdlet.ParameterSetName)
  { 

    "64bit"
    {  
       $result=$false

       if ( [System.Environment]::Is64BitOperatingSystem) 
       {
          $result=$true
       }

       return $result
    } 

    "32bit"
    {
      return !([System.Environment]::Is64BitOperatingSystem)  
    }

  } #switch
   
}
#Helper function for [string]::IsNullOrWhiteSpace - http://msdn.microsoft.com/en-us/library/system.string.isnullorwhitespace%28v=vs.110%29.aspx
<#
 write-host "Tests for Get-StringIsNullOrWhiteSpace"
 Get-StringIsNullOrWhiteSpace "a" #False
 Get-StringIsNullOrWhiteSpace "" #true
 Get-StringIsNullOrWhiteSpace " " #true
 Get-StringIsNullOrWhiteSpace "     " #true
 Get-StringIsNullOrWhiteSpace $null #true
#> 
function Get-StringIsNullOrWhiteSpace()
{
<#
  .SYNOPSIS
  Returns true if the string is either $null, empty, or consists only of white-space characters.

  .PARAMETER String
  The string value to be checked

  .OUTPUTS
  $true if the string is either $null, empty, or consists only of white-space characters, $false otherwise
#>
[OutputType([bool])] 
param (
 [Parameter(Mandatory=$True,Position=1)]
 [AllowEmptyString()] #we need this or PowerShell will complain "Cannot bind argument to parameter 'string' because it is an empty string." 
 [string]$string
)

  if ([string]::IsNullOrWhiteSpace($string)) 
  {
     return $true
  } else {
     return $false
  }
 
}


function Get-StringHasData()
{
<#
  .SYNOPSIS
  Returns true if the string contains data (not $null, empty or only white spaces)

  .PARAMETER string
  The string value to be checked

  .OUTPUTS
  $true if the string is not $null, empty, or consists only of white space characters, $false otherwise
#>
[OutputType([bool])] 
param (
 [Parameter(Mandatory=$True,Position=1)]
 [AllowEmptyString()] #we need this or PowerShell will complain "Cannot bind argument to parameter 'string' because it is an empty string." 
 [string]$string
)

 if (-Not (Get-StringIsNullOrWhiteSpace $string)) 
 {
    return $true
 } 
 else 
 {
    return $false
 } 

}


#Yes, I know about $env:TEMP but this will always return a 8+3 path, e.g. C:\USERS\ADMIN~1\AppData..."
#This function returns the real path without that "~" garbage
function Get-TempFolder() 
{
<#
  .SYNOPSIS
  Returns a path to the temporary folder without any (8+3) paths in it

  .OUTPUTS
  Path to temporary folder without an ending "\"
#> 

 $temp=[System.IO.Path]::GetTempPath()
 if ( $temp.EndsWith("\") )
 {
   $temp=$temp.TrimEnd("\")
 }

 return $temp
}


Function Get-ModuleAvailable {
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
  [Parameter(Mandatory=$True,Position=1)]
  [ValidateNotNullOrEmpty()]
  [string]$Name
 )
 
 #First check if the requested module is already available in this session
 if(-Not (Get-Module -name $name))
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

     $mod=Import-Module $name -PassThru -ErrorAction SilentlyContinue -Scope Local
     if ($mod -ne $null) 
     {
        return $true
     } 
     else 
     {
        return $false
     }

 } else { 
   #module is already available in this runspace
   return $true 
 }

} 


Function Get-ComputerLastBootupTime(){<#
  .SYNOPSIS
  Returns the date and time of the last bootup time of this computer.

  .OUTPUTS
  DateTime (Kind = Local) that is the last bootup time of this computer
#>    [OutputType([datetime])] #param(#) $obj = Get-CIMInstance Win32_OperatingSystem -Property "LastBootupTime"  return $obj.LastBootUpTime}#From: http://stackoverflow.com/a/25224840#      by kuujinbo (http://stackoverflow.com/users/604196/kuujinbo)Function Get-RunningInISE()
{
<#
  .SYNOPSIS
  Returns if the current script is executed by Windows PowerShell ISE 

  .OUTPUTS
  $TRUE if running in ISE, FALSE otherise
#>    [OutputType([bool])]    
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


function Start-TranscriptTaskSequence()
{
<#
  .SYNOPSIS
  If the scripts runs in MDT or SCCM, the transcript will be stored in the path LOGPATH defines. If not, C:\WINDOWS\TEMP is used.

  .PARAMETER NewLog
  When set, will create a log file every time a transcript is started 

  .OUTPUTS
  None
#>    param(
 [Parameter(Mandatory=$False)]
 [switch]$NewLog=$False
) try
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

 $logName=Split-Path -Path $myInvocation.ScriptName -Leaf   
 
 if ( $NewLog ) 
 {
    Start-TranscriptIfSupported -Path $logPath -Name $logName -NewLog  } else {    Start-TranscriptIfSupported -Path $logPath -Name $logName }}function Start-TranscriptIfSupported {
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
#>     param(
  [Parameter(Mandatory=$False,Position=1)]
  [string]$Path=$env:TEMP,

  [Parameter(Mandatory=$False,Position=2)]
  [string]$Name,
  
  [Parameter(Mandatory=$False)]
  [switch]$NewLog=$False
 )
 if ( ! (Get-StringHasData $Name) )
 {
   $baseName=$Name
 }
 else
 {
  $scriptFilename=Split-Path -Path $myInvocation.ScriptName -Leaf   
 }
 
 $logFileTemplate = "$($Name).log"
 $extension="txt" #always use lower case chars only!
 
 #only needed if we need to add something
 $fileNameTail=""

 if ( $NewLog )
 {
   #we need to create log file like <SCRIPTNAME.ps>-Log #001.txt
   $filter="$($logFileTemplate)-??.$extension"

   [uint32]$value=1

   $existing_files=Get-ChildItem -Path $Path -File -Filter $filter -Force 
   
   #In case we get $null this means that no files were found. Nothing more to 
   if ( $existing_files -ne $null )
   {
    #at least one other file exists. Reorder so the log file with the highest name is at the end
    $existing_files=$existing_files | Sort-Object -Property "Name"
    
    #check if the result is one file or not
    if ( $existing_files -is [array] )
    {
       $temp=$existing_files[$existing_files.Count-1].Name
    }
    else
    {
       $temp=$existing_files.Name
    }

    #now access the last object in the list
    $temp=$temp.ToLower()

    #cut the ".txt" part from the end
    $temp=$temp.TrimEnd(".$extension")
    
    #Extract the the last two digitis, e.g. "13"
    $curValueText=$temp.Substring($temp.Length-2, 2)

    #convert to int so we can calculate with it. Maybe this will fail in which case we default to 99
    try
    {
      [uint32]$value=$curValueText
      #add one to the value
      $value++
    }
    catch
    { 
      $value=99 
    }
    
    #Final check. If the value is > 99, use 99 anyway
    if ( $value -gt 99 )
    {
      $value=99
    }

    #Done calculating $value
   }


   #Ensure that we have leading zeros if required
   $fileNameTail="-{0:D2}" -f $value
 }


 $logFile = "$Path\$($logFileTemplate)$($filenameTail).$extension"

 try 
 {
   write-verbose "Trying to execute Start-Transcript for $logFile"

   Start-Transcript -Path $logfile
   Write-verbose "Start-TranscriptIfSupported: Logging to $logFile"
 }
 catch [System.Management.Automation.PSNotSupportedException] {
    # The current PowerShell Host doesn't support transcribing
    write-host "Start-TranscriptIfSupported WARNING: The current PowerShell host doesn't support transcribing. No log will be generated."
 }}function Stop-TranscriptIfSupported {
<#
  .SYNOPSIS
  Stops a transscript, but ignores if the host does not support it.

  .OUTPUTS
  None
#>     try 
 {
   Stop-Transcript
 }
 catch [System.Management.Automation.PSNotSupportedException] 
 {
   write-host "Stop-TranscriptIfSupported WARNING: The current PowerShell host doesn't support transcribing. No log was generated."
 }}function Show-MessageBox {
<#
  .SYNOPSIS
  Shows the message box to the user using a message box.

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
 [Parameter(Mandatory=$True,Position=1)]
 [ValidateNotNullOrEmpty()]
 [string]$Message,

 [Parameter(Mandatory=$False,Position=2)]
 [string]$Titel,

 [Parameter(Mandatory=$False)]
 [switch]$Critical,

 [Parameter(Mandatory=$False)]
 [switch]$Huge
)

 #make sure the assembly is loaded
 [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
  
 $type=[System.Windows.Forms.MessageBoxIcon]::Information
 if ( $Critical )
 {
   $type=[System.Windows.Forms.MessageBoxIcon]::Error
 }

 if ( Get-StringIsNullOrWhiteSpace $Titel ) 
 {
    $Titel=$myInvocation.ScriptName
 }

 if ( $Huge ) 
 {
    $crlf="`r`n"    
    $crlf5="$crlf$crlf$crlf$crlf$crlf" 
    $Message="$Message $crlf5$crlf5$crlf5$crlf5$crlf5$crlf5"
 }

 #display message box
 $ignored=[System.Windows.Forms.MessageBox]::Show($message, $Titel, 0, $type)
}


function Add-RegistryValue {
<#
  .SYNOPSIS
  Adds a value to the given registry path. Right now only string values are supported.

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
  [Parameter(Mandatory=$True,Position=1)]
  [ValidateNotNullOrEmpty()]
  [string]$Path,

  [Parameter(Mandatory=$True,Position=2)]
  [ValidateNotNullOrEmpty()]
  [string]$Name,

  [Parameter(Mandatory=$True,Position=3)]
  [ValidateNotNull()]
  [string]$Value,

  [Parameter(Mandatory=$True)]
  [switch]$REG_SZ
)

 if( !(Test-Path $Path) ) 
 {
    $ignored=New-Item -Path $Path -Force 
 } 

 $ignored=New-ItemProperty -Path $path -Name $name -Value $value -PropertyType String -Force 
}


#From http://stackingcode.com/blog/2011/10/27/quick-random-string
# by Adam Boddington
function Get-RandomString { 
<#
  .SYNOPSIS
  Returns a random string (only Aa-Zz are used).

  .PARAMETER Length
  The length of the string that should be generated.

  .OUTPUTS
  Generated random string.
#> 
param (
  [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
  [ValidateNotNullOrEmpty()]
  [int]$Length
)
  $set    = "abcdefghijklmnopqrstuvwxyz0123456789".ToCharArray()
  $result = ""
  
  for ($x = 0; $x -lt $Length; $x++) 
  {
      $result += $set | Get-Random
  }
  
  return $result
}



<#
 This is most basic way I could think of to represent a hash table with single string values as a file 

 ; Comment (INI style)
 # also understood as comment (PowerShell style)
 Key1==Value1
 Key2==Value2
 ...
#>
function Read-StringHashtable() {
<#
  .SYNOPSIS
  Reads a hashtable from a file where the key-value pairs are stored as Key==Value

   .PARAMETER File
  The file to read the hashtable from

  .OUTPUTS
  Hashtable
#>
[OutputType([Hashtable])]  
param(
  [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
  [string]$File
)

  $result=@{}
  write-verbose "Reading hashtable from $file"

  if ( Test-Path $file )
  {     
     $data=Get-Content $file -Raw
     $lines=$data -split "`n" #we split at LF, not CR+LF in case someone has used the wrong line ending AGAIN

     if ( ($lines -eq $null) -or ($lines.Count -eq 0) )
     {
       #OK, this didn't worked. Maybe someone used pure CR?
       $lines=$data -split "`r"
     }
   
     foreach ($line in $lines) 
     {
       #just to make sure that nothing was left over 
       $line=$line -replace "´r",""
       $line=$line -replace "´n",""
       $line=$line.Trim()

       if ( !($line.StartsWith("#")) -and !($line.StartsWith(";")) -and !(Get-StringIsNullOrWhiteSpace $line) )
       {
         #this has to be a setting
         $setting=$line -split "=="

         if ( $setting.Count -ne 2 ) {
             $format_exception = New-Object System.FormatException "Error parsing [$line] as key-value pair - did you forgot to use '=='?"
             throw $format_exception
             
             #this code should never be reached
             $result=@{}
             break
         }
         else
         {
            $name=$setting[0].Trim()
            $value=$setting[1].Trim()
            
            #I'm unsure if this information is of any use
            #write-verbose "Key-Value pair found: [$name] : [$value]"

            if ( $result.ContainsKey($name) )
            {
               $duplicate_exception= New-Object System.InvalidOperationException "A duplicate key [$name] (Value: $value) can not be added"
               throw $duplicate_exception
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
     $filenotfound_exception = New-Object System.IO.FileNotFoundException "The file named $file does not exist or is not accessible"
     throw $filenotfound_exception
  }

 
 return $result
}


#The verb "Humanize" is taken from this great project: [Humanizer](https://github.com/MehdiK/Humanizer)
#Idea from [Which Disk is that volume on](http://www.uvm.edu/~gcd/2013/01/which-disk-is-that-volume-on/) by Geoff Duke 
function ConvertTo-HumanizedBytesString {
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
 [Parameter(Mandatory=$True,Position=1)]
 [AllowEmptyString()] 
 [int64]$bytes
)

 #Better set strict mode on function scope than on module level
 Set-StrictMode -version 2.0

 #Original code was :N2 which means "two decimal points"
 if     ( $bytes -gt 1pb ) { return "{0:N0} PB" -f ($bytes / 1pb) }
 elseif ( $bytes -gt 1tb ) { return "{0:N0} TB" -f ($bytes / 1tb) }
 elseif ( $bytes -gt 1gb ) { return "{0:N0} GB" -f ($bytes / 1gb) }
 elseif ( $bytes -gt 1mb ) { return "{0:N0} MB" -f ($bytes / 1mb) }
 elseif ( $bytes -gt 1kb ) { return "{0:N0} KB" -f ($bytes / 1kb) } 
 else   { return "{0:N0} Bytes" -f $bytes } 

}


function ConvertTo-Version()
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
   [Parameter(Mandatory=$False,ValueFromPipeline=$True)]
   [string]$Text="",

   [Parameter(Mandatory=$False,ValueFromPipeline=$True)]
   [switch]$RespectLeadingZeros=$false

 )   
 try
 {
   [version]$version=$Text
 }
 catch
 {
    $version=$null
 }

 if ( $version -ne $null) 
 {
   #when we are here, the version could be parsed 
   if ( $RespectLeadingZeros) {
      #Reminder: Version object defines Major.Minor.Build.Revision      

      #In case the version only contains of a major version, there is nothing to respect.
      #Whoever wants to have leading zeros for a major version respected should be killed. 
      if ( $version.Minor -gt -1 ) 
      {
         $verarray=@()
         $tokens=$Text.Split(".")         

         #always add the major version as is
         $verArray += [int]$tokens[0]

         if ( $tokens.Count -ge 2) 
         {
            $minor=$tokens[1]
            if ( $minor.StartsWith(0) )
            {
               #Add 0 as minor and the minor version as Build
               $verArray += 0               
            }
            $verArray += [int]$minor

            if ( $tokens.Count -ge 3) 
            {
              
              $build=$tokens[2]
              if ( $build.StartsWith(0) ) 
              {
               $verArray += 0               
              }
              $verArray += [int]$build


              if ( $tokens.Count -ge 4)
              {
                 $revision=$tokens[3]
                 if ( $revision.StartsWith(0) ) 
                 { 
                   $verArray += 0                   
                 }
                 $verArray += [int]$revision
              }
            }
         }


         #Turn the array to a string
         $verString=""
         foreach ($part in $verarray)
         {
          $verString += "$part."
         }
         $verString=$verString.TrimEnd(".")


         #Given that version can only hold Major.Minor.Build.Revision, we need to check if we have four or less entries
         if ( $verArray.Count -ge 5 )
         {
            $exception=New-Object System.ArgumentOutOfRangeException "Parsing given text resulted in a version that is incompatible with System.Version ($verString)"
            throw $exception
         }
         else
         {                                 
            $versionNew=New-Object System.Version $verarray
            $version=$versionNew
         }


         #all done
      }
   }

 }

 return $version
} 


function Exit-Context {
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
  [Parameter(Mandatory=$True,Position=1)]
  [ValidateNotNullOrEmpty()]
  [int32]$ExitCode,

  [Parameter(Mandatory=$False)]
  [switch]$Force=$False
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
      $ignored=[Environment]::Exit($ExitCode)
   }
   
   #This is also possible...
   #$host.SetShouldExit($returncode)  

   exit $ExitCode
 }
} 


function Get-QuickReference()
{
<#
  .SYNOPSIS
  Returns a quick reference about the given function or all functions in the module (if you are on GitHub, this text was generated with it).

  .PARAMETER Name
  Name of the function or the module to generate a quick reference

  .PARAMETER Module
  Name specifies a module, a quick reference for all functions in the module should be generated 

  .PARAMETER Output
  If the output should be a string (default), CommonMark or the real objects

  .OUTPUTS
  String
#>
param (
  [Parameter(Mandatory=$True,Position=1)]
  [string]$Name,

  [Parameter(Mandatory=$False)]
  [ValidateSet('String','CommonMark','Objects')]
  [System.String]$Output="String",

  [Parameter(Mandatory=$False)]
  [switch]$Module
)
 $qrList=@()

 if ( -not $Module )
 {
    $functions=Get-Command $Name
 }
 else
 {
    $functions=Get-Command -Module $Name
 }


 foreach ($function in $functions)
 {
   #generate result object 
   $QuickRef=[PSObject]@{"Name"=""; "Synopsis"=""; "Syntax"=@(); "Parameter"=@(); }

   #We need to respect the order of the parameters in the list, so we can't use a hashtable
   #  $QuickRef.Parameter=@{}
   #Or an OrderedDictionary
   #  $QuickRef.Parameter=New-Object "System.Collections.Specialized.OrderedDictionary"
   #A normal generic dictionary will do
   $QuickRef.Parameter=New-Object "System.Collections.Generic.Dictionary[string,string]"

      
   $functionName = $function.Name   
   
   $help=get-help $functionName

   $QuickRef.Name=$function.Name.Trim()
   $QuickRef.Synopsis=[string]$help.Synopsis.Trim() #aka "Description"
 
   ##################################
   # Syntax
   $syntax=$help.Syntax | Out-String   
   $syntax=$syntax.Trim()
   
   #check if we have more than one entry in syntax
   $syntaxTokens=$syntax.Split("`n")
   foreach ($syntaxToken in $syntaxTokens)
   {
      #most of the function do not support common params, so we leave this out
      $syntaxToken=$syntaxToken.Replace("[<CommonParameters>]", "")
      $syntaxToken=$syntaxToken.Trim()

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
     #Temp object which will used to either store a single paramter or a pointer to the real parameter collection
     $params=@()

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
             $ignored=$help.parameters.parameter.Count             
             $params=$help.parameters.parameter
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
      $paramName=$Param.Name
     
      #we might suck at documentation and forgot the description
      try 
      {
        $paramDesc=[string]$Param.Description.Text.Trim()
      }
      catch
      {
        $desc="*!*!* PARAMETER DESCRIPTION MISSING *!*!*"
      }     
      
      $QuickRef.Parameter.Add($paramName,$paramDesc) 
     }

   
   } #params is null

   #Now we should have everything in our QuickRef object
   $qrList += $QuickRef

  } #foreach
  
  #$qrList contains one or more objects we can use - check which output the caller wants
  switch ($Output)
  {
     "Objects"
     {
       return $qrList    
     }

     "CommonMark"
     {
        $txt=""

        #github requires three back-ticks but this is an escape char for PS 
        $CODE_BLOCK_END="``````" 
        $CODE_BLOCK_START="$($CODE_BLOCK_END)powershell" 

        foreach ($qr in $qrList)
        {  
          $txt +="### $($qr.Name) ###`n"
          $txt +="$($qr.Synopsis)`n"
   
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
        $txt=""

        foreach ($qr in $qrList)
        {  
          $txt +="( $($qr.Name) ) - $($qr.Synopsis)`n"
   
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