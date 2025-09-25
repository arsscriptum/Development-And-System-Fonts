#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   ListFonts.ps1                                                                ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <codegp@icloud.com>                                         ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝

[System.Collections.ArrayList]$Script:TmpPreviewImagePaths = [System.Collections.ArrayList]::new()
[System.Collections.ArrayList]$Script:ScriptsPreviewFontsList = [System.Collections.ArrayList]::new()
[uint32]$Script:TotalDownloadedFiles = 0
[uint32]$Script:CurrentDownloadedFiles = 0


function Get-ExternalsLibraryPath {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $RootPath = (Resolve-Path -Path "$PSScriptRoot\..").Path
    $LibPath = Join-Path "$RootPath" "lib"
    return $LibPath
}

function Register-HtmlAgilityPack2a {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    begin {
        
        $ExternalsLibraryPath = Get-ExternalsLibraryPath
        $LibPath = "{0}\{1}\HtmlAgilityPack.dll" -f "$ExternalsLibraryPath", "$($PSVersionTable.PSEdition)"
    }
    process {
        try {
            if (-not (Test-Path -Path "$LibPath" -PathType Leaf)) { throw "no such file `"$LibPath`"" }
            if (!("HtmlAgilityPack.HtmlDocument" -as [type])) {
                Write-Verbose "Registering HtmlAgilityPack... "
                add-type -Path "$LibPath"
            } else {
                Write-Verbose "HtmlAgilityPack already registered "
            }
        } catch {
            Show-ExceptionDetails ($_) -ShowStack
        }
    }
}


function Get-IrfaViewPath {
    [CmdletBinding(SupportsShouldProcess, SupportsPaging = $true)]
    param()
    $Path = "C:\Programs\IrfaView\i_view64.exe"
    $Path
}


function Open-PreviewLocalPicture {
    [CmdletBinding(SupportsShouldProcess, SupportsPaging = $true)]
    param(
        [Parameter(Mandatory, HelpMessage = "picture path")]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $IrfaViewPath = Get-IrfaViewPath
    & "$IrfaViewPath" "$Path"
}



function Get-FontCategoryIdFromName {
    [CmdletBinding(SupportsShouldProcess= $true)]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "Symbolic font category name (e.g. General_Various)")]
        [ValidateNotNullOrEmpty()]
        [string]$CategoryName
    )
    # Mapping table
    $CategoryMap = @{
        General_Cartoon = 101
        General_Comic = 102
        General_Groovy = 103
        General_OldSchool = 104
        General_Curly = 105
        General_Western = 106
        General_Eroded = 107
        General_Distorted = 108
        General_Destroy = 109
        General_Horror = 110
        General_FireIce = 111
        General_Decorative = 112
        General_Typewriter = 113
        General_Stencil_Army = 114
        General_Retro = 115
        General_Initials = 116
        General_Grid = 117
        General_Various = 118

        Techno_Square = 301
        Techno_LCD = 302
        Techno_SciFi = 303
        Techno_Various = 304

        Culture_Medieval = 401
        Culture_Modern = 402
        Culture_Celtic = 403
        Culture_Initials = 404
        Culture_Various = 405

        Basic_SansSerif = 501
        Basic_Serif = 502
        Basic_Fixedwidth = 503
        Basic_Various = 504

        Script_Calligraphy = 601
        Script_School = 602
        Script_Handwritten = 603
        Script_Brush = 604
        Script_Trash = 605
        Script_Graffiti = 606
        Script_OldSchool = 607
        Script_Various = 608
    }
    if ($CategoryMap.ContainsKey($CategoryName)) {
        return $CategoryMap[$CategoryName]
    } else {
        Write-Warning "Unknown category name: $CategoryName"
        return $null
    }
}


function Invoke-ListDafontFonts {
    [CmdletBinding(SupportsShouldProcess= $true, SupportsPaging = $true)]
    param(
        [Parameter(Mandatory, HelpMessage = "Font category name (e.g. General_Various)")]
        [ValidateNotNullOrEmpty()]
        [string]$CategoryName,
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 50)]
        [int]$Page = 1,
        [Parameter(Mandatory = $false)]
        [ValidateSet(25, 50, 100, 200)]
        [int]$FontsPerPage = 200,
        [Parameter(Mandatory = $false)]
        [ValidateLength(4, 64)]
        [ValidateNotNullOrEmpty()]
        [string]$Text
    )

    process {
        $CategoryId = Get-FontCategoryIdFromName -CategoryName $CategoryName
        if (-not $CategoryId) {
            throw "Invalid category name: $CategoryName"
        }
        Write-Verbose "Resolved category: $CategoryName -> $CategoryId"

        try {
            $baseUrl = 'https://www.dafont.com/theme.php'
            if (-not ([System.Web.HttpUtility] -as [type])) {
                Add-Type -AssemblyName 'System.Web'
                Write-Verbose "Loaded System.Web for UrlEncode"
            }


            $cat = [System.Web.HttpUtility]::UrlEncode($CategoryId.ToString())
            $page = [System.Web.HttpUtility]::UrlEncode($Page.ToString())
            $fpp = [System.Web.HttpUtility]::UrlEncode($FontsPerPage.ToString())
            $text = [System.Web.HttpUtility]::UrlEncode($Text)

            $Url = "https://www.dafont.com/theme.php?cat={0}&fpp={1}&text={2}" -f $cat, $fpp, $text

            Write-Verbose "Constructed URL: $Url"
            if ([string]::IsNullOrEmpty($ENV:PreviousUrl)) {
                $ENV:PreviousUrl = "https://www.dafont.com/theme.php?cat={0}&fpp={1}&text={2}" -f $cat, $fpp, $text
            }

            $hdrz = @{
                "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8"
                "Accept-Encoding" = "gzip, deflate, br, zstd"
                "Accept-Language" = "en-US,en;q=0.6"
                "Cache-Control" = "no-cache"
                "Pragma" = "no-cache"
                "Referer" = "$ENV:PreviousUrl"
            }


            $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -Headers $hdrz -ErrorAction Stop
            Write-Verbose "StatusCode: $($resp.StatusCode)"
            Write-Verbose "Response received successfully"


            [System.Collections.ArrayList]$List = [System.Collections.ArrayList]::new()
            $HtmlContent = $resp.Content

            [HtmlAgilityPack.HtmlDocument]$HtmlDoc = @{}
            $HtmlDoc.LoadHtml($HtmlContent)

            $result = @()
            # Each font block is in a div.lv1left.dfbg
            foreach ($fontDiv in $HtmlDoc.DocumentNode.SelectNodes("//div[contains(@class,'lv1left') and contains(@class,'dfbg')]")) {
                $nameLink = $fontDiv.SelectSingleNode("./a[1]")
                $fontName = $nameLink.InnerText.Trim()
                $fontPage = $nameLink.GetAttributeValue("href", "")
                $authorLink = $fontDiv.SelectSingleNode(".//a[2]")
                $author = if ($authorLink) { $authorLink.InnerText.Trim() } else { "" }

                # Download link: the next sibling is .dlbox > a.dl
                $dlDiv = $fontDiv.ParentNode.SelectSingleNode("./div[@class='dlbox']/a[@class='dl']")
                $downloadHref = if ($dlDiv) { $dlDiv.GetAttributeValue("href", "") } else { "" }
                if ($downloadHref -and $downloadHref.StartsWith("//")) { $downloadHref = "https:$downloadHref" }

                # License or usage info
                $lv2Div = $fontDiv.ParentNode.SelectSingleNode("./div[contains(@class,'lv2right')]")
                $license = if ($lv2Div) {
                    $licNode = $lv2Div.SelectSingleNode(".//a[contains(@href,'faq.php#copyright')]")
                    if ($licNode) { $licNode.InnerText.Trim() } else { "" }
                } else { "" }

                $result += [pscustomobject]@{
                    FontName = $fontName
                    DafontPage = "https://www.dafont.com/$fontPage"
                    Author = $author
                    DownloadLink = $downloadHref
                    License = $license
                }
            }
            return $result
        } catch {
            Show-ExceptionDetails ($_) -ShowStack
        }
    }
}

function Get-daFontsPreviewUrls {
    [CmdletBinding(SupportsShouldProcess, SupportsPaging = $true)]
    param(
        [Parameter(Position=0,Mandatory=$True, HelpMessage = "Font category name (e.g. General_Various)")]
        [ValidateNotNullOrEmpty()]
        [string]$CategoryName,
        [Parameter(Position=1,Mandatory=$false)]
        [ValidateRange(1, 50)]
        [int]$Page = 1,
        [Parameter(Position=2,Mandatory = $false)]
        [ValidateSet(25, 50, 100, 200)]
        [int]$FontsPerPage = 200,
        [Parameter(Position=3,Mandatory = $false)]
        [ValidateLength(4, 64)]
        [ValidateNotNullOrEmpty()]
        [string]$Text
    )

    process {
        $CategoryId = Get-FontCategoryIdFromName -CategoryName $CategoryName
        if (-not $CategoryId) { throw "Invalid category name: $CategoryName" }
        Write-Verbose "Resolved category: $CategoryName -> $CategoryId"

        try {
            $baseUrl = 'https://www.dafont.com/theme.php'
            if (-not ([System.Web.HttpUtility] -as [type])) {
                Add-Type -AssemblyName 'System.Web'
                Write-Verbose "Loaded System.Web for UrlEncode"
            }
            $cat = [System.Web.HttpUtility]::UrlEncode($CategoryId.ToString())
            $page = [System.Web.HttpUtility]::UrlEncode($Page.ToString())
            $fpp = [System.Web.HttpUtility]::UrlEncode($FontsPerPage.ToString())
            $text = [System.Web.HttpUtility]::UrlEncode($Text)
            $Url = "https://www.dafont.com/theme.php?cat={0}&page={1}&fpp={2}&text={3}" -f $cat, $page, $fpp, $text

            Write-Verbose "Constructed URL: $Url"
            $hdrz = @{
                "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8"
                "Accept-Encoding" = "gzip, deflate, br, zstd"
                "Accept-Language" = "en-US,en;q=0.6"
                "Cache-Control" = "no-cache"
                "Pragma" = "no-cache"
            }

            $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -Headers $hdrz -ErrorAction Stop
            Write-Verbose "StatusCode: $($resp.StatusCode)"
            Write-Verbose "Response received successfully"

            # Load HTMLAgilityPack
             Register-HtmlAgilityPack2a 
            $HtmlContent = $resp.Content
            $HtmlDoc = New-Object HtmlAgilityPack.HtmlDocument
            $HtmlDoc.LoadHtml($HtmlContent)
            # $HtmlDoc is your loaded HtmlAgilityPack.HtmlDocument
            $rootNodes = $HtmlDoc.DocumentNode.SelectNodes("//body/div[1]/div/div/div/div") # This selects the main container div

            $result = @()
            if ($rootNodes) {
                $nodes = $rootNodes.ChildNodes | Where-Object { $_.NodeType -eq 'Element' }
                for ($i = 0; $i -lt $nodes.Count; $i++) {
                    $node = $nodes[$i]
                    if ($node.Name -eq 'div' -and $node.Attributes['class'] -and $node.Attributes['class'].Value -like '*lv1left*dfbg*') {
                        # Font info node found
                        $fontDiv = $node
                        $fontNameNode = $fontDiv.SelectSingleNode("./a[1]")
                        $fontName = $fontNameNode.InnerText.Trim()
                        $fontPage = $fontNameNode.GetAttributeValue("href", "")
                        $authorLink = $fontDiv.SelectSingleNode(".//a[2]")
                        $author = if ($authorLink) { $authorLink.InnerText.Trim() } else { "" }

                        # Find download and preview nodes by scanning forward
                        $downloadHref = ""
                        $license = ""
                        $previewUrl = ""

                        # Look for next dlbox, lv2right, preview
                        $j = $i + 1
                        while ($j -lt $nodes.Count) {
                            $nextNode = $nodes[$j]
                            if ($nextNode.Name -eq 'div' -and $nextNode.Attributes['class']) {
                                $cls = $nextNode.Attributes['class'].Value
                                if ($cls -like '*dlbox*' -and !$downloadHref) {
                                    $dlLink = $nextNode.SelectSingleNode(".//a[@class='dl']")
                                    if ($dlLink) {
                                        $downloadHref = $dlLink.GetAttributeValue("href", "")
                                        if ($downloadHref.StartsWith("//")) { $downloadHref = "https:$downloadHref" }
                                    }
                                }
                                if ($cls -like '*lv2right*' -and !$license) {
                                    $licNode = $nextNode.SelectSingleNode(".//a[contains(@href,'faq.php#copyright')]")
                                    $license = if ($licNode) { $licNode.InnerText.Trim() } else { "" }
                                }
                                if ($cls -like '*preview*' -and !$previewUrl) {
                                    $style = $nextNode.GetAttributeValue("style", "")
                                    if ($style -match "background-image:url\(([^)]+)\)") {
                                        $previewUrl = $matches[1].Trim("'\`"")
                                        if ($previewUrl.StartsWith("//")) { $previewUrl = "https:$previewUrl" }
                                        elseif ($previewUrl.StartsWith("/")) { $previewUrl = "https://www.dafont.com$previewUrl" }
                                    }
                                    break # Preview is always the last related node for the entry
                                }
                                # When next lv1left found, stop
                                if ($cls -like '*lv1left*dfbg*' -and $j -ne $i + 1) {
                                    break
                                }
                            }
                            $j++
                        }

                        $result += [pscustomobject]@{
                            FontName = $fontName
                            DafontPage = "https://www.dafont.com/$fontPage"
                            Author = $author
                            DownloadLink = $downloadHref
                            License = $license
                            PreviewUrl = $previewUrl
                        }
                    }
                }
            }

            return $result

        } catch {
            Show-ExceptionDetails ($_) -ShowStack
        }
    }
}


function Open-PreviewUrlPicture {
    [CmdletBinding(SupportsShouldProcess, SupportsPaging = $true)]
    param(
        [Parameter(Mandatory, HelpMessage = "picture path")]
        [ValidateNotNullOrEmpty()]
        [string]$Url
    )
    process {
        try {
            Add-Type -AssemblyName System.Web
            [uri]$u = $Url

            # Assuming $u is your [System.Uri] object:
            $queryParams = [System.Web.HttpUtility]::ParseQueryString($u.Query)
            $textValue = $queryParams["ttf"]
            $NewPicturePath = Get-FontPreviewPicturePath $Url $CategoryName
            Write-Verbose "Font $textValue" 
            Write-Verbose " Saving file `"$NewPicturePath`""

            $Headerz = @{
                "Accept" = "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8"
                "Accept-Encoding" = "gzip, deflate, br, zstd"
                "Cache-Control" = "no-cache"
                "Pragma" = "no-cache"
                "Referer" = "https://www.dafont.com/"
            }
            try {
                if (-not (Test-Path "$NewPicturePath")) {
                    Invoke-WebRequest -UseBasicParsing -Uri "$Url" -Headers $Headerz -OutFile "$NewPicturePath" -ErrorAction Stop
                }
            } catch {
                Write-Verbose "$_"
            }
            "$NewPicturePath"
        } catch {
            Show-ExceptionDetails ($_) -ShowStack
        }
    }
}

function Show-ImagesPreviewDialog {
    [CmdletBinding(SupportsShouldProcess= $true)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$ImagePaths
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Font Previews"
    $form.Size = '900,380'
    $form.StartPosition = 'CenterScreen'
    $form.Topmost = $true

    $panel = New-Object System.Windows.Forms.FlowLayoutPanel
    $panel.Dock = 'Fill'
    $panel.AutoScroll = $true
    $panel.WrapContents = $false
    $panel.FlowDirection = 'LeftToRight'

    foreach ($imgPath in $ImagePaths) {
        if (Test-Path $imgPath) {
            # Create container panel for image + label
            $container = New-Object System.Windows.Forms.Panel
            $container.Width = 260
            $container.Height = 300
            $container.Margin = '5,5,5,5'

            # Create PictureBox
            $pic = New-Object System.Windows.Forms.PictureBox
            $pic.Width = 260
            $pic.Height = 260
            $pic.SizeMode = 'Zoom'
            $pic.Image = [System.Drawing.Image]::FromFile($imgPath)

            # Create Label
            $label = New-Object System.Windows.Forms.Label
            $label.Text = [System.IO.Path]::GetFileName($imgPath)
            $label.Width = 260
            $label.TextAlign = 'MiddleCenter'
            $label.Dock = 'Bottom'

            # Add image and label to container
            $container.Controls.Add($pic)
            $container.Controls.Add($label)

            # Add container to main panel
            $panel.Controls.Add($container)
        }
    }

    $form.Controls.Add($panel)
    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()
}



function Get-FontsModuleTemporaryDirectory {
    [CmdletBinding(SupportsShouldProcess= $true)]
    param()
    process {

        $PreviewFontsPath = "C:\Share\PreviewFonts"
        if (-not (Test-Path $PreviewFontsPath)) {
            New-Item -Path $PreviewFontsPath -ItemType Directory -Force | Out-Null
        }

        return $PreviewFontsPath
    }
}


function Get-FontsModuleTmpScriptsDirectory {
    [CmdletBinding(SupportsShouldProcess= $true)]
    param()
    process {

        $FontsModuleTemporaryDirectory = Get-FontsModuleTemporaryDirectory
        $FontsModuleTmpScriptsDirectory = Join-Path "$FontsModuleTemporaryDirectory" "Scripts"
        if (-not (Test-Path $FontsModuleTmpScriptsDirectory)) {
            New-Item -Path $FontsModuleTmpScriptsDirectory -ItemType Directory -Force | Out-Null
        }

        return $FontsModuleTmpScriptsDirectory
    }
}




function Get-FontPreviewPicturePath {
    [CmdletBinding(SupportsShouldProcess= $true)]
    param(
        [Parameter(Mandatory = $true, position = 0, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,
        [Parameter(Mandatory = $true, position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Category 
    )
    process {
        Add-Type -AssemblyName System.Web
        [uri]$u = $Url



        # Assuming $u is your [System.Uri] object:
        $queryParams = [System.Web.HttpUtility]::ParseQueryString($u.Query)
        $textValue = $queryParams["ttf"]

        $LocalPath = Get-FontsModuleTemporaryDirectory

        if(!([string]::IsNullOrEmpty($Category))){
            $LocalPath = Join-Path "$LocalPath" "$Category"
        }

        if (-not (Test-Path $LocalPath)) {
            New-Item -Path $LocalPath -ItemType Directory -Force | Out-Null
        }
        $originalName = "$textValue".Replace(' ', '')
        $cleanName = ($originalName -replace "[<>:""/\\|?*]", '')

        $NewName = $cleanName.ToLower() + '.png'
        $NewPicturePath = Join-Path "$LocalPath" "$NewName"
        return $NewPicturePath
    }
}


function New-ScriptDecl {
    [CmdletBinding(SupportsShouldProcess= $true)]
    param(
        [Parameter(Mandatory = $true, position = 0, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        [Parameter(Mandatory = $true, position = 1)]
        [System.Collections.ArrayList]$List
    )
    process {
        $lines = @()
        $lines += '$Global:List = [System.Collections.ArrayList]@('

        foreach ($item in $List) {
            $escaped = $item -replace '"', '\"'
            $lines += "    `"$escaped`""
        }

        $lines += ')'
        Set-Content -Path $Path -Value $lines -Force

        Add-Content -Path $Path -Value "`n`nShow-ImagesPreviewDialog -ImagePaths `$List`n`n"
        $Path
    }
}

function New-ScriptDecl2 {
    [CmdletBinding(SupportsShouldProcess= $true)]
    param(
        [Parameter(Mandatory = $true, position = 0, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        [Parameter(Mandatory = $true, position = 1)]
        [System.Collections.ArrayList]$List
    )
    process {
        $lines = @()
        $lines += '$Global:List = [System.Collections.ArrayList]@('

        foreach ($item in $List) {
            $escaped = $item -replace '"', '\"'
            $lines += "    `"$escaped`""
        }

        $lines += ')'
        Set-Content -Path $Path -Value $lines -Force

        Add-Content -Path $Path -Value "`n`nForEach(`$item in  `$List){ . `"`$item`" }`n`n"

    }
}


function Open-PreviewLocalPicture {
    [CmdletBinding(SupportsShouldProcess= $true)]
    param(
        [Parameter(Mandatory, HelpMessage = "picture path")]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )
    Show-ImagePreviewDialog -ImagePath $Path
}


function Show-ImagePreviewDialog {
    [CmdletBinding(SupportsShouldProcess= $true)]
    param(
        [Parameter(Mandatory)]
        [string]$ImagePath
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Font Preview"
    $form.Size = '500,280'
    $form.StartPosition = 'CenterScreen'
    $form.Topmost = $true

    $pictureBox = New-Object System.Windows.Forms.PictureBox
    $pictureBox.Dock = 'Fill'
    $pictureBox.SizeMode = 'Zoom'
    $pictureBox.Image = [System.Drawing.Image]::FromFile($ImagePath)

    $form.Controls.Add($pictureBox)
    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()
}



function Test-PreviewLocalPicture {
    [CmdletBinding(SupportsShouldProcess= $true)]
    param(
        [Parameter(Mandatory = $true, position = 0)]
        [ValidateLength(4, 64)]
        [ValidateNotNullOrEmpty()]
        [string]$Text,
        [Parameter(Mandatory = $true)]
        [string]$CategoryName,
        [Parameter(Mandatory = $true)]
        [ValidateSet(25, 50, 100, 200)]
        [int]$ImagesPerFonts,
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 50)]
        [int]$Page
    )
    try {
        $MaxFonts = 50
        
        [System.Collections.ArrayList]$Script:TmpPreviewImagePaths = [System.Collections.ArrayList]::new()
        $Script:CurrentImageIndex = 1
        $Data = Get-daFontsPreviewUrls -CategoryName "$CategoryName" -Page $Page -FontsPerPage $MaxFonts -Text "$Text"
    

        $Data | % {
            [bool]$DownloadResult = $False
            $url = $_.PreviewUrl
            Write-Verbose "Get-FontPreviewPicturePath $url $CategoryName"
            Write-Verbose "$NewPicturePath"
            $NewPicturePath = Get-FontPreviewPicturePath $url $CategoryName
            if (-not (Test-Path "$NewPicturePath" -PathType LEaf)) {
                $imgPath = Open-PreviewUrlPicture $url
                [void]$Script:TmpPreviewImagePaths.Add($imgPath)
                $Script:CurrentImageIndex = $Script:CurrentImageIndex + 1

                $index = "[{0:d3} / {1:d3}]" -f $NumImages, $MaxFonts
                Write-Verbose "$index" 
                Write-Verbose " Download SUCCESS!" 
                $Script:CurrentDownloadedFiles++
                [bool]$DownloadResult = $True
            } else {
                Write-Host "Image preview $NewPicturePath exits!"
                Write-Verbose "$index" 
                Write-Verbose " already here"
                [bool]$DownloadResult = $true
                 $Path=$NewPicturePath.Replace('\\','\')
            [void]$Script:TmpPreviewImagePaths.Add($Path)
            }

           
            [pscustomobject]$resultsObject = [pscustomobject]@{
                    ImageIndex = $Script:CurrentImageIndex
                    TotalImages = $MaxFonts
                    ImagePath = "$Path"
                    Category  = "$CategoryName"
                    DownloadResult = $DownloadResult
                    CurrentPage = $Page
                    NumDownloaded = $Script:CurrentDownloadedFiles
                    TotalFonts = $Script:TotalDownloadedFiles
                }
            $resultJson = $resultsObject | ConvertTo-Json
            Write-Output "$resultJson"
        }
      
Show-ImagesPreviewDialog $Script:TmpPreviewImagePaths
    } catch {
        Show-ExceptionDetails ($_) -ShowStack
    }
    #Show-ImagesPreviewDialog -ImagePaths $List
}

function Invoke-DownloadFontsPreview {
    [CmdletBinding(SupportsShouldProcess= $true)]
    param(
        [Parameter(Position=0,Mandatory=$false)]
        [System.Collections.ArrayList]$PresetCategories,
        [Parameter(Position=1,Mandatory=$false)]
        [ValidateSet(25, 50, 100, 200)]
        [int]$FontsPerPage = 200,
        [Parameter(Position=2,Mandatory=$false)]
        [ValidateRange(1, 50)]
        [int]$PagePerCategories = 2
    )
    try {
        if($PresetCategories -eq $Null){
            $Cats = Get-PreviewFontsCategories
        }else{
            $Cats = $PresetCategories;

        }
        $CatsCount = $Cats.Count
        Write-Verbose "[Test-DriveInsightFonts] "
        Write-Verbose "will be loading $CatsCount categories "  
        foreach ($cat in $Cats) {
            Write-Verbose "$cat"
        }
        $PresetCategoriesCount = $PresetCategories.Count
        [uint32]$Script:CurrentDownloadedFiles = 0
        [uint32]$Script:TotalDownloadedFiles = $PagePerCategories * $FontsPerPage * $PresetCategoriesCount

        Write-Host "Will download $PagePerCategories pages ($FontsPerPage fots per page) of category $cat. Total $($Script:TotalDownloadedFiles) fonts for this category"

        ForEach($cat in $PresetCategories){
            1..$PagePerCategories | % {
                $page = $_
                Test-PreviewLocalPicture "DriveInsight - monitor your devices health" -CategoryName "$cat" -ImagesPerFonts $FontsPerPage -Page $page 
            }
        }

    } catch {
        Show-ExceptionDetails ($_) -ShowStack
    }
}



function Get-PreviewFontsCategories {
    [CmdletBinding(SupportsShouldProcess= $true)]
    param()
    try {
        [System.Collections.ArrayList]$List = [System.Collections.ArrayList]::new()
        $Presets = @('Culture_Various', 'Culture_Modern', 'Techno_Various', 'Techno_Square', 'Techno_Square', 'Techno_LCD', 'General_Stencil_Army', 'General_Typewriter', 'General_Various')
        foreach ($cat in $Presets) {
             [void]$List.Add($cat)
        }
       
        $List
    } catch {
        Show-ExceptionDetails ($_) -ShowStack
    }
}





