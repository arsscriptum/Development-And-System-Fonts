#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   SearchFonts.ps1                                                              ║
#║   Search and list installed fonts. Test them by render in tmp web page         ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <codegp@icloud.com>                                         ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝


function Get-InstalledFontsListFromRegistry {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    try {
        $FontsNamesToFiles = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
        $FontsRealNamesPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontsRealNames'

        $props = Get-ItemProperty -Path $FontsNamesToFiles -ErrorAction Ignore
        $propsRealNames = Get-ItemProperty -Path $FontsRealNamesPath -ErrorAction Ignore

        $fontList = @()

        foreach ($fontPrettyName in ($props.PSObject.Properties | Where-Object { $_.Name -ne 'PSPath' })) {
            $fontFile = $props.$($fontPrettyName.Name)
            if ([string]::IsNullOrWhiteSpace($fontFile)) { continue }

            # Try to get the true family name from the secondary registry
            $realName = $null
            if ($propsRealNames.PSObject.Properties.Name -contains $fontFile) {
                $realName = $propsRealNames.$fontFile
            }

            $fontList += [PSCustomObject]@{
                PrettyName   = $fontPrettyName.Name
                FontFile     = $fontFile
                RealFontName = $realName
            }
        }
        return $fontList
    } catch {
        Show-ExceptionDetails $_ -ShowStack
    }
}





function Get-CustomfontsRealNamesList {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    try {
        $fontsRealNamesList = [System.Collections.Generic.List[string]]::new()
         Get-InstalledFontsListFromRegistry | Select -ExpandProperty RealFontName | % {
             $fontsRealNamesList.Add("$_")
         }

        $sortedFonts = $fontsRealNamesList | sort | Select -Unique
        $sortedFonts
    } catch {
        Show-ExceptionDetails $_ -ShowStack
    }
}

function Search-FontByName {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Font name or pattern to search for")]
        [string]$Pattern,
        [Parameter(Mandatory = $false, HelpMessage = "Scope for registry font search")]
        [ValidateSet('All', 'Machine', 'User')]
        [string]$Scope = 'All'
    )
    try {
        $fonts = Get-InstalledFontsListFromRegistry -Scope $Scope
        $fonts | Where-Object { $_ -match [regex]::Escape($Pattern) }
    } catch {
        Show-ExceptionDetails $_ -ShowStack
    }
}


function Export-FontZipMapToJson {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Directory containing font .zip files")]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$Path,
        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Output JSON file path")]
        [string]$OutputJson
    )

    # Recursively get all zip files
    $zipFiles = Get-ChildItem -Path $Path -Filter *.zip -Recurse

    $fontMap = @{}

    foreach ($zip in $zipFiles) {
        # Use the base file name (no extension) as the font name
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($zip.Name)
        # If you want to improve font name detection, extract TTF/OTF and read names here
        $fontMap[$zip.FullName] = $baseName
    }

    # Export as JSON
    $json = $fontMap | ConvertTo-Json -Depth 3
    Set-Content -Path $OutputJson -Value $json -Encoding UTF8
}

function Save-ExportedFontZipMapToJson {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    $fontsDirectory = "C:\Dev\Development-And-System-Fonts\packages\daFonts.com\bmpterm"

    $RootPath = (Resolve-Path -Path "$PSScriptRoot\..").Path
    $jsonPath = Join-Path "$RootPath" "json"
    $jsonFontsPath = Join-Path "$jsonPath" "font_zip_map.json"

    Export-FontZipMapToJson -Path "$fontsDirectory" -OutputJson "$jsonFontsPath"
   
    return $jsonFontsPath
}


function Export-FontPreviewHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Array of sample strings to render with each font")]
        [string[]]$Samples,
        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Array of font family names to preview")]
        [string[]]$Fonts,
        [Parameter(Mandatory = $true, Position = 2, HelpMessage = "Output HTML file path")]
        [string]$OutputHtml
    )

    $html = @"
<!DOCTYPE html>
<html>
<head>
  <meta charset='UTF-8'>
  <title>Font Preview</title>
  <style>
    body { font-family: Arial, sans-serif; background: #181818; color: #eee; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border-bottom: 1px solid #333; padding: 10px 8px; }
    th { background: #232323; }
    .font-name { font-size: 18px; font-weight: bold; color: #aee; }
    .sample { font-size: 22px; }
    tr:hover { background: #242a2e; }
  </style>
</head>
<body>
  <h1>Font Preview</h1>
  <table>
    <tr>
      <th>Font Name</th>
"@
    foreach ($sample in $Samples) {
        $html += "      <th>Sample: <span style='color:#9bffb7'>" + [System.Web.HttpUtility]::HtmlEncode($sample) + "</span></th>`n"
    }
    $html += "    </tr>`n"

    foreach ($font in $Fonts) {
        $html += "    <tr>`n"
        $html += "      <td class='font-name'>" + [System.Web.HttpUtility]::HtmlEncode($font) + "</td>`n"
        foreach ($sample in $Samples) {
            $html += "      <td class='sample' style='font-family:&quot;$font&quot;,monospace,sans-serif;'>" + [System.Web.HttpUtility]::HtmlEncode($sample) + "</td>`n"
        }
        $html += "    </tr>`n"
    }

    $html += @"
  </table>
</body>
</html>
"@

    Set-Content -Path $OutputHtml -Value $html -Encoding UTF8
}

function Test-RenderedFonts {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Font name or pattern to search for")]
        [string]$Pattern,
        [Parameter(Mandatory = $false)]
        [switch]$StartBrave
    )

    $BraveBrowserPath = "C:\Users\gp\AppData\Local\BraveSoftware\Brave-Browser\Application\brave.exe"
    $outPath = "$env:TEMP\font_preview.html"

    Write-Host "🔎 Searching for fonts matching pattern: '$Pattern'..."
    [string[]]$fonts = Search-FontByName $Pattern
    $count = $fonts.Count
    Write-Host "✅ $count fonts matched pattern '$Pattern'."
    if ($count -eq 0) {
        Write-Warning "No fonts matched. Exiting."
        return
    }
    Write-Host "Fonts to be rendered:"
    $fonts | ForEach-Object { Write-Host " - $_" }

    $samples = @(
        "The quick brown fox",
        "0123456789",
        "Sphinx of black quartz, judge my vow."
    )

    Write-Host "📝 Generating preview HTML: $outPath"
    Export-FontPreviewHtml -Samples $samples -Fonts $fonts -OutputHtml $outPath

    if ($StartBrave) {
        if (Test-Path $BraveBrowserPath) {
            Write-Host "🚀 Launching Brave to view preview..."
            Start-Process -FilePath $BraveBrowserPath -ArgumentList $outPath
        } else {
            Write-Warning "Brave not found at $BraveBrowserPath. Open the HTML manually."
        }
    } else {
        Write-Host "Preview HTML created at: $outPath"
    }
}


function Show-FontPreview {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Array of font family names to render")]
        [string[]]$Fonts,
        [Parameter(Mandatory = $false)]
        [switch]$StartBrave
    )

    $BraveBrowserPath = "C:\Users\gp\AppData\Local\BraveSoftware\Brave-Browser\Application\brave.exe"
    $outPath = "$env:TEMP\font_preview.html"

    $count = $Fonts.Count
    Write-Host "✅ $count fonts to be rendered."
    if ($count -eq 0) {
        Write-Warning "No fonts provided. Exiting."
        return
    }
    Write-Host "Fonts to be rendered:"
    $Fonts | ForEach-Object { Write-Host " - $_" }

    $samples = @(
        "The quick brown fox",
        "0123456789",
        "Sphinx of black quartz, judge my vow."
    )

    Write-Host "📝 Generating preview HTML: $outPath"
    Export-FontPreviewHtml -Samples $samples -Fonts $Fonts -OutputHtml $outPath

    if ($StartBrave) {
        if (Test-Path $BraveBrowserPath) {
            Write-Host "🚀 Launching Brave to view preview..."
            Start-Process -FilePath $BraveBrowserPath -ArgumentList $outPath
        } else {
            Write-Warning "Brave not found at $BraveBrowserPath. Open the HTML manually."
        }
    } else {
        Write-Host "Preview HTML created at: $outPath"
    }
}

function Get-FontFamilyFromZip {
    param([Parameter(Mandatory)] [string]$ZipPath)
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $tmp = Join-Path $env:TEMP ("fontscan_" + [guid]::NewGuid())
    New-Item $tmp -ItemType Directory | Out-Null
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $tmp)
        $fontFiles = Get-ChildItem $tmp -Recurse -Include *.ttf,*.otf
        $names = @()
        foreach ($font in $fontFiles) {
            try {
                $fc = New-Object System.Drawing.Text.PrivateFontCollection
                $fc.AddFontFile($font.FullName)
                $fc.Families | ForEach-Object { $names += $_.Name }
            } catch {}
        }
        $names | Sort-Object -Unique
    } catch {
        Write-Warning "Failed: $ZipPath"
        @()
    } finally {
        Remove-Item $tmp -Force -Recurse -ErrorAction SilentlyContinue
    }
}


function Update-FontsRealNamesRegistry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$FontsRegPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
        [Parameter(Mandatory=$false)]
        [string]$FontsRealNamesPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontsRealNames'
    )

    Add-Type -AssemblyName System.Drawing
    $fontsDir = Join-Path $env:WINDIR "Fonts"
    if (-not (Test-Path $FontsRealNamesPath)) {
        New-Item -Path $FontsRealNamesPath -Force | Out-Null
    }
    $items = Get-ItemProperty -Path $FontsRegPath | Get-Member -MemberType NoteProperty
    foreach ($item in $items) {
        $fontFile = (Get-ItemProperty -Path $FontsRegPath).$($item.Name)
        # Some values are just file names, some are relative paths
        $fullFontPath = if ([System.IO.Path]::IsPathRooted($fontFile)) {
            $fontFile
        } else {
            Join-Path $fontsDir $fontFile
        }
        if (-not (Test-Path $fullFontPath)) { continue }
        try {
            $collection = New-Object System.Drawing.Text.PrivateFontCollection
            $collection.AddFontFile($fullFontPath)
            $family = $collection.Families | Select-Object -First 1
            if ($null -ne $family) {
                $realName = $family.Name
                Set-ItemProperty -Path $FontsRealNamesPath -Name $fontFile -Value $realName
                Write-Host "$fontFile : $realName"
            }
        } catch {
            Write-Warning "Failed for $fontFile"
        }
    }
}
