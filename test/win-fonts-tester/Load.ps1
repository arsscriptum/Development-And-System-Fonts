#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   Load.ps1                                                                     ║
#║   Load XAML files                                                              ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <codegp@icloud.com>                                         ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝

[void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')
[void][System.Reflection.Assembly]::LoadWithPartialName('PresentationCore')
[void][System.Reflection.Assembly]::LoadWithPartialName('WindowsBase')
[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
[void][System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')
[void][System.Reflection.Assembly]::LoadWithPartialName('System')
[void][System.Reflection.Assembly]::LoadWithPartialName('System.Xml')
[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows')

[System.Windows.Window]$Script:Window=$Null

$tmpJsonFonts = Get-Content -Path "$PSScriptRoot\allfonts.json" -Raw | ConvertFrom-Json
$Script:allfontsJson = set-variable -Name "allfontsJson" -Value $first -Option AllScope -Force -Scope Script -PassThru | Select -ExpandProperty Value

function Write-RichTextLog {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = 'Text to log')]
        [string]$Object,
        [Parameter(Mandatory = $false, HelpMessage = 'Foreground color')]
        [Alias('f')]
        [string]$ForegroundColor = 'Black',
        [Alias('b')]
        [Parameter(Mandatory = $false, HelpMessage = 'Background color')]
        [string]$BackgroundColor = 'White',
        [Parameter(Mandatory = $false, HelpMessage = 'No newline at the end')]
        [switch]$NoNewline,

        # Font weight flags
        [Parameter(Mandatory = $false)]
        [switch]$Thin,
        [Parameter(Mandatory = $false)]
        [switch]$ExtraLight,
        [Parameter(Mandatory = $false)]
        [switch]$Light,
        [Parameter(Mandatory = $false)]
        [switch]$Normal,
        [Parameter(Mandatory = $false)]
        [switch]$Medium,
        [Parameter(Mandatory = $false)]
        [switch]$SemiBold,
        [Parameter(Mandatory = $false)]
        [switch]$DemiBold,
        [Parameter(Mandatory = $false)]
        [switch]$Bold,
        [Parameter(Mandatory = $false)]
        [switch]$ExtraBold,
        [Parameter(Mandatory = $false)]
        [switch]$UltraBold,
        [Parameter(Mandatory = $false)]
        [switch]$Black,
        [Parameter(Mandatory = $false)]
        [switch]$ExtraBlack,
        [Parameter(Mandatory = $false)]
        [switch]$UltraBlack,
        [Parameter(Mandatory = $false)]
        [switch]$Heavy,

        # Direct by-name (overrides flags)
        [Parameter(Mandatory = $false)]
        [string]$FontWeight,

        # Decorations
        [Parameter(Mandatory = $false)]
        [switch]$Underline,
        [Parameter(Mandatory = $false)]
        [switch]$Strike,
        [Parameter(Mandatory = $false)]
        [switch]$Overline
    )

    if (-not $Script:txtLogs) { throw "RichTextBox parameter is required" }

    $run = New-Object System.Windows.Documents.Run $Object

    # Determine FontWeight (direct wins, else first flag set, else default Normal)
    $weightSet = $null
    if ($FontWeight) {
        $weightSet = $FontWeight
    } elseif ($UltraBlack) { $weightSet = 'UltraBlack'
    } elseif ($ExtraBlack) { $weightSet = 'ExtraBlack'
    } elseif ($Black)      { $weightSet = 'Black'
    } elseif ($Heavy)      { $weightSet = 'Heavy'
    } elseif ($UltraBold)  { $weightSet = 'UltraBold'
    } elseif ($ExtraBold)  { $weightSet = 'ExtraBold'
    } elseif ($Bold)       { $weightSet = 'Bold'
    } elseif ($DemiBold)   { $weightSet = 'DemiBold'
    } elseif ($SemiBold)   { $weightSet = 'SemiBold'
    } elseif ($Medium)     { $weightSet = 'Medium'
    } elseif ($Normal)     { $weightSet = 'Normal'
    } elseif ($Light)      { $weightSet = 'Light'
    } elseif ($ExtraLight) { $weightSet = 'ExtraLight'
    } elseif ($Thin)       { $weightSet = 'Thin'
    } else { $weightSet = 'Normal' }
    $run.FontWeight = [System.Windows.FontWeights]::$weightSet

    # Decorations (combine)
    $decs = @()
    if ($Underline) { $decs += [System.Windows.TextDecorations]::Underline }
    if ($Strike)    { $decs += [System.Windows.TextDecorations]::Strikethrough }
    if ($Overline)  { $decs += [System.Windows.TextDecorations]::OverLine }
    if ($decs.Count) {
        $coll = New-Object System.Windows.TextDecorationCollection
        $decs | ForEach-Object { $coll.Add($_) }
        $run.TextDecorations = $coll
    }

    # Colors
    if ($ForegroundColor) {
        $run.Foreground = [System.Windows.Media.Brushes]::${ForegroundColor}
    }
    if ($BackgroundColor) {
        $run.Background = [System.Windows.Media.Brushes]::${BackgroundColor}
    }

    # Newline
    $toAppend = $run
    if (-not $NoNewline) {
        $toAppend = New-Object System.Windows.Documents.Span
        $toAppend.Inlines.Add($run) | Out-Null
        $toAppend.Inlines.Add((New-Object System.Windows.Documents.LineBreak)) | Out-Null
    }

    # Add to the end of document
    $paragraph = $Script:txtLogs.Document.Blocks | Where-Object { $_ -is [System.Windows.Documents.Paragraph] } | Select-Object -First 1
    if (-not $paragraph) {
        $paragraph = New-Object System.Windows.Documents.Paragraph
        $Script:txtLogs.Document.Blocks.Add($paragraph)
    }
    $paragraph.Inlines.Add($toAppend) | Out-Null

    $Script:txtLogs.ScrollToEnd()
}

function Import-AvailableFontsArrayFromJson {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Position = 0, Mandatory = $false)]
        [string]$Path
    )

    $JsonPath = $Path
    if([string]::IsNullOrEmpty($Path)){
        Write-Verbose "Path not specified, using default"
        $JsonPath = (Resolve-Path -Path "$PSScriptRoot\allfonts.json").Path
    }

    Write-Verbose "Loading fonts from json `"$JsonPath`""
    $FontsRaw = Get-Content -Path "$JsonPath" -Raw | ConvertFrom-Json
    $FontsRawCount = $FontsRaw.Count
    Write-Verbose "Raw fonts array has $FontsRawCount items"
    return $FontsRaw
}



function Invoke-OnCloseClicked   { 
    [CmdletBinding(SupportsShouldProcess)]
    param ()
}
function Invoke-OnClearClicked   { 
    [CmdletBinding(SupportsShouldProcess)]
    param ()
    $Script:txtLogs.Document.Blocks.Clear() 
}

function Test-RichTextLogTheme {
    [CmdletBinding(SupportsShouldProcess)]
    param ()
    # Log level palette
    $levels = @(
        @{
            Name = 'Verbose'
            Fg = 'SlateGray'
            Bg = 'White'
            Font = @{}
            Note = 'Low-priority diagnostic.'
        },
        @{
            Name = 'Info'
            Fg = 'Black'
            Bg = 'WhiteSmoke'
            Font = @{}
            Note = 'Normal info.'
        },
        @{
            Name = 'Important'
            Fg = 'RoyalBlue'
            Bg = 'AliceBlue'
            Font = @{ Bold = $true }
            Note = 'Important notification.'
        },
        @{
            Name = 'Warning'
            Fg = 'DarkOrange'
            Bg = 'LemonChiffon'
            Font = @{ Bold = $true; Underline = $true }
            Note = 'Caution: something needs attention.'
        },
        @{
            Name = 'Error'
            Fg = 'Red'
            Bg = 'MistyRose'
            Font = @{ UltraBold = $true; Strike = $true }
            Note = 'Error condition!'
        }
    )

    foreach ($level in $levels) {
        $args = @{
            ForegroundColor = $level.Fg
            BackgroundColor = $level.Bg
        }
        foreach ($k in $level.Font.Keys) { $args[$k] = $level.Font[$k] }
        Write-RichTextLog "$($level.Name): $($level.Note)" @args
    }

    # FontWeight showcase
    $weights = @(
        @{ Label = 'Thin';        Switch = @{ Thin = $true } },
        @{ Label = 'Normal';      Switch = @{} },
        @{ Label = 'Bold';        Switch = @{ Bold = $true } },
        @{ Label = 'ExtraBold';   Switch = @{ ExtraBold = $true } },
        @{ Label = 'UltraBold';   Switch = @{ UltraBold = $true } },
        @{ Label = 'Black';       Switch = @{ Black = $true } },
        @{ Label = 'ExtraBlack';  Switch = @{ ExtraBlack = $true } },
        @{ Label = 'UltraBlack';  Switch = @{ UltraBlack = $true } },
        @{ Label = 'Heavy';       Switch = @{ Heavy = $true } }
    )
    foreach ($w in $weights) {
        $args = @{
            ForegroundColor = 'Black'
            BackgroundColor = 'White'
        }
        foreach ($k in $w.Switch.Keys) { $args[$k] = $w.Switch[$k] }
        Write-RichTextLog "FontWeight: $($w.Label)" @args
    }

    # TextDecoration showcase
    Write-RichTextLog "Underline sample" -ForegroundColor 'Black'    -BackgroundColor 'WhiteSmoke' -Underline
    Write-RichTextLog "Strike sample"    -ForegroundColor 'DarkGray' -BackgroundColor 'White'      -Strike
    Write-RichTextLog "Overline sample"  -ForegroundColor 'RoyalBlue'-BackgroundColor 'White'      -Overline
    Write-RichTextLog "Underline+Strike" -ForegroundColor 'Red'      -BackgroundColor 'White'      -Underline -Strike
}


function Invoke-OnPlayClicked {
    $in  = $Script:textPathIn.Text
    $out = $Script:txtPathOut.Text
    $in_exists  = Test-Path $in
    Write-RichTextLog "`"$in`" in_exists $in_exists" -ForegroundColor Magenta -Bold
    $out_exists = Test-Path $out
    Write-RichTextLog "`"$out`" out_exists $out_exists" -ForegroundColor Blue -Bold
    if ($in_exists -and $out_exists) {
        Convert-PngsToIco $in $out
    }
}



function Invoke-OnSelectedFontChanged { 
    [CmdletBinding(SupportsShouldProcess)]
    param ()
}


function Invoke-OnBrowseOutClicked { 
    [CmdletBinding(SupportsShouldProcess)]
    param ()
    $dialog = [System.Windows.Forms.OpenFileDialog]::new()
    $dialog.Filter = "json files (*.json)|*.json|All files (*.*)|*.*"
    $dialog.Title = "SELECT JSON FILE CONTAINING FONT NAMES"
    $result = $dialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $Script:txtPathOut.Text = $dialog.FileName
    }
}

function Initialize-FontCategoryCombo {
    param(
        [Parameter(Mandatory)]
        [string]$JsonPath = ".\allfonts.json",
        [Parameter(Mandatory)]
        $ComboBoxControl # Pass in the actual WPF ComboBox object
    )

    # Load font list with categories
    $allFonts = Get-Content $JsonPath -Raw | ConvertFrom-Json

    # Extract all unique "Parent/SubCategory" pairs (skip missing)
    $categoryList = $allFonts |
        Where-Object { $_.ParentCategory -and $_.SubCategory } |
        ForEach-Object { "$($_.ParentCategory)/$($_.SubCategory)" } |
        Sort-Object -Unique

    # Optionally, sort by Parent then SubCategory
    # $categoryList = $categoryList | Sort-Object { $_.Split('/')[0] }, { $_.Split('/')[1] }

    # Set ComboBox ItemsSource
    $ComboBoxControl.ItemsSource = $categoryList
    $ComboBoxControl.SelectedIndex = 0 # Optional: select first by default

    Write-Host "Initialized category combo with $($categoryList.Count) values." -ForegroundColor Cyan
}

function Initialize-FontComboForCategory {
    param(
        [Parameter(Mandatory = $true)] [object]$Form,
        [Parameter(Mandatory = $true)] [object[]]$AllFonts,
        [Parameter(Mandatory = $true)] [string]$SelectedCategory
    )
    # Parse Parent / Sub
    $parts = $SelectedCategory -split ' / ', 2
    $parent = $parts[0]
    $sub = if ($parts.Count -gt 1) { $parts[1] } else { "" }

    # Filter
    $filtered = $AllFonts | Where-Object {
        $_.ParentCategory -eq $parent -and $_.SubCategory -eq $sub
    }

    # Clear and populate
    $combo = $Form.FindName("comboSelectedFont")
    $combo.Items.Clear()
    foreach ($f in $filtered) {
        [void]$combo.Items.Add($f.DisplayName)
    }
    # Optional: select first
    if ($combo.Items.Count -gt 0) { $combo.SelectedIndex = 0 }
}


function Initialize-ScriptRunner {
    [CmdletBinding(SupportsShouldProcess)]
    param ()

    [bool]$UseFormNameAsNamespace = $True
    #[string]$XAMLPath = "$PSScriptRoot\main.xaml"
    [string]$XAMLPath = Join-Path "$($PWD.Path)" "main.xaml"

    #Build the GUI
    [xml]$xaml = Get-Content $XAMLPath 
     
    $reader=(New-Object System.Xml.XmlNodeReader $xaml)
    [System.Windows.Window]$Script:Window=[Windows.Markup.XamlReader]::Load( $reader )
    $WndType = $Window.GetType().Fullname 
    Write-Host "WndType => $WndType" -f DarkRed

    #AutoFind all controls 
    Write-Host "Variables"
    $xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")  | ForEach-Object { 
        $VarName =  "$($_.Name)"
        $VarValue = $Window.FindName($VarName)
        $VarValueTypeName = $VarValue.GetType().Fullname
        Write-Host "VarName $VarName VarValueTypeName $VarValueTypeName" -ForegroundColor Cyan
        $v = New-Variable  -Name "$VarName" -Value  -Option AllScope -Visibility Public -Force -PassThru -Scope Global
        $n=($($v.Value) -as [string]).Split(':')[0]
        $log ="[$n]`$Script:$($_.Name)"
        Write-Host "  $log" -f DarkCyan
    }

    # Example handlers

# Assign handlers
$Script:button_close.Add_Click(   { Invoke-OnCloseClicked } )
$Script:button_clear.Add_Click(   { Invoke-OnClearClicked } )
$Script:button_play.Add_Click(    { Invoke-OnPlayClicked } )
$Script:btnBrowseIn.Add_Click(    { Invoke-OnBrowseInClicked } )
$Script:btnBrowseOut.Add_Click(   { Invoke-OnBrowseOutClicked } )
$Script:comboCategory.Add_SelectionChanged({
    $cat = $comboCategory.SelectedItem.ToString()
    Initialize-FontComboForCategory -Form $window -AllFonts $Script:allfontsJson -SelectedCategory $cat
})


}


Initialize-ScriptRunner
Initialize-FontCategoryCombo -JsonPath "$PSScriptRoot\allfonts.json" -ComboBoxControl $Script:comboFontCategory

Test-RichTextLogTheme
$Window.ShowDialog() | Out-Null

$v = Get-Variable  -Name "txtLogs"


