# 最初に Connect してねのエラーメッセージ
# get-azureserchIndexes を追加
# merge-＊に -mergeOrUpload スイッチをつける

# search-AzureSearch -name  | 

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

$IndexKeyTable = @{ 
}

$ModuleTemplate = @'
function Global:Add-AzureSearch{8}Document{{
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
    
    $result = Invoke-WebRequest -Uri $requestUri -Method Post -Headers $BaseRequestHeaders -Body $body
    Write-Verbose -Message ("Status Code : " + $result.StatusCode)
    Write-Verbose -Message ("Description : " + $result.StatusDescription)
}}

function Global:Merge-AzureSearch{8}Document{{
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
    $result = Invoke-WebRequest -Uri $requestUri -Method Post -Headers $requestHeaders -Body $body
    Write-Verbose -Message ("Status Code : " + $result.StatusCode)
    Write-Verbose -Message ("Description : " + $result.StatusDescription)
}}

function Global:Remove-AzureSearch{8}Document{{
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
    $result = Invoke-WebRequest -Uri $requestUri -Method Post -Headers $requestHeaders -Body $body
    Write-Verbose -Message ("Status Code : " + $result.StatusCode)
    Write-Verbose -Message ("Description : " + $result.StatusDescription)
}}

Export-ModuleMember -Function *Document
'@

function Out-JsonObject{
    Param([Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true)]$JsonObj)
    if($JsonObj.value -eq $null)
    {
        $JsonObj
    }
    else
    {
        $JsonObj.Value
    }

}

function Check-AzureConnection
{
    if($AzureSearchKey -eq $null)
    {
        Write-Error "Run Connect-AzureSearch command first. Connect-AzureSearch -Key <adminKey> -ServiceName <AzureSearch Service Name>"
        $false
    } 
    else
    {
        $true
    }
}

function Update-AzureSearchSubModule{
    $script:IndexKeyTable = @{}
    $uri = $Script:AzureSearchService + "indexes" + $Script:AzureSearchAPIVersion
    $global:indexList = (Invoke-WebRequest -Headers $BaseRequestHeaders -Uri $uri -Method Get).Content | ConvertFrom-Json

    foreach($indexInfo in $global:indexList.Value){

        $indexName =  $indexInfo.name
        $UpperindexName = [char]::ToUpper($indexInfo.name[0]) + $indexInfo.name.Substring(1)
        $keyField = $indexInfo.fields | Where-Object key -eq "true"
        $nonKeyField = $indexInfo.fields | Where-Object key -ne "true"

        $script:IndexKeyTable[$indexName] = $keyField 

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
        Invoke-Command -ScriptBlock ([scriptblock]::Create($moduleDefinition))
    }
}

function Connect-AzureSearch{
    [CmdletBinding(
            SupportsShouldProcess=$true, 
            PositionalBinding=$true)]
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
    $result = Invoke-WebRequest -Uri ($AzureSearchService + "indexes/" + $Script:AzureSearchAPIVersion) -Headers $BaseRequestHeaders
    if($result.StatusCode -ne 200)
    {
        $Script:AzureSearchKey = $null
        $Script:AzureSearchService = $null
        $Script:BaseRequestHeaders = $null
        Write-Verbose -Message ("Failed to connect AzureSearch") 
    }

    Write-Verbose -Message ("Connect-AzureSearch")
    Update-AzureSearchSubModule -Verbose
}

function New-AzureSearchField{
    [CmdletBinding(
            SupportsShouldProcess=$true, 
            PositionalBinding=$true)]
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
        [switch]$IsKey,
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

function Add-AzureSearchDocument{
    [CmdletBinding(
                SupportsShouldProcess=$true, 
                PositionalBinding=$true)]
    Param(
            [Parameter(Mandatory=$true)][string]$KeyFieldName,
            [Parameter(Mandatory=$true)][string]$KeyFieldValue,
            [Parameter(Mandatory=$true)][string]$IndexName,
            [System.Collections.Hashtable]$DocumentData
        )
    $objectData=[ordered]@{
        '@search.action'='upload';
        $KeyFieldName=$KeyFieldValue;
    }
    if($DocumentData -ne $null)
    {
       $objectData += $DocumentData
    }
    $uploadObject = New-Object psobject |  Add-Member -NotePropertyName value -NotePropertyValue @(New-Object psobject -Property $objectData) -PassThru
    $data = $uploadObject | ConvertTo-Json
    $body = [System.Text.Encoding]::UTF8.GetBytes($data)
    $requestUri = $AzureSearchService + "indexes/" + $IndexName + "/docs/index" + $AzureSearchAPIVersion
    
    #"{5}indexes/{0}/docs/index{6}"
    $requestUri
    $result = Invoke-WebRequest -Uri $requestUri -Method Post -Headers $BaseRequestHeaders -Body $body
    Write-Verbose -Message ("Status Code : " + $result.StatusCode)
    Write-Verbose -Message ("Description : " + $result.StatusDescription)
}

function Merge-AzureSearchDocument{
    [CmdletBinding(
                SupportsShouldProcess=$true, 
                PositionalBinding=$true)]
    Param(
            [Parameter(Mandatory=$true)][string]$KeyFieldName,
            [Parameter(Mandatory=$true)][string]$KeyFieldValue,
            [Parameter(Mandatory=$true)][string]$IndexName,
            [System.Collections.Hashtable]$DocumentData,
            [switch]$MergeOrUpload
        )

    if($MergeOrUpload)
    {
        $action = 'mergeOrUpload'
    }
    else
    {
        $action = 'merge'
    }
    $objectData=[ordered]@{ 
        '@search.action'=$action
        $KeyFieldName=$KeyFieldValue
    }

    if($DocumentData -ne $null)
    {
       $objectData += $DocumentData
    }
    $uploadObject = New-Object psobject |  Add-Member -NotePropertyName value -NotePropertyValue @(New-Object psobject -Property $objectData) -PassThru
    $data = $uploadObject | ConvertTo-Json
    $body = [System.Text.Encoding]::UTF8.GetBytes($data)
    $requestUri = $AzureSearchService + "indexes/" + $IndexName + "/docs/index" + $AzureSearchAPIVersion

    $result = Invoke-WebRequest -Uri $requestUri -Method Post -Headers $BaseRequestHeaders -Body $body
    Write-Verbose -Message ("Status Code : " + $result.StatusCode)
    Write-Verbose -Message ("Description : " + $result.StatusDescription)
}

function Remove-AzureSearchDocument{
    [CmdletBinding(
                SupportsShouldProcess=$true, 
                PositionalBinding=$true)]
    Param(
            [Parameter(Mandatory=$true)][string]$KeyFieldName,
            [Parameter(Mandatory=$true)][string]$KeyFieldValue,
            [Parameter(Mandatory=$true)][string]$IndexName
        )
    $objectData=[ordered]@{ 
        '@search.action'='delete';
        $KeyFieldName=$KeyFieldValue
    }
    $uploadObject = New-Object psobject |  Add-Member -NotePropertyName value -NotePropertyValue @(New-Object psobject -Property $objectData) -PassThru
    $data = $uploadObject   | ConvertTo-Json
    $body = [System.Text.Encoding]::UTF8.GetBytes($data)

    $requestUri = $AzureSearchService + "indexes/" + $IndexName + "/docs/index" + $AzureSearchAPIVersion
    $result = Invoke-WebRequest -Uri $requestUri -Method Post -Headers $BaseRequestHeaders -Body $body
    Write-Verbose -Message ("Status Code : " + $result.StatusCode)
    Write-Verbose -Message ("Description : " + $result.StatusDescription)
}


function New-AzureSearchIndex{
    [CmdletBinding(
            SupportsShouldProcess=$true, 
            PositionalBinding=$true)]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        $Fields,
        [switch]$AsJson
        )
    Write-Verbose -Message ("New-AzureSearchIndex")
    $requestUri = $AzureSearchService + "indexes" + $AzureSearchAPIVersion
    $props =[ordered]@{
        name = $Name
        fields= $Fields
    }
    
    $indexData = New-Object psobject -Property $props
    Write-Verbose -Message ("Request URL : " + $requestUri)
    Write-Verbose ("Index definition")
    Write-Verbose ($indexData)
    $data = $indexData | ConvertTo-Json
    if($AsJson){
        Write-Output $data
    }
    else
    {
        $body = [System.Text.Encoding]::UTF8.GetBytes($data)
        $result = Invoke-WebRequest -Uri $requestUri -Method Post -Headers $BaseRequestHeaders -Body $body
        Write-Verbose -Message ("Status Code : " + $result.StatusCode)
        Write-Verbose -Message ("Description : " + $result.StatusDescription)
        Update-AzureSearchSubModule
    }
}


function Search-AzureSearch
{
    [CmdletBinding(
            SupportsShouldProcess=$true, 
            PositionalBinding=$true)]
    Param(
        [Parameter(Mandatory=$true)][string]$IndexName,
        [string]$SearchString,
        [string]$FieldSelection="*",
        [string]$Filter,
        [switch]$AsJson
        )
    Write-Verbose -Message ("Search-AzureSearch")
    $requestUri = $AzureSearchService + "indexes/" + $IndexName + "/docs/search" + $AzureSearchAPIVersion
    $searchObj=[ordered]@{
        search = $SearchString
        select = $FieldSelection 
    }
    if($MyInvocation.BoundParameters.ContainsKey("filter"))
    {
        $searchObj.filter = $Filter
    }
    Write-Verbose -Message ("Request URL : " + $requestUri)
    Write-Verbose ("Search condition")
    Write-Verbose ("$searchObj")
    $indexData = New-Object psobject -Property $searchObj
    $data = $indexData | ConvertTo-Json
    if($AsJson)
    {
        Write-Output $data
    }
    else
    {
        $body = [System.Text.Encoding]::UTF8.GetBytes($data)
        $result = Invoke-WebRequest -Uri $requestUri -Method Post -Headers $BaseRequestHeaders -Body $body
        Write-Verbose -Message ("Status Code : " + $result.StatusCode)
        Write-Verbose -Message ("Description : " + $result.StatusDescription)
        $result.content | ConvertFrom-Json | ForEach-Object value
    }
}

function Remove-AzureSearchIndex {
    [CmdletBinding(
                  SupportsShouldProcess=$true, 
                  PositionalBinding=$false,
                  HelpUri = 'http://www.microsoft.com/',
                  ConfirmImpact='Medium')]
    Param(
        [string]$Name,
        [switch]$AsJson
         )
    Write-Verbose -Message ("Remove-AzureSearchIndex")
    $AppStr = "indexes/" + $Name

    $URI = $AzureSearchService + $AppStr + $AzureSearchAPIVersion
    Write-Verbose -Message ("Request URL : " + $URI)
    $result = Invoke-WebRequest -Uri $URI -Headers $BaseRequestHeaders -Method Delete
    Write-Verbose -Message ("Status Code : " + $result.StatusCode)
    Write-Verbose -Message ("Description : " + $result.StatusDescription)
}

function Get-AzureSearchIndex {
    [CmdletBinding(
            SupportsShouldProcess=$true, 
            PositionalBinding=$true)]
    Param([string]$Name)
    Write-Verbose -Message ("Get-AzureSearchIndex")
    
    if([string]::IsNullOrEmpty($Name) -or ($Name -eq '*'))
    {
        $uri = $AzureSearchService + "indexes" + $AzureSearchAPIVersion
    }
    else
    {
        $appStr = "indexes/" + $Name
        $uri = $AzureSearchService + $appStr + $AzureSearchAPIVersion
    }

    Write-Verbose -Message ("Request URL : " + $uri)

    $result = Invoke-WebRequest -Uri $uri -Headers $BaseRequestHeaders -Method Get
    Write-Verbose -Message ("Status Code : " + $result.StatusCode)
    Write-Verbose -Message ("Description : " + $result.StatusDescription)
    $result.content | ConvertFrom-Json | Out-JsonObject
}


Export-ModuleMember -Function *
#Export-ModuleMember -Function Connect-AzureSearch,Get-AzureSearchIndex,New-AzureSearchField,New-AzureSearchIndex,Remove-AzureSearchIndex,Search-AzureSearch
