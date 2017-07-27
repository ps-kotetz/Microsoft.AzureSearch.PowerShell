# 最初に Connect してねのエラーメッセージ

# search-AzureSearch -name  | 

$AzureSearchKey = ""
$AzureSearchService = ""
$AzureSearchAPIVersion=""
$BaseRequestHeaders=$null

## Dynamic Functions ##
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

$TypeValueObjectTable=@{
    "Edm.String" = [String]
    "Collection(Edm.String)"=[String[]]
    "Edm.Boolean"=[Boolean]
    "Edm.Int32" = [Int32]
    "Edm.Int64" = [Int64]
    "Edm.Double"= [Double]
    "Edm.DateTimeOffset"=[DateTimeOffset]
    "Edm.GeographyPoint" = [string]
}

$IndexDefinitionTable = @{ 
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
    
    $result = Invoke-WebRequest -Uri $requestUri -Method Post -Headers $BaseRequestHeaders -Body $body
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

    $result = Invoke-WebRequest -Uri $requestUri -Method Post -Headers $BaseRequestHeaders -Body $body
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

    $result = Invoke-WebRequest -Uri $requestUri -Method Post -Headers $BaseRequestHeaders -Body $body
}}

Export-ModuleMember -Function *Document
'@




function Update-AzureSearchSubModule{
<#
 .SYNOPSIS
 Generate Index specific funtions 

 .DESCRIPTION
 The Update-AzureSearchSubModule cmdlet generates index specific functions from index information.
 
 .EXAMPLE
 Update-AzureSearchSubModule

 This examples generates index specific functions
#>
    $script:IndexDefinitionTable = @{}
    $uri = $Script:AzureSearchService + "indexes" + $Script:AzureSearchAPIVersion
    $global:indexList = (Invoke-WebRequest -Headers $BaseRequestHeaders -Uri $uri -Method Get).Content | ConvertFrom-Json

    foreach($indexInfo in $global:indexList.Value){
        
        $indexName =  $indexInfo.name

        $script:IndexDefinitionTable[$indexName] = $indexInfo

        $UpperindexName = [char]::ToUpper($indexInfo.name[0]) + $indexInfo.name.Substring(1)
        $keyField = $indexInfo.fields | Where-Object key -eq "true"
        $nonKeyField = $indexInfo.fields | Where-Object key -ne "true"

       
        

        $keyFieldParameterName = $keyField.name
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
<#
 .SYNOPSIS
 Stores AzureSearch related parameters to scrip variable to be used in other functions.

 .DESCRIPTION
 The Connect-AzureSearch cmdlet lets you store AzureSearch parameters to scrip variable to be used in other functions.

 .parameter Key
 Azure Search Admin Key.

 .parameter ServiceName
 Azure Search service name. If your search uri is https://mysearch.search.windows.net/, then mysearch is the service name.

 .parameter APIVersion
 Azure Search API version. (optional)

 .EXAMPLE
 Connect-AzureSearch -Key j3fjejfzjo3ifjijf -ServiceName mysearch

 This examples connects to Azure Search of https://mysearch.search.windows.net/
#>
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
<#
 .SYNOPSIS
 Create new Azure Serach Field

 .DESCRIPTION
 The New-AzureSearchField cmdlet lets create new Azure Serach field

 .PARAMETER Name
 Azure Search field Name.

 .PARAMETER Type
 The data type for the field. See https://docs.microsoft.com/en-us/rest/api/searchservice/supported-data-types for more deatil.

 .PARAMETER Searchable
 Marks the field as full-text search-able. This means it will undergo analysis such as word-breaking during indexing. If you set a searchable field to a value like "sunny day", internally it will be split into the individual tokens "sunny" and "day". This enables full-text searches for these terms. Fields of type Edm.String or Collection(Edm.String) are searchable by default. Fields of other types are not searchable. Note: searchable fields consume extra space in your index since Azure Search will store an additional tokenized version of the field value for full-text searches. If you want to save space in your index and you don't need a field to be included in searches, set searchable to false.

 .PARAMETER Filterable
 Allows the field to be referenced in $filter queries. filterable differs from searchable in how strings are handled. Fields of type Edm.String or Collection(Edm.String) that are filterable do not undergo word-breaking, so comparisons are for exact matches only. For example, if you set such a field f to "sunny day", $filter=f eq 'sunny' will find no matches, but $filter=f eq 'sunny day' will. All fields are filterable by default.

 .PARAMETER Sortable
 By default the system sorts results by score, but in many experiences users will want to sort by fields in the documents. Fields of type Collection(Edm.String) cannot be sortable. All other fields are sortable by default.

 .PARAMETER Facetable
 Typically used in a presentation of search results that includes hit count by category (e.g. search for digital cameras and see hits by brand, by megapixels, by price, etc.). This option cannot be used with fields of type Edm.GeographyPoint. All other fields are facetable by default. Note: Fields of type Edm.String that are filterable, sortable, or facetable can be at most 32 kilobytes in length. This is because such fields are treated as a single search term, and the maximum length of a term in Azure Search is 32K kilobytes. If you need to store more text than this in a single string field, you will need to explicitly set filterable, sortable, and facetable to false in your index definition. Note: If a field has none of the above attributes set to true (searchable, filterable, sortable, facetable) the field is effectively excluded from the inverted index. This option is useful for fields that are not used in queries, but are needed in search results. Excluding such fields from the index improves performance.

 .PARAMETER IsKey
 Marks the field as containing unique identifiers for documents within the index. Exactly one field must be chosen as the key field and it must be of type Edm.String. Key fields can be used to look up documents directly. See Lookup Document (Azure Search Service REST API) for details.

 .PARAMETER Retrievable
 Sets whether the field can be returned in a search result. This is useful when you want to use a field (e.g., margin) as a filter, sorting, or scoring mechanism but do not want the field to be visible to the end user. This attribute must be true for key fields

 .PARAMETER Analyzer
 Sets the name of the language analyzer to use for the field. For the allowed set of values see Language support (Azure Search Service REST API). This option can be used only with searchable fields and it can't be set together with either searchAnalyzer or indexAnalyzer. Once the analyzer is chosen, it cannot be changed for the field.

 .EXAMPLE
 New-AzureSearchField -Name hotelId -Type Edm.String -isKey -Retrievable

 This exmaple creates new key field as string type.

 .EXAMPLE
 New-AzureSearchField -Name baseRate -Type Edm.Double

 This exmaple creates a field as double type.

 #>
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

function New-AzureSearchSuggester{
<#
 .SYNOPSIS
 Create new Azure Serach Suggester

 .DESCRIPTION
 The New-AzureSearchField cmdlet lets create new Azure Serach field

 .PARAMETER Name
 Azure Search suggester name.

 .PARAMETER SearchMode
 Azure Search suggester search mode.

 .PARAMETER SourceFields
 Suggestion target fields.

 .EXAMPLE
 New-AzureSearchSuggester -Name mySuggester -SourceFields [ID, NAME, AGE] 

 This exmaple creates new key field as string type.

 #>
    [CmdletBinding(
            SupportsShouldProcess=$true, 
            PositionalBinding=$true)]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$SearchMode="analyzingInfixMatching",
        [Parameter(Mandatory=$true)]
        [string]$SourceFields
    )

    $fieldData=[ordered]@{
        name=$Name
        searchMode=$SearchMode
        sourceFields=$SourceFields
    }
    New-Object psobject -Property $fieldData
}

function New-AzureSearchIndex{
<#
 .SYNOPSIS
 Create new Azure Serach index

 .DESCRIPTION
 The New-AzureSearchIndex cmdlet lets create new Azure Serach inde

 .PARAMETER Name
 Azure Search index Name.

 .PARAMETER Fields
 Fields to be added to the index. You can use New-AzureSearchField function to create fields.

 .PARAMETER Suggesters
 Suggesters to be added to the index. You can use New-AzureSearchSuggester function to create fields.

 .PARAMETER JsonRequest
 When specified, result is returned as json object.

 .EXAMPLE
 $fields= & {
        New-AzureSearchField -Name hotelId -Type Edm.String -isKey -Retrievable
        New-AzureSearchField -Name baseRate -Type Edm.Double
        New-AzureSearchField -Name description -Type Edm.String -Retrievable -Searchable
        New-AzureSearchField -Name description_fr -Type Edm.String -Analyzer "fr.lucene" -Searchable
        New-AzureSearchField -Name hotelName -Type Edm.String -Retrievable
        New-AzureSearchField -Name category -Type Edm.String -Filterable
        New-AzureSearchField -Name tags -Type 'Collection(Edm.String)' -Searchable
        New-AzureSearchField -Name parkingINcluded -Type Edm.Boolean
        New-AzureSearchField -Name smokingAllowed -Type Edm.Boolean
        New-AzureSearchField -Name lastRenovationDate -Type Edm.DateTimeOffset
        New-AzureSearchField -Name rating -Type Edm.Int32 -Filterable
        New-AzureSearchField -Name location -Type Edm.GeographyPoint
 }
 New-AzureSearchIndex -Name hotels -Fields $fields -Verbose

 This example creates an index with 12 fields.
#>
    [CmdletBinding(
            SupportsShouldProcess=$true, 
            PositionalBinding=$true)]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        $Fields,
        [Parameter(Mandatory=$true)]
        $Suggesters,
        [switch]$JsonRequest
        )
    Write-Verbose -Message ("New-AzureSearchIndex")
    $requestUri = $AzureSearchService + "indexes" + $AzureSearchAPIVersion
    $props =[ordered]@{
        name = $Name
        fields = $Fields
        suggesters = $Suggesters
    }
    
    $indexData = New-Object psobject -Property $props
    Write-Verbose -Message ("Request URL : " + $requestUri)
    Write-Verbose ("Index definition")
    Write-Verbose ($indexData)

    if($JsonRequest)
    {
        Get-PostResult -Uri $requestUri -Object $indexData -JsonRequest
    }
    else
    {
        Get-PostResult -Uri $requestUri -Object $indexData 
    }
    Update-AzureSearchSubModule
}

function Get-AzureSearchIndex {
<#
 .SYNOPSIS
 Get existing Azure Serach index(es)

 .DESCRIPTION
 The Get-AzureSearchIndex cmdlet lets get existing Azure Serach index(es)

 .PARAMETER Name
 Azure Search index Name. If you omit name, you get all existing index(es).

 .EXAMPLE
 Get-AzureSearchIndex -Name hotels 

 This example gets hotels index.

 .EXAMPLE
 Get-AzureSearchIndex
 This example gets all indexes.
#>
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

function Remove-AzureSearchIndex {
<#
 .SYNOPSIS
 Delete an Azure Serach index

 .DESCRIPTION
 The Remove-AzureSearchIndex cmdlet lets delete an Azure Serach index

 .PARAMETER Name
 Azure Search index Name.
  
 .EXAMPLE
 Remove-AzureSearchIndex -Name hotels

 This example deletes hotels index.
#>
    [CmdletBinding(
                  SupportsShouldProcess=$true, 
                  PositionalBinding=$false)]
    Param(
        [string]$Name
         )
    Write-Verbose -Message ("Remove-AzureSearchIndex")
    $AppStr = "indexes/" + $Name

    $URI = $AzureSearchService + $AppStr + $AzureSearchAPIVersion
    Write-Verbose -Message ("Request URL : " + $URI)
    $result = Invoke-WebRequest -Uri $URI -Headers $BaseRequestHeaders -Method Delete
    Write-Verbose -Message ("Status Code : " + $result.StatusCode)
    Write-Verbose -Message ("Description : " + $result.StatusDescription)
}

function Add-AzureSearchDocument{
<#
 .SYNOPSIS
 Add new document(s) to the index.

 .DESCRIPTION
 The Add-AzureSearchDocument cmdlet lets you add new document(s) to the index.

 .PARAMETER InputObject
 You can pass documents data from pipe.

 .PARAMETER IndexName
 Azure Search index Name to add documents.

 .PARAMETER DocumentData
 Documemtns to be added to the index.

 .PARAMETER JsonRequest
 When specified, result is returned as json object.

 .EXAMPLE
 Add-AzureSearchDocument -IndexName hotels -DocumentData @{hotelId=01;hotelName="nicerHotel";description="Nice Hotel";rating=1} -Verbose

 This example add a document to hotels index.

 .EXAMPLE
 Import-Csv hoteldata.csv | Add-AzureSearchDocument
 
 This example bulk add documents. Index name will be automatically found from fields information.
#>
    [CmdletBinding(
                SupportsShouldProcess=$true, 
                PositionalBinding=$true)]
    Param(
            [Parameter(ParameterSetName="PipeLine",ValueFromPipeline=$true,Mandatory=$true)][PSObject]$InputObject,
            [string]$IndexName,
            [Parameter(ParameterSetName="CmdLine")][System.Collections.Hashtable]$DocumentData,
            
            [switch]$JsonRequest
        )
    Process{
    
        switch ($PsCmdlet.ParameterSetName) 
        {
            "CmdLine" {
                $requestUri = $AzureSearchService + "indexes/" + $IndexName + "/docs/index" + $AzureSearchAPIVersion
                $fieldMetadata = $IndexDefinitionTable[$IndexName]
                $keyFieldName = Get-KeyField -IndexName $IndexName
                $objectData = [ordered]@{
                    '@search.action'='upload';
                    $keyFieldName=$DocumentData[$keyFieldName] -as (Get-FieldTypeData -IndexName $IndexName -FieldName $keyFieldName)
                }
                $DocumentData.Remove($keyFieldName)

                # Fix data type for input
                if($DocumentData -ne $null)
                {
                    foreach($currentKey in $DocumentData.Keys)
                    {
                        $fieldMetadata = $IndexDefinitionTable[$IndexName].fields | Where-Object {$_.name -eq $currentKey} 
                        $metadataType = $TypeValueObjectTable[$fieldMetadata.type]
                        $objectData[$currentKey] = $DocumentData[$currentKey] -as $metadataType
                    }
                }
            }
            "PipeLine" {
                 $fields = $InputObject | Get-Member -MemberType *Property* | % name
                 $tmpIndexName = (Get-LikelyIndex -Fields $fields).fieldName

                 $requestUri = $AzureSearchService + "indexes/" + $tmpIndexName + "/docs/index" + $AzureSearchAPIVersion
                 $keyFieldName = Get-KeyField -IndexName $tmpIndexName
                 $objectData = [ordered]@{
                    '@search.action'='upload';
                    $keyFieldName=$InputObject.$keyFieldName -as (Get-FieldTypeData -IndexName $tmpIndexName -FieldName $keyFieldName)
                }
                $fields = $fields | Where-Object {$_ -ne $keyFieldName}

                foreach($currentKey in $fields)
                {
                    $fieldMetadata = $IndexDefinitionTable[$tmpIndexName].fields | Where-Object {$_.name -eq $currentKey} 
                    $metadataType = $TypeValueObjectTable[$fieldMetadata.type]
                    if(-not [string]::IsNullOrEmpty($InputObject.$currentKey)){
                        $objectData[$currentKey] = $InputObject.$currentKey -as $metadataType
                    }
                }
            }
        }
        $uploadObject = New-Object psobject |  Add-Member -NotePropertyName value -NotePropertyValue @(New-Object psobject -Property $objectData) -PassThru
        if($JsonRequest)
        {
            Get-PostResult -Uri $requestUri -Object $uploadObject -JsonRequest
        }
        else
        {
            Get-PostResult -Uri $requestUri -Object $uploadObject 
        }
    }
}

function Merge-AzureSearchDocument{
<#
 .SYNOPSIS
 Update existing document in the index.

 .DESCRIPTION
 The Merge-AzureSearchDocument cmdlet lets you update existing document in the index
 
 .PARAMETER IndexName
 Azure Search index Name to add documents.

 .PARAMETER DocumentData
 Documemtns to be added to the index.

 .PARAMETER MergeOrUpload
 When specified, it behaves like merge if a document with the given key already exists in the index. If the document does not exist, it adds a new document. 
 If not specified and no matching document exists, it fails.

 .PARAMETER JsonRequest
 When specified, result is returned as json object.

 .EXAMPLE
 Merge-AzureSearchDocument -IndexName hotels -DocumentData @{hotelId=01;name="nicerHotel";description="Nice Hotel";rating=1}

 This example update a document with hotelId 01 with new value. If no such document, it fails.

 .EXAMPLE
 Merge-AzureSearchDocument -IndexName hotels -DocumentData @{hotelId=01;name="nicerHotel";description="Nice Hotel";rating=1} -MergeOrUpload

 This example update a document with hotelId 01 with new value. If no such document, it adds new document.
#>
    [CmdletBinding(
                SupportsShouldProcess=$true, 
                PositionalBinding=$true)]
    Param(
            [Parameter(Mandatory=$true)][string]$IndexName,
            [System.Collections.Hashtable]$DocumentData,
            [switch]$MergeOrUpload,
            [switch]$JsonRequest
        )
    $requestUri = $AzureSearchService + "indexes/" + $IndexName + "/docs/index" + $AzureSearchAPIVersion
    $fieldMetadata = $IndexDefinitionTable[$IndexName]
    $keyFieldName=Get-KeyField -IndexName $IndexName
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
         $keyFieldName=$DocumentData[$keyFieldName] -as (Get-FieldTypeData -IndexName $IndexName -FieldName $keyFieldName)
    }
    $DocumentData.Remove($keyFieldName)
    if($DocumentData -ne $null)
    {
        foreach($currentKey in $DocumentData.Keys)
        {
            $fieldMetadata = $IndexDefinitionTable[$IndexName].fields | Where-Object {$_.name -eq $currentKey} 
            $metadataType = $TypeValueObjectTable[$fieldMetadata.type]
            $objectData[$currentKey] = $DocumentData[$currentKey] -as $metadataType
        }
    }
    $uploadObject = New-Object psobject |  Add-Member -NotePropertyName value -NotePropertyValue @(New-Object psobject -Property $objectData) -PassThru
    if($JsonRequest)
    {
        Get-PostResult -Uri $requestUri -Object $uploadObject -JsonRequest
    }
    else
    {
        Get-PostResult -Uri $requestUri -Object $uploadObject 
    }
}

function Remove-AzureSearchDocument{
<#
 .SYNOPSIS
 Removes existing document from the index.

 .DESCRIPTION
 The Add-AzureSearchDocument cmdlet lets you removes existing document from the index.
 
 .PARAMETER IndexName
 Azure Search index Name to add documents.

 .PARAMETER KeyFieldName
 The key field name of the index.

 .PARAMETER KeyFieldValue
 The value of the key field.

 .PARAMETER JsonRequest
 When specified, result is returned as json object.

 .EXAMPLE
 Remove-AzureSearchDocument -IndexName hotels -KeyFieldName hotelId -KeyFieldValue 01

 This example removes a document with key value of 01 from the hotels index.

#>
    [CmdletBinding(
                SupportsShouldProcess=$true, 
                PositionalBinding=$true)]
    Param(
            [Parameter(Mandatory=$true)][string]$KeyFieldName,
            [Parameter(Mandatory=$true)][string]$KeyFieldValue,
            [Parameter(Mandatory=$true)][string]$IndexName,
            [switch]$JsonRequest
        )

    $requestUri = $AzureSearchService + "indexes/" + $IndexName + "/docs/index" + $AzureSearchAPIVersion
    $objectData=[ordered]@{ 
        '@search.action'='delete';
        $KeyFieldName=$KeyFieldValue
    }
    $uploadObject = New-Object psobject |  Add-Member -NotePropertyName value -NotePropertyValue @(New-Object psobject -Property $objectData) -PassThru
    if($JsonRequest)
    {
        Get-PostResult -Uri $requestUri -Object $uploadObject -JsonRequest
    }
    else
    {
        Get-PostResult -Uri $requestUri -Object $uploadObject 
    }
}

function Search-AzureSearch{
<#
 .SYNOPSIS
 Search Azure Search index

 .DESCRIPTION
 The Search-AzureSearch cmdlet lets you search Azure Search index.

 .PARAMETER IndexName
 Azure Search index Name to search documents.

 .PARAMETER SearchString
 Search Criteria.

 .PARAMETER FieldSelection
 Specify field names to retrieve. If you omit it, it gets all fields.

 .PARAMETER Filter
 Specify filter condition.

 .PARAMETER JsonRequest
 When specified, result is returned as json object.

 .EXAMPLE
 Search-AzureSearch -IndexName hotels -SearchString nice -Fields hotelName,rating,description

 This example search the hotels index by 'nice' criteria and retrieves specified fields.

 .EXAMPLE
 Search-AzureSearch -IndexName hotels -SearchString good -Fileter 'ratring eq 1'
 
 This example search the hotels which has 1 rating.
#>
    [CmdletBinding(
            SupportsShouldProcess=$true, 
            PositionalBinding=$true)]
    Param(
        [Parameter(Mandatory=$true)][string]$IndexName,
        [string]$SearchString,
        [string]$FieldSelection="*",
        [string]$Filter,
        [switch]$JsonRequest
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

    if($JsonRequest)
    {
        Get-PostResult -Uri $requestUri -Object $indexData -JsonRequest
    }
    else
    {
        Get-PostResult -Uri $requestUri -Object $indexData 
    }
}

## by Mubaatar
function Suggest-AzureSearch{
<#
 .SYNOPSIS
 Suggest Azure Search document

 .DESCRIPTION
 The Suggest-AzureSearch cmdlet suggests you an Azure Search document.

 .PARAMETER IndexName
 Azure Search index Name to search documents.

 .PARAMETER SearchString
 Search Criteria.

 .PARAMETER FieldSelection
 Specify field names to retrieve. If you omit it, it gets all fields.

 .PARAMETER Filter
 Specify filter condition.

 .PARAMETER SuggesterName
 Determines which fields are scanned for suggested query terms.

 .PARAMETER Fuzzy
 When set to true, this API finds suggestions even if there is a substituted or missing character in the search text. 

 .PARAMETER Top
 The number of suggestions to retrieve.

 .PARAMETER OrderBy
 A list of comma-separated expressions to sort the results by. 

 .PARAMETER JsonRequest
 When specified, result is returned as json object.

 .EXAMPLE
 Suggest-AzureSearch -IndexName hotels -SearchString nice -Fields hotelName,rating,description -SuggesterName 

 This example search the hotels index by 'nice' criteria and retrieves specified fields.

 .EXAMPLE
 Suggest -IndexName hotels -SearchString goo -Fileter 'ratring eq 1'
 
 This example search the hotels which has 1 rating.
#>
    [CmdletBinding(
            SupportsShouldProcess=$true, 
            PositionalBinding=$true)]
    Param(
        [Parameter(Mandatory=$true)][string]$IndexName,
        [string]$SearchString,
        [string]$FieldSelection="*",
        [string]$Filter,
        [string]$SuggesterName,
        [boolean]$Fuzzy=$false,
        [Int32]$Top=10,
        [string]$OrderBy,
        [switch]$JsonRequest
        )
    Write-Verbose -Message ("Suggest-AzureSearch")
    $requestUri = $AzureSearchService + "indexes/" + $IndexName + "/docs/suggest" + $AzureSearchAPIVersion
    $searchObj=[ordered]@{
        search = $SearchString
        select = $FieldSelection 
        suggesterNeame = $SuggesterName
    }
    if($MyInvocation.BoundParameters.ContainsKey("filter"))
    {
        $searchObj.filter = $Filter
    }
    if($MyInvocation.BoundParameters.ContainsKey("fuzzy"))
    {
        $searchObj.filter = $Fuzzy
    }
    if($MyInvocation.BoundParameters.ContainsKey("top"))
    {
        $searchObj.filter = $Top
    }
    if($MyInvocation.BoundParameters.ContainsKey("orderby"))
    {
        $searchObj.filter = $OrderBy
    }
    Write-Verbose -Message ("Request URL : " + $requestUri)
    Write-Verbose ("Suggest condition")
    Write-Verbose ("$searchObj")
    $indexData = New-Object psobject -Property $searchObj

    if($JsonRequest)
    {
        Get-PostResult -Uri $requestUri -Object $indexData -JsonRequest
    }
    else
    {
        Get-PostResult -Uri $requestUri -Object $indexData 
    }
}

## Private functions ##
function Check-AzureConnection{
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

function Get-LikelyIndex{
    Param([string[]]$Fields)
    $scorelist=@()
    $keys=$IndexDefinitionTable.Keys
    for ($i=0 ; $i -lt $keys.Count ; $i++)
    {
        $props =@{
            fieldName = $keys[$i]
            similerity= (Compare-Object $Fields ($IndexDefinitionTable[$keys].fields | % name) -IncludeEqual -ExcludeDifferent).count
        }
        $scorelist+=New-Object psobject -Property $props
    }

    $sortedScore=$scorelist | Sort-Object similerity -Descending 
    # return similerity MAX. this could be multiple value
    $sortedScore | Where-Object {$_.similerity -eq $sortedScore[0].similerity}
}

function Get-KeyField{
    Param([string]$IndexName)
    ($IndexDefinitionTable[$IndexName].fields | Where-Object {$_.key -eq "True"}).name
}

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

function Get-PostResult{
    Param($Uri,$Object,[switch]$JsonRequest)
    $jsonData = $Object | ConvertTo-Json
    if($JsonRequest)
    {
        Write-Output $jsonData
    }
    else
    {
        $body = [System.Text.Encoding]::UTF8.GetBytes($jsonData)
        $result = Invoke-WebRequest -Uri $Uri -Method Post -Headers $Script:BaseRequestHeaders -Body $body
        $resultData = $result.content | ConvertFrom-Json
        if($resultData.Value -eq $null)
        {
            $resultData
        }
        else
        {
            $resultData.Value
        }
    }
}

function Get-FieldTypeData {
    Param([string]$IndexName,[string]$FieldName)
    $fieldMetadata = $IndexDefinitionTable[$IndexName].fields | Where-Object {$_.name -eq $FieldName} 
    $TypeValueObjectTable[$fieldMetadata.type]
}


Export-ModuleMember -Function *AzureSearch*
#Export-ModuleMember -Function Connect-AzureSearch,Get-AzureSearchIndex,New-AzureSearchField,New-AzureSearchIndex,Remove-AzureSearchIndex,Search-AzureSearch
