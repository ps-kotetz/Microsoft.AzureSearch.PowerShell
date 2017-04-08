
$AzureSearchKey = ""
$AzureSearchService = ""
$AzureSearchAPIVersion=""
$BaseRequestHeaders=$null

$TypeValueTable = @{
    "Edm.String" = "[String]"
    "Collection(Edm.String)"="[String[]]" 
    "Edm.Boolean"="[Boolean]"
    "Edm.Int32" = "[Int32]"
    "Edm.Int64" = "[Int64]"
    "Edm.Double"= "[Double]"
    "Edm.DateTimeOffset"="[DateTimeOffset]"
    "Edm.GeographyPoint" = "[string]"
}


function Update-AzureSearchSubModule{
    $uri = $Script:AzureSearchService + "indexes" + $Script:AzureSearchAPIVersion
    $global:indexList = (Invoke-WebRequest -Headers $BaseRequestHeaders -Uri $uri -Method Get).Content | ConvertFrom-Json

    foreach($indexInfo in $global:indexList.Value){
        # Key field top
        $fieldData = $indexInfo.fields | Sort-Object -Descending key
        $indexName = $indexInfo.name

        $keyField = $indexInfo.fields | Where-Object key -eq "true"
        $nonKeyField = $indexInfo.fields | Where-Object key -ne "true"

        $paramDef = ( $TypeValueTable[$keyField.type] + '$KeyFeild_' + $keyField.name) + "," +   (($nonKeyField | % {$TypeValueTable[$_.type]  + '$' + $_.name}) -join ",")
        $hashDef =  $keyField.name + '=$KeyFeild_' + $keyField.name + ";" +  (($nonKeyField | % {$_.name + '=$' + $_.name}) -join ";")

        $moduleDefinition = @'

function Set-AzureSearch{0}Document{{
    Param([ValidateSet("upload", "merge","mergeOrUpload","delete")][string]$Action="upload",{1})
    
    $objectData=[ordered]@{{  
        '@search.action'=$Action;
        {2}=${3};
    
    }}
    $nonKeyFields = $MyInvocation.BoundParameters.keys | Where-Object {{ ($_ -ne "Action") -and ($_ -ne "{3}") }}
    foreach($field in $nonKeyFields)
    {{
        $objectData[$field] = $MyInvocation.BoundParameters[$field]
    }}
    $uploadObject = New-Object psobject |  Add-Member -NotePropertyName value -NotePropertyValue @(New-Object psobject -Property $objectData) -PassThru
    $uploadObject 
    $data = $uploadObject   | ConvertTo-Json
    $data
    $body = [System.Text.Encoding]::UTF8.GetBytes($data)

    $requestUri = "{4}indexes/{0}/docs/index{5}"
    $requestHeaders = @{{
        "api-key"="{6}"
        "Content-Type" = "application/json"
    }}
    
    Invoke-WebRequest -Uri $requestUri -Method Post -Headers $requestHeaders -Body $body
}}
'@ -f @($indexName,$paramDef,$keyField.name,('KeyFeild_' + $keyField.name),$AzureSearchService,$AzureSearchAPIVersion,$AzureSearchKey)

    Write-Verbose $moduleDefinition
    Write-Verbose "Update-AzureSearchSubModule"
        New-Module -Name ("Microsoft.AzureSearch.PowerShell." + $indexName) -ScriptBlock ([scriptblock]::Create($moduleDefinition)) | Import-Module -Global

        Get-Module
    }
}
function Connect-AzureSearch{
    Param(
        [Parameter(Mandatory=$true)][string]$Key,
        [Parameter(Mandatory=$true)][string]$ServiceName,
        [string]$APIVersion="api-version=2016-09-01"
    )
    $AzureSearchKey = $Key
    $Script:AzureSearchService = "https://" + $ServiceName + ".search.windows.net/"
    $Script:AzureSearchAPIVersion = "?" + $APIVersion
    $Script:AzureSearchKey = $Key
    $Script:BaseRequestHeaders = @{
        "api-key"=$Script:AzureSearchKey
        "Content-Type" = "application/json"
    }
    Write-Verbose -Message ("Connect-AzureSearch")
    #New-Module -ScriptBlock -Name 
    #https://[service name].search.windows.net/indexes?api-version=[api-version]
    Update-AzureSearchSubModule -Verbose
    
}


function New-AzureSearchField{
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Edm.String", "Collection(Edm.String)", "Edm.Boolean","Edm.Int32" , "Edm.Int64" , "Edm.Double" , "Edm.DateTimeOffset" , "Edm.GeographyPoint")]
        [string]$Type,
        [switch]$Searchable,
        [switch]$Filterable,
        [switch]$Sortable,
        [switch]$Facetable,
        [switch]$isKey,
        [switch]$Retrievable,
        [string]$Analyzer
    )

    # retriebable は default true ? searchable もdefault true?
    $fieldData=[ordered]@{
        name=$Name
        type=$Type
        searchable=$Searchable.ToBool()
        filterable = $Filterable.ToBool()
        sortable=$Sortable.ToBool()
        facetable= $Facetable.ToBool()
        key=$isKey.ToBool()
        retrievable=$Retrievable.ToBool()
    }
    if($Analyzer -ne $null)
    {
        $fieldData.analyzer = $Analyzer
    }
    New-Object psobject -Property $fieldData
}




#$body = [System.Text.Encoding]::UTF8.GetBytes($data)

function New-AzureSearchIndex{
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        $Fields
        )
    $requestUri = $AzureSearchService + "indexes" + $AzureSearchAPIVersion
    $props =[ordered]@{
        name = $Name
        fields= $Fields
    }


    $indexData = New-Object psobject -Property $props
    $data = $indexData | ConvertTo-Json
    $body = [System.Text.Encoding]::UTF8.GetBytes($data)
    Invoke-WebRequest -Uri $requestUri -Method Post -Headers $BaseRequestHeaders -Body $body
}

function Invoke-AzureSearch
{
    Param($Query)

}

function Remove-AzureSearchIndex {
    [CmdletBinding(
                  SupportsShouldProcess=$true, 
                  PositionalBinding=$false,
                  HelpUri = 'http://www.microsoft.com/',
                  ConfirmImpact='Medium')]
    Param([string]$Name)
    $AppStr = "indexes/" + $Name

    $URI = $AzureSearchService + $AppStr + $AzureSearchAPIVersion
    Write-Verbose -Message ("Request URL : " + $URI)
  #   "https://psazuresearch.search.windows.net/indexes/hotels?api-version=2016-09-01"
    Invoke-WebRequest -Uri $URI -Headers $BaseRequestHeaders -Method Delete
}

function Get-AzureSearchIndex {
    Param([string]$Name)
    $appStr = "indexes/" + $Name
    $uri = $AzureSearchService + $appStr + $AzureSearchAPIVersion
    Write-Verbose -Message ("Request URL : " + $uri)
  #   "https://psazuresearch.search.windows.net/indexes/hotels?api-version=2016-09-01"
    $result = Invoke-WebRequest -Uri $uri -Headers $BaseRequestHeaders -Method Get
    $result.content | ConvertFrom-Json
}

<#
New-AzureSearchField
New-AzureSearchIndex
Update-AzureSearchIndex
Delete-AzureSearchIndex
Get-AzureSearchStatistics
Analyze-AzureSearchText
Get-AzureSearchAnalyzedText
Invoke-WebRequest -Method Post

Add-AzureSearchDocument
Update-AzureSearchDocument
Delete-AzureSearchDocument
Get-AzureSearchDocument

Search-AzureSearch
#>

function Add-AzureSearchDocument{
    Param([string]$Name)
    $requestUri = $AzureSearchService + "indexes" + $AzureSearchAPIVersion
    $props =[ordered]@{
        name = $Name
        fields= $Fields
    }


    $indexData = New-Object psobject -Property $props
    $data = $indexData | ConvertTo-Json
    $body = [System.Text.Encoding]::UTF8.GetBytes($data)
    Invoke-WebRequest -Uri $requestUri -Method Post -Headers $BaseRequestHeaders -Body $body
}

$sampleData=@'
{
    "value": [
        {
            "@search.action": "upload",
            "hotelId": "1",
            "baseRate": 199.0,
            "description": "Best hotel in town",
            "description_fr": "Meilleur hôtel en ville",
            "hotelName": "Fancy Stay",
            "category": "Luxury",
            "tags": ["pool", "view", "wifi", "concierge"],
            "parkingIncluded": false,
            "smokingAllowed": false,
            "lastRenovationDate": "2010-06-27T00:00:00Z",
            "rating": 5,
            "location": { "type": "Point", "coordinates": [-122.131577, 47.678581] }
        },
        {
            "@search.action": "upload",
            "hotelId": "2",
            "baseRate": 79.99,
            "description": "Cheapest hotel in town",
            "description_fr": "Hôtel le moins cher en ville",
            "hotelName": "Roach Motel",
            "category": "Budget",
            "tags": ["motel", "budget"],
            "parkingIncluded": true,
            "smokingAllowed": true,
            "lastRenovationDate": "1982-04-28T00:00:00Z",
            "rating": 1,
            "location": { "type": "Point", "coordinates": [-122.131577, 49.678581] }
        },
        {
            "@search.action": "mergeOrUpload",
            "hotelId": "3",
            "baseRate": 129.99,
            "description": "Close to town hall and the river"
        },
        {
            "@search.action": "delete",
            "hotelId": "6"
        }
    ]
}
'@




$sampleData=@'
{
    "name": "hotels",  
    "fields": [
        {"name": "hotelId", "type": "Edm.String", "key": true, "searchable": false, "sortable": false, "facetable": false},
        {"name": "baseRate", "type": "Edm.Double"},
        {"name": "description", "type": "Edm.String", "filterable": false, "sortable": false, "facetable": false},
        {"name": "description_fr", "type": "Edm.String", "filterable": false, "sortable": false, "facetable": false, "analyzer": "fr.lucene"},
        {"name": "hotelName", "type": "Edm.String", "facetable": false},
        {"name": "category", "type": "Edm.String"},
        {"name": "tags", "type": "Collection(Edm.String)"},
        {"name": "parkingIncluded", "type": "Edm.Boolean", "sortable": false},
        {"name": "smokingAllowed", "type": "Edm.Boolean", "sortable": false},
        {"name": "lastRenovationDate", "type": "Edm.DateTimeOffset"},
        {"name": "rating", "type": "Edm.Int32"},
        {"name": "location", "type": "Edm.GeographyPoint"}
    ]
}
'@
