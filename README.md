# BIOS Sledgehammer
Automated BIOS, ME, TPM firmware update and BIOS settings for HP devices.

```
            _
    jgs   ./ |    
         /  /    BIOS Sledgehammer  
       /'  /     Copyright © 2015-2017 Michael 'Tex' Hex  
      /   /      
     /    \      https://github.com/texhex/BiosSledgehammer
    |      ``\     
    |        |                                ___________________
    |        |___________________...-------'''- - -  =- - =  - = `.
   /|        |                   \-  =  = -  -= - =  - =-   =  - =|
  ( |        |                    |= -= - = - = - = - =--= = - = =|
   \|        |___________________/- = - -= =_- =_-=_- -=_=-=_=_= -|
    |        |                   `` -------...___________________.'
    |________|      
      \    /     This is *NOT* sponsored/endorsed by HP or Intel.
      |    |     This is *NOT* an official HP or Intel tool.
    ,-'    `-,   
    |        |   Use at your own risk. 
    `--------'    

```
ASCII banner from: http://chris.com/ascii/index.php?art=objects/tools

## <a name="warning">Disclaimer</a> 

* BIOS Sledgehammer is **NOT** an official HP or Intel tool.                         
* This is **NOT** sponsored or endorsed by HP or Intel.
* HP or Intel were **NOT** involved in developing BIOS Sledgehammer.
* The device can become [FUBAR](https://en.wikipedia.org/wiki/List_of_military_slang_terms#FUBAR) in the process. 

## <a name="about">About</a>

Suppose you get a workitem like this: 

> For the Windows 10 rollout, we need you to support ten different hardware models and all of them need to be updated to the newest BIOS version. Some devices require a TPM firmware update to use the security features that depend on TPM 2.0. You also need to update the BIOS settings for all devices (Secure Boot, Fast Boot etc.) to meet Microsoft recommendations. And while you are at it, please also make sure to patch the Management Engine firmware security issue. Oh, and a new BIOS password would be a big plus because we currently have twenty different passwords in use. 

You can now waste precious life time to try to script this, or you can just use BIOS Sledgehammer:
* You can support several BIOS passwords for your devices, it will simply try all passwords you specify until the correct one is found
* You define which BIOS version the devices should have. Devices with newer versions will not trigger a downgrade. The BIOS version parsing works from older devices like 6300 Pro up to a 1040 G3.
* Define which Management Engine (ME) firmware a device should have and if the current firmware is older, an update if applied. 
* Define which TPM firmware and/or specification version (1.2 or 2.0) the device should have. Firmware checks are in place so BIOS Sledgehammer won’t try to flash “Update 6.40 to 7.41” on a device that has firmware 6.41
* The BIOS password can be set individual per model or you just set all devices to the same password. All passwords are stored encrypted (using *HPQPswd64.exe*). 
* The log files from the HP BIOS or TPM update tools are automatically appended to the BIOS Sledgehammer log, so if something goes wrong you only have one log to check. 
* BIOS settings are changed individual so when something goes wrong, you know exactly what the problem was.
* You can use it directly from MDT/SCCM, it will detect if a OSD is active and store the log(s) in the same path the task sequence uses. If desired, it can also be executed visible to see what it does.
* It offers a command line switch to be used during an in-place BIOS to UEFI boot mode conversion (Windows 10 1703 using MBR2GPT.exe), so the computer will start in UEFI mode (requires Windows 10 1703 or later).        
    
If this sounds good to you, see [Process](#process) how BIOS Sledgehammer works, view how to use it in [MDT or SCCM](#sccmmdt) or download it directly from [Releases](https://github.com/texhex/BiosSledgehammer/releases).


## <a name="requirements">System requirements</a>

* PowerShell 4.0 or higher
* Windows 7 64-bit or Windows 10 64-bit (Windows 8 should also work, but wasn't tested)
    * Due to restrictions in several HP tools, it can NOT be run in Windows Preinstallation Environment (WinPE)
* [HP BIOS Configuation Utility](https://ftp.hp.com/pub/caps-softpaq/cmit/HP_BCU.html) (BCU) stored in the folder ``\BCU-[Version]`` and the device must be supported by it. Most commercial devices that report "HP" as manufacturer are working. To cite the BCU docs:
    * *BCU requires HP custom WMI namespace and WMI classes (at the namespace root\HP\InstrumentedBIOS)
provided by BIOS. BCU will only support models with a WMI-compliant BIOS, which are most commercial HP
desktops, notebooks, and workstations.* 
* BIOS updates file for the models you want to support
	* Search http://www.hp.com/drivers for "(Model) BIOS" to locate them 
* TPM update files if a TPM specification or TPM firmware update is desired 
    * See [HP C05381064 advisory (TPM 2.0 Updates)](https://support.hp.com/en-us/document/c05381064) and [HP HPSBHF03568 advisory (Infineon TPM Security Update)](https://support.hp.com/us-en/document/c05792935)
* [Intel-SA-00075 Detection Tool](https://downloadcenter.intel.com/download/26755) stored in the folder ``ISA75DT-[Version]`` for Management Engine (ME) firmware tasks
    * For ME firmware files, see [HPSBHF03557 Advisory]( http://www8.hp.com/us/en/intelmanageabilityissue.html) or the driver download page from HP for the model
* Note: Several BIOS, TPM and ME files for the example models that are included in ``BiosSledgehammer.zip`` can be downloaded automatically - see [Installation](#install).  

## <a name="process">Process</a>

When starting BiosSledgehammer.ps1, the following will happen:

* A log file ``BiosSledgehammer.ps1.log-XX.txt`` is created, where XX is sequentially increased value with each run. See [Logfile](#logfile) for details.
* It checks if the environment is ready (64-bit OS, required folders found, device is from HP etc.).
* A check is made if communication between BCU (*BiosConfigUtility64.exe*) and the BIOS through WMI is possible by reading the value of the setting *Universally Unique Identifier (UUID)* or *Serial Number* from the BIOS.
* A search is performed below the [Models folder](#modelsfolder) to locate the matching folder for the current model. First an exact match for the model (e.g. if the current model is a *HP EliteBook Folio 1040 G1*, a folder named ``HP EliteBook Folio 1040 G1`` is expected). If this yields no result, a partially search is performed - a sub folder named ``1040 G1`` will match. All configuration is then read from this folder only. 
* It tries to figure out the password the device is using by going through all files in the [PwdFiles folder](#pwdfilesfolder) and trying to change the value of *Asset Tracking Number* to a random value (it will be reverted to the original value at the end). An empty password is always tried first.  
* If the file **BIOS-Update.txt** is found, it is read and checked if a BIOS update is required. If so, the BIOS update files are locally copied and the update is performed. Any **.log* file generated by the update tool is attached to the BIOS Sledgehammer log file.  Finally, a restart is requested because the actual update is performed during POST. See [BIOS Update](#biosupdate) for more details.
* If the file **ME-Update.txt** is found, it is read and checked if a Management Engine (ME) firmware update is required. If so, the ME firmware files are locally copied and an update is performed. Any **.log* file generated by the update tool is attached to the BIOS Sledgehammer log file.  Finally, a restart is requested because the actual update is performed during POST. See [ME Update](#meupdate) for more details.
* If the file **TPM-Update.txt** exists, it is read and checked if a TPM update is required. This happens by checking if the TPM specification version (1.2 or 2.0) or the TPM firmware are below the configured versions. If so, the TPM updates files are locally copied and executed. Any **.log* file generated by the update tool is attached to the BIOS Sledgehammer log file.  Finally, a restart is requested because the actual update is performed during POST. See [TPM Update](#tpmupdate) for more details.
* If the file **BIOS-Password.txt** is found, it is checked if the device is already set to use this password. The password is not specified directly (clear), but by using a *.bin file name that stores the password encrypted. If the passwords differ, the configured *.bin file is read from the [PwdFiles folder](#pwdfilesfolder) and the password is changed. See [BIOS Password](#biospassword) for more details.
* If the file **BIOS-Settings.txt** exists, it is read and each entry is the name of a BIOS setting that needs to be changed. Each entry will be performed as single change (not all in a batch) to detect faulty settings more easily. See [BIOS Settings](#biossettings) for more details.

Starting with Windows 10 1703, you can in-place convert from BIOS legacy (MBR) to UEFI boot mode (GPT); this is supported by BIOS Sledgehammer using the parameter ``-ActivateUEFIBoot``. This parameter will result in BIOS Sledgehammer only apply the BIOS settings defined in **Activate-UEFIBoot.txt**, which are one or two settings to change the boot mode to UEFI. Please see [In-place BIOS to UEFI boot mode conversion](#activateuefimode) for more details.  

## <a name="returncodes">Return Code (exit code)</a>

* 0 if everything was successful
* 3010 (ERROR_SUCCESS_REBOOT_REQUIRED) if a restart is required because of a BIOS or TPM update
* 666 if something didn't worked (Error)

## <a name="install">Installation</a>

BIOS Sledgehammer is "installed" by copying it to a folder where the device, that should run it, can execute it. Just store the contents of the ZIP archive (see [Releases](https://github.com/texhex/BiosSledgehammer/releases)) all in the same folder and don't rename any folder (``\PwdFiles``, ``\Models`` etc.). In case you want to run it from [MDT/SCCM](#sccmmdt), a good place is a new sub-folder below ``\Scripts`` in the MDT share.

You still need to customize some files so it works in your environment. The first thing should be to create the password files so BIOS Sledgehammer is able to access the BIOS (see [PwdFiles folder](pwdfilesfolder)).

The configuration for your different models is up to you, but the archive comes with several example in the [Models folder](#modelsfolder). Those examples lack the required BIOS, ME or TPM update files from HP. To acquire them, just start ``StartExampleDownloads.bat`` which will download and store them automatically.

:exclamation: **IMPORTANT!** The setting and downloaded files in ``\Models`` are just examples; there might be newer BIOS or TPM files available from HP, the settings provided might not match you environment etc. Please do not use these examples "as is" in production.   

## <a name="configformat">Configuration files format</a>

BIOS Sledgehammer uses several configuration files that all follow the same ``NAME==VALUE`` syntax. There are saved as *.txt files. 

```
# This is a comment and ignored
; So is this line. 
#And this.
;And this also.

# The general format is NAME==VALUE
Version==1.08

# Leading or trailing white spaces are ignored 
 Version2 == 3.7


# Empty line are ignored, add as many as you see fit
```

## <a name="logfile">Logfile</a>

Each time BIOS Sledgehammer is executed, a new logfile with the pattern ``BiosSledgehammer.ps1.log-XX.txt`` is created - ``XX`` is sequentially increased so the first run can be found in ``BiosSledgehammer.ps1.log-01.txt``, the second run in ``BiosSledgehammer.ps1.log-02.txt`` and so on. The location where these files are stored depends on if MDT/SCCM is active:

* By default the logfile is saved to ``C:\Windows\Temp\``.

* If it is executed in a task sequence by MDT or SCCM, the task sequence variable **LogPath** is used: ``C:\miniNT\SMSOSD\OSDLOGS\`` or ``C:\Windows\Temp\DeploymentLogs\``.

## <a name="modelsfolder">*Models* folder</a>

It is expected that each model (type) of hardware you want to support has a separate sub folder below ``\Models``. The model is displayed automatically by BIOS Sledgehammer, so simply run it once for each hardware to know the model. 

The sub folder for each model will contain all settings files together with source files for any updates. For example, if you execute BIOS Sledgehammer on a *HP EliteBook 820 G1* and a folder called ``\Models\HP EliteBook 820 G1\`` exists, the settings files need to be stored as ``\Models\HP EliteBook 820 G1\(FILENAME).txt``, e.g. ``\Models\HP EliteBook 820 G1\BIOS-Update.txt``. 

Any update files need to be stored as seperate folder below that path. For example, if ``\Models\HP EliteBook 820 G1\BIOS-Update.txt`` defines that a BIOS update to 1.39 is required, the BIOS update files need to be stored in the folder ``\Models\HP EliteBook 820 G1\BIOS-1.39\``. Please note that BIOS Sledgehammer does not support "sharing" update files between several models as sharing files between models has proven to cause problems for older models each time the shared folders are updated for new models. 

To locate a matching model folder, an exact match for current model is performed first. This means, if the current model is a *HP EliteBook Folio 1040 G1*, a folder named ``HP EliteBook Folio 1040 G1`` is expected. If there is no folder by this name, a partially search is performed. This will accept any folder that contains parts of the name of the current model, e.g. folder names like ``EliteBook Folio 1040 G1``, ``Folio 1040 G1`` or even ``1040 G1`` can be used.

Where this partially search helps a lot is for models that are technical identical but have different model names. For example, the *ProDesk 600 G1* comes in different form factors, each with a unique name: *HP ProDesk 600 G1 TWR* (Tower), *HP ProDesk 600 G1 SFF* (Small Format Factor) and so on. You can just create one folder ``HP ProDesk 600 G1`` and this folder will match all these form factors.

However, there are also cases where one family supports different form factors, and one of the form factors differs. For example, the *ProDesk 600 G2* comes in *TWR*, *MT*, *SFF* and *DM* form factors. The desktop mini (*DM*) has different hardware so it requires other settings. To support this, just create two folders: The first will match only the *DM*, so create a folder ``HP ProDesk 600 G2 DM``. For all other form factors, a partially matching folder named ``HP ProDesk 600 G2`` can be used. The *DM* will use his "private" folder, all other form factors will use the second folder.  

If you do not want to change anything for a given model, simply create an empty folder. If no model folder at all is found, an error is generated. 


## <a name="pwdfilesfolder">*PwdFiles* folder</a>

The ``\PwdFiles`` folder stores all BIOS passwords that your devices might use. When BIOS Sledgehammer starts, it tries every file in this folder until the password for the device has been found (an empty password is automatically added, there is no file for this). If no password file matches, an error is generated. 

The order, in which they are tried, is determined by sorting the files by name: a file called *01_Standard.bin* is tried before *02_Standard.bin*. The most commonly used password should always come first because some BIOS versions enforce how many times you can try a wrong BIOS password. When this limit is reached, any password is rejected until the computer is restarted. 

To create a password file, execute ``HPQPswd64.exe`` (found in the BCU folder) and save the file to the ``\PwdFiles`` folder as *.BIN file.  


## <a name="biosupdate">BIOS Update</a>

The settings for a BIOS update are read from the file ``BIOS-Update.txt`` in the matching [model folder](#modelsfolder). Example file:

```
# 850 G1 BIOS Update

# The BIOS version the device should have
Version == 1.37

# Command to be executed for the BIOS update
Command==HPBiosUpdRec64.exe 

# Arguments to pass to COMMAND

# Silent
Arg1 == -s
# Do not restart automatically
Arg2 == -r
# Disable BitLocker during upgrade
Arg3 == -b
# Password file (parameter will be removed if device has no BIOS password)
Arg4 == -p"@@PASSWORD_FILE@@"
```

Some devices (e.g. ProBook 6570b) feature different BIOS families which require that the correct firmware file for the BIOS family is passed to the update process. This can be done by creating an entry *Family==FirmwareFile* in ``BIOS-Update.txt`` and define the parameter for a firmware file together with the replacement value *@@FIRMWARE_FILE@@*. Models that only offer one BIOS family (this is the majority) do not need these entries. 
```
# 6570b Update

# The BIOS version the device should be on
Version == F.66

# This model supports different BIOS families - define the update files for each of them
68ICE==68ICE.CAB
68ICF==68ICF.CAB

# Command to be executed for the BIOS update
Command==hpqFlash64.exe

# Arguments to pass to COMMAND

# Silent
Arg1 == -s
# Password file (will be removed if empty password)
Arg2 == -p"@@PASSWORD_FILE@@"
# Firmware file for BIOS family
Arg3 == -f"@@FIRMWARE_FILE@@"
# Do not restart automatically
Arg4 == -r
```

**Note**: BIOS Sledgehammer enforces that the source files are stored in a sub folder of the [model folder](#modelsfolder) called ``BIOS-<VERSION>``. If the desired BIOS version is ``1.37``, the folder name would be ``\BIOS-1.37\``.  

The source folder is then copied to %TEMP% (to avoid any network issues) and the update process is started from there. Because the update utility sometimes restarts itself, the execution is paused until the process noted in COMMAND is no longer running. If any **.log* file was generated in the local folder, the content is added to the normal BIOS Sledgehammer log. A restart is requested after that because the “real” update process happens during POST, after the restart. 

If anything goes wrong during the process, an error is generated. 


## <a name="meupdate">Management Engine (ME) Update</a>

Depending on the model, a device might be equipped with [Intel Active Management Technology](https://en.wikipedia.org/wiki/Intel_Active_Management_Technology) (Intel vPro) which allows for remote out-of-band management, so the device can be managed even if it's off or no operating system at all is installed. This function is provided by the Intel Management Engine (ME) which is also updatable. This can be done with BIOS Sledgehammer.   
 
:warning: **WARNING!** Some versions of the update tool for the ME firmware from HP **DO NOT** check if the provided ME firmware file matches the current model. This means, they allows to flash the wrong firmware without any error message. If this happens, the machine will be FUBAR on next start (CAPS LOCK will blink 5 times and a mainboard replacement is required). Please pay extra caution when using ME firmware updates and always do a test run on a spare machine. 

If possible, check if an BIOS update is available that also updates the ME firmware as this method is much safer than direct ME firmware updates. On the other hand, some BIOS versions require a ME firmware after a BIOS update (see [ProDesk 600 G2 BIOS v2.17](https://ftp.hp.com/pub/softpaq/sp78001-78500/sp78294.html)), so you might be forced to do direct updates.

The settings for a ME update are read from the file ``ME-Update.txt`` in the matching [model folder](#modelsfolder). Example:

```
# EliteBook 820 G1

# The ME firmware version the device should have
Version == 9.5.61.3012

# Command to be executed for the ME update
Command==CallInst.exe
  
Arg1 == /app Update.bat 
Arg2 == /hide
```

:exclamation: **IMPORTANT!** Please note that newer versions of the ME firmware update tool require the .NET 3.x framework to be installed. 

*Version* defines which ME version the device should have. If the current firmware is older, the update files are copied locally and then started using the settings *Command* and *ArgX*. A restart is requested after that because the new firmware will only be activated during POST, after an restart. 

**Note**: BIOS Sledgehammer enforces that the source files are stored in a sub folder of the [model folder](#modelsfolder) called ``ME-<VERSION>``. If the desired ME firmware version is ``9.5.61.3012``, the folder needs to be named ``\ME-9.5.61.3012\``. 

If anything goes wrong during the process, an error is generated. 


## <a name="meissuecheck">Management Engine (ME) Vulnerability Check</a>

In 2017-05 a severe security vulnerability was found in the Management Engine (ME): [INTEL-SA-00075](https://security-center.intel.com/advisory.aspx?intelid=INTEL-SA-00075&languageid=en-fr) / [CVE-2017-5689](http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2017-5689) which could allow an unprivileged attacker to gain full control of the ME, which in turn allows full control of the device.

BIOS Sledgehammer can run the [Intel-SA-00075 Detection Tool](https://downloadcenter.intel.com/download/26755) to check if the device is vulnerable and log the result. To do so, the file ``ME-VulnerabilityScan.txt`` must exist in the [model folder](#modelsfolder). No settings in this file are needed.
```
# If this file (ME-VulnerabilityScan.txt) exists, the Intel-SA-00075 detection tool will be run.
# See https://downloadcenter.intel.com/download/26755
```

If the system is detected as vulnerable, check the [HPSBHF03557 Advisory](http://www8.hp.com/us/en/intelmanageabilityissue.html) for an updated ME firmware and use the [Management Engine (ME) Update](#meupdate) process.


## <a name="tpmupdate">TPM Update</a>

The settings for a TPM update are read from the file ``TPM-Update.txt`` in the matching [model folder](#modelsfolder). Example file: 

```
# 1040 G3 TPM Update

# Manufacturer of the TPM. 
# If the value exists, the device must have this vendor or no update takes place
Manufacturer == 1229346816
# 1229346816 is IFX

# The TPM Spec version we want this device to have
SpecVersion == 2.0

# The Firmware version we want this device to have 
FirmwareVersion == 7.41

# Define the upgrade file to be used for each firmware
# The firmware active on the device must match an entry here or no upgrade can be performed
6.40 == Firmware\TPM12_6.40.190.0_to_TPM20_7.41.2375.0.BIN
6.41 == Firmware\TPM12_6.41.197.0_to_TPM20_7.41.2375.0.BIN
7.40 == Firmware\TPM20_7.40.2098.0_to_TPM20_7.41.2375.0.BIN

# Command to be used to perform the TPM firmware upgrade
Command == TPMConfig64.exe

# Arguments passed to COMMAND
Arg1 == -s
Arg2 == -f"@@FIRMWARE_FILE@@"
Arg3 == -p"@@PASSWORD_FILE@@"
```
The first setting **Manufacturer** is optional and can be used to ensure that the TPM firmware vendor for the device matches the update files. If it's not defined, the TPM firmware vendor is ignored. 

To detect if an TPM update is required, two versions need to be checked: The TPM Specification version (**SpecVersion**) and the firmware version (**FirmwareVersion**). 

The reason is that all TPM firmware is developed by 3rd parties so a change from TPM 1.2 to 2.0 can result in a LOWER firmware version when the vendor is changed (see [this article on the Dell wiki]( http://en.community.dell.com/techcenter/enterprise-client/w/wiki/11850.how-to-change-tpm-modes-1-2-2-0) – TPM Spec 1.2 is firmware 5.81 from WEC, TPM Spec 2.0 is firmware 1.3 from NTC). BIOS Sledgehammer checks both versions and if any of those two are higher than the current device reports, a TPM update is started. 

The current TPM firmware version of the device is retrieved and it is checked if the settings file contains an entry for this firmware version. Given that the current device has TPM firmware 6.40, the update can be performed as an entry for this version exists (**6.40 == Firmware\TPM12....**). However, if the device would have firmware 6.22 the update would fail because no entry for this version exists.

The TPM update also requires that BitLocker is turned off (as any BitLocker keys are lost during the upgrade), so BIOS Sledgehammer will check if the system drive C: is encrypted with BitLocker and starts an automatic decryption before executing the update. This works for Windows 10, but fails in Windows 7 as the required BitLocker PowerShell module does not exist. 

Once this is all set and done, the source folder is copied to %TEMP% (to avoid any network issues) and the process is started from there.

**Note:** BIOS Sledgehammer enforces that the source files are stored in a sub folder of the [model folder](#modelsfolder) called ``TPM-<VERSION>``. If the desired TPM firmware version is ``7.41``, the folder name would be ``\TPM-7.41\``. 

Because the update utility sometimes restarts itself, the execution is paused until the process noted in COMMAND is no longer running. If any **.log* file was generated in the local folder, the content is added to the normal BIOS Sledgehammer log. A restart is requested after that because the actual update process happens during POST, after the restart. 

If anything goes wrong during the process, an error is generated. 

### Special handling for 6.41 firmware

BIOS Sledgehammer is able to handle the special case of the 6.41.x firmware. This firmware comes in two different versions:

 * 6.41.**197** is used for devices that have a TPM 1.2 by default
 * 6.41.**198** is used for devices that were downgraded from TPM 2.0 to TPM 1.2

The problem is that the [Win32_TPM](https://msdn.microsoft.com/en-us/library/windows/desktop/aa376484(v=vs.85).aspx) CIM class does not provide the BUILD number (.197 or .198) in the ``ManufacturerVersion`` field. Therefore, it can not be detected which 6.41 firmware is currently active. 

If the firmware file specified for the update does not match exactly, the TPM will reject the update (Full details in [Issue #9](https://github.com/texhex/BiosSledgehammer/issues/9)).

To support this special case, it is possible to define two entries for the same firmware version:

```
6.41.A == Firmware\TPM12_6.41.197.0_to_TPM20_7.61.2785.0.BIN
6.41.B == Firmware\TPM12_6.41.198.0_to_TPM20_7.61.2785.0.BIN
```

BIOS Sledgehammer will first try to flash the first file (*6.41.A). If the TPM update executable returns a *Wrong firmware file* error, the second firmware file (*6.41.B*) is tried.

### BIOS setting dependencies

Newer BIOS version for the EliteBook series (G3 or upward) do not allow TPM updates when either [Intel Software Guard Extensions aka "SGX"](https://en.wikipedia.org/wiki/Software_Guard_Extensions) or [Intel Trusted Execution Technology aka "TXT"](https://en.wikipedia.org/wiki/Trusted_Execution_Technology) are activated.

To support this, these BIOS settings can be disabled just before the TPM update takes place using the file `` TPM-BIOS-Settings.txt``. If no TPM update is required, no changes are made. The file works exactly the same as described in [BIOS Settings](#biossettings) and should only contain the changes that are required for the TPM update to succeed.
 
```
# EliteBook 8x0 G4 BIOS Settings required for TPM update
# When these options are activated, no TPM firmware can be installed

Intel Software Guard Extensions (SGX) == Disable
Trusted Execution Technology (TXT) == Disable
```

**NOTE:** It is perfectly fine to set a setting here differently than in [BIOS Settings](#biossettings). For example, **Trusted Execution Technology (TXT)** needs to be *DISABLE* here (as this is required to allow an TPM update) but can be set to *ENABLE* in [BIOS Settings](#biossettings). The later is executed after the TPM update so the settings there will be in effect. 


### Disable automatic BitLocker decryption

In cases of updates for in-use machines, the automatic decryption of BitLocker that BIOS Sledgehammer performs might not be desired as this will require a full roll-in of BitLocker later on. 

It is possible that a script (executed before BIOS Sledgehammer) removes the TPM protector and then pauses BitLocker protection. Adding the parameter **IgnoreBitLocker==Yes** in ``TPM-Update.txt`` will cause BIOS Sledgehammer to ignore BitLocker all together and not start a full decryption. 
 

```
# Ignore BitLocker - If activated, no automatic BitLocker decryption will take place
IgnoreBitLocker==Yes
```

:warning: **WARNING!** Please take extra care when using this parameter! When removing the TPM protector using ``manager-bde.exe`` and forget to also specify the **RebootCount** parameter, you can lock yourself out of your device. For full details, see the [manage-bde docs](https://technet.microsoft.com/en-us/library/ff829848(v=ws.11).aspx#BKMK_disableprot). You have been warned. 


## <a name="biospassword">BIOS Password</a>

To set a BIOS password, you define the password file (containing the desired password) in ``BIOS-Password.txt``. This file must be stored in the [model folder](#modelsfolder). Example file:
```
# Use our standard password
PasswordFile == 01_W2f4x7t8NxD4xUH.bin
```
:exclamation: **IMPORTANT!** This is insecure and just an example! Do not use the password itself as file name!   

This file has to be stored in the [PwdFiles folder](#pwdfilesfolder) (see the section how to create the files). If you want to use an empty password, just leave the value empty like this:
```
# Empty password (bad idea!)
PasswordFile == 
```
Regarding BIOS passwords, please note the following:
* Passwords need to meet minimum complexity rules (must contain upper and lower case letters and a number) or the BIOS will reject the password change but won't issue any specific error message - it will simply return "Invalid password file". The only exception of this rule is an empty password which is always allowed.
* There are only some password changes allowed per power cycle. If the password change just doesn’t work although it has worked before, turn the device off and on.


## <a name="biossettings">BIOS Settings</a>

The configuration of the BIOS are read from the file ``BIOS-Settings.txt`` in the matching [model folder](#modelsfolder). Example file: 
```
# 850 G1 
LAN/WLAN Switching == Enable

Intel (R) HT Technology == Enable

Floppy boot == Disable

Asset Tracking Number == @@COMPUTERNAME@@
```
Each entry simply lists how the BIOS setting is called, e.g. **LAN/WLAN Switching**, and to which value, e.g. **Enable** it should be configured. To get a complete list which BIOS settings the current device support, execute ``GetAllBiosSettings.bat`` (as Administrator) in the BCU folder. Please note that the list of available settings differs which each model and can also change when the BIOS is updated. Always first update the BIOS, then check the list of available settings.
 
Each setting is individual changed and not as batch so if any setting is wrong, it is very clear which setting is causing an issue. BIOS Sledgehammer also tries to “translate” the error code of BCU to an explanation what went wrong (as defined by the error code list from the BCU User Guide PDF).
 
A single replacement value is supported: *@@COMPUTERNAME@@*. If this value is detected, the value is replaced with the computer name of the device executing BIOS Sledgehammer. 

Please note that on some devices, some BIOS settings (e.g. TPM Activation Policy on a 2570p), require a password to be set or they can’t be activated. If this happens, BCU just fails with error 32769.

Also, BCU performs some basic checks to prevent changes that are not compatible with the current OS. For example, setting “SecureBoot” to “Enable” fails with error code 32769 when using Windows 7 but works directly on Windows 10. However, other settings are not checked so don’t count on that BCU will prevent all incompatible changes.


## <a name="activateuefimode">In-place BIOS to UEFI boot mode conversion</a>

Some Windows 10 security features (e.g. Device Guard) require that the computer is in UEFI boot mode. If you already have updated machines to Windows 10, but those are using BIOS legacy boot mode, you couldn't use these security features as switching the boot mode to UEFI caused Windows to stop working.

With Windows 10 1703, you can in-place switch to UEFI boot mode (see this [demo](https://technet.microsoft.com/en-us/windows/mt782786) for details). This is a two step process by first executing [MBR2GPT.exe](https://technet.microsoft.com/en-us/itpro/windows/deploy/mbr-to-gpt), which prepares Windows to use UEFI boot mode, and then changing the BIOS settings to start in UEFI mode.

For the later, you can use BIOS Sledgehammer with the ``-ActivateUEFIBoot`` switch. When this switched is used, only the file ``Activate-UEFIBoot.txt`` will be applied which is read from the matching [model folder](#modelsfolder). Example: 
```
# 850 G2

Boot Mode==UEFI Native (Without CSM)
SecureBoot==Enable
```
The file works exactly as described in [BIOS Settings](#biossettings) and can, if required, contain more settings. However, since the in-place boot mode change is a critical step, you should keep the changes to a minimum. After the change has been done, and the computer was restarted, you can execute BIOS Sledgehammer normally and change all other settings.    


## <a name="sccmmdt">Using it from MDT or SCCM</a>

By default, MDT/SCCM will run all scripts hidden to hide sensitive information. If you are okay with this, just run ``BiosSledgehammer.ps1`` as PowerShell script, but remember to tick the box for "Disable 64bit file system redirection" so it is run as 64-bit PowerShell process. This settings applies only for SCCM - MDT always runs PowerShell scripts native.

If you want to see what BIOS Sledgehammer is doing, run the provided batch file ``RunVisble.bat`` with this command line in MDT/SCCM: ``cmd.exe /c "%SCRIPTROOT%\BiosSledgehammer\RunVisible.bat"`` (given you stored it in the *\Scripts* folder). 

This batch automatically uses the correct (native) version of PowerShell and will also set the ``-WaitAtEnd`` parameter which causes BIOS Sledgehammer to pause for 30 seconds when finished. This way, you can have a quick look at the results.

:exclamation: **IMPORTANT** When using the ``RunVisible.bat``, no error code is transfered back to the task sequence. So even if BIOS Sledgehammer reports a fatal exit code, the Task Sequence will receive return code 0. This comes from the fact the task sequence executes cmd.exe which starts a batch, which starts "START" which executes PowerShell.exe which starts BiosSledgehammer.ps1. Somewhere along the way the return code is lost.  

It is recommended to start BIOS Sledgehammer **four** times and restart the device after each run. If a device requires a BIOS Update, a TPM update and BIOS setting changes, three executions are needed. The final one is to make sure everything worked - for example if an operator accidently hit F2 (Do not perform update) during POST when asked if a firmware update should take place.

In case you used ``RunVisible.bat`` the last (4th) run should not use it but instead execute directly ``BiosSledgehammer.ps1`` using *Run PowerShell Script* with the parameter ``-Verbose``. That's because ``RunVisible.bat`` does not return any error code. So if there is a problem, this last run will make sure MDT/SCCM is getting a correct return code and can break the deployment if there is a problem. The ``-Verbose`` option will make sure that the log contains all data (even BCU output) for troubelshooting.   


## <a name="contributions">Contributions</a>
Any constructive contribution is very welcome! 

If you encounter a bug, please start BIOS Sledgehammer with the option -Verbose (``.\BiosSledgehammer.ps1 -Verbose``) and attach the logfile to [new issue](https://github.com/texhex/BiosSledgehammer/issues/new).

## <a name="license">License</a>
``BiosSledgehammer.ps1`` and ``MPSXM.psm1``: Copyright © 2015-2017 [Michael Hex](http://www.texhex.info/). Licensed under the **Apache 2 License**. For details, please see LICENSE.txt.

All HP related files (BCU, BIOS, TPM etc.) are © Copyright 2012–2015 Hewlett-Packard Development Company, L.P. and/or other HP companies. These files are licensed under different terms. 

All Intel related files (SA-00075) are © Copyright Intel. These files are licensed under different terms. 

