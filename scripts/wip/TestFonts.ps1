

function Get-InstalledFontsListFromRegistry {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateSet('All', 'Machine', 'User')]
        [string]$Scope = 'All',
        [Parameter(Mandatory = $false, HelpMessage = "Only show monospaced fonts")]
        [switch]$MonospaceOnly
    )
    try {
        $regPaths = switch ($Scope) {
            'All' { @('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts', 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts') }
            'Machine' { @('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts') }
            'User' { @('HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts') }
        }
        $FontsNames = foreach ($path in $regPaths) {
            $props = Get-ItemProperty -Path "$path" -ErrorAction Ignore
            if ($props -ne $Null) {
                Get-Member -InputObject $props -MemberType NoteProperty | ForEach-Object {
                    # Strip style names for clean family
                    $n = $_.Name -replace '\s*\(.*?\)\s*$', ''
                    $n
                }
            }
        }
        $FontsNamesOrdered = $FontsNames | select -Unique | sort

        $FontsNamesOrdered
    } catch {
        Show-ExceptionDetails $_ -ShowStack
    }
}


function Get-FontFamilyNames {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    if ($PSVersionTable.PSEdition -eq 'Core') {
        # PowerShell Core/7+: Get-CimInstance replaces Get-WmiObject
        # But Win32_FontInfoAction is NOT reliable on all Windows builds
        # Use registry as fallback
        $regPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
            'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
        )
        $fontNames = foreach ($reg in $regPaths) {
            try {
                Get-ItemProperty -Path $reg |
                  Get-Member -MemberType NoteProperty |
                  ForEach-Object { $_.Name -replace '\s*\(.*?\)\s*$', '' }
            } catch {}
        }
        $fontNames | Sort-Object | Get-Unique
    }
    else {
        # Windows PowerShell 5.x
        if (Get-Command Get-WmiObject -ErrorAction SilentlyContinue) {
            try {
                Get-WmiObject -Class Win32_FontInfoAction |
                    Select-Object -ExpandProperty Caption |
                    Sort-Object | Get-Unique
            } catch {
                # fallback to registry if needed
                $regPaths = @(
                    'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
                    'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
                )
                $fontNames = foreach ($reg in $regPaths) {
                    Get-ItemProperty -Path $reg |
                      Get-Member -MemberType NoteProperty |
                      ForEach-Object { $_.Name -replace '\s*\(.*?\)\s*$', '' }
                }
                $fontNames | Sort-Object | Get-Unique
            }
        } else {
            Write-Error "Get-WmiObject is not available."
        }
    }
}


function Show-InstalledFontsList {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Only show monospaced fonts")]
        [switch]$MonospaceOnly
    )


    Add-Type -AssemblyName System.Drawing
    $FontsNames = [System.Collections.Generic.List[string]]::new()
    [System.Drawing.Text.InstalledFontCollection]::new().Families | ForEach-Object {
        $fontName = "$($_.Name)"
        $FontsNames.Add("$fontName")
    }

    $FontsNamesOrdered = $FontsNames | select -Unique | sort

    $FontsNamesOrdered
}


function Get-InstalledFonts {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Only show monospaced fonts")]
        [switch]$MonospaceOnly
    )

    Add-Type -AssemblyName System.Drawing

    $col = New-Object System.Drawing.Text.InstalledFontCollection
    $bmp = New-Object System.Drawing.Bitmap 1, 1
    $g = [System.Drawing.Graphics]::FromImage($bmp)

    $probeTextNarrow = 'iiiiii'
    $probeTextWide = 'WWWWWW'

    foreach ($fam in $col.Families) {
        # Try a sane style we can instantiate
        $style = if ($fam.IsStyleAvailable([System.Drawing.FontStyle]::Regular)) {
            [System.Drawing.FontStyle]::Regular
        } elseif ($fam.IsStyleAvailable([System.Drawing.FontStyle]::Normal)) {
            [System.Drawing.FontStyle]::Normal
        } elseif ($fam.IsStyleAvailable([System.Drawing.FontStyle]::Bold)) {
            [System.Drawing.FontStyle]::Bold
        } else {
            $null
        }
        if (-not $style) { continue }

        try {
            $font = New-Object System.Drawing.Font ($fam, 14, $style, [System.Drawing.GraphicsUnit]::Pixel)
        } catch { continue }

        # Monospace heuristic: narrow and wide strings measure the same advance
        $wN = [math]::Round(($g.MeasureString($probeTextNarrow, $font)).Width, 2)
        $wW = [math]::Round(($g.MeasureString($probeTextWide, $font)).Width, 2)
        $isMono = ($wN -eq $wW)

        if ($MonospaceOnly -and -not $isMono) { continue }

        # Styles available
        $styles = @()
        foreach ($s in [Enum]::GetValues([System.Drawing.FontStyle])) {
            if ($fam.IsStyleAvailable($s)) { $styles += $s }
        }

        [pscustomobject]@{
            FamilyName = $fam.Name # <- Use this in Windows Terminal: "font": { "face": "<FamilyName>" }
            IsMonospaced = $isMono
            Styles = ($styles -join ', ')
        }
    }

    $g.Dispose(); $bmp.Dispose()
}


function Show-FontSampler {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Only show monospaced fonts")]
        [switch]$MonospaceOnly,

        [Parameter(Mandatory = $false, HelpMessage = "Initial sample text")]
        [string]$Sample = 'The quick brown fox jumps over 0123456789 ~!@#$%^&*() [] {} <> | \ / "''  —  iIl1 O0 WW',

        [Parameter(Mandatory = $false, HelpMessage = "Initial size")]
        [int]$Size = 14
    )

    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Drawing

    # Reuse detector from A
    $fonts = Get-InstalledFonts @PSBoundParameters |
    Sort-Object FamilyName

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Font Sampler" Width="1200" Height="700" Background="#111111"
        WindowStartupLocation="CenterScreen">
  <Grid Margin="10">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="320"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <StackPanel Grid.Column="0" Margin="0,0,10,0">
      <TextBox x:Name="SearchBox" Margin="0,0,0,8" Height="28" Padding="6"
               Text="" PlaceholderText="Filter..." />
      <ListBox x:Name="FontList" Height="Auto" Background="#1a1a1a" Foreground="#dddddd"
               BorderBrush="#333333" BorderThickness="1"
               ScrollViewer.CanContentScroll="True"/>
    </StackPanel>

    <StackPanel Grid.Column="1">
      <DockPanel>
        <TextBox x:Name="FamilyName" IsReadOnly="True" Margin="0,0,10,8" Height="28" Padding="6" Width="420"
                 ToolTip="Windows Terminal: profiles.defaults.font.face"/>
        <Button x:Name="CopyBtn" Content="Copy name" Width="110" Height="28" Margin="0,0,10,8"/>
        <TextBlock Text="Size:" VerticalAlignment="Center" Margin="0,0,6,8" Foreground="#dddddd"/>
        <Slider x:Name="SizeSlider" Minimum="8" Maximum="28" Value="{x:Static System:Double.NaN}"
                Width="180" Margin="0,0,10,8"/>
        <TextBlock x:Name="SizeLabel" Foreground="#dddddd" VerticalAlignment="Center" Margin="0,0,0,8"/>
      </DockPanel>

      <TextBox x:Name="SampleBox" TextWrapping="Wrap" AcceptsReturn="True" Height="Auto" MinHeight="500"
               Background="#0f0f0f" Foreground="#eaeaea" BorderBrush="#333333" BorderThickness="1"
               Padding="10" />
    </StackPanel>
  </Grid>
</Window>
"@

    # Add xmlns for Slider binding label
    $xaml = $xaml -replace 'Window xmlns=', 'Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:System="clr-namespace:System;assembly=mscorlib" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" '

    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $FontList = $window.FindName('FontList')
    $SearchBox = $window.FindName('SearchBox')
    $SampleBox = $window.FindName('SampleBox')
    $FamilyBox = $window.FindName('FamilyName')
    $CopyBtn = $window.FindName('CopyBtn')
    $SizeSlider = $window.FindName('SizeSlider')
    $SizeLabel = $window.FindName('SizeLabel')

    $SampleBox.Text = $Sample
    $SizeSlider.Value = $Size
    $SizeLabel.Text = " $($SizeSlider.Value) pt"

    $items = New-Object System.Collections.ObjectModel.ObservableCollection[object]
    $fonts | ForEach-Object {
        $items.Add($_) | Out-Null
    }
    $FontList.ItemsSource = $items
    $FontList.DisplayMemberPath = 'FamilyName'

    $applyFont = {
        $sel = $FontList.SelectedItem
        if ($null -eq $sel) { return }
        $FamilyBox.Text = $sel.FamilyName
        $SampleBox.FontFamily = New-Object System.Windows.Media.FontFamily ($sel.FamilyName)
        $SampleBox.FontSize = $SizeSlider.Value
    }

    $FontList.Add_SelectionChanged({ & $applyFont })
    $SizeSlider.Add_ValueChanged({
            $SizeLabel.Text = " $([int]$SizeSlider.Value) pt"
            & $applyFont
        })

    $SearchBox.Add_TextChanged({
            $q = $SearchBox.Text
            $FontList.ItemsSource = $null
            if ([string]::IsNullOrWhiteSpace($q)) {
                $FontList.ItemsSource = $items
            } else {
                $filtered = New-Object System.Collections.ObjectModel.ObservableCollection[object]
                foreach ($f in $items) {
                    if ($f.FamilyName -like "*$q*") { $filtered.Add($f) | Out-Null }
                }
                $FontList.ItemsSource = $filtered
            }
            if ($FontList.Items.Count -gt 0) { $FontList.SelectedIndex = 0 }
        })

    $CopyBtn.Add_Click({
            if ($FamilyBox.Text) { Set-Clipboard -Value $FamilyBox.Text }
        })

    if ($FontList.Items.Count -gt 0) { $FontList.SelectedIndex = 0 }
    $window.ShowDialog() | Out-Null
}
