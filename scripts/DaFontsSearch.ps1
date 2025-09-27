#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   DaFontsSearch.ps1                                                            ║
#║   Search and list installed fonts. Test them by render in tmp web page         ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <codegp@icloud.com>                                         ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝


function Get-ExternalsLibraryPath {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $RootPath = (Resolve-Path -Path "$PSScriptRoot\..").Path
    $LibPath = Join-Path "$RootPath" "lib"
    return $LibPath
}

function Register-HtmlAgilityPack3b {
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


function Remove-NonAlphanumericAndAccents {
    [CmdletBinding()]
    param(
        [Parameter(
            Position = 0,
            Mandatory = $true,
            ValueFromPipeline = $true,
            HelpMessage = "Input string"
        )]
        [string]$InputString
    )
    process {
        # Remove accents
        $normalized = $InputString.Normalize([Text.NormalizationForm]::FormD)
        $plain = -join ($normalized.ToCharArray() | Where-Object {
                [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark'
            })

        # Remove everything except alphanumeric and space
        $result = ($plain -replace '[^A-Za-z0-9 ]', '')
        $result
    }
}



function Invoke-DaFontsSearch {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Font name or pattern to search for")]
        [string]$Pattern
    )
    try {
        $HeadersObj = @{
            "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8"
            "Accept-Encoding" = "gzip, deflate, br, zstd"
            "Accept-Language" = "en-US,en;q=0.8"
            "Referer" = "https://www.dafont.com/"
        }
        $BaseUrl = "https://www.dafont.com/search.php"
        $SearchQuery = [System.Web.HttpUtility]::UrlEncode($Pattern)
        Write-Verbose "Searching for `"$Pattern`". Encoded query `"$SearchQuery`""
        $SearchRequestUrl = "{0}?q={1}" -f $BaseUrl, $SearchQuery
        Write-Verbose "SearchRequestUrl is `"$SearchRequestUrl`""

        $RequestResult = Invoke-WebRequest -UseBasicParsing -Uri "$SearchRequestUrl" -Headers $HeadersObj -ErrorAction Stop

        $StatusCode = $RequestResult.StatusCode
        $StatusDescription = $RequestResult.StatusDescription
        if ($StatusCode -ne 200) { throw "Search Request Returned Error ($StatusCode) $StatusDescription" }
        $HtmlContent = $RequestResult.Content

        [HtmlAgilityPack.HtmlDocument]$HtmlDoc = @{}
        $HtmlDoc.LoadHtml($HtmlContent)

        $HtmlNode = $HtmlDoc.DocumentNode

        $leftNodes = $HtmlNode.SelectNodes("//div[contains(@class,'lv1left') and contains(@class,'dfbg')]")
        $rightNodes = $HtmlNode.SelectNodes("//div[contains(@class,'lv1right') and contains(@class,'dfbg')]")

        if ($null -eq $leftNodes) { return }
        $leftNodesCount = $leftNodes.Count
        Write-Verbose "leftNodesCount $leftNodesCount"
        $rightNodesCount = $rightNodes.Count
        Write-Verbose "rightNodesCount $rightNodesCount"
        [pscustomobject[]]$SearchResults = @()
        if ($leftNodes -and $rightNodes) {
            for ($i = 0; $i -lt $leftNodes.Count; $i++) {
                $left = $leftNodes[$i]
                $right = $rightNodes[$i]

                $tmpFontText = $left.InnerText.Trim()
                $fontText = [System.Web.HttpUtility]::HtmlDecode($tmpFontText)  | Remove-NonAlphanumericAndAccents
                $tmpFontName = ($fontText -split ' by ')[0].Trim()
                $fontName = [System.Web.HttpUtility]::HtmlDecode($tmpFontName)  | Remove-NonAlphanumericAndAccents
                $authorNode = $left.SelectSingleNode(".//a[1]")
                $tmpAuthorVal = if ($authorNode -ne $Null) { $authorNode.InnerText.Trim() } else { 'unknown' }
                $author = [System.Web.HttpUtility]::HtmlDecode($tmpAuthorVal)  | Remove-NonAlphanumericAndAccents

                # The category is the plain text and/or <a> nodes in $right
                $tmpCategoryValue = ($right.InnerText.Trim() -replace '\s+', ' ')
                $tmpCategoryValue = $tmpCategoryValue.TrimStart('in ')
                $tmpCategoryValueHasSubCat = ($tmpCategoryValue.IndexOf('&gt;') -ge 0)
                if ($tmpCategoryValueHasSubCat) {
                    $tmpCategoryValueParentCat = ($tmpCategoryValue.Split('&gt;')[0])
                    $tmpCategoryValueSubCat = ($tmpCategoryValue.Split('&gt;')[1])
                } else {
                    $tmpCategoryValueParentCat = $tmpCategoryValue.Trim()
                    $tmpCategoryValueSubCat = "n/a"
                }

                [pscustomobject]$obj = [pscustomobject]@{
                    FontName = $fontName
                    Author = $author
                    ParentCategory = $tmpCategoryValueParentCat
                    SubCategory = $tmpCategoryValueSubCat
                }
                $SearchResults += $obj
            }
        }
        return $SearchResults

    } catch {
        Write-Error "$_"
    }

}
