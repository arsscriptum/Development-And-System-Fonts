#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   TestParseFontHtml                                                            ║
#║   test functions, wip                                                          ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <codegp@icloud.com>                                         ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝



# Sample Code For Example Only 



$Script:EnableDebugLogs = $false
function Invoke-ParseFontNodes {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Font name or pattern to search for")]
        [HtmlAgilityPack.HtmlNodeCollection]$nodes,
        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Font name or pattern to search for")]
        [HtmlAgilityPack.HtmlNodeCollection]$nodesCat
    )

    function Write-ParseLog {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param(
            [Parameter(Mandatory = $true, Position = 0)]
            [Alias('m')]
            [string]$Message,
            [Parameter(Mandatory = $false)]
            [Alias('h')]
            [switch]$Highlight,
            [Parameter(Mandatory = $false)]
            [Alias('n')]
            [switch]$NoNewLine
        )
        if ($Script:EnableDebugLogs -eq $False) { return }
        $col1 = 'Blue'
        $col2 = 'White'
        $NoNewLineArg = ''
        if ($Highlight) { $col1 = 'DarkYellow'; $col2 = 'DarkRed' }

        Write-Host -f $col1 -n "[Parsing] "

        if ($NoNewLine) {
            Write-Host -n -f $col2 "$Message"
        } else {
            Write-Host -f $col2 "$Message"
        }

    }
    
    if ($null -eq $resultsFontsNodes) { return }
    $resultsFontsNodesCount = $resultsFontsNodes.Count
    Write-ParseLog "Search returned $resultsFontsNodesCount fonts nodes"
    [PsCustomObject[]]$flist = @()
    for ($i = 0; $i -lt $nodes.Count; $i++) {
        $node = $nodes[$i]
        $nodeCat = $nodesCat[$i]
        $fontName = ''
        $fontAuthor = ''
        $fontCategory = 'unknown'
        Write-ParseLog "  parsing"
        $tmpFontAuthor = [System.Web.HttpUtility]::HtmlDecode($node.InnerText.Trim())
        Write-ParseLog "  Decoding $($node.InnerText.Trim()) ==> $tmpFontAuthor"
        $tmpFontAuthorHasBy = ($tmpFontAuthor.IndexOf(' by ') -ge 0)
        $tmpFontAuthorHasDash = ($tmpFontAuthor.IndexOf('-') -ge 0)
        $authorNode = $node.SelectSingleNode(".//a[1]")
        $catNode = $node.SelectSingleNode('.//*[contains(@class,"dfcategory")]')

        if (($catNode -ne $Null) -and (!([string]::IsNullOrEmpty($($catNode.InnerText))))) {
            $tmpFontCategory = $catNode.InnerText -replace "^in\s*", ""
            $fontCategory = [System.Web.HttpUtility]::HtmlDecode($tmpFontCategory)
            Write-ParseLog2 "      fontCategory $fontCategory"
        }
        if ($tmpFontAuthorHasBy) {
            $fontName = ($tmpFontAuthor.Split(' by ')[0].Trim())
            $fontAuthor = ($tmpFontAuthor.Split(' by ')[1].Trim()) | Remove-NonAlphanumericAndAccents
            Write-ParseLog " using by . parsing $tmpFontAuthor"
            Write-ParseLog "      fontName $fontName"
            Write-ParseLog "      fontAuthor $fontAuthor"
        } elseif ($tmpFontAuthorHasDash) {
            $fontName = ($tmpFontAuthor.Split('-')[0].Trim())
            $fontAuthor = ($tmpFontAuthor.Split('-')[1].Trim()) | Remove-NonAlphanumericAndAccents
            Write-ParseLog "  using dash . parsing $tmpFontAuthor"
            Write-ParseLog "      fontName $fontName"
            Write-ParseLog "      fontAuthor $fontAuthor"
        } else {
            $fontName = $tmpFontAuthor
            $fontAuthor = 'unknown'
            Write-Verbose "parse errror`n string $($node.InnerText.Trim())"
        }

        $fontName = $fontName | Remove-NonAlphanumericAndAccents
        Write-ParseLog " [fontid] $fontName"
        Write-ParseLog " [author] $fontAuthor"
        [pscustomobject]$fobj = [pscustomobject]@{
            FontName = $fontName
            Author = $fontAuthor
            Category = $fontCategory
        }
        $flist += $fobj
    }

    $flist
}



function Invoke-DaFontsSearchOLD {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Font name or pattern to search for")]
        [string]$Pattern,
        [Parameter(Mandatory = $false)]
        [switch]$StartBrave
    )
    try{
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

        $resultsFontsNodes = $HtmlNode.SelectNodes("//div[contains(@class,'lv1left') and contains(@class,'dfbg')]")

        if ($null -eq $resultsFontsNodes) { return }
        $resultsFontsNodesCount = $resultsFontsNodes.Count
        [PsCustomObject[]]$flist = @()
        try{
            $flist = Invoke-ParseFontNodes $resultsFontsNodes
        }catch{
            throw $_
        }
        return $flist
    }catch{
        Write-Error "$_"
    }
    
}
