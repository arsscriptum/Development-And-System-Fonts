

function Invoke-ExtractZipFiles {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({
                if (-not ($_ | Test-Path)) {
                    throw "File or folder does not exist"
                }
                if (-not ($_ | Test-Path -PathType Container)) {
                    throw "The Path argument must be a Directory. Files paths are not allowed."
                }
                return $true
            })]
        [string]$SourcePath,
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationPath,
        [Parameter(Mandatory = $false)]
        [switch]$ShowExtractedFilenames

    )

    # Ensure destination folder exists
    if (-not (Test-Path -Path $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath | Out-Null
    }

    # Get all ZIP files from source path
    $zipFiles = Get-ChildItem -Path $SourcePath -Filter *.zip

    foreach ($zip in $zipFiles) {
        Write-Host "Extracting: $($zip.FullName)"
        try {
            if ($ShowExtractedFilenames) {
                Expand-Archive -Path "$($zip.FullName)" -DestinationPath "$DestinationPath" -Force -Verbose -ErrorAction Stop -Verbose
            } else {
                Expand-Archive -Path "$($zip.FullName)" -DestinationPath "$DestinationPath" -Force -Verbose -ErrorAction Stop
            }

        }
        catch {
            Write-Warning "Failed to extract $($zip.FullName): $_"
        }
    }

    Write-Host "SUCCESS ! All ZIP files have been extracted to $DestinationPath" -f DarkGreen
}

function Invoke-CleanAndMoveTTFFiles {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({
                if (-not ($_ | Test-Path)) {
                    throw "File or folder does not exist"
                }
                if (-not ($_ | Test-Path -PathType Container)) {
                    throw "The Path argument must be a Directory. Files paths are not allowed."
                }
                return $true
            })]
        [string]$TargetPath
    )


    # Ensure target path exists
    if (-not (Test-Path -Path $TargetPath)) {
        Write-Error "Target path does not exist: $TargetPath"
        return
    }

    # Get all files recursively
    $allFiles = Get-ChildItem -Path $TargetPath -File -Recurse

    foreach ($file in $allFiles) {
        if ($file.Extension -ne ".ttf") {
            # Delete non-TTF files
            try {
                Remove-Item -Path $file.FullName -Force
                Write-Host "Deleted: $($file.FullName)"
            }
            catch {
                Write-Warning "Failed to delete $($file.FullName): $_"
            }
        }
        else {
            # Move TTF files to root target folder if not already there
            if ($file.DirectoryName -ne $TargetPath) {
                $destination = Join-Path $TargetPath $file.Name
                try {
                    Move-Item -Path $file.FullName -Destination $destination -Force
                    Write-Host "Moved: $($file.FullName) -> $destination"
                }
                catch {
                    Write-Warning "Failed to move $($file.FullName): $_"
                }
            }
        }
    }

    Write-Host "Cleanup complete. All .ttf files are now in $TargetPath"
}

function Test-InvokeCleanAndMoveTTFFiles {
    [CmdletBinding(SupportsShouldProcess)]
    param()


    [string]$SourcePath = "C:\DATA\Development-And-System-Fonts\packages\daFonts.com"
    [string]$DestinationPath = "C:\DATA\Development-And-System-Fonts\extracted\dafonts"
    Write-Host "`n"
    Write-Host "=========================================" -f DarkYellow
    Write-Host "       EXTRACTING DAFONTS FONTS          " -f DarkRed
    Write-Host "=========================================" -f DarkYellow
    Write-Host "`n"
    Write-Host "Extracting fonts in $DestinationPath`n" -f DarkCyan

    New-Item -Path "$DestinationPath" -ItemType Directory -Force -EA Ignore | Out-Null


    Invoke-ExtractZipFiles $SourcePath $DestinationPath
}

function Test-InvokeCleanAndMoveTTFFiles {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    [string]$DestinationPath = "C:\DATA\Development-And-System-Fonts\extracted\dafonts"

    Invoke-CleanAndMoveTTFFiles $DestinationPath
}

function Remove-EmptySubfolders {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({
                if (-not ($_ | Test-Path)) {
                    throw "File or folder does not exist"
                }
                if (-not ($_ | Test-Path -PathType Container)) {
                    throw "The Path argument must be a Directory. Files paths are not allowed."
                }
                return $true
            })]
        [string]$TargetPath
    )

    # Ensure target path exists
    if (-not (Test-Path -Path $TargetPath)) {
        Write-Error "Target path does not exist: $TargetPath"
        return
    }

    # Get all subfolders recursively (deepest first)
    $subfolders = Get-ChildItem -Path $TargetPath -Directory -Recurse | Sort-Object FullName -Descending

    foreach ($folder in $subfolders) {
        # Check if folder is empty
        if (-not (Get-ChildItem -Path $folder.FullName)) {
            try {
                Remove-Item -Path $folder.FullName -Force
                Write-Host "Deleted empty folder: $($folder.FullName)"
            }
            catch {
                Write-Warning "Failed to delete $($folder.FullName): $_"
            }
        }
    }

    Write-Host "Cleanup complete. All empty subfolders have been removed from $TargetPath"
}
