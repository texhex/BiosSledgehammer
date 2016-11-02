# BIOS Sledgehammer
Automated BIOS update, TPM firmware update and BIOS settings for HP devices.


```
            _
    jgs   ./ |   BIOS Sledgehammer 
         /  /      
       /'  /       
      /   /      https://github.com/texhex/BiosSledgehammer
     /    \      
    |      ``\     
    |        |                                ___________________
    |        |___________________...-------'''- - -  =- - =  - = `.
   /|        |                   \-  =  = -  -= - =  - =-   =  - =|
  ( |        |                    |= -= - = - = - = - =--= = - = =|
   \|        |___________________/- = - -= =_- =_-=_- -=_=-=_=_= -|
    |        |                   `` -------...___________________.'
    |________|      
      \    /     
      |    |     This is *NOT* an official HP tool.                         
    ,-'    `-,   This is *NOT* sponsored or endorsed by HP.
    |        |   Use at your own risk. 
    `--------'    

```

## Disclaimer 

* BIOS Sledgehammer is **NOT** an official HP tool.                         
* This is **NOT** sponsored or endorsed by HP.
* HP was **NOT** involved in developing BIOS Sledgehammer.
* You computer can become FUBAR in the process. 

## About

## Process

When starting BiosSledgehammer.ps1, the following will happen:

* It checks if the environment is ready (64-bit OS, required folders, device is from HP)
* It will try to figure out the password the device is using by going through all files in the [PwdFiles](pwdfilesfolder) folder 

### <a name="pwdfilesfolder">PwdFile folder</a>

The ``\PwdFiles`` folder stores all passowrds BIOS Sledgehammer should try and also the order in which they are processed. 

## TPM Information

* [Dell: TPM 1.2 vs. 2.0 Features](http://en.community.dell.com/techcenter/enterprise-client/w/wiki/11849.tpm-1-2-vs-2-0-features)
* [Dell: Get TPM information using PowerShell](http://en.community.dell.com/techcenter/b/techcenter/archive/2015/12/09/retrieve-trusted-platform-module-tpm-version-information-using-powershell)
* [Dell: How to change TPM Modes](http://en.community.dell.com/techcenter/enterprise-client/w/wiki/11850.how-to-change-tpm-modes-1-2-2-0)
* 



http://chris.com/ascii/index.php?art=objects/tools

## Using from MDT or SCCM

By default, MDT will run all scripts hidden in order to hide any sensitive information displayed. If you are okay with that, just run ``BiosSledgehammer.ps1`` as PowerShell scripts but remember to tick the box for "Disable 64bit file system redirection" so it is run as 64-bit PowerShell process (this settings is only for SCCM - MDT always runs PowerShell native).

If you want to see what BIOS Sledgehammer is doing, run the provided batch file ``RunVisble.bat`` from MDT with this command line: ``cmd.exe /c "%SCRIPTROOT%\BiosSledgehammer\RunVisible.bat"`` (given you stored it in the *\Scripts* folder). 

This batch automatically uses the correct version of PowerShell, so no box to check for this. It will also set the ``-WaitAtEnd`` parameter which causes BIOS Sledgehammer to pause for 30 seconds when finished so you can have a quick look at the results. 
  


## Contributions
Any constructive contribution is very welcome! If you encounter a bug or have an addition, please create a [new issue](https://github.com/texhex/BiosSledgehammer/issues/new).

## License
Copyright © 2016 [Michael Hex](http://www.texhex.info/). Licensed under the **Apache 2 License**. For details, please see LICENSE.txt.



## TODO
* In case BCU returns the code 32769 it can mean two things:
  * This setting can not be set without a BIOS password beeing in place (TPM Activation Policy for example)
  * This setting would result in damage to the current systen (Secure Boot enabled when running this script from Windows 7)
* BIOS passwords need to meet minimum complexity rules. If the password stored in a *.bin file does not meet this rules, the password change will fail. Make sure your password contains uppercase and lowercase letter, together with at least one number.
*  #HPBiosUpdRec64.exe might restart itself as a service in order to perform the update...        

    More about TPM Data:
    http://en.community.dell.com/techcenter/b/techcenter/archive/2015/12/09/retrieve-trusted-platform-module-tpm-version-information-using-powershell
    http://en.community.dell.com/techcenter/enterprise-client/w/wiki/11850.how-to-change-tpm-modes-1-2-2-0
    http://www.dell.com/support/article/de/de/debsdt1/SLN300906/en
    http://h20564.www2.hp.com/hpsc/doc/public/display?docId=emr_na-c05192291
  #>

  * Dell:
  *   ID 1314145024 = NTC with Version 1.3 = TPM 2.0
  *   ID 1464156928 = WEC with Version 5.81 = TPM 1.2
  * HP:
  *   ID 1229346816 = IFX with Version 4.32 = TPM 1.2
  *

* TPM Update: Check Manufacturer ID  
* TPM Update starts if either the TPM SpecVersion **OR** the firmware is below the defined values
* TPM Update: BitLocker for C: and BitLocker module available will cause a full decryption
* Log file are either in C:\Windows\Temp\BiosSledgehammer.ps1.log-XX.txt or in the path your MDT/SCCM defines as ``LogPath`` (typical *C:\MININT\SMSOSD\OSDLOGS* or when it's finished *C:\Windows\Temp\DeploymentLogs\*)

BCU:
  https://ftp.hp.com/pub/caps-softpaq/cmit/HP_BCU.html
  
BIOS Updates:
  http://www.hp.com/drivers

TPM Advisory:
  http://h20564.www2.hp.com/hpsc/doc/public/display?docId=emr_na-c05192291
  
Download:
  ftp://ftp.hp.com/pub/softpaq/sp76001-76500/sp76423.html

* zz_GetAllBiosSettings.bat