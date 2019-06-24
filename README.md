# BIOS Sledgehammer

Automated BIOS, ME, TPM firmware update and BIOS settings for HP devices.

```
            _
    jgs   ./ |    
         /  /    BIOS Sledgehammer  
       /'  /     Copyright © 2015-2019 Michael 'Tex' Hex  
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

## Disclaimer

* BIOS Sledgehammer is **NOT** an official HP or Intel tool.
* This is **NOT** sponsored or endorsed by HP or Intel.
* HP or Intel were **NOT** involved in developing BIOS Sledgehammer.
* The device can become [FUBAR](https://en.wikipedia.org/wiki/List_of_military_slang_terms#FUBAR) in the process. 

## About

Suppose you get a workitem like this:

> For the Windows 10 rollout, we need you to support ten different hardware models and all of them need to be updated to the newest BIOS version. Some devices require a TPM firmware update to use the security features that depend on TPM 2.0. You also need to update the BIOS settings for all devices (Secure Boot, Fast Boot etc.) to meet Microsoft recommendations. And while you are at it, please also make sure to patch the Management Engine firmware security issue. Oh, and a new BIOS password would be a big plus because we currently have twenty different passwords in use.

You can now waste precious life time to try to script this, or you can just use BIOS Sledgehammer:

* You can support several BIOS passwords for your devices, it will simply try all passwords you specify until the correct one is found.
* You define which BIOS version the devices should have. Devices with newer versions will not trigger a downgrade.
* The BIOS version parsing works from rather old devices like 6300 Pro up to a modern device.
* Define which Management Engine (ME) firmware a device should have and if the current firmware is older, an update if applied.
* Configure which TPM firmware and/or specification version (1.2 or 2.0) a device should have - if any of those do not match, an update is started.
* The BIOS password can be set individual per model or you just set all devices to the same password. All passwords are stored encrypted (using *HPQPswd64.exe*).
* The log files from the update tools are automatically appended to the BIOS Sledgehammer log, so you have one log with all details.
* Configure the BIOS settings for a device by using a simple Name==Value format. They are changed individual so if there is any issue, you know exactly which setting is to blame.
* Shared configurations are supported, so device families (e.g. the EliteBook 8x0 series) can use a single configuration folder.
* You can use it directly from MDT/SCCM, it will detect if a OSD is active and store the log(s) in the same path the task sequence uses. If desired, it can also be executed visible to see what it does.
* It offers a command line switch to be used during an in-place BIOS to UEFI boot mode conversion (Windows 10 1703 using MBR2GPT.exe), so the computer will start in UEFI mode (requires Windows 10 1703 or later).

If this sounds good to you, see [Process](#process) how BIOS Sledgehammer works, view how to use it in [MDT or SCCM](#using-it-from-MDT-or-SCCM) or download it directly from [Releases](https://github.com/texhex/BiosSledgehammer/releases).

## System requirements

* PowerShell 4.0 or higher
* Windows 7 64-bit or Windows 10 64-bit
  * Due to restrictions in several HP tools, it can **NOT** be run in Windows Preinstallation Environment (WinPE)
* [HP BIOS Configuation Utility](https://ftp.hp.com/pub/caps-softpaq/cmit/HP_BCU.html) (BCU) stored in the folder ``\BCU-[Version]`` and the device must be supported by it. Most commercial devices that report "HP" as manufacturer are working. To cite the BCU docs:
  * BCU requires HP custom WMI namespace and WMI classes (at the namespace root\HP\InstrumentedBIOS)
provided by BIOS. BCU will only support models with a WMI-compliant BIOS, which are most commercial HP
desktops, notebooks, and workstations.*
* BIOS updates file for the models you want to support
  * Search http://www.hp.com/drivers for "(Model) BIOS" to locate them or see [HPSBHF03573 advisory (Intel Spectre V2 BIOS updates)](https://support.hp.com/us-en/document/c05869091)
* TPM update files if a TPM specification or TPM firmware update is desired
  * See [HP C05381064 advisory (TPM 2.0 Updates)](https://support.hp.com/en-us/document/c05381064) and [HP HPSBHF03568 advisory (Infineon TPM Security Update)](https://support.hp.com/us-en/document/c05792935)
* ME updates if a Management Engine (vPro) update is desired
  * See [HPSBHF03571 advisory](https://support.hp.com/us-en/document/c05843704) ([Intel-SA-00086](https://www.intel.com/content/www/us/en/support/articles/000025619/software.html)) and
  [HPSBHF03557 advisory](http://www8.hp.com/us/en/intelmanageabilityissue.html) ([Intel-SA-00075](https://security-center.intel.com/advisory.aspx?intelid=INTEL-SA-00075&languageid=en-fr)) or the driver download page from HP for the model
* [Intel-SA-00075 Detection Tool](https://downloadcenter.intel.com/download/26755) stored in the folder ``ISA75DT-[Version]`` for Management Engine (ME) firmware tasks

:information_source: **Note:** Several BIOS, TPM and ME files for the example models that are included can be downloaded automatically - see [Installation](#installation).

## Process

When starting BiosSledgehammer.ps1, the following will happen:

* A log file ``BiosSledgehammer.ps1.log-XX.txt`` is created, where XX is sequentially increased value with each run. See [Logfile](#logfile) for details.
* It checks if the environment is ready (64-bit OS, required folders found, device is from HP etc.).
* A check is made if communication between BCU (*BiosConfigUtility64.exe*) and the BIOS through WMI is possible by reading the value of the setting *Universally Unique Identifier (UUID)* or *Serial Number* from the BIOS.
* A search is performed below the [Models folder](#models-folder) to locate the matching folder for the current model. First, a folder named exactly as the SKU of the current device is searched. If this folder does not exist, an exact match for the model name is performed. For example, if the current model is a *HP EliteBook Folio 1040 G1*, a folder named ``HP EliteBook Folio 1040 G1`` is expected. If this also yields no result, a partially search is performed - a sub folder named ``1040 G1`` will match. All configuration is then read from this folder only.
* It tries to figure out the password the device is using by going through all files in the [PwdFiles folder](#pwdfiles-folder) and trying to change the value of *Asset Tracking Number* to a random value (it will be reverted to the original value at the end). An empty password is always tried first.
* If the file **BIOS-Update.txt** is found, it is read and checked if a BIOS update is required. If so, the BIOS update files are locally copied and the update is performed. Any **.log* file generated by the update tool is attached to the BIOS Sledgehammer log file.  Finally, a restart is requested because the actual update is performed during POST. See [BIOS Update](#bios-update) for more details.
* If the file **ME-Update.txt** is found, it is read and checked if a Management Engine (ME) firmware update is required. If so, the ME firmware files are locally copied and an update is performed. Any **.log* file generated by the update tool is attached to the BIOS Sledgehammer log file.  Finally, a restart is requested because the actual update is performed during POST. See [ME Update](#management-engine-me-update) for more details.
* If the file **TPM-Update.txt** exists, it is read and checked if a TPM update is required. This happens by checking if the TPM specification version (1.2 or 2.0) or the TPM firmware are below the configured versions. If so, the TPM updates files are locally copied and executed. Any **.log* file generated by the update tool is attached to the BIOS Sledgehammer log file.  Finally, a restart is requested because the actual update is performed during POST. See [TPM Update](#tpm-update) for more details.
* If the file **BIOS-Password.txt** is found, it is checked if the device is already set to use this password. The password is not specified directly (clear), but by using a *.bin file name that stores the password encrypted. If the passwords differ, the configured *.bin file is read from the [PwdFiles folder](#pwdfiles-folder) and the password is changed. See [BIOS Password](#bios-password) for more details.
* If the file **BIOS-Settings.txt** exists, it is read and each entry is the name of a BIOS setting that needs to be changed. Each entry will be executed as a single change in the exact order they are defined; this makes detecting faulty settings (if any) easy. See [BIOS Settings](#bios-settings) for more details.

For both [BIOS Update](#bios-update) and [TPM Update](#tpm-update), BIOS Sledeghammer can change BIOS settings just before an update happens. This is often required since both updates will not work if certain BIOS settings are in place. Please see [BIOS Settings for BIOS update](#bios-settings-for-bios-update) and [TPM BIOS Settings](#tpm-bios-settings).

Starting with Windows 10 1703, you can in-place convert from BIOS legacy (MBR) to UEFI boot mode (GPT); this is supported by BIOS Sledgehammer using the parameter ``-ActivateUEFIBoot``. This parameter will result in BIOS Sledgehammer only apply the BIOS settings defined in **Activate-UEFIBoot.txt**, which are one or two settings to change the boot mode to UEFI. Please see [In-place BIOS to UEFI boot mode conversion](#in-place-bios-to-uefi-boot-mode-conversion) for more details.

## Return Code (exit code)

* 0 if everything was successful
* 3010 (ERROR_SUCCESS_REBOOT_REQUIRED) if a restart is required because of a BIOS or TPM update
* 666 if something didn't worked (Error)

## Installation

BIOS Sledgehammer is "installed" by copying it to a folder where the device, that should run it, can execute it. Just store the contents of the ZIP archive (see [Releases](https://github.com/texhex/BiosSledgehammer/releases)) all in the same folder and don't rename any folder (``\PwdFiles``, ``\Models`` etc.). In case you want to run it from [MDT/SCCM](#using-it-from-mdt-or-sccm), a good place is a new sub-folder below ``\Scripts`` in the MDT share. If you do not use any of these tools and wish to execute the script manually, you can also use a file share from a file server or NAS.

You still need to customize some files so it works in your environment. The first thing should be to create the password files so BIOS Sledgehammer is able to access the BIOS (see [PwdFiles folder](#pwdfiles-folder)).

The configuration for your different models is up to you, but the archive comes with several example in the [Models folder](#models-folder) and [Shared folder](#shared-folder). Those examples lack the required BIOS, ME or TPM update files from HP. To acquire them, just start ``StartSoftPaqDownloads.bat`` which will download and store them automatically.

:exclamation: **IMPORTANT!** The settings and downloaded files in ``\Models`` and ``\Shared`` are just examples; there might be newer firmware files available from HP, the settings provided might not match you environment etc. Please do not use these examples "as is" in production.

## Configuration files format

BIOS Sledgehammer uses several configuration files that all follow the same ``NAME==VALUE`` syntax. There are saved as *.txt files.

```cfg
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

## Logfile

Each time BIOS Sledgehammer is executed, a new logfile with the pattern ``BiosSledgehammer.ps1.log-XX.txt`` is created - ``XX`` is sequentially increased so the first run can be found in ``BiosSledgehammer.ps1.log-01.txt``, the second run in ``BiosSledgehammer.ps1.log-02.txt`` and so on. The location where these files are stored depends on if MDT/SCCM is active:

* By default the logfile is saved to ``C:\Windows\Temp\``.

* If it is executed in a task sequence by MDT or SCCM, the task sequence variable **LogPath** is used: ``C:\miniNT\SMSOSD\OSDLOGS\`` or ``C:\Windows\Temp\DeploymentLogs\``.

## *Models* folder

It is expected that each model (type) of hardware you want to support has a separate sub folder below ``\Models``. The model is displayed automatically by BIOS Sledgehammer, so simply run it once for each hardware to get the model name.

The sub folder for each model will contain all settings files together with source files for any updates. For example, if you execute BIOS Sledgehammer on a *HP EliteBook 820 G1* and a folder called ``\Models\HP EliteBook 820 G1\`` exists, the settings files need to be stored as ``\Models\HP EliteBook 820 G1\(FILENAME).txt``, e.g. ``\Models\HP EliteBook 820 G1\BIOS-Update.txt``.

Any update files need to be stored as seperate folder below that path. For example, if ``\Models\HP EliteBook 820 G1\BIOS-Update.txt`` defines that a BIOS update to 1.39 is required, the BIOS update files need to be stored in the folder ``\Models\HP EliteBook 820 G1\BIOS-1.39\``.

To locate a matching model folder, BIOS Sledgehammer will first check for a folder named as the SKU (Stock Keeping Unit, a unique identification number) for the current device - we'll come back to this shortly. If no SKU folder was found, an exact match for the current model is performed.

This means, if the current model is a *HP EliteBook Folio 1040 G1*, a folder named ``HP EliteBook Folio 1040 G1`` is expected. If there is no folder by this name, a partially search is performed. This will accept any folder that contains parts of the name of the current model, e.g. folder names like ``EliteBook Folio 1040 G1``, ``Folio 1040 G1`` or even ``1040 G1`` can be used.

Where this partially search helps a lot is for models that are technical identical but have different model names. For example, the *ProDesk 600 G1* comes in different form factors, each with a unique name: *HP ProDesk 600 G1 TWR* (Tower), *HP ProDesk 600 G1 SFF* (Small Format Factor) and so on. You can just create one folder ``HP ProDesk 600 G1`` and this folder will match all these form factors.

However, there are also cases where one family supports different form factors, and one of the form factors differs. For example, the *ProDesk 600 G2* comes in *TWR*, *MT*, *SFF* and *DM* form factors. The desktop mini (*DM*) has different hardware so it requires other settings. To support this, just create two folders: The first will match only the *DM*, so create a folder ``HP ProDesk 600 G2 DM``. For all other form factors, a partially matching folder named ``HP ProDesk 600 G2`` can be used. The *DM* will use his "private" folder, all other form factors will use the second folder.

If you do not want to change anything for a given model, simply create a matching folder without any files in it. If no model folder at all is found, an error is generated.

### SKU Model Folder

As said before, BIOS Sledgehammer will try to locate a model folder first by the SKU of the current device. A HP SKU is a seven-digit unique identification number for example *X3V00AV* or *Z2V72ET* (sometimes with an additional # and three more chars, e.g. *T6F44UT#ABA*) that identifies a given device and the configuration for it. It is recommended to use SKU folders only when required and as exception, as a SKU is rather meaningless.

A typical example where you will need them is when you need to support the same model (e.g. EliteBook 820 G4) in two different configurations where those configurations require different settings. For example, an EliteBook 820 G4 without Intel vPro/AMT will not support *Intel Software Guard Extensions* (SGX). If you want to change the default BIOS setting for this feature, this will fail on the devices without vPro.

In this case, create a folder named after the SKU of the non vPro devices (e.g. ``\Models\X3V00AV``) and delete the setting that changes the status of SGX. All other (with vPro) devices will continue to use the folder ``\Models\HP EliteBook 820 G4`` where the SGX settings remains unchanged.

## *Shared* folder

By default, each model has its own set of settings and update files and does not share them with any other model. This model-specific configuration ensures that changes to one model do not affect any other model.

Sharing can have benefits, however. Device families (like the EliteBook 830/840/850 series) share all firmware files because they have the same base board. A significant proportion of options are also shared among members of a device family which permits shared settings configurations. The upside to a shared approach is that it saves space and improves changing settings. The downside is that an update can have unwanted effects for some members of the family.

BIOS Sledgehammer prioritizes model-specific files over shared files - shared settings can optionally be defined. With this approach, it is possible to mix model-specific and shared configuration needs to achieve a balance that you desire.

To achieve a shared configuration, create a `Shared-<Configuration File>.txt` file to define any file that you want to retrieve from the ``\Shared`` folder. The default behavior of BIOS Sledgehammer is to search for the configuration file by name and, if it is not found in the model folder, look for a file named `Shared-<Configuration File>.txt`.

For example, if ``BIOS-Update.txt`` is not present, it will look for the file `Shared-BIOS-Update.txt`. This file contains a single value that defines the directory path below ``\Shared``:

```cfg
# Shared directory for EliteBook 8xx Gen 4
Directory == HP EliteBook 8xx G4
```

In this example, the requested file was `BIOS-Update.txt` and `Shared-BIOS-Update.txt` pointed to `\Shared\HP EliteBook 8xx G4\`; this means it retrieves the settings for the BIOS update from `\Shared\HP EliteBook 8xx G4\BIOS-Update.txt`. It is necessary to store update files in the same folder - for example, if the BIOS update is 1.22, the update exe needs be located in `\Shared\HP EliteBook 8xx G4\BIOS-1.22\`.

This procedure works in the same fashion for any configuration file, even for "companion" files like `TPM-Update-BIOS-Settings.txt` (shared file would be `Shared-TPM-Update-BIOS-Settings.txt`).

## Model folder location examples

Because the procedures to find the correct folder and settings files in \Models or \Shared can be confusing, here are some examples. The following layout of the \BIOSSledehammer folder is assumed; it misses several files and folder that are used in production to make it easier to read.

````text
.
├── BiosSledgehammer.ps1
├── README.md
├── ...
├── Models
│   ├── HP EliteBook Folio 1040 G1
│   │   ├── BIOS-Update.txt
│   │   ├── BIOS-1.37
│   │   │   └── HPQFlash.exe
│   │   └── BIOS-Settings.txt
│   ├── HP EliteBook 820 G4
│   │   ├── Shared-BIOS-Update.txt
│   │   └── Shared-BIOS-Settings.txt
│   ├── HP EliteBook 840 G4
│   │   ├── Shared-BIOS-Update.txt
│   │   └── Shared-BIOS-Settings.txt
│   └── X3V00AV
│       ├── Shared-BIOS-Update.txt
│       └── BIOS-Settings.txt
├── Shared
│   └── HP EliteBook 8xx G4
│       ├── BIOS-Update.txt
│       ├── BIOS-1.15
│       │   └── HPQFlash.exe
│       └── BIOS-Settings.txt
````

* Example 1: Executed on a *HP EliteBook Folio 1040 G1*, SKU *F2R71UT*
  * Search for folder named as the SKU: \Models\F2R71UT
  * SKU folder does not exist, search for folder named as the model: \Models\HP EliteBook Folio 1040 G1
  * Folder exists, will use folder
  * BIOS-Update.txt and BIOS-Settings.txt found, will use these files from \Models\HP EliteBook Folio 1040 G1
* Example 2: Executed on a *HP Pro x2 612 G2*, SKU *L5H60EA#ABD*
  * Search for folder named as the SKU: \Models\L5H60EA#ABD
  * SKU folder does not exist, search for folder named as the model: \Models\HP Pro x2 612 G2
  * Folder does not exist, search for partitial matching folder
  * No partial folder found, error message will be displayed
* Example 3: Executed on a *HP EliteBook 820 G4*, SKU *1FX36UT#ABA*
  * Search for folder named as the SKU: \Models\1FX36UT#ABA
  * SKU folder does not exist, search for folder named as the model: \Models\HP EliteBook 820 G4
  * Folder exists, will use folder
  * Shared-BIOS-Update.txt and Shared-BIOS-Settings.txt found, both files point to \Shared\HP EliteBook 8xx G4
  * Will use BIOS-Update.txt and BIOS-Settings.txt from this shared folder
* Example 4: Executed on a *HP EliteBook 840 G4*, SKU *Z2V72ET*
  * Search for folder named as the SKU: \Models\Z2V72ET
  * SKU folder does not exist, search for folder named as the model: \Models\HP EliteBook 840 G4
  * Folder exists, will use folder
  * Shared-BIOS-Update.txt and Shared-BIOS-Settings.txt found, both files point to \Shared\HP EliteBook 8xx G4
  * Will use BIOS-Update.txt and BIOS-Settings.txt from this shared folder
* Example 4: Executed on a *HP EliteBook 840 G4*, SKU *X3V00AV* (note the different SKU as this device does not have Intel vPro)
  * Search for folder named as the SKU: \Models\X3V00AV
  * SKU folder found, will use folder
  * BIOS-Settings.txt found, will use this file from \Models\X3V00AV
  * Shared-BIOS-Update.txt found and points to \Shared\HP EliteBook 8xx G4
  * Will use BIOS-Update.txt from \Shared\HP EliteBook 8xx G4

For more examples, see the \Models folder in the downloaded archive.

## *PwdFiles* folder

The ``\PwdFiles`` folder stores all BIOS passwords that your devices might use. When BIOS Sledgehammer starts, it tries every file in this folder until the password for the device has been found (an empty password is automatically added, there is no file for this). If no password file matches, an error is generated.

The order, in which they are tried, is determined by sorting the files by name: a file called *01_Standard.bin* is tried before *02_Standard.bin*. The most commonly used password should always come first because some BIOS versions enforce how many times you can try a wrong BIOS password. When this limit is reached, any password is rejected until the computer is restarted.

For more details, and how to create a password file, please see [BIOS Password](#bios-password).

## BIOS Update

The settings for a BIOS update are read from the file ``BIOS-Update.txt`` in the matching [model folder](#models-folder). Example file:

```cfg
# 850 G1 BIOS Update

# The BIOS version the device should have
Version == 1.37

# Command to be executed for the BIOS update
Command == HPBiosUpdRec64.exe

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

```cfg
# 6570b Update

# The BIOS version the device should be on
Version == F.66

# This model supports different BIOS families - define the update files for each of them
68ICE == 68ICE.CAB
68ICF == 68ICF.CAB

# Command to be executed for the BIOS update
Command == hpqFlash64.exe

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

:information_source: **Note:** BIOS Sledgehammer enforces that the BIOS updates (firmware files) are stored in a sub folder of the [model folder](#models-folder) called ``BIOS-<VERSION>``. If the desired BIOS version is ``1.37``, the folder needs be named ``\BIOS-1.37\``. For more information on how to obtain new firmware files and how to store them, please see [Adding firmware files](#adding-firmware-files).

The source folder is then copied to %TEMP% (to avoid any network issues) and the update process is started from there. Because the update utility sometimes restarts itself, the execution is paused until the process noted in COMMAND is no longer running. If any **.log* file was generated in the local folder, the content is added to the normal BIOS Sledgehammer log. A restart is requested after that because the “real” update process happens during POST, after the restart.

If anything goes wrong during the process, an error is generated.

## BIOS settings for BIOS update

:information_source: **Note:** This works for v6 and upward only.

Nearly all HP BIOS versions support BIOS settings that control if a BIOS firmware update can be applied. These settings are intended to prevent unwanted BIOS updates or to prevent that older BIOS versions are installed (to exploit security issues).

Depending on the device, the BIOS version, and which settings are in place, the [BIOS update](#bios-update) might either fail when `HpFirmwareUpdRec64.exe` is executed or during the first restart after executing it (POST phase). It might also happen that the BIOS Update is allowed, but a BIOS password prompt appears during POST, breaking an unattended deployment.

This can be solved by using the configuration file ``BIOS-Update-BIOS-Settings.txt`` which contains BIOS settings that are applied just before the BIOS update is executed. In case a BIOS update is not required, this file is ignored and no changes are made. It works exactly the same as described in [BIOS Settings](#bios-settings) but should **only** contain the BIOS settings to allow the BIOS update to work.

```cfg
# EliteBook 8x0 G5 BIOS settings to allow BIOS update

Lock BIOS Version == Disable

Minimum BIOS Version == 00.00.00
```

Starting in 2014 (e.g. with the EliteBook 8x0 G3 series), HP BIOS also support the setting `BIOS Rollback Policy` which can be set to `Unrestricted Rollback to older BIOS` to allow BIOS downgrades or to `Restricted Rollback to older BIOS` to prevent it. This setting is not required for BIOS Sledgehammer as it will never perform a BIOS downgrade.

:information_source: **Note:** It is perfectly fine to set a setting here differently than in [BIOS Settings](#bios-settings). For example, **Lock BIOS Version** needs to be *DISABLE* to allow a BIOS update, but it can be set to *ENABLE* in [BIOS Settings](#bios-settings) in case this is required by company policies. The later is executed after the BIOS update so the settings there will be in effect.

## Management Engine (ME) Update

Depending on the model, a device might be equipped with [Intel Active Management Technology](https://en.wikipedia.org/wiki/Intel_Active_Management_Technology) (Intel vPro) which allows for remote out-of-band management, so the device can be managed even if it's off or no operating system at all is installed. This function is provided by the Intel Management Engine (ME) which is also updatable.

If possible, check if an BIOS update is available that also updates the ME firmware as this method is much safer than direct ME firmware updates. On the other hand, some BIOS versions require a ME firmware after a BIOS update (see [ProDesk 600 G2 BIOS v2.17](https://ftp.hp.com/pub/softpaq/sp78001-78500/sp78294.html)), so you might be forced to do direct updates.

:exclamation: **IMPORTANT!** Please note that newer versions of the ME firmware update tool require the .NET 3.x framework to be installed before.

The settings for a ME update are read from the file ``ME-Update.txt`` in the matching [model folder](#models-folder). Example:

```cfg
# EliteBook 820 G1

# The ME firmware version the device should have
Version == 9.5.61.3012

# Command to be executed for the ME update
Command==CallInst.exe

Arg1 == /app Update.bat
Arg2 == /hide
```

*Version* defines which ME version the device should have. If the current firmware is older, the update files are copied locally and then started using the settings *Command* and *ArgX*. A restart is requested after that because the new firmware will only be activated during POST, after an restart.

:information_source: **Note:** BIOS Sledgehammer enforces that the ME updates (firmware files) are stored in a sub folder of the [model folder](#models-folder) called ``ME-<VERSION>``. If the desired ME firmware version is ``9.5.61.3012``, the folder needs to be named ``\ME-9.5.61.3012\``. For more information on how to obtain new firmware files and how to store them, please see [Adding firmware files](#adding-firmware-files).

If anything goes wrong during the process, an error is generated.

:warning: **WARNING!** Some versions of the update tool for the ME firmware from HP **DO NOT** check if the provided ME firmware file matches the current model. This means, they allows to flash the wrong firmware without any error message. If this happens, the machine will be FUBAR on next start (CAPS LOCK will blink 5 times and a mainboard replacement is required). Please pay extra caution when using ME firmware updates and always do a test run on a spare machine.

## Ignoring Management Engine (ME) detection errors

As soon as a ``ME-Update.txt`` file is found, BIOS Sledgehammer expects the Intel SA tool to be able to read the current ME version to detect if an update is required.

However, the Intel SA tool can’t read the version if AMT is disabled in BIOS or an [kill switch](http://blog.ptsecurity.com/2017/08/disabling-intel-me.html) was used. Normally, BIOS Sledgehammer would generate an error and halt the execution, because it can't be ensured that the version of ME is "compliant" with the version defined in the configuration.

To have BIOS Sledgehammer continue, and ignore this error, use the following setting in ``ME-Update.txt``:

```cfg
# Ignore ME detection errors
# If activated, a failure to get the current ME version is ignored and the script will continue.
IgnoreMEDetectionError == Yes
```

Please note however, that this can cause inconsistent ME versions of your device fleet. For example, if it is started on 10 identical devices that all have an outdated ME, but six of those devices have AMT disabled, only four will get the ME update.

## TPM Update

The settings for the TPM update are read from the file ``TPM-Update.txt`` in the matching [model folder](#models-folder). Example:

```cfg
# TPM IFX SLB 9670 Firmware

# Manufacturer of the TPM (optional) - The device must have this vendor or no update takes place (1229346816 is IFX)
Manufacturer==1229346816

# The TPM spec version we want this this device to have
SpecVersion == 2.0

# The firmware version we expect this device to have - a lower firmware will trigger an update
FirmwareVersion == 7.63


# The files from this subfolder will be copied locally to the root of the temporary location used for the update
# TPMConfig64.exe requires all firmware files in the same folder where the EXE is (it won't look in the \SRC folder)
AdditionalFilesDirectory == src

# The required upgrade firmware is selected by TPMConfig64.exe (mandatory setting starting with 5.0)
UpgradeFirmwareSelection==ByTPMConfig


# Command to be used to perform the TPM firmware upgrade
Command == TPMConfig64.exe

# Silent
Arg1 == -s
# TPMConfig will automatically choose the correct upgrade firmware file
Arg2 == -a@@SPEC_VERSION@@
# BIOS password file to be used - if the device does not have a BIOS password, this parameter is removed
Arg3 == -p"@@PASSWORD_FILE@@"
```

The first setting **Manufacturer** is optional and can be used to ensure that the TPM firmware vendor for the device matches the update files. If it's not defined, the TPM firmware vendor is ignored.

To detect if an TPM update is required, two versions need to be checked: The TPM Specification version (**SpecVersion**) and the firmware version (**FirmwareVersion**). That's because the TPM firmware is developed by 3rd parties so a change from TPM 1.2 to 2.0 can result in a LOWER firmware version when the vendor is changed (see [this article on the Dell wiki]( http://en.community.dell.com/techcenter/enterprise-client/w/wiki/11850.how-to-change-tpm-modes-1-2-2-0) – TPM Spec 1.2 is firmware 5.81 from WEC, TPM Spec 2.0 is firmware 1.3 from NTC). BIOS Sledgehammer checks both versions and if any of those two are higher than the current device reports, a TPM update is started.

:exclamation: **IMPORTANT!** Because of limitations in the [Win32_TPM](https://msdn.microsoft.com/en-us/library/windows/desktop/aa376484(v=vs.85).aspx) CIM class, BIOS Sledgehammer can only retrieve the major and minor part (first two numbers) of the current TPM firmware (e.g. *7.63*) while the firmware is also using a build (third) number, e.g. *7.63.3353*. For "normal" updates, where the major and/or minor part changes, this is not an issue. But in cases where the newest TPM firmware is available in two versions that only differ in the build number (e.g. *7.63.3144* and *7.63.3353*) **AND** the device has the lower build number installed, BIOS Sledgehammer will not start an upgrade. That's because the config file defines version *7.63* and since BIOS Sledgehammer cannot access the build number, both builds will be considered up-to-date so no update is triggered.

<!--
* 6.41.**197** is used for devices that have a TPM 1.2 by default
* 6.41.**198** is used for devices that were downgraded from TPM 2.0 to TPM 1.2
The problem is that the [Win32_TPM](https://msdn.microsoft.com/en-us/library/windows/desktop/aa376484(v=vs.85).aspx) CIM class does not provide the BUILD number (.197 or .198) in the ``ManufacturerVersion`` field. Therefore, it can not be detected which 6.41 firmware is currently active. However, if the firmware file specified for the update does not match **exactly**, the TPM will reject the update (Full details in [Issue #9](https://github.com/texhex/BiosSledgehammer/issues/9)).
-->

TPM updates differ from other updates as they require a special From-To firmware file. This means, if the device is currently using version 7.40 and an update to 7.63 is required, a firmware file exactly for this From-To combination (TPM20_7.40_to_TPM20_7.63) is required. Together with the above noted limitation, selecting the correct firmware file can be tricky.

Starting with [SoftPaq #87492](https://ftp.hp.com/pub/softpaq/sp87001-87500/sp87492.html), HP offers TPMConfig64.exe v2 which can automatically select the correct From-To firmware by using the parameter ``-a``. This is the method BIOS Sledgehammer uses and to document this, the entry ``UpgradeFirmwareSelection==ByTPMConfig`` has to be in ``TPM-Update.txt``.

To allow TPMConfig64.exe this automatic selection, it is required that the firmware files are in the same folder as the EXE itself. Since the SoftPaq stores these files in the subfolder \src, the configuration entry ``AdditionalFilesDirectory == src`` will instruct BIOS Sledgehammer to copy the firmware files from \src to the root of the temporary folder used during update.

A TPM update also requires that BitLocker is turned off (as any BitLocker keys are lost during the upgrade), so BIOS Sledgehammer will check if the system drive C: is encrypted with BitLocker and starts an automatic decryption before executing the update. This works for Windows 10, but fails in Windows 7 as the required BitLocker PowerShell module does not exist.

Once everything is ready, the source folder is copied to %TEMP% (to avoid any network issues) and the process is started from there.

Because the update utility sometimes restarts itself, the execution is paused until the process noted in COMMAND is no longer running. If any **.log* file was generated in the local folder, the content is added to the normal BIOS Sledgehammer log. A restart is requested after that because the actual update process happens during POST, after the restart. If anything goes wrong during the process, an error is generated and it is tried to translate the error code to a meaningful error message.

:information_source: **Note:** BIOS Sledgehammer enforces that the TPM firmware files are stored in a sub folder of the [model folder](#models-folder) called ``TPM-<VERSION>``. If the desired TPM firmware version is ``7.41``, the folder name needs to be named ``\TPM-7.41\``. For more information on how to obtain new firmware files and how to store them, please see [Adding firmware files](#adding-firmware-files).

### Disable automatic BitLocker decryption during TPM update

In cases of updates for in-use machines, the automatic decryption of BitLocker that BIOS Sledgehammer performs might not be desired as this will require a full roll-in of BitLocker later on.

It is possible that a script (executed before BIOS Sledgehammer) removes the TPM protector and then pauses BitLocker protection. Adding the parameter **IgnoreBitLocker==Yes** in ``TPM-Update.txt`` will cause BIOS Sledgehammer to ignore BitLocker all together and not start a full decryption.

```cfg
# Ignore BitLocker - If activated, no automatic BitLocker decryption will take place
IgnoreBitLocker == Yes
```

:warning: **WARNING!** Please take extra care when using this parameter! When removing the TPM protector using ``manager-bde.exe`` and forget to also specify the **RebootCount** parameter, you can lock yourself out of your device. For full details, see the [manage-bde docs](https://technet.microsoft.com/en-us/library/ff829848(v=ws.11).aspx#BKMK_disableprot). You have been warned.

## TPM BIOS settings

Newer BIOS version for the EliteBook series (G3 or upward) do not allow TPM updates when either [Intel Software Guard Extensions aka "SGX"](https://en.wikipedia.org/wiki/Software_Guard_Extensions), [Intel Trusted Execution Technology aka "TXT"](https://en.wikipedia.org/wiki/Trusted_Execution_Technology) or [Virtualization Technology aka "VTx"](https://en.wikipedia.org/wiki/X86_virtualization#Intel_virtualization_(VT-x)) are activated. Additonally, any TPM firmware upgrade will require the operator to press F1 after restarting the machine to acknowledge the update. To prevent this, the BIOS setting ``TPM Activation Policy`` must be set to ``No prompts``.

To support these dependencies, several BIOS settings can be changed just before the [TPM Update](#tpm-update) takes place by using the file ``TPM-Update-BIOS-Settings.txt``. If no TPM update is required, no changes are made. The file works exactly the same as described in [BIOS Settings](#bios-settings) but should only contain the changes related to a TPM update.

```cfg
# EliteBook 8x0 G4 BIOS Settings required for TPM update

# No F1 prompt to approve TPM update
TPM Activation Policy == No prompts

# These settings must be disabled to allow a TPM update
Intel Software Guard Extensions (SGX) == Disable
Trusted Execution Technology (TXT) == Disable
Virtualization Technology (VTx) == Disable
```

:information_source: **Note:** It is perfectly fine to set a setting here differently than in [BIOS Settings](#bios-settings). For example, **Trusted Execution Technology (TXT)** needs to be *DISABLE* here (as this is required to allow an TPM update) but can be set to *ENABLE* in [BIOS Settings](#bios-settings). The later is executed after the TPM update so the settings there will be in effect.

## BIOS Password

To set a BIOS password, you define the password file, containing the desired password, in ``BIOS-Password.txt``. This file must be stored in the [model folder](#models-folder). Example file:

```cfg
# Use our standard password
PasswordFile == 01_W2f4x7t8NxD4xUH.bin
```

:exclamation: **IMPORTANT!** This is insecure and just an example! Do not use the password itself as file name!

The password file you have defined has to be stored in the [PwdFiles folder](#pwdfiles-folder). For details how to create a password file, please see [Creating a BIOS password file](#creating-a-bios-password-file).

In case you want to use an empty password, just leave the value empty like this:

```cfg
# Empty password (bad idea!)
PasswordFile ==
```

Regarding BIOS passwords, please also note the following:

* Passwords need to meet minimum complexity rules (must contain upper- and lower-case letters and a number) or the BIOS will reject the password change but won't issue any specific error message - it will simply return "Invalid password file". The only exception of this rule is an empty password which is always allowed.
* There are only some password changes allowed per power cycle. If the password change just doesn’t work although it has worked before, turn the device off and on.

## Creating a BIOS password file

To create a password file, do the following:

* Download any newer BIOS release from HP, e.g. [SoftPaq #85233](https://ftp.hp.com/pub/softpaq/sp85001-85500/sp85233.exe)
* Open a command prompt with administrative privileges and change to the folder the SPxxx.exe was downloaded to
* Execute *SPxxxx.exe -s -e* (e.g. `SP85233.exe -s -e`)
* The contents of the SoftPaq will be extract to *C:\SWSetup\SPxxxx*, e.g. `C:\SWSetup\SP85233`
* Start `HpqPswd64.exe` from that location
* Enter the password two times and type in the filename to save it (e.g. `02_Standard_2018.bin`)
* Please ensure that the file has a .BIN extension
* Copy this file to the [PwdFiles folder](#pwdfiles-folder)

## BIOS Settings

The configuration of the BIOS are read from the file ``BIOS-Settings.txt`` in the matching [model folder](#models-folder). Example:

```cfg
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

## In-place BIOS to UEFI boot mode conversion

Some Windows 10 security features (e.g. Device Guard) require that the computer is in UEFI boot mode. If you already have updated machines to Windows 10, but those are using BIOS legacy boot mode, you couldn't use these security features as switching the boot mode to UEFI caused Windows to stop working.

With Windows 10 1703, you can in-place switch to UEFI boot mode (see this [demo](https://technet.microsoft.com/en-us/windows/mt782786) for details). This is a two step process by first executing [MBR2GPT.exe](https://technet.microsoft.com/en-us/itpro/windows/deploy/mbr-to-gpt), which prepares Windows to use UEFI boot mode, and then changing the BIOS settings to start in UEFI mode.

For the later, you can use BIOS Sledgehammer with the ``-ActivateUEFIBoot`` switch. When this switched is used, only the file ``Activate-UEFIBoot.txt`` will be applied which is read from the matching [model folder](#models-folder). Example:

```cfg
# 850 G2

Boot Mode == UEFI Native (Without CSM)
SecureBoot == Enable
```

The file works exactly as described in [BIOS Settings](#bios-settings) and can, if required, contain more settings. However, since the in-place boot mode change is a critical step, you should keep the changes to a minimum. After the change has been done, and the computer was restarted, you can execute BIOS Sledgehammer normally and change all other settings.

## Using it from MDT or SCCM

By default, MDT/SCCM will run all scripts hidden to hide sensitive information. If you are okay with this, just run ``BiosSledgehammer.ps1`` as PowerShell script, but remember to tick the box for "Disable 64bit file system redirection" so it is run as 64-bit PowerShell process. This settings applies only for SCCM - MDT always runs PowerShell scripts native.

If you want to see what BIOS Sledgehammer is doing, run the provided batch file ``RunVisble.bat`` with this command line in MDT/SCCM: ``cmd.exe /c "%SCRIPTROOT%\BiosSledgehammer\RunVisible.bat"`` (given you stored it in the *\Scripts* folder).

This batch automatically uses the correct (native) version of PowerShell and will also set the ``-WaitAtEnd`` parameter which causes BIOS Sledgehammer to pause for 30 seconds when finished. This way, you can have a quick look at the results.

:exclamation: **IMPORTANT** When using the ``RunVisible.bat``, no error code is transfered back to the task sequence. So even if BIOS Sledgehammer reports a fatal exit code, the Task Sequence will receive return code 0. This comes from the fact the task sequence executes cmd.exe which starts a batch, which starts "START" which executes PowerShell.exe which starts BiosSledgehammer.ps1. Somewhere along the way the return code is lost.

It is recommended to start BIOS Sledgehammer **four** times and restart the device after each run. If a device requires a BIOS Update, a TPM update and BIOS setting changes, three executions are needed. The final one is to make sure everything worked - for example if an operator accidently hit F2 (Do not perform update) during POST when asked if a firmware update should take place.

In case you used ``RunVisible.bat`` the last (4th) run should not use it but instead execute directly ``BiosSledgehammer.ps1`` using *Run PowerShell Script* with the parameter ``-Verbose``. That's because ``RunVisible.bat`` does not return any error code. So if there is a problem, this last run will make sure MDT/SCCM is getting a correct return code and can break the deployment if there is a problem. The ``-Verbose`` option will make sure that the log contains all data (even BCU output) for troubelshooting.

## Adding firmware files

BIOS Sledgehammer requires firmware files (BIOS, TPM etc.) from HP to update a device, which are distributed as SoftPaqs (self-extracting executables). Before they can be used, they need to be extracted and stored in a matching folder.

 This section will explain the required steps based on a [new BIOS update](#bios-update) for the *HP EliteBook x360 1030 G2*, but the general procedure applies to all firmware files for all models.

* Locate the new BIOS for this model. The easiest way is to search for *HP EliteBook x360 1030 G2 bios download* using Google which should bring you directly to the *HP Software and Driver Downloads* page
* On this page, expand the section BIOS and make a note of the current BIOS version (1.23 as of writing this) and download the SoftPaq file (*SP90109.exe*)
* Open a command prompt with administrative privileges and change to the folder the SoftPaq was downloaded to
* Execute `SP90109.exe -s -e` (Silent extract) to extract the archive to `C:\SWSetup\SP90109`
* Open the matching [model folder](#models-folder) for the model on your BIOS Sledgehammer installation, e.g. `\\MDTSRV01\MDT$\Scripts\BiosSledgehammer\Models\HP EliteBook x360 1030 G2\`
* Create a new folder that matches the firmware type and the version. As this is a BIOS file and the version is 1.23, create the folder `\BIOS-1.23`. In this example, the full path would be `\\MDTSRV01\MDT$\Scripts\BiosSledgehammer\Models\HP EliteBook x360 1030 G2\BIOS-1.23`
* Copy the files from `C:\SWSetup\SP90109` to this new folder so that for example `HPBiosUpdRec64.exe` is found directly inside the `\BIOS-1.23` folder
* Update the file `BIOS-Update.txt` in the [model folder](#models-folder):

```cfg
# The BIOS version the device should be on
Version == 1.23
```

BIOS Sledgehammer also comes with `StartSoftPaqDownloads.bat` which can take care of the entire download, extract and copy process, given you provide a text file with the required URLs of the downloads. To use this method, do the following:

* On the HP download page, right-click the download button and select *Copy link location* / *Copy link address*. In this example, it’s `https://ftp.hp.com/pub/softpaq/sp90001-90500/sp90109.exe`
* Create the required folder `\BIOS-1.23` in the [model folder](#models-folder)
* Create a new text file called `SPDownload.txt` in this folder with the following content:

```cfg
SPaqURL==https://ftp.hp.com/pub/softpaq/sp90001-90500/sp90109.exe
NoteURL==https://ftp.hp.com/pub/softpaq/sp90001-90500/sp90109.html
```

:exclamation: **IMPORTANT** Please make sure to only use http**S** links within `SPDownload.txt` to ensure  the files are originating from hp.com.

* The *SPaqURL* value contains the URL for the SoftPaq itself, while *NoteURL* is the name of the release notes HTML document. This is always the name of the SoftPaq but with the *html* extension instead of EXE.
* Run `StartSoftPaqDownloads.bat` which will download `SP90109.exe` (and the HTML file), extract it and copy the results to `\BIOS-1.23`. As `StartSoftPaqDownloads.bat` will only download files that have not been downloaded so far, you can run it as often as you want without fearing it will pull gigabytes of data on every run
* When finished, update `BIOS-Update.txt` in the [model folder](#models-folder)

You can also let a batch file generate `SPDownload.txt` for you; it only require the SoftPaq number as input. You find this batch file in the first message for [issue #75](https://github.com/texhex/BiosSledgehammer/issues/75).

## TPM BIOS settings configuration filename change for v6

BIOS Sledgehammer 6.x (or newer) uses a new filename for the BIOS settings applied just before a TPM update. Starting with v6, this file has to be named `TPM-Update-BIOS-Settings.txt` (v5 used the name `TPM-BIOS-Settings.txt`). This also applies to the [shared file](#shared-folder) which is now called `Shared-TPM-Update-BIOS-Settings.txt` (old name was `Shared-TPM-BIOS-Settings.txt`). The settings within the file remain the same, only the filename itself has changed.

Please do the following:

* Make a copy of your current productive installation (the folder where BIOS Sledgehammer and all configuration files are stored) in case something goes wrong
* Download the [newest release](https://github.com/texhex/BiosSledgehammer/releases) and unpack it to a folder (e.g. C:\Temp\BiosSledge) on your machine.
* Copy the files from the root folder of the unpacked archive to the productive folder, overwriting any existing files (BiosSledgehammer.ps1, LICENSE, MPSXM.psm1, RunVisible..., StartSoftpaq... and zRenameConfigFilesForV6.bat)
* Open a command prompt with administrative privileges and change to the productive folder
* Run the batch file `zRenameConfigFilesForV6.bat`
* After a confirmation, the batch file will search for any `TPM-BIOS-Settings.txt` file in any subfolder and rename it to new name `TPM-Update-BIOS-Settings.txt` (shared files will also be renamed)

Once all files are renamed, BIOS Sledgehammer is ready to be used again.

As a side note: you can run the batch file a second time to be sure; it will always only touch “old” files and never re-rename anything.

:exclamation: **IMPORTANT** If you are updating from v4 to v6, please first perform the required changes noted in the next section, then the changes noted here.

## TPM Update configuration changes for v5

BIOS Sledgehammer 5.x (or newer) requires changes to TPM-Update.txt and the TPM updates files that are not compatible with 4.x or earlier.

From v5 on, the update tool (TPMConfig64.exe v2) decides which TPM firmware file is used for an TPM update. To support this, both the configuration and the TPM files need to be updated.

Please do the following:

* Make a copy of your current productive installation (e.g. just copy \Scripts\BiosSledgehammer\ so you can access it when something goes wrong)
* Download the [newest release]( https://github.com/texhex/BiosSledgehammer/releases) and unpack it to a folder (e.g. C:\Temp\BiosSledge) on your machine. Then start `StartSoftPaqDownloads.bat` so the newest releases from HP are downloaded
* When finished, delete the folder `\Shared\TPM SLB 9670` in your current productive installation.
* Copy the local folder (e.g. `C:\Temp\BiosSledge\Shared\TPM SLB 9670`) with all files and sub folders to your productive installation. This will ensure that the newest TPM-Update.txt and associate TPM firmware files are in place
* Next, search the folder `\Models\` of your productive installation for any `TPM-Update.txt` file (ignore any `Shared-TPM-Update.txt` file for now). If you find a file, this indicates that this model is not yet switched to the shared folder.
* In the model folder, where a `TPM-Update.txt` was located, delete `TPM-Update.txt` and also any `TPM-x.xx` folder you find. Next, check the exact same model in your local path and copy the file `Shared-TPM-Update.txt` to your productive installation
* For example, if you detect the file `\Models\HP EliteBook 820 G3\TPM-Update.txt` in your productive installation, delete `\Models\HP EliteBook 820 G3\TPM-Update.txt` as well as the folder `\Models\HP EliteBook 820 G3\TPM-7.xx`. Next, open `C:\Temp\BiosSledge\Models\HP EliteBook 820 G3` and copy the file `Shared-TPM-Update.txt`
* Once finished, all models should point to the new shared TPM folder and your entire productive installation should contain the file `TPM-Update.txt` only once in `\Shared\TPM SLB 9670`.

When done, the next step is to replace all `Shared-TPM-BIOS-Settings.txt` or `TPM-BIOS-Settings.txt`. That’s because TPMConfig64.exe 2.x requires the BIOS Setting *VTx* to be disabled, which was not the case for the older version.

* Search your entire productive installation for `Shared-TPM-BIOS-Settings.txt` or `TPM-BIOS-Settings.txt` files
* When found, copy those files from your local folder and overwrite them in the productive installation
* In case your installation supports models that are not included in our examples, please update your files to disable *VTx* for the TPM update.
* See [TPM BIOS Settings](#tpm-bios-settings) for details how to do this

## Two-Step BIOS Update Process

Some older devices require a two-step process to update, e.g. the HP Compaq Pro 6300. It requires that the  device is first updated to the transition BIOS version 2.99 (if the current version < 3.00) and only then an 3.x BIOS version can be installed. When trying to flash directly from anything below 2.99 to 3.x, the update fails.

This two-step process is not directly supported by BIOS Sledgehammer but can be solved by creating a second “Pre-Update” installation of BIOS Sledgehammer that is run before your “main” installation. It is only responsible to update those older machines to an updatable BIOS version, which will happen in the main installation.

The general procedure is as follows:

* Create a new BIOS Sledgehammer folder, completely separated from the “main” folder.
* If the main folder is `\Scripts\BiosSledgehammer`, name the new folder `\Scripts\BiosSledeghammer_PreUpdate`.
* To that new folder, copy all files from the main BIOS Sledgehammer folder
* **Delete** everything in `BiosSledeghammer_PreUpdate\Shared` and in `BiosSledeghammer_PreUpdate\Models` except the folder `HP Compaq Pro 6300`
* Inside that folder delete all folders and files except `FIRST-FLASH-BIOS-2.99` and `BIOS-Update.txt`
* Rename the folder `FIRST-FLASH-BIOS-2.99` to `BIOS-2.99`
* Edit `BIOS-Update.txt` and change the VERSION parameter to `VERSION == 2.99`

:information_source: **Note:** This of course requires that the folder `BIOS-2.99` contains the BIOS update files. If your installation does not, just download the [latest release]( https://github.com/texhex/BiosSledgehammer/releases/), unpack it and run `StartSoftPaqDownloads.bat` which will download the required files from HP.com.

Within MDT/SCCM, locate the second where the calls to BIOS Sledgehammer are. Just **before** the first call, insert a new section and set a WMI filter so this section will only run when the computer/device model is *HP Compaq Pro 6300*.

Insert a new command and let SCCM/MDT execute `cmd.exe /c "%SCRIPTROOT%\BiosSledgehammer_PreUpdate\RunVisible.bat"` and add a restart command after that. If you want to be sure, add another command and restart, duplicating the one you already created. This is not necessary, just a precaution.

What will happen is the following:

* For any device that is **NOT** a 6300, nothing will change because the section is ignored as the WMI filter does not match. This means, only the main BIOS Sledgehammer script is run as before.
* In case the device is a Pro 6300, `\BiosSledeghammer_PreUpdate` will run and update the BIOS to 2.99.
* After the restart(s), the task sequence will continue, starting the main BIOS Sledgehammer (`\BiosSledeghammer`) and updating the BIOS to 3.x (or anything newer) which is now possible because the device has BIOS 2.99 already
* If an already updated (BIOS 3.x) Pro 6300 is started again, the `\BiosSledeghammer_PreUpdate` will be executed, but since the BIOS is already newer, it won’t update anything, making the call a no-operation.

As this `\BiosSledeghammer_PreUpdate` folder is only used for one model, it’s not necessary to keep it up to date with new releases or files, since it only serves one purpose and it’s highly unlikely that HP will ever update the BIOS 2.99 release. Of course, this folder can also support other models that might are in the need of such a Pre-Update.

:information_source: **Note:** It can happen that these rather old BIOS versions are not able to read the “normal” password files (*.bin) and show an error message that the BIOS password is wrong. If this happens, recreate the password files with `\HPQFlash\HpqPswd.exe` from BIOS-2.99 and store them in `BiosSledeghammer_PreUpdate\PwdFiles`.

## Contributions

Any constructive contribution is very welcome!

If you encounter a bug, please start BIOS Sledgehammer with the option -Verbose (``.\BiosSledgehammer.ps1 -Verbose``) and attach the logfile to [new issue](https://github.com/texhex/BiosSledgehammer/issues/new).

## License

``BiosSledgehammer.ps1`` and ``MPSXM.psm1``: Copyright © 2015-2019 [Michael Hex](http://www.texhex.info/). Licensed under the **Apache 2 License**. For details, please see LICENSE.txt.

All HP related files (BCU, BIOS, TPM etc.) are © Copyright 2012–2018 Hewlett-Packard Development Company, L.P. and/or other HP companies. These files are licensed under different terms.

All Intel related files (SA-00075) are © Copyright Intel. These files are licensed under different terms.
