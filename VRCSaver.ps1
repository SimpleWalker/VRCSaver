<#
.SYNOPSIS
  A simple powershell script to monitor the clipboard to save new copied text to new files in different profile folder 
  and to load the last file data to the clipboard from startup or changing profile

.DESCRIPTION
  A simple powershell script to monitor the clipboard to save new copied text to new files in different profile folder 
  and to load the last file data to the clipboard from startup or changing profile

.PARAMETER
  None

.INPUTS
  Data from clipboard

.OUTPUTS
  Files with data from clipboard

.NOTES
  Version:        1.0
  Author:         SimpleWalker
  Creation Date:  29/12/2024
  Purpose/Change: Initial script development

.EXAMPLE
  None
#>

#region Initialisations

# Load module for GUI
Add-Type -AssemblyName System.Windows.Forms
# Load module for error box
Add-Type -AssemblyName PresentationCore,PresentationFramework

# Check if app folder exist and if not, create it
if (!(Test-Path "$env:APPDATA\VRCsaver")){

    New-Item -Path "$env:APPDATA\" -Name "VRCsaver" -ItemType "directory" | Out-Null
}

# Check if settings exist and if not, create with default values
if (!(Test-Path "$env:APPDATA\VRCsaver\Settings.json" -PathType Leaf)){

    $SettingJSON = ConvertTo-Json @{
        AutoStart= $true
        DefaultProfile="default"
        CodeCharacter="@"
        Speed=5
        MaxHistory=10
    }
    New-Item -Path "$env:APPDATA\VRCsaver\" -Name "Settings.json" -ItemType "file" -Value $SettingJSON | Out-Null
}

# Get settings from setting files
# TODO: Add try catch
$Settings = Get-Content -Path "$env:APPDATA\VRCsaver\Settings.json" | ConvertFrom-Json

# Check if settings is corrupted
$SettingCorrupted = Compare-Object -ReferenceObject @("AutoStart","DefaultProfile","CodeCharacter","Speed","MaxHistory") -DifferenceObject $($Settings.PSobject.Properties.name) -PassThru

# If corrupted, Create new settings file with default values as set settings object with default values
if($SettingCorrupted){

    $SettingJSON = ConvertTo-Json @{
        AutoStart= $true
        DefaultProfile="default"
        CodeCharacter="@"
        Speed=5
        MaxHistory=10
    }
    New-Item -Path "$env:APPDATA\VRCsaver\" -Name "Settings.json" -ItemType "file" -Value $SettingJSON -Force | Out-Null
    $Settings = ConvertFrom-Json $SettingJSON
}

# Check if default folder (profile) exist and if not, create it
if (!(Test-Path "$env:APPDATA\VRCsaver\default")){

    New-Item -Path "$env:APPDATA\VRCsaver\" -Name "default" -ItemType "directory" | Out-Null
}

# List all windows illegal characters to later check against when making a new folder (profile)
$WindowsPattern = "[{0}]" -f ([Regex]::Escape([String][System.IO.Path]::GetInvalidFileNameChars()))
# List all folders (profiles), need to be an array as if it just default it would get set as a string
[array]$List = (Get-ChildItem -path "$env:APPDATA\VRCsaver" -Directory).BaseName

# Check if setting default profile folder exist, if not. Set as default
if ($List -notcontains $Settings.DefaultProfile){$Settings.DefaultProfile = "default"}

# Get all the files of the default folder (profile) if any to load last save into the clipboard
$FilePath = Get-ChildItem -Path "$env:APPDATA\VRCsaver\$($Settings.DefaultProfile)\" -Filter "*.txt"

# If there is files, load last save as raw text into clipboard. Otherwise clear the clipboard
# $Set the fileclip as this is used as last copied item when checking if new data been copied into the clipboard
if ($FilePath){

    $FileClip = Get-Content -Path $($FilePath | Select -Last 1 -ExpandProperty FullName) -Raw
    Set-Clipboard -Value $FileClip
} else {

    $FileClip = ""
    Set-Clipboard -Value $null
}
#endregion

#region Clipboard monitoring script

# Create the runspace
$Runspace = [runspacefactory]::CreateRunspace()
$Runspace.ApartmentState = "STA"
$Runspace.ThreadOptions = "ReuseThread"
$Runspace.Open()
$Runspace.Name = "Clipboard"

$code = {

    # Get variable from runspace invoke to run the script
    param(

        $WindowsPattern,
        $Active,
        $FileClip,
        $CodeCharacter,
        $TimeCycle,
        $MaxHistory
    )

    # List all folders (profiles), need to be an array as if it just default it would get set as a string
    # Need to do a new list as new profiles could be created in the GUI before started
    [array]$List = (Get-ChildItem -path "$env:APPDATA\VRCsaver" -Directory).BaseName

    do {

        # How long to wait between check check
        Start-Sleep -Seconds $TimeCycle

        # Get current clipboard as raw as if there is enter in text, get-clipboard returns an object
        $CurrentClip = Get-Clipboard -Raw -Format Text

        # If clipboard is blank, do nothing
        if (($CurrentClip -eq $null) -or ($CurrentClip -eq "")){Continue}

        # End the loop if the stop code is copied into the clipboard
        if ($CurrentClip -eq "$($CodeCharacter)stop"){break}

        # If the code character is at the start and there is no illegal characters for windows folder
        # Treat it like a profile name
        if (($CurrentClip -like "$($CodeCharacter)*") -and ($CurrentClip -notmatch $WindowsPattern)){

            # Remove the code character as it is no longer needed
            $SwitchActive = $CurrentClip.Substring(1)
            # If nothing is left, then it was just the code character and treat it as default profile
            if ($SwitchActive -eq ""){$SwitchActive = "default"}

            # Check if profile is in the existing list and set it as the active profile
            [string]$Active = $List -eq $SwitchActive
            
            # If not, create a new folder (profile) and set as the active profile
            if ($Active -eq ""){

                New-Item -Path "$env:APPDATA\VRCsaver\" -Name "$SwitchActive" -ItemType "directory" | Out-Null
                $Active = $SwitchActive
                # Remember to update the list of existing profile
                # This did not catch me out, I swear gov
                [array]$List = (Get-ChildItem -path "$env:APPDATA\VRCsaver" -Directory).BaseName
            }

            # As before in the Initialisations, get list of files and load lastest on into clipboard. otherwise clear the clipboard
            $FilePath = Get-ChildItem -Path "$env:APPDATA\VRCsaver\$Active\" -Filter "*.txt"
            if ($FilePath){

                $FileClip = Get-Content -Path $($FilePath | Select -Last 1 -ExpandProperty FullName) -Raw
                Set-Clipboard -Value $FileClip
            } else {
        
                $FileClip = ""
                Set-Clipboard -Value $null
            }

            # Retart the loop as we are not saving any new data
            continue
        }

        # Check if current clipboard is different from file clipboard (last clipbopard change)
        if ($CurrentClip -ne $FileClip){

            # Make new file with the clipboard data and set file clipboard to current clipboard (Remember, backup your data. No one ever does)
            New-Item -Path "$env:APPDATA\VRCsaver\$Active\" -Name "$Active`_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt" -ItemType "file" -Value $CurrentClip | Out-Null
            $FileClip = $CurrentClip

            # If max history is set to a limit (0 = unlimited) then remove oldest file
            if ($MaxHistory -gt 0){

                Get-ChildItem -Path "$env:APPDATA\VRCsaver\$Active\" -Filter "*.txt" |  Sort CreationTime -desc |  Select -skip $MaxHistory | Remove-Item -Force
            }
        }
    # Spooky while loop
    } while ($true)
}

# Create runspace for clipboard code so it runs as it own thread to not lockup main thread which have the GUI
$PSinstance = [powershell]::Create().AddScript($Code)
[void] $PSinstance.AddArgument($WindowsPattern)
[void] $PSinstance.AddArgument($Settings.DefaultProfile)
[void] $PSinstance.AddArgument($FileClip)
[void] $PSinstance.AddArgument($Settings.CodeCharacter)
[void] $PSinstance.AddArgument($Settings.Speed)
[void] $PSinstance.AddArgument($Settings.MaxHistory)
$PSinstance.Runspace = $Runspace

# Do need to explain this to you?
if ($Settings.AutoStart){
    $PSinstance.BeginInvoke()
}
#endregion

#region GUI

# Main form
$MainForm = New-Object System.Windows.Forms.Form
$MainForm.Font = "Microsoft Sans Serif, 18pt"
$MainForm.Text ="VRCSaver"
$MainForm.Width = 400
$MainForm.Height = 520
$MainForm.FormBorderStyle = "FixedDialog"

$LabelProfile = New-Object System.Windows.Forms.Label
$LabelProfile.Location = New-Object System.Drawing.Point 10,15
$LabelProfile.Size = New-Object System.Drawing.Point 80,25
$LabelProfile.Name = "LabelProfile"
$LabelProfile.Text = "Profile"

$ComboProfile = New-Object System.Windows.Forms.ComboBox
$ComboProfile.Location = New-Object System.Drawing.Point 90,10
$ComboProfile.Size = New-Object System.Drawing.Point 280,35
$ComboProfile.Name = "ComboProfile"
$ComboProfile.Text = ""
$List | ForEach-Object {[void] $ComboProfile.Items.Add($_)}
# Get index of settings default profile to set as dropbox index
$ComboProfile.SelectedIndex = $([array]::IndexOf($list, $Settings.DefaultProfile))

$ButtonDefault = New-Object System.Windows.Forms.Button
$ButtonDefault.Location = New-Object System.Drawing.Point 10,50
$ButtonDefault.Size = New-Object System.Drawing.Point 360,35
$ButtonDefault.Name = "ButtonDefault"
$ButtonDefault.Text = "Set as default"
$ButtonDefault.Add_Click({

    # Check if it the same to save doing work
    if ($Settings.DefaultProfile -eq $ComboProfile.Text){Return}
    # Just do it
    $Settings.DefaultProfile = $ComboProfile.Text
    New-Item -Path "$env:APPDATA\VRCsaver\" -Name "Settings.json" -ItemType "file" -Value $($Settings | ConvertTo-Json) -Force | Out-Null
    $LabelStatus.Text = "Status: Default Updated"
})

$ButtonFolder = New-Object System.Windows.Forms.Button
$ButtonFolder.Location = New-Object System.Drawing.Point 10,90
$ButtonFolder.Size = New-Object System.Drawing.Point 360,35
$ButtonFolder.Name = "ButtonDefault"
$ButtonFolder.Text = "Open profile folder"
$ButtonFolder.Add_Click({ii "$env:APPDATA\VRCsaver\$($ComboProfile.Text)\"})

$ButtonCreateProfile = New-Object System.Windows.Forms.Button
$ButtonCreateProfile.Location = New-Object System.Drawing.Point 10,130
$ButtonCreateProfile.Size = New-Object System.Drawing.Point 360,35
$ButtonCreateProfile.Name = "ButtonCreateProfile"
$ButtonCreateProfile.Text = "Create New Profile"
$ButtonCreateProfile.Add_Click({

    # Create popup window
    $Popup = New-Object System.Windows.Forms.Form
    $Popup.Font = "Microsoft Sans Serif, 18pt"
    $Popup.Text ="VRCSaver - Create New Profile"
    $Popup.Width = 290
    $Popup.Height = 140
    $Popup.FormBorderStyle = "FixedDialog"

    $TextboxPopup = New-Object System.Windows.Forms.TextBox
    $TextboxPopup.Location = New-Object System.Drawing.Point 10,10
    $TextboxPopup.Size = New-Object System.Drawing.Point 250,35
    $TextboxPopup.Name = "TextboxPopup"
    # Close the popup to run the rest of the event
    $TextboxPopup.Add_Keydown({if ($_.keycode -eq "Enter"){$Popup.Close()}})

    $buttonPopup = New-Object System.Windows.Forms.Button
    $buttonPopup.Location = New-Object System.Drawing.Point 10,50
    $buttonPopup.Size = New-Object System.Drawing.Point 250,35
    $buttonPopup.Name = "TextboxPopup"
    $buttonPopup.Text = "Create"
    # Close the popup to run the rest of the event
    $buttonPopup.Add_Click({$Popup.Close()})

    $Popup.Controls.AddRange(@($TextboxPopup,$buttonPopup))
    $Popup.ShowDialog() | Out-Null

    # Check name if legal and already exist and warn the user and return out
    if ($TextboxPopup.Text -match $WindowsPattern){[System.Windows.MessageBox]::Show("Illegal characters in profile name","Error",0,16);return}
    if (Test-Path "$env:APPDATA\VRCsaver\$($TextboxPopup.Text)"){[System.Windows.MessageBox]::Show("Profile already exists","Warning",0,48);return}
    
    # Create new folder (profile) and set as currently selected profile
    New-Item -Path "$env:APPDATA\VRCsaver\" -Name "$($TextboxPopup.Text)" -ItemType "directory" | Out-Null
    $ComboProfile.SelectedIndex = $ComboProfile.Items.Add($TextboxPopup.Text)
})

$ButtonRemoveProfile = New-Object System.Windows.Forms.Button
$ButtonRemoveProfile.Location = New-Object System.Drawing.Point 10,170
$ButtonRemoveProfile.Size = New-Object System.Drawing.Point 360,35
$ButtonRemoveProfile.Name = "ButtonRemoveProfile"
$ButtonRemoveProfile.Text = "Remove Profile"
$ButtonRemoveProfile.Add_Click({

    # Ask the user to confirm before deleting
    # Default folder cannot be removed but cleaned
    if ($ComboProfile.Text -ne "default"){
    
        $Answer = [System.Windows.MessageBox]::Show("Are you sure you want to delete profile $($ComboProfile.Text)?","Warning",4,48)
        if ($Answer -eq "No"){Return}
        Remove-Item -LiteralPath "$env:APPDATA\VRCsaver\$($ComboProfile.Text)" -Force -Recurse
        $ComboProfile.Items.Remove($ComboProfile.Text)
        $ComboProfile.SelectedIndex = $([array]::IndexOf($list, $Settings.DefaultProfile))

    } else {

        $Answer = [System.Windows.MessageBox]::Show("Default cannot be removed but can be cleared. Clear default?","Warning",4,48)
        if ($Answer -eq "No"){Return}
        Remove-Item -Path "$env:APPDATA\VRCsaver\default\*" -Recurse
    }
    
})

$LabelControl = New-Object System.Windows.Forms.Label
$LabelControl.Location = New-Object System.Drawing.Point 10,210
$LabelControl.Size = New-Object System.Drawing.Point 110,25
$LabelControl.Name = "LabelControl"
$LabelControl.Text = "Control"

$TextBoxControl = New-Object System.Windows.Forms.TextBox
$TextBoxControl.Location = New-Object System.Drawing.Point 140,205
$TextBoxControl.Size = New-Object System.Drawing.Point 30,25
$TextBoxControl.Name = "TextBoxControl"
$TextBoxControl.Text = "$($Settings.CodeCharacter)"
$TextBoxControl.MaxLength = 1
# If textbox is blank, add default key back in
$TextBoxControl.Add_Leave({if ($TextBoxControl.Text -eq ""){$TextBoxControl.Text = "@"}})

$LabelAutoStart = New-Object System.Windows.Forms.Label
$LabelAutoStart.Location = New-Object System.Drawing.Point 10,240
$LabelAutoStart.Size = New-Object System.Drawing.Point 130,25
$LabelAutoStart.Name = "LabelAutoStart"
$LabelAutoStart.Text = "AutoStart"

$CheckBoxAutoStart = New-Object System.Windows.Forms.CheckBox
$CheckBoxAutoStart.Location = New-Object System.Drawing.Point 150,240
$CheckBoxAutoStart.Size = New-Object System.Drawing.Point 130,25
$CheckBoxAutoStart.Name = "CheckBoxAutoStart"
if ($Settings.AutoStart -eq $true){$CheckBoxAutoStart.Checked = $true}

$LabelSpeed = New-Object System.Windows.Forms.Label
$LabelSpeed.Location = New-Object System.Drawing.Point 10,270
$LabelSpeed.Size = New-Object System.Drawing.Point 200,25
$LabelSpeed.Name = "LabelSpeed"
$LabelSpeed.Text = "Seconds: $($Settings.Speed)"

$TrackBarSpeed = New-Object System.Windows.Forms.TrackBar
$TrackBarSpeed.Location = New-Object System.Drawing.Point 10,300
$TrackBarSpeed.Size = New-Object System.Drawing.Point 360,25
$TrackBarSpeed.Orientation = "Horizontal"
$TrackBarSpeed.TickStyle = "TopLeft"
$TrackBarSpeed.SetRange(1,30)
$TrackBarSpeed.Value = $Settings.Speed
$TrackBarSpeed.Add_ValueChanged({

    $LabelSpeed.Text = "Seconds: $($TrackBarSpeed.Value)"
})

$LabelMaxhistory = New-Object System.Windows.Forms.Label
$LabelMaxhistory.Location = New-Object System.Drawing.Point 10,340
$LabelMaxhistory.Size = New-Object System.Drawing.Point 360,25
$LabelMaxhistory.Name = "LabelMaxhistory"
# Maxhistory of 0 is unlimited
if ($Settings.MaxHistory -eq 0){

    $MaxHistoryText = "Unlimited"
} else {

    $MaxHistoryText = $Settings.MaxHistory
}
$LabelMaxhistory.Text = "Max History: $MaxHistoryText"

$TrackBarMaxhistory = New-Object System.Windows.Forms.TrackBar
$TrackBarMaxhistory.Location = New-Object System.Drawing.Point 10,360
$TrackBarMaxhistory.Size = New-Object System.Drawing.Point 360,25
$TrackBarMaxhistory.Orientation = "Horizontal"
$TrackBarMaxhistory.TickStyle = "TopLeft"
$TrackBarMaxhistory.SetRange(0,10)
$TrackBarMaxhistory.Value = $Settings.MaxHistory
$TrackBarMaxhistory.Add_ValueChanged({

    if ($TrackBarMaxhistory.Value -eq 0){

        $MaxHistoryText = "Unlimited"
    } else {

        $MaxHistoryText = $TrackBarMaxhistory.Value
    }
    $LabelMaxhistory.Text = "Max History: $MaxHistoryText"
})

$LabelStatus = New-Object System.Windows.Forms.Label
$LabelStatus.Location = New-Object System.Drawing.Point 10,400
$LabelStatus.Size = New-Object System.Drawing.Point 360,30
$LabelStatus.Name = "LabelStatus"
# Check if clipboard runspace is already running due to auto run
if ((Get-Runspace -name "Clipboard").RunspaceAvailability -eq "Busy") {

    $LabelStatus.Text = "Status: Started"
} else {

    $LabelStatus.Text = "Status: "
}

$ButtonSave = New-Object System.Windows.Forms.Button
$ButtonSave.Location = New-Object System.Drawing.Point 10,440
$ButtonSave.Size = New-Object System.Drawing.Point 100,35
$ButtonSave.Name = "ButtonSave"
$ButtonSave.Text = "Save"
$ButtonSave.Add_Click({

    # Just save everything
    $Settings.AutoStart = $CheckBoxAutoStart.Checked
    $Settings.Speed = $TrackBarSpeed.Value
    $Settings.CodeCharacter = $TextBoxControl.Text
    $Settings.MaxHistory = $TrackBarMaxhistory.Value

    New-Item -Path "$env:APPDATA\VRCsaver\" -Name "Settings.json" -ItemType "file" -Value $($Settings | ConvertTo-Json) -Force | Out-Null
    $LabelStatus.Text = "Status: Settings Saved"
})

$ButtonStart = New-Object System.Windows.Forms.Button
$ButtonStart.Location = New-Object System.Drawing.Point 120,440
$ButtonStart.Size = New-Object System.Drawing.Point 100,35
$ButtonStart.Name = "ButtonStart"
$ButtonStart.Text = "Start"
$ButtonStart.Add_Click({

    if ((Get-Runspace -name "Clipboard").RunspaceAvailability -eq "Busy"){return}

    $PSinstance.BeginInvoke()
    $LabelStatus.Text = "Status: Started"
})

$ButtonStop = New-Object System.Windows.Forms.Button
$ButtonStop.Location = New-Object System.Drawing.Point 230,440
$ButtonStop.Size = New-Object System.Drawing.Point 100,35
$ButtonStop.Name = "ButtonStop"
$ButtonStop.Text = "Stop"
$ButtonStop.Add_Click({
    
    $PSinstance.Stop()
    $LabelStatus.Text = "Status: Stopped"
})

# Yes, this is very long. I know, also I don't care
$MainForm.Controls.AddRange(@($LabelProfile,$ComboProfile,$ButtonDefault,$ButtonFolder,$ButtonCreateProfile,$ButtonRemoveProfile,$ButtonRemoveProfile,$LabelControl,$TextBoxControl,$LabelAutoStart,$CheckBoxAutoStart,$LabelSpeed,$TrackBarSpeed,$LabelMaxhistory,$TrackBarMaxhistory,$LabelStatus,$ButtonSave,$ButtonStart,$ButtonStop))
$MainForm.ShowDialog() | Out-Null

# Clean up runspace
$PSinstance.Dispose()
$Runspace.Dispose()
#endregion
