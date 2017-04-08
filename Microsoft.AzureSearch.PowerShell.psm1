
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

$ModuleTemplate = @'
function Add-AzureSearch{8}Document{{
    Param({1},{2})
    $objectData=[ordered]@{{  
        '@search.action'='upload';
        {3}=${4};
    }}
    $nonKeyFields = $MyInvocation.BoundParameters.keys | Where-Object {{ $_ -ne "{4}" }}
    foreach($field in $nonKeyFields)
    {{
        $objectData[$field] = $MyInvocation.BoundParameters[$field]
    }}
    $uploadObject = New-Object psobject |  Add-Member -NotePropertyName value -NotePropertyValue @(New-Object psobject -Property $objectData) -PassThru
    $data = $uploadObject   | ConvertTo-Json
    $body = [System.Text.Encoding]::UTF8.GetBytes($data)

    $requestUri = "{5}indexes/{0}/docs/index{6}"
    $requestHeaders = @{{
        "api-key"="{7}"
        "Content-Type" = "application/json"
    }}
    
    Invoke-WebRequest -Uri $requestUri -Method Post -Headers $requestHeaders -Body $body
}}

function Merge-AzureSearch{8}Document{{
    Param({1},{2})
    
    $objectData=[ordered]@{{  
        '@search.action'='merge';
        {3}=${4};
    
    }}
    $nonKeyFields = $MyInvocation.BoundParameters.keys | Where-Object {{ $_ -ne "{4}"}}
    foreach($field in $nonKeyFields)
    {{
        $objectData[$field] = $MyInvocation.BoundParameters[$field]
    }}
    $uploadObject = New-Object psobject |  Add-Member -NotePropertyName value -NotePropertyValue @(New-Object psobject -Property $objectData) -PassThru
    $data = $uploadObject   | ConvertTo-Json
    $body = [System.Text.Encoding]::UTF8.GetBytes($data)
    $requestUri = "{5}indexes/{0}/docs/index{6}"
    $requestHeaders = @{{
        "api-key"="{7}"
        "Content-Type" = "application/json"
    }}
    
    Invoke-WebRequest -Uri $requestUri -Method Post -Headers $requestHeaders -Body $body
}}

function Remove-AzureSearch{8}Document{{
    Param({1})
    
    $objectData=[ordered]@{{  
        '@search.action'='delete';
        {3}=${4};
    
    }}
    $uploadObject = New-Object psobject |  Add-Member -NotePropertyName value -NotePropertyValue @(New-Object psobject -Property $objectData) -PassThru
    $data = $uploadObject   | ConvertTo-Json
    $body = [System.Text.Encoding]::UTF8.GetBytes($data)

    $requestUri = "{5}indexes/{0}/docs/index{6}"
    $requestHeaders = @{{
        "api-key"="{7}"
        "Content-Type" = "application/json"
    }}
    
    Invoke-WebRequest -Uri $requestUri -Method Post -Headers $requestHeaders -Body $body
}}
'@



function Update-AzureSearchSubModule{
    $uri = $Script:AzureSearchService + "indexes" + $Script:AzureSearchAPIVersion
    $global:indexList = (Invoke-WebRequest -Headers $BaseRequestHeaders -Uri $uri -Method Get).Content | ConvertFrom-Json

    foreach($indexInfo in $global:indexList.Value){

        $indexName =  $indexInfo.name
        $UpperindexName = [char]::ToUpper($indexInfo.name[0]) + $indexInfo.name.Substring(1)
        $keyField = $indexInfo.fields | Where-Object key -eq "true"
        $nonKeyField = $indexInfo.fields | Where-Object key -ne "true"

        $keyFieldParameterName = 'KeyFeild_' + $keyField.name
        $paramDefForKeyField = ( $TypeValueTable[$keyField.type] + '$' + $keyFieldParameterName) 
        
        $paramDefForNonKeyField = ($nonKeyField | % {$TypeValueTable[$_.type]  + '$' + $_.name}) -join "," 
        $hashDef =  $keyField.name + '=$' + $keyFieldParameterName  + ";" +  (($nonKeyField | % {$_.name + '=$' + $_.name}) -join ";")

        $moduleDefinition =  $ModuleTemplate -f @(
                                                    $indexName,
                                                    $paramDefForKeyField,
                                                    $paramDefForNonKeyField,
                                                    $keyField.name,
                                                    $keyFieldParameterName,
                                                    $AzureSearchService,
                                                    $AzureSearchAPIVersion,
                                                    $AzureSearchKey,
                                                    $UpperindexName
                                                )

        Write-Verbose $moduleDefinition
        Write-Verbose "Update-AzureSearchSubModule"
        if((Get-Module ("Microsoft.AzureSearch.PowerShell." + $indexName)) -ne $null){
            Remove-Module ("Microsoft.AzureSearch.PowerShell." + $indexName)
        }
        New-Module -Name ("Microsoft.AzureSearch.PowerShell." + $indexName) -ScriptBlock ([scriptblock]::Create($moduleDefinition)) | Import-Module -Global
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
    Update-AzureSearchSubModule
}

function Search-AzureSearch
{
    Param([string]$IndexName,[string]$SearchString,[string]$FieldSelection="*",[string]$Filter)
    $requestUri = $AzureSearchService + "indexes/" + $IndexName + "/docs/search" + $AzureSearchAPIVersion
    $searchObj=[ordered]@{
        search = $SearchString
        select = $FieldSelection 
    }
    if($MyInvocation.BoundParameters.ContainsKey("filter"))
    {
        $searchObj.filter = $Filter
    }

    $indexData = New-Object psobject -Property $searchObj
    $data = $indexData | ConvertTo-Json
    $body = [System.Text.Encoding]::UTF8.GetBytes($data)
    $result = Invoke-WebRequest -Uri $requestUri -Method Post -Headers $BaseRequestHeaders -Body $body
    $result.content | ConvertFrom-Json | ForEach-Object value
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
