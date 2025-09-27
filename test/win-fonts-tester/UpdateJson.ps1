

function Update-AllFontsJson {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Path to allfonts.json")]
        [string]$Path = ".\allfonts.json"
    )

    Write-Host "Loading fonts from $Path ..." -ForegroundColor Cyan
    $allfonts = Get-Content $Path -Raw | ConvertFrom-Json

    $total = $allfonts.Count
    Write-Host "Found $total fonts." -ForegroundColor Cyan

    $idx = 0
    foreach ($font in $allfonts) {
        $idx++
        $fontId = $font.FontId

        Write-Host "[$idx/$total] FontId: " -NoNewline -ForegroundColor Gray
        Write-Host "'$fontId'" -NoNewline -ForegroundColor Yellow

        if ([string]::IsNullOrWhiteSpace($fontId)) {
            Write-Host " ... Skipping (empty FontId)" -ForegroundColor DarkGray
            Add-Member -InputObject $font -MemberType NoteProperty -Name "ParentCategory" -Value  "undefined" -Force
            Add-Member -InputObject $font -MemberType NoteProperty -Name "SubCategory" -Value  "undefined" -Force
            continue
        }

        try {
            Write-Host " ... Querying DaFont ..." -NoNewline -ForegroundColor DarkGray
            $result = Invoke-DaFontsSearch $fontId | Select-Object -First 1


            if ($result) {
                
               Add-Member -InputObject $font -MemberType NoteProperty -Name "ParentCategory" -Value  $result.ParentCategory -Force
                Add-Member -InputObject $font -MemberType NoteProperty -Name "SubCategory" -Value  $result.SubCategory -Force
                Write-Host " [OK] " -NoNewline -ForegroundColor Green
                Write-Host "$($result.ParentCategory)/$($result.SubCategory)" -ForegroundColor Magenta
            } else {
                 Add-Member -InputObject $font -MemberType NoteProperty -Name "ParentCategory" -Value  "undefined" -Force
                Add-Member -InputObject $font -MemberType NoteProperty -Name "SubCategory" -Value  "undefined" -Force
                Write-Host " [NO CATEGORY]" -ForegroundColor Red
            }
        } catch {
           Add-Member -InputObject $font -MemberType NoteProperty -Name "ParentCategory" -Value  "undefined" -Force
                Add-Member -InputObject $font -MemberType NoteProperty -Name "SubCategory" -Value  "undefined" -Force
            Write-Host " [ERROR: $($_.Exception.Message)]" -ForegroundColor Red
        }

        # Save progress every 10 fonts, or at the end
        if ($idx % 10 -eq 0 -or $idx -eq $total) {
            Write-Host "Saving progress to $Path ..." -ForegroundColor DarkCyan
            $allfonts | ConvertTo-Json -Depth 5 | Set-Content $Path -Encoding UTF8
        }
    }
    Write-Host "Update complete. All fonts processed." -ForegroundColor Cyan
}

function Update-BitmapCategoriesInFontsJson {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path = ".\allfonts.json"
    )

    Write-Host "Loading fonts from $Path ..." -ForegroundColor Cyan
    $allFonts = Get-Content $Path -Raw | ConvertFrom-Json

    $total = $allFonts.Count
    $changed = 0

    for ($i = 0; $i -lt $total; $i++) {
        $font = $allFonts[$i]
        $message = "[$($i+1)/$total] FontId: $($font.FontId)"
        Write-Progress -Activity "Updating Bitmap Categories" -Status $message -PercentComplete (($i+1)*100/$total)

        if ($font.ParentCategory -and $font.ParentCategory -like "Bitmap*") {
            Write-Host "$message ... Updated Bitmap category" -ForegroundColor Yellow
            $font.ParentCategory = "Bitmap"
            $font.SubCategory = "Pixel"
            $changed++
        }
    }

    Write-Host "$changed fonts updated. Saving to $Path..." -ForegroundColor Green
    $allFonts | ConvertTo-Json -Depth 5 | Set-Content $Path -Encoding UTF8
    Write-Host "Done." -ForegroundColor Cyan
}
