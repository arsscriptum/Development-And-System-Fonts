#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   Clean-FontsFolder.ps1                                                        ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <codegp@icloud.com>                                         ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Path to clean")]
    [ValidateNotNullOrEmpty()]
    [string]$Path
    [Parameter(Mandatory = $False)]
    [switch]$Confirm
)

function Invoke-CleanFontsFolder {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Path to clean")]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )
    process {
        # Resolve path
        $Path = (Resolve-Path $Path).Path
        Write-Verbose "Cleaning folder: $Path"

        # Remove all .ttf files recursively
        $ttfFiles = Get-ChildItem -Path $Path -Filter *.ttf -Recurse -File
        foreach ($ttf in $ttfFiles) {
            if ($PSCmdlet.ShouldProcess($ttf.FullName, "Delete TTF file")) {
                Remove-Item $ttf.FullName -Force
                Write-Verbose "Deleted: $($ttf.FullName)"
            }
        }

        # Prepare target folders
        $installedPackages = Join-Path $Path 'InstalledPackages'
        $misc = Join-Path $Path 'Misc'
        $scriptsDir = Join-Path $Path 'Scripts'
        foreach ($dir in @($installedPackages, $misc, $scriptsDir)) {
            if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory | Out-Null }
        }

        # Move all zip files to InstalledPackages
        $zipFiles = Get-ChildItem -Path $Path -Filter *.zip -Recurse -File
        foreach ($zip in $zipFiles) {
            $target = Join-Path $installedPackages $zip.Name
            if ($PSCmdlet.ShouldProcess($zip.FullName, "Move ZIP to InstalledPackages")) {
                Move-Item -Path $zip.FullName -Destination $target -Force
                Write-Verbose "Moved ZIP: $($zip.FullName) -> $target"
            }
        }
        # Move all other files (not .ttf, not .zip) to Misc
        $scriptsFiles = Get-ChildItem -Path $Path -Recurse -File | Where-Object {
            $_.Extension -ne '.ps1' -and $_.Extension -ne '.bat'
        }

        foreach ($file in $scriptsFiles) {
            $target = Join-Path $scriptsDir $file.Name
            if ($PSCmdlet.ShouldProcess($file.FullName, "Move misc file to Misc")) {
                Move-Item -Path $file.FullName -Destination $target -Force
                Write-Verbose "Moved Misc: $($file.FullName) -> $target"
            }
        }

        # Move all other files (not .ttf, not .zip) to Misc
        $otherFiles = Get-ChildItem -Path $Path -Recurse -File | Where-Object {
            $_.Extension -ne '.ttf' -and $_.Extension -ne '.zip'
        }
        foreach ($file in $otherFiles) {
            $target = Join-Path $misc $file.Name
            if ($PSCmdlet.ShouldProcess($file.FullName, "Move misc file to Misc")) {
                Move-Item -Path $file.FullName -Destination $target -Force
                Write-Verbose "Moved Misc: $($file.FullName) -> $target"
            }
        }

        # Delete all empty directories (except InstalledPackages and Misc)
        $allDirs = Get-ChildItem -Path $Path -Recurse -Directory | Sort-Object FullName -Descending
        foreach ($dir in $allDirs) {
            if ($dir.FullName -eq $installedPackages -or $dir.FullName -eq $misc) { continue }
            if (-not (Get-ChildItem -Path $dir.FullName -Recurse | Where-Object { -not $_.PSIsContainer })) {
                if ($PSCmdlet.ShouldProcess($dir.FullName, "Delete empty directory")) {
                    Remove-Item -Path $dir.FullName -Force
                    Write-Verbose "Deleted empty dir: $($dir.FullName)"
                }
            }
        }
    }
}

function Get-AndConfirmPath {
    [CmdletBinding()]
    param()
    process {
        $Path = $Null
        $Done = $False
        while (!$Done) {
            Write-Host " 🎯 Please Select a Path " -ForegroundColor White -n
            $Path = Read-Host " "

            $dirExists = [System.IO.Directory]::Exists($Path)
            Write-Host " ✋ Wait! You provided the following path:"
            Write-Host "  `"$Path`" " -ForegroundColor Cyan -n
            if (!$dirExists) {
                Write-Host " ❌ which doesn't exists! Try Again!" -ForegroundColor DarkYellow
                continue
            } else {
                Write-Host " ✔️ a valid path" -ForegroundColor White
                $answer = Read-Host "Is this correct ❓ [[Y]es/[N]o/[C]ancel]"
                $answer = $answer.ToLower()

                if ($answer -match '^(y|yes)') {
                    $Done = $True
                    return $Path
                } elseif ($answer -match '^(c|cancel)') {
                    $Done = $True
                    Write-Host " ⛔ Cancelled! " -ForegroundColor DarkRed
                   return $Null
                } else {
                    Write-Host " OK, Try Again ❗ " -ForegroundColor DarkRed -n
                    $Done = $False
                    $Path = $Null
                }
            }

        }
        return $Null
    }
}

function Test-ConfirmPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "Path to confirm")]
        [string]$Path
    )
    process {
        Write-Host "You provided the following path:"
        Write-Host "  $Path" -ForegroundColor Cyan
        $answer = Read-Host "Is this correct? [Y/N]"
        if ($answer -match '^(y|yes)$') {
            return $true
        } else {
            return $false
        }
    }
}


$WorkPath = Resolve-Path -Path "$Path" -ErrorAction Stop

if(-not(Test-ConfirmPath -Path $WorkPath)) {
    $WorkPath = Get-AndConfirmPath    
}
if(-not($WorkPath)) { return }
Invoke-CleanFontsFolder $WorkPath