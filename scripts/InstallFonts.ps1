#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   installfonts.ps1                                                             ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <codegp@icloud.com>                                         ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝


function Test-IsAdmin {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([bool])]
    param()

    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal ($currentUser)

    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}




function Register-NewFonts {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if (-not (Test-IsAdmin)) {
        Write-Warning "❌ You must run this script as Administrator."
        return
    }

    # This registers all TTF fonts in C:\Windows\Fonts that are missing registry entries
    $fontRegPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

    $fontsDir = Join-Path "$env:SystemRoot" "Fonts"
    if(!(Test-Path "$fontsDir")){return}
    # Get all font files (TTF/OTF/other as needed)
    $files = Get-ChildItem -Path $fontsDir -Recurse -File | Where-Object {$_.Extension -ieq '.ttf' -or $_.Extension -ieq '.otf' -or $_.Extension -ieq '.fon' -or $_.Extension -ieq '.ttc'}
    $filesCount = $files.Count
    $numRegister = 0
    $numDupe = 0
    Write-Host "  ☑ listing from $valueName ... $filesCount Fonts!"
    foreach ($file in $files) {
        # Try to read font name (for registry, fallback to file name)
        try {
            # Use Windows API to read friendly font name if you want, here we just use the file name
            $regName = $file.Name # E.g. "Tomorrow-Regular.ttf"
        } catch {
            $regName = $file.Name
        }

        # Registry entry should be something like "Tomorrow Regular (TrueType)"
        $valueName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name) + " (TrueType)"

        # Check if already registered
        $existing = Get-ItemProperty -Path $fontRegPath -Name $valueName -ErrorAction SilentlyContinue

        if (-not $existing) {
            Write-Host "  ✔️ ($numRegister) Registering font: $valueName = $($file.Name)"
            New-ItemProperty -Path $fontRegPath -Name $valueName -Value $file.Name -PropertyType String -Force | Out-Null
            $numRegister++
        } else {
            $numDupe++
            Write-Host "  ⚠️  Already registered ($numDupe) $valueName"
        }
    }
    Write-Host "`n✅ All fonts processed." -ForegroundColor Cyan
    Write-Host "Done. Reboot or log off/on to see changes."
}



function Install-FontsFromZips {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Path to folder containing ZIP files.")]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$SourceFolder
    )

    if (-not (Test-IsAdmin)) {
        Write-Warning "❌ You must run this script as Administrator."
        return
    }


    $tempDir = Join-Path -Path $env:TEMP -ChildPath "ExtractedFonts"
    $fontsDir = "$env:SystemRoot\Fonts"

    # Create temp directory
    if (-not (Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory | Out-Null
    }

    # Get ZIP files
    $zipFiles = Get-ChildItem -Path $SourceFolder -Filter *.zip

    foreach ($zip in $zipFiles) {
        $zipPath = $zip.FullName
        $extractTo = Join-Path -Path $tempDir -ChildPath ([IO.Path]::GetFileNameWithoutExtension($zip.Name))

        # Extract ZIP
        Expand-Archive -Path $zipPath -DestinationPath $extractTo -Force

        # Find font files (.ttf, .otf)
        $fontFiles = Get-ChildItem -Path $extractTo -Include *.ttf, *.otf -Recurse -ErrorAction SilentlyContinue

        foreach ($font in $fontFiles) {
            $targetPath = Join-Path -Path $fontsDir -ChildPath $font.Name

            try {
                # Copy font to Fonts directory
                if ($PSCmdlet.ShouldProcess($targetPath, "Copy font")) {
                    Copy-Item -Path $font.FullName -Destination $targetPath -Force
                }

                # Optional: register the font (Windows 7-10 compatibility)
                $addFont = Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public class FontInstaller {
    [DllImport("gdi32.dll")]
    public static extern int AddFontResource(string lpFileName);
}
"@ -Passthru

                [FontInstaller]::AddFontResource($targetPath) | Out-Null
                Write-Host "Installed: $($font.Name)" -ForegroundColor Green
            } catch {
                Write-Warning "❌ Failed to install $($font.Name): $_"
            }
        }
    }

    Write-Host "`n✅ All fonts processed." -ForegroundColor Cyan
    Register-NewFonts
}
