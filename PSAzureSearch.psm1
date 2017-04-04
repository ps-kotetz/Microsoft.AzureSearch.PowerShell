# $AzureSearchKey = 
$AzureSearchKey = ""
#$AzureSearchURL = "https://psazuresearch.search.windows.net/indexes?api-version=2016-09-01"
$AzureSearchService = ""
$AzureSearchAPIVersion=""
https://psazuresearch.search.windows.net/indexes?api-version=2016-09-01

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
        [switch]$retrievable
    )
    $fieldData=[ordered]@{
        name=$Name
        type=$Type
        searchable=$Searchable.ToBool()
        filterable = $Filterable.ToBool()
        sortable=$Sortable.ToBool()
        facetable= $Facetable.ToBool()
        key=$isKey.ToBool()
        retrievable=$retrievable.ToBool()
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
    $requestUri
    $props =[ordered]@{
        name = $Name
        fields= $Fields
    }
    $headers = @{
        "api-key"=$AzureSearchKey
        "Content-Type" = "application/json"
    }
    $headers

    $indexData = New-Object psobject -Property $props
    $indexData
    $data = $indexData | ConvertTo-Json
    $data
    $body = [System.Text.Encoding]::UTF8.GetBytes($data)
    Invoke-WebRequest -Uri $requestUri -Method Post -Headers $Headers -Body $body
}

function Remove-AzureSearchIndex {

Invoke-WebRequest 
$URI = "https://psazuresearch.search.windows.net/indexes/hotels?api-version=2016-09-01"
Invoke-WebRequest -Uri $URI -Headers $Headers -Method Delete


}

<#
New-AzureSearchField
New-AzureSearchIndex
New-AzureSearchField
Get-AzureSearchIndex
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
