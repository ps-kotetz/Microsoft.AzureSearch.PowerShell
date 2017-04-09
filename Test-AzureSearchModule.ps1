$AzureKey=""

function Test-AzureSearchModule{

    Write-Host -ForegroundColor Yellow "Unload Microsoft.AzureSearch.PowerShell module"
    Remove-Module AzureSearch*
    Write-Host -ForegroundColor Yellow "Load Microsoft.AzureSearch.PowerShell module"
    Import-Module AzureSearch
    Write-Host -ForegroundColor Yellow "Invoke Connect-AzureSearch"
    Connect-AzureSearch -Key $AzureKey -ServiceName psazuresearch -Verbose
    
    Remove-AzureSearchIndex -Name "hotels" -verbose
    Remove-AzureSearchIndex -Name "hotels2" -Verbose

    Write-Host -ForegroundColor Yellow "Define index fields"
    $fields= & {
        New-AzureSearchField -Name hotelId -Type Edm.String -isKey -Retrievable
        New-AzureSearchField -Name baseRate -Type Edm.Double
        New-AzureSearchField -Name description -Type Edm.String -Retrievable
        New-AzureSearchField -Name description_fr -Type Edm.String -Analyzer "fr.lucene" -Searchable
        New-AzureSearchField -Name hotelName -Type Edm.String
        New-AzureSearchField -Name category -Type Edm.String
        New-AzureSearchField -Name tags -Type 'Collection(Edm.String)'
        New-AzureSearchField -Name parkingINcluded -Type Edm.Boolean
        New-AzureSearchField -Name smokingAllowed -Type Edm.Boolean
        New-AzureSearchField -Name lastRenovationDate -Type Edm.DateTimeOffset
        New-AzureSearchField -Name rating -Type Edm.Int32
        New-AzureSearchField -Name location -Type Edm.GeographyPoint
    }

    Write-Host -ForegroundColor Yellow "Create new indexes"
    New-AzureSearchIndex -Name hotels -Fields $fields -Verbose
    New-AzureSearchIndex -Name hotels2 -Fields $fields -Verbose
    
    Write-Host -ForegroundColor Yellow "Get created indexes"
    Get-AzureSearchIndex -Name hotels -Verbose
    Get-AzureSearchIndex -Name hotels2 -Verbose

    
    Write-Host -ForegroundColor Yellow "Upload test data"
    Add-AzureSearchHotelsDocument -KeyFeild_hotelId 01 -hotelName nicerHotel -category business -description "very nice hotel" -rating 1 -Verbose
    Add-AzureSearchHotelsDocument -KeyFeild_hotelId 02 -hotelName nicerHotel2 -category business -description "very nice hotel2" -rating 2 -Verbose
    Add-AzureSearchHotelsDocument -KeyFeild_hotelId 03 -hotelName nicerHotel3 -category business -description "very nice hotel3" -rating 3 -Verbose

    Add-AzureSearchHotels2Document -KeyFeild_hotelId 01 -hotelName nonNicerHotel -category business -description "not very nice hotel1" -rating 2 -Verbose
    Add-AzureSearchHotels2Document -KeyFeild_hotelId 02 -hotelName nonNicerHotel2 -category business -description "not very nice hotel2" -rating 3 -Verbose
    Add-AzureSearchHotels2Document -KeyFeild_hotelId 03 -hotelName nonNicerHotel3 -category business -description "not very nice hotel3" -rating 1 -Verbose

    Write-Host -ForegroundColor Yellow "Search test data"
    Search-AzureSearch -IndexName hotels -SearchString *
    Search-AzureSearch -IndexName hotels2 -SearchString hoge
 
}
