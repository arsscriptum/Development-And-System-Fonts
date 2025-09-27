#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   FontCategory.ps1                                                             ║
#║   fonts categories as defined in dafonts.com                                   ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <codegp@icloud.com>                                         ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝

# --- Enums ---

enum FontMainCategory {
    General = 100
    Techno  = 300
    Culture = 400
    Basic   = 500
    Script  = 600
}

enum FontSubCategory {
    # General
    Cartoon        = 101
    Comic          = 102
    Groovy         = 103
    OldSchool      = 104
    Curly          = 105
    Western        = 106
    Eroded         = 107
    Distorted      = 108
    Destroy        = 109
    Horror         = 110
    FireIce        = 111
    Decorative     = 112
    Typewriter     = 113
    StencilArmy    = 114
    Retro          = 115
    Initials       = 116
    Grid           = 117
    VariousGeneral = 118

    # Techno
    Square         = 301
    LCD            = 302
    SciFi          = 303
    VariousTechno  = 304

    # Culture
    Medieval       = 401
    Modern         = 402
    Celtic         = 403
    InitialsCulture= 404
    VariousCulture = 405

    # Basic
    SansSerif      = 501
    Serif          = 502
    Fixedwidth     = 503
    VariousBasic   = 504

    # Script
    Calligraphy    = 601
    School         = 602
    Handwritten    = 603
    Brush          = 604
    Trash          = 605
    Graffiti       = 606
    OldSchoolScript= 607
    VariousScript  = 608
}

# --- Lookup Table ---
$Script:FontCategoryLookup = @{
    # General
    "General/Cartoon"         = [FontSubCategory]::Cartoon
    "General/Comic"           = [FontSubCategory]::Comic
    "General/Groovy"          = [FontSubCategory]::Groovy
    "General/OldSchool"       = [FontSubCategory]::OldSchool
    "General/Curly"           = [FontSubCategory]::Curly
    "General/Western"         = [FontSubCategory]::Western
    "General/Eroded"          = [FontSubCategory]::Eroded
    "General/Distorted"       = [FontSubCategory]::Distorted
    "General/Destroy"         = [FontSubCategory]::Destroy
    "General/Horror"          = [FontSubCategory]::Horror
    "General/FireIce"         = [FontSubCategory]::FireIce
    "General/Decorative"      = [FontSubCategory]::Decorative
    "General/Typewriter"      = [FontSubCategory]::Typewriter
    "General/StencilArmy"     = [FontSubCategory]::StencilArmy
    "General/Retro"           = [FontSubCategory]::Retro
    "General/Initials"        = [FontSubCategory]::Initials
    "General/Grid"            = [FontSubCategory]::Grid
    "General/Various"         = [FontSubCategory]::VariousGeneral

    # Techno
    "Techno/Square"           = [FontSubCategory]::Square
    "Techno/LCD"              = [FontSubCategory]::LCD
    "Techno/SciFi"            = [FontSubCategory]::SciFi
    "Techno/Various"          = [FontSubCategory]::VariousTechno

    # Culture
    "Culture/Medieval"        = [FontSubCategory]::Medieval
    "Culture/Modern"          = [FontSubCategory]::Modern
    "Culture/Celtic"          = [FontSubCategory]::Celtic
    "Culture/Initials"        = [FontSubCategory]::InitialsCulture
    "Culture/Various"         = [FontSubCategory]::VariousCulture

    # Basic
    "Basic/SansSerif"         = [FontSubCategory]::SansSerif
    "Basic/Serif"             = [FontSubCategory]::Serif
    "Basic/Fixedwidth"        = [FontSubCategory]::Fixedwidth
    "Basic/Various"           = [FontSubCategory]::VariousBasic

    # Script
    "Script/Calligraphy"      = [FontSubCategory]::Calligraphy
    "Script/School"           = [FontSubCategory]::School
    "Script/Handwritten"      = [FontSubCategory]::Handwritten
    "Script/Brush"            = [FontSubCategory]::Brush
    "Script/Trash"            = [FontSubCategory]::Trash
    "Script/Graffiti"         = [FontSubCategory]::Graffiti
    "Script/OldSchool"        = [FontSubCategory]::OldSchoolScript
    "Script/Various"          = [FontSubCategory]::VariousScript
}

# --- Reverse Lookup Table (ID to "Main/Sub") ---
$Script:FontCategoryIdToString = @{}
foreach ($key in $Script:FontCategoryLookup.Keys) {
    $id = [int]$Script:FontCategoryLookup[$key]
    $Script:FontCategoryIdToString[$id] = $key
}

# --- Functions ---

function Get-FontSubCategoryIdFromString {
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [string]$MainCategory,
        [Parameter(Position=1)]
        [string]$SubCategory
    )
    process {
        $key = if ($PSBoundParameters.ContainsKey('SubCategory')) {
            "$MainCategory/$SubCategory"
        } else {
            $MainCategory.Trim()
        }
        if ($Script:FontCategoryLookup.ContainsKey($key)) {
            return [int]$Script:FontCategoryLookup[$key]
        } else {
            throw "Unknown font category: $key"
        }
    }
}

function Get-FontCategoryStringFromId {
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [int]$Id
    )
    process {
        if ($Script:FontCategoryIdToString.ContainsKey($Id)) {
            return $Script:FontCategoryIdToString[$Id]
        } else {
            throw "Unknown font category id: $Id"
        }
    }
}

function Get-FontMainCategoryFromId {
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [int]$Id
    )
    process {
        # Main category is the hundred digit
        $mainId = [int](($Id / 100) * 100)
        $mainEnum = [FontMainCategory]::$([FontMainCategory].GetEnumNames() | Where-Object { [FontMainCategory]::$_ -eq $mainId })
        return $mainEnum
    }
}

function Get-FontMainAndSubCategoryFromId {
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [int]$Id
    )
    process {
        if ($Script:FontCategoryIdToString.ContainsKey($Id)) {
            $parts = $Script:FontCategoryIdToString[$Id] -split '/', 2
            [PSCustomObject]@{
                Main = $parts[0]
                Sub  = $parts[1]
            }
        } else {
            throw "Unknown font category id: $Id"
        }
    }
}

# --- End of file ---
