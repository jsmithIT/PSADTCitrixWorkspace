<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory = $false)]
	[ValidateSet('Install', 'Uninstall', 'Repair')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory = $false)]
	[ValidateSet('Interactive', 'Silent', 'NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory = $false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory = $false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory = $false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

	##*===============================================
	##* ANCHOR: VARIABLE DECLARATION
	##*===============================================
	##* Variables: Application
	[string]$appVendor = 'Citrix Systems, Inc.'
	[string]$appName = 'Citrix Workspace'
	[string]$appVersion = '19.12.7000.10'
	[string]$appArch = 'x64'
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '2.0.0'
	[string]$appScriptDate = '2022.06.07'
	[string]$appScriptAuthor = 'CuBaker, KTeuton, JBSMITH'

	##* Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = "$appName ($appVersion)"
	[string]$installTitle = "$appName ($appVersion)"

	##*===============================================
	##* ANCHOR: VARIABLE DECLARATION - Template
	##* Changeable Array(s)/Variable(s)
	##*===============================================
	# Template array(s)/variable(s) used within the PSADT.
	
	##* InstallationWelcomeCloseApps
	# Used with the PSADT 'Show-InstallationWelcome -CloseApps' function.
	# Mainly used in the Pre-Installation and Pre-Uninstallation phases.
	# This variable will tell users what needs to be closed during install/uninstall phases.
	$CloseApps = "iexplore=Internet Explorer,ssonsvr=Citrix,selfserviceplugin=Citrix,receiver=Citrix,selfservice=Citrix,redirector=Citrix,concentr=Citrix,authmansvr=Citrix,wfcrun32=Citrix"
    
	##* Prerequisite Application install parameters. 
	# Prerequisite application 1 name.
	$PrereqApp1Name = "Microsoft Visual C++ 2015-2022 Redistributable (x64)"
	# Prerequisite application 1 install path.
	$PrereqApp1InstallPath = "$PSScriptRoot\Files\VC_redist.x64.exe"
	# Prerequisite application 1 install parameters.
	$PrereqApp1InstallParam = "/install /quiet /norestart"

	# Prerequisite application 2 name.
	$PrereqApp2Name = "Microsoft Visual C++ 2015-2022 Redistributable (x86)"
	# Prerequisite application 2 install path.
	$PrereqApp2InstallPath = "$PSScriptRoot\Files\VC_redist.x86.exe"
	# Prerequisite application 2 install parameters.
	$PrereqApp2InstallParam = "/install /quiet /norestart"

	##* Application install parameters.
	# 64-bit application
	# 64-bit application install name.
	$64bitAppInstallName = "Citrix Workspace App"
	# Application install Path.
	$64bitAppInstallPath = "$PSScriptRoot\Files\Installation\CitrixWorkspaceAppWeb.exe"
	# Application  install parameters.
	$64bitAppInstallParam = "/AutoUpdateCheck=disabled /AutoUpdateStream=LTSR /AURolloutPriority=Slow /EnableCEIP=False /InstallEmbeddedBrowser /includeappprotection /silent /forceinstall" 

	# 32-bit application
	# 32-bit application install name.
	#$32bitAppInstallName = "" 
	# Application install Path.
	#$32bitAppInstallPath = ""
	# Application install parameters.
	#$32bitAppInstallParam = ""

	##* Remove Application Names 
	# Mainly used in the Pre-Installation, Pre-Uninstallation, Uninstallation and Post-Uninstallation phases.
	# These scalable Array(s)/Variable(s) are used to remove previous application(s) by name.
	$RemoveAppNamesMSI = @("Online Plug-in", "Citrix")
	#$RemoveAppNamesEXE = @("")

	##* Prerequisite Application uninstall parameters. 
	# Prerequisite application 1 name.
	#$PrereqApp1UninstallName = "Microsoft Visual C++ 2015-2019 Redistributable (x64)"
	# Prerequisite application 1 install path.
	#$PrereqApp1UninstallPath = "VC_redist.x64.exe"
	# Prerequisite application 1 install parameters.
	#$PrereqApp1UninstallParam = "/uninstall /quiet"

	##* Application uninstall parameters.
	# 64-bit application
	# 64-bit application uninstall name.
	$64bitAppUninstallName = "Citrix Workspace App"
	# Application uninstall path.
	$64bitAppUninstallPath = "$PSScriptRoot\Files\Uninstallation\CitrixWorkspaceApp.exe"
	# Application uninstall parameters.
	$64bitAppUninstallParam = "/uninstall /silent /norestart"

	# 32-bit application
	# 32-bit application uninstall name.
	#$32bitAppUninstallName = "" 
	# Application uninstall path.
	#$32bitAppUninstallPath = ""
	# Application uninstall parameters.
	#$32bitAppUninstallParam = ""
    
	##* Application Settings File Name
	# Names of files used for application settings.
	#[string[]]$appSettingsNames = @("")

	##* Application Settings Directory
	# Directory where application settings be reside.
	#[string[]]$appSettingsDirs = @("")
    
	## Set variables to match script variables
	# These Variable(s) keep the spaces the PSADT script removes. These can and are used in titles, messages, logs and the PIRK information for the application being installed.
	$apVendor = $appVendor
	$apName = $appName
	$apversion = $appVersion
	$apScriptVersion = $appScriptVersion

	##*===============================================
	##* ANCHOR: VARIABLE DECLARATION - Author
	##* Changeable Array(s)/Variable(s)
	##*===============================================
	# If the template array(s)/variable(s) aren't enough, add more array(s)/variable(s) here.

	$PrereqApp3Name = "Microsoft Visual C++ 2015-2019 Redistributable (x64)"
	$PrereqApp4Name = "Microsoft Visual C++ 2015-2019 Redistributable (x86)"


	##*===============================================
	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.8.3'
	[string]$deployAppScriptDate = '30/09/2020'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0) { [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
		##*===============================================
		##* ANCHOR: PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		# Check if deployment is interactive. 
		# If yes (it is interactive), show install prompt.
		If ($DeployMode -eq "Interactive") {
			$dialog = (Show-InstallationPrompt -Message "Changes are going to be made to your device. `n `n Please save your work and close all windows. `n `n To defer the changes, click the defer button on the next screen." -Icon "Information" -PersistPrompt -ButtonMiddleText "OK")
		}

		# Check if user accepted the install prompt.
		# If yes (it was accepted), show close application(s) prompt. Do not allow application(s) to start during install. 
		If ($dialog -eq "OK") { 
			Show-InstallationWelcome -CloseApps "$CloseApps" -MinimizeWindows $false -PersistPrompt -DeferDays "3" -BlockExecution -AllowDefer -DeferTimes "3"
		}


		# For each item in the array...
		# Check if previous MSI versions of application are installed.  
		# If application is installed, uninstall previous MSI versions of application.
		# If uninstall failed, log results. Exit script. 
		Foreach ($RemoveAppNameMSI in $RemoveAppNamesMSI) {
			# Check if previous MSI versions of application are installed.  
			$RemoveAppNamesMSICheck = Get-InstalledApplication -Name "$RemoveAppNameMSI"
			If ($null -ne $RemoveAppNamesMSICheck) {
				# Uninstall previous MSI versions of application(s).    
				Try {  
					Write-Log -Message "Previous MSI versions of $RemoveAppNameMSI are installed. Removing..." 
					Remove-MSIApplications -Name "$RemoveAppNameMSI"
					$RemoveAppNamesMSICheck = ""
				}
				# If uninstall failed, log results. Exit script.
				Catch [System.Exception] {
					Write-Log -Message "Uninstaling previous MSI versions of $RemoveAppNameMSI failed with error: $_."
					Write-Log -Message "Exiting script with error."
					Exit-Script -ExitCode 1627
				}
			}
			# Else, log results from check.
			Else {
				Write-Log -Message "Previous MSI versions of $RemoveAppNameMSI are not installed."
			}
		}

		# Check if previous versions of Citrix Workspace App exist.
		# If Citrix Workspace App exists, remove previous versions of Citrix Workspace 1912 App.
		# If removal failed, log results. Exit script. 
		# Else, log results from check.
		If ((Test-Path -Path "$envProgramFilesX86\Citrix\Citrix Workspace 1912") -Or (Test-Path -Path "$envProgramFilesX86\Citrix\ICA Client")) { 
			# Remove previous versions of Citrix Workspace 1912 App.
			Try {
				Write-Log -Message "Previous versions of $64bitAppUninstallName exist. Removing..."
				Execute-Process -Path "$64bitAppUninstallPath" -Parameters "$64bitAppUninstallParam"
                Remove-Folder -Path "$envProgramFilesX86\Citrix\Citrix Workspace 1912"
                Remove-Folder -Path "$envProgramFilesX86\Citrix\ICA Client"
				Write-Log -Message "Removing previous versions of $64bitAppUninstallName complete."

			}
			# If removal failed, log results. Exit script. 
			Catch [System.Exception] {
				Write-Log -Message "Removing previous versions of $64bitAppUninstallName failed with error: $_"
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}
		# Else, log results from check. 
		Else { 
			Write-Log -Message "Previous versions of $64bitAppUninstallName do not exist."  
		}


        # Test if the ICA CLient path still exists.
        # If the path still exists, show installation restart prompt. The ICA CLient path can only be removed after a reboot (it appears).
		If (Test-Path -Path "$envProgramFilesX86\Citrix\ICA Client") { 
			# Remove previous versions of Citrix Workspace 1912 App.
			Try {
                Write-Log -Message "Device restart needed to finish removing the ICA Client. PLease restart and try again."
		        # Show installation restart prompt.
		        Show-InstallationRestartPrompt -CountdownSeconds "3600" -CountdownNoHideSeconds "10"
			}
			# If removal failed, log results. Exit script. 
			Catch [System.Exception] {
				Write-Log -Message "Rebooting the device failed with error: $_"
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}


		<#
		# Check if previous versions of Visual C++ 2015-2019 Redistributable exist.
		# If Visual C++ 2015-2019 Redistributable exists, remove previous versions of Visual C++ 2015-2019 Redistributable.
		# If removal failed, log results. Exit script. 
		# Else, log results from check.
		If (Test-Path -Path "C:\WINDOWS\System32\vcamp140.dll") { 
			# Remove previous versions of Visual C++ 2015-2019 Redistributable.
			Try {
				Write-Log -Message "Previous versions of $PrereqApp1InstallName exist. Removing..."
				Execute-Process -Path "$dirFiles\$PrereqApp1InstallPath" -Parameters "$PrereqApp1UninstallParam"
				Write-Log -Message "Removing previous versions of $PrereqApp1InstallName complete."
			}
			# If removal failed, log results. Exit script. 
			Catch [System.Exception] {
				Write-Log -Message "Removing previous versions of $PrereqApp1InstallName failed with error: $_"
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}
		# Else, log results from check. 
		Else { 
			Write-Log -Message "Previous versions of $PrereqApp1InstallName do not exist."  
		}
		#>

		# Check if previous versions of package information registry key (PIRK) exist. 
		# If package information registry key (PIRK) exists, remove previous versions of package information registry key (PIRK).
		# If removal failed, log results. Exit script. 
		# Else, log results from check.
		If (Test-Path -Path "HKLM:\SOFTWARE\Tuolumne County\Package Information\$apName*") { 
			# Remove previous versions of package information registry key (PIRK).
			Try {
				Write-Log -Message "Previous versions of package information registry key (PIRK) exist. Removing..."
				Remove-Item -Path "HKLM:\SOFTWARE\Tuolumne County\Package Information\$apName*" -Force
				Write-Log -Message "Removing previous versions of package information registry key (PIRK) complete."
			}
			# If removal failed, log results. Exit script. 
			Catch [System.Exception] {
				Write-Log -Message "Removing previous versions of package information registry key (PIRK) failed with error: $_"
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}
		# Else, log results from check. 
		Else { 
			Write-Log -Message "Previous versions of package information registry key (PIRK) do not exist."  
		}

		# Remove Citrix Receiver 4.8 installations if found
		$strAllUsersProfile = (get-content env:ALLUSERSPROFILE)
		$strExistingInstall = "$strAllUsersProfile\Citrix\Citrix Receiver 4.8\TrolleyExpress.exe"
		If ((Test-Path $strExistingInstall) -eq $true) {
			Write-Log "Found Previous Install At $strExistingInstall. Removing..."
			Execute-Process -FilePath "$strExistingInstall" -Arguments "/uninstall /cleanup /silent"
		}
		
		# Remove Citrix Receiver 4.11 installations if found
		$strAllUsersProfile = (get-content env:ALLUSERSPROFILE)
		$strExistingInstall = "$strAllUsersProfile\Citrix\Citrix Receiver 4.11\TrolleyExpress.exe"
		If ((Test-Path $strExistingInstall) -eq $true) {
			Write-Log "Found Previous Install At $strExistingInstall. Removing..."
			Execute-Process -FilePath "$strExistingInstall" -Arguments "/uninstall /cleanup /silent"
		}
		
		# Remove Previous Citrix online plug-in Installations
		$strExistingInstall = "$strAllUsersProfile\Citrix\Citrix online plug-in\TrolleyExpress.exe"
		If ((Test-Path $strExistingInstall) -eq $true) {
			Write-Log "Found Previous Install At $strExistingInstall. Removing..."
			Execute-Process -FilePath "$strExistingInstall" -Arguments "/uninstall /cleanup /silent"
		}
		
		# Remove old fashioned Active Setup if exists.
		If ((Test-Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\DisableCitrixAutoUpdate") -eq $true) {
			Write-Log "Found old fashioned Active Setup. Removing..."
			Remove-RegistryKey -Key "HKLM\SOFTWARE\Microsoft\Active Setup\Installed Components\DisableCitrixAutoUpdate"
		}
		
		# Remove old fashioned Active Setup if exists.
		If ((Test-Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\AnaCitrix4.8.0") -eq $true) {
			Write-Log "Found old fashioned Active Setup. Removing..."
			Remove-RegistryKey -Key "HKLM\SOFTWARE\Microsoft\Active Setup\Installed Components\AnaCitrix4.8.0"
		}		
		
		# Remove old Active Setup Command File
		If ((Test-Path "$envWindir\Installer\CU-DisableCitrixUpdate.cmd") -eq $true) {
			Write-Log "Found old Active Setup Command File. Removing..."
			Remove-File -Path "$envWindir\Installer\CU-DisableCitrixUpdate.cmd"
		}
		
		##*===============================================
		##* ANCHOR: INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		# Show installation progress message window.
		Show-InstallationProgress -StatusMessage "Installing `n `n $apName ($apversion) `n `n Please Wait..." 

        # Microsoft Visual C++ 2015-2022 Redistributable (x64)
		# Install Prerequiste application(s) (x64).
		# If installation failed, log results. Exit script.
		$RemovePrereqAppNamesCheck1 = Get-InstalledApplication -Name "$PrereqApp1Name"
		$RemovePrereqAppNamesCheck3 = Get-InstalledApplication -Name "$PrereqApp3Name"
		If ($null -eq $RemovePrereqAppNamesCheck1 -And $Null -eq $RemovePrereqAppNamesCheck3) {
			Try {
				Write-log -Message "Installing $PrereqApp1Name."
				Execute-Process -Path "$PrereqApp1InstallPath" -Parameters "$PrereqApp1InstallParam"
				Write-Log -Message "Installing $PrereqApp1Name complete." 
			}
			# If install failed, log results. Exit script.
			Catch [System.Exception] {
				Write-Log -Message "Installing $PrereqApp1Name failed with error: $_."
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}

        # Microsoft Visual C++ 2015-2022 Redistributable (x86)
		# Install Prerequiste application(s) (x86).
		# If installation failed, log results. Exit script.
		$RemovePrereqAppNamesCheck2 = Get-InstalledApplication -Name "$PrereqApp2Name"
		$RemovePrereqAppNamesCheck4 = Get-InstalledApplication -Name "$PrereqApp4Name"
		If ($null -eq $RemovePrereqAppNamesCheck2 -And $Null -eq $RemovePrereqAppNamesCheck4) {
			Try {
				Write-log -Message "Installing $PrereqApp1Name."
				Execute-Process -Path "$PrereqApp2InstallPath" -Parameters "$PrereqApp2InstallParam"
				Write-Log -Message "Installing $PrereqApp1Name complete." 
			}
			# If install failed, log results. Exit script.
			Catch [System.Exception] {
				Write-Log -Message "Installing $PrereqApp1Name failed with error: $_."
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}

		# Install application(s).
		# If installation failed, log results. Exit script. 
		Try {
			Write-log -Message "Installing $apName ($apversion)."
			Execute-Process -Path "$64bitAppInstallPath" -Parameters "$64bitAppInstallParam"
			Write-Log -Message "Installing $apName ($apversion) complete." 
		}
		# If install failed, log results. Exit script.
		Catch [System.Exception] {
			Write-Log -Message "Installing $apName ($apversion) failed with error: $_."
			Write-Log -Message "Exiting script with error."
			Exit-Script -ExitCode 1627
		}

		##* Every package should have a package information registry key (PIRK), which details what the $apversion and $apScriptVErsion are, along with any other information.
		# Create package information registry key (PIRK).
		# If creation failed, log results. Exit script.
		Try {
			Write-Log -Message "Creating package information registry key (PIRK)."
			Set-RegistryKey -Key "HKLM:\Software\Tuolumne County\Package Information" -Name "Readme" -Value "These Package Information Registry Keys (PIRKs) are used for SCCM application detection. Please do not modify unless you know what you are doing." -Type String
			Set-RegistryKey -Key "HKLM:\Software\Tuolumne County\Package Information\$apName" -Name "apVersion" -Value "$apversion" -Type String
			Set-RegistryKey -Key "HKLM:\Software\Tuolumne County\Package Information\$apName" -Name "apScriptVersion" -Value "$apScriptVErsion" -Type String
			Write-Log -Message "Creating package information registry key (PIRK) complete." 
		}
		# If creation failed, log results. Exit script.
		Catch [System.Exception] {
			Write-Log -Message "Creating package information registry key (PIRK) failed with error: $_."
			Write-Log -Message "Exiting script with error."
			Exit-Script -ExitCode 1627
		}

		##*===============================================
		##* ANCHOR: POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		# Show installation restart prompt.
		Show-InstallationRestartPrompt -CountdownSeconds "3600" -CountdownNoHideSeconds "10"

	}
	ElseIf ($deploymentType -ieq 'Uninstall') {
		##*===============================================
		##* ANCHOR: PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		# Check if deployment is interactive.
		# If yes (it is interactive), show close application(s) prompt. Do not allow application(s) to start during install. 
		If ($DeployMode -eq "Interactive") {
			Show-InstallationWelcome -CloseApps "$CloseApps" -MinimizeWindows $false -PersistPrompt -DeferDays "3" -BlockExecution -AllowDefer -DeferTimes "3"
		}

		##*===============================================
		##* ANCHOR: UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		# Check if previous versions of Citrix Workspace App exist.
		# If Citrix Workspace App exists, remove previous versions of Citrix Workspace 1912 App.
		# If removal failed, log results. Exit script. 
		# Else, log results from check.
		If ((Test-Path -Path "$envProgramFilesX86\Citrix\Citrix Workspace 1912") -Or (Test-Path -Path "$envProgramFilesX86\Citrix\ICA Client")) { 
			# Remove previous versions of Citrix Workspace 1912 App.
			Try {
				Write-Log -Message "Previous versions of $64bitAppUninstallName exist. Removing..."
				Execute-Process -Path "$64bitAppUninstallPath" -Parameters "$64bitAppUninstallParam"
                Remove-Folder -Path "$envProgramFilesX86\Citrix\Citrix Workspace 1912"
                Remove-Folder -Path "$envProgramFilesX86\Citrix\ICA Client"
				Write-Log -Message "Removing previous versions of $64bitAppUninstallName complete."

			}
			# If removal failed, log results. Exit script. 
			Catch [System.Exception] {
				Write-Log -Message "Removing previous versions of $64bitAppUninstallName failed with error: $_"
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}
		# Else, log results from check. 
		Else { 
			Write-Log -Message "Previous versions of $64bitAppUninstallName do not exist."  
		}

        # Test if the ICA CLient path still exists.
        # If the path still exists, show installation restart prompt. The ICA CLient path can only be removed after a reboot (it appears).
		If (Test-Path -Path "$envProgramFilesX86\Citrix\ICA Client") { 
			Try {
                Write-Log -Message "Device restart needed to finish removing the ICA Client. PLease restart and try again."
		        # Show installation restart prompt.
		        Show-InstallationRestartPrompt -CountdownSeconds "3600" -CountdownNoHideSeconds "10"
			}
			# If removal failed, log results. Exit script. 
			Catch [System.Exception] {
				Write-Log -Message "Rebooting the device failed with error: $_"
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}
		
        <#
		# Check if previous versions of Visual C++ 2015-2019 Redistributable exist.
		# If Visual C++ 2015-2019 Redistributable exists, remove previous versions of Visual C++ 2015-2019 Redistributable.
		# If removal failed, log results. Exit script. 
		# Else, log results from check.
		If (Test-Path -Path "C:\WINDOWS\System32\vcamp140.dll") { 
			# Remove previous versions of Visual C++ 2015-2019 Redistributable.
			Try {
				Write-Log -Message "Previous versions of $PrereqApp1UninstallName exist. Removing..."
				Execute-Process -Path "$dirFiles\$PrereqApp1UninstallPath" -Parameters "$PrereqApp1UninstallParam"
				Write-Log -Message "Removing previous versions of $PrereqApp1UninstallName complete."
			}
			# If removal failed, log results. Exit script. 
			Catch [System.Exception] {
				Write-Log -Message "Removing previous versions of $PrereqApp1UninstallName failed with error: $_"
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}
		# Else, log results from check. 
		Else { 
			Write-Log -Message "Previous versions of $PrereqApp1UninstallName do not exist."  
		}
        #>

		# Check if previous versions of package information registry key (PIRK) exist. 
		# If package information registry key (PIRK) exists, remove previous versions of package information registry key (PIRK).
		# If removal failed, log results. Exit script. 
		# Else, log results from check.
		If (Test-Path -Path "HKLM:\SOFTWARE\Tuolumne County\Package Information\$apName*") { 
			# Remove previous versions of package information registry key (PIRK).
			Try {
				Write-Log -Message "Previous versions of package information registry key (PIRK) exist. Removing..."
				Remove-Item -Path "HKLM:\SOFTWARE\Tuolumne County\Package Information\$apName*" -Force
				Write-Log -Message "Removing previous versions of package information registry key (PIRK) complete."
			}
			# If removal failed, log results. Exit script. 
			Catch [System.Exception] {
				Write-Log -Message "Removing previous versions of package information registry key (PIRK) failed with error: $_"
				Write-Log -Message "Exiting script with error."
				Exit-Script -ExitCode 1627
			}
		}
		# Else, log results from check. 
		Else { 
			Write-Log -Message "Previous versions of package information registry key (PIRK) do not exist."  
		}

		##*===============================================
		##* ANCHOR: POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		# Show installation restart prompt.
		Show-InstallationRestartPrompt -CountdownSeconds "3600" -CountdownNoHideSeconds "10"

	}
	ElseIf ($deploymentType -ieq 'Repair') {
		##*===============================================
		##* ANCHOR: PRE-REPAIR
		##*===============================================
		[string]$installPhase = 'Pre-Repair'

		## <Perform Pre-Repair tasks here>

		##*===============================================
		##* ANCHOR: REPAIR
		##*===============================================
		[string]$installPhase = 'Repair'

		## Handle Zero-Config MSI Repairs
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}
		
		# <Perform Repair tasks here>

		##*===============================================
		##* ANCHOR: POST-REPAIR
		##*===============================================
		[string]$installPhase = 'Post-Repair'

		## <Perform Post-Repair tasks here>

	}
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}
