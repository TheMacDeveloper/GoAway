if($args[0] -match "help" -or $args.Count -eq 0)
{
    Write-Host "GoAway - Application Annihilator for Windows 10" -ForegroundColor Green -BackgroundColor Black
    Write-Host "usage: .\GoAway.ps1 [<ProgramName> [Optional <InstallFolderPath>]] [delete]" -ForegroundColor Red -BackgroundColor Black
    return
} 
$ProgramName = $args[0]
$InstallFolderPath = "cd $Env:Programfiles", "${Env:ProgramFiles(x86)}", "$Env:USERPROFILE\AppData\"

if($ProgramName -eq "delete")
{
    Get-Content -Path .\MatchedKeys.txt
    Write-Host "ARE YOU SURE YOU WOULD LIKE TO DELETE THESE KEYS... (ctrl+c to stop)" -ForegroundColor Red -BackgroundColor Black
    cmd /c pause

    #System restore point
    Write-Host "Creating System Restore Point..." -ForegroundColor Green -BackgroundColor Black
    Checkpoint-Computer -Description "GoAway-$(get-date -f yyyy-MM-dd_HH-mm-ss)"

    #Delete
    Get-Content -Path .\MatchedKeys.txt | Remove-ItemProperty

    return
}

# Program user path
if($args.Count -eq 2)
{
    $InstallFolderPath = $args[1]   
}

# Looks for files in the stated file path, finds them if they have the key term uninstall and lists them
# Get-ChildItem -Path "$($UninstallPath)\*" -Include *uninstall* 
Write-Host "Searching for uninstallers in " $InstallFolderPath - -ForegroundColor Red -BackgroundColor Black

#for each loop that takes each file found called "uninstall.exe" and runs it
foreach ($uninstallexe in Get-ChildItem -Path "$($UninstallPath)\*" -Include *uninstall* )
{
    Start-Process -FilePath $uninstallexe
}

function Search-Registry { 
    <# 
    From https://gallery.technet.microsoft.com/scriptcenter/Search-Registry-Find-Keys-b4ce08b4

    .SYNOPSIS 
    Searches registry key names, value names, and value data (limited). 
    
    .DESCRIPTION 
    This function can search registry key names, value names, and value data (in a limited fashion). It outputs custom objects that contain the key and the first match type (KeyName, ValueName, or ValueData). 
    
    .EXAMPLE 
    Search-Registry -Path HKLM:\SYSTEM\CurrentControlSet\Services\* -SearchRegex "svchost" -ValueData 
    
    .EXAMPLE 
    Search-Registry -Path HKLM:\SOFTWARE\Microsoft -Recurse -ValueNameRegex "ValueName1|ValueName2" -ValueDataRegex "ValueData" -KeyNameRegex "KeyNameToFind1|KeyNameToFind2" 
    
    #> 
        [CmdletBinding()] 
        param( 
            [Parameter(Mandatory, Position=0, ValueFromPipelineByPropertyName)] 
            [Alias("PsPath")] 
            # Registry path to search 
            [string[]] $Path, 
            # Specifies whether or not all subkeys should also be searched 
            [switch] $Recurse, 
            [Parameter(ParameterSetName="SingleSearchString", Mandatory)] 
            # A regular expression that will be checked against key names, value names, and value data (depending on the specified switches) 
            [string] $SearchRegex, 
            [Parameter(ParameterSetName="SingleSearchString")] 
            # When the -SearchRegex parameter is used, this switch means that key names will be tested (if none of the three switches are used, keys will be tested) 
            [switch] $KeyName, 
            [Parameter(ParameterSetName="SingleSearchString")] 
            # When the -SearchRegex parameter is used, this switch means that the value names will be tested (if none of the three switches are used, value names will be tested) 
            [switch] $ValueName, 
            [Parameter(ParameterSetName="SingleSearchString")] 
            # When the -SearchRegex parameter is used, this switch means that the value data will be tested (if none of the three switches are used, value data will be tested) 
            [switch] $ValueData, 
            [Parameter(ParameterSetName="MultipleSearchStrings")] 
            # Specifies a regex that will be checked against key names only 
            [string] $KeyNameRegex, 
            [Parameter(ParameterSetName="MultipleSearchStrings")] 
            # Specifies a regex that will be checked against value names only 
            [string] $ValueNameRegex, 
            [Parameter(ParameterSetName="MultipleSearchStrings")] 
            # Specifies a regex that will be checked against value data only 
            [string] $ValueDataRegex 
        ) 
    
        begin { 
            switch ($PSCmdlet.ParameterSetName) { 
                SingleSearchString { 
                    $NoSwitchesSpecified = -not ($PSBoundParameters.ContainsKey("KeyName") -or $PSBoundParameters.ContainsKey("ValueName") -or $PSBoundParameters.ContainsKey("ValueData")) 
                    if ($KeyName -or $NoSwitchesSpecified) { $KeyNameRegex = $SearchRegex } 
                    if ($ValueName -or $NoSwitchesSpecified) { $ValueNameRegex = $SearchRegex } 
                    if ($ValueData -or $NoSwitchesSpecified) { $ValueDataRegex = $SearchRegex } 
                } 
                MultipleSearchStrings { 
                    # No extra work needed 
                } 
            } 
        } 
    
        process { 
            foreach ($CurrentPath in $Path) { 
                Get-ChildItem $CurrentPath -Recurse:$Recurse |  
                    ForEach-Object { 
                        $Key = $_ 
    
                        if ($KeyNameRegex) {  
                            Write-Verbose ("{0}: Checking KeyNamesRegex" -f $Key.Name)  
    
                            if ($Key.PSChildName -match $KeyNameRegex) {  
                                Write-Verbose "  -> Match found!" 
                                return [PSCustomObject] @{ 
                                    Key = $Key 
                                    Reason = "KeyName" 
                                } 
                            }  
                        } 
    
                        if ($ValueNameRegex) {  
                            Write-Verbose ("{0}: Checking ValueNamesRegex" -f $Key.Name) 
    
                            if ($Key.GetValueNames() -match $ValueNameRegex) {  
                                Write-Verbose "  -> Match found!" 
                                return [PSCustomObject] @{ 
                                    Key = $Key 
                                    Reason = "ValueName" 
                                } 
                            }  
                        } 
    
                        if ($ValueDataRegex) {  
                            Write-Verbose ("{0}: Checking ValueDataRegex" -f $Key.Name) 
    
                            if (($Key.GetValueNames() | ForEach-Object { $Key.GetValue($_) }) -match $ValueDataRegex) {  
                                Write-Verbose "  -> Match!" 
                                return [PSCustomObject] @{ 
                                    Key = $Key 
                                    Reason = "ValueData" 
                                } 
                            } 
                        } 
                    } 
            } 
        } 
    } 

Write-Host "Searching for $ProgramName... This may take several hours depending on your system..." -ForegroundColor Green -BackgroundColor Black
Write-Host "Nothing will be deleted at this stage..." -ForegroundColor Red -BackgroundColor Black

#Search and output to file
Search-Registry -Path "HKLM:\" -Recurse -SearchRegex $ProgramName | Out-File -FilePath .\MatchedKeys.txt
Get-Content -Path .\MatchedKeys.txt

cmd /c pause