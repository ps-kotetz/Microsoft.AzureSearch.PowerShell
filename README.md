# Microsoft.AzureSearch.PowerShell
This is a PowerShell module for Azure Search.
See detali at [Azure Search](https://azure.microsoft.com/en-us/services/search/)

## Installation
```C#
Install-Module -Name AzureSearch
```

### Dependencies
This module has no dependencies.

### Minimum PowerShell version
4.0

## How to use

#### Connect to Azure using a credential stored in the variable AzureKey
```powershell
Connect-AzureSearch -Key $AzureKey -ServiceName psazuresearch -Verbose
```

#### Remove the existing Index called hotels

```powershell
Remove-AzureSearchIndex -Name "hotels" -verbose
```

#### Create some fields for the index

```powershell
$fields= & {
     New-AzureSearchField -Name hotelId -Type Edm.String -isKey -Retrievable
     New-AzureSearchField -Name baseRate -Type Edm.Double
     New-AzureSearchField -Name description -Type Edm.String -Retrievable
     New-AzureSearchField -Name description_fr -Type Edm.String -Analyzer "fr
     New-AzureSearchField -Name hotelName -Type Edm.String
     New-AzureSearchField -Name category -Type Edm.String
     New-AzureSearchField -Name tags -Type 'Collection(Edm.String)'
     New-AzureSearchField -Name parkingINcluded -Type Edm.Boolean
     New-AzureSearchField -Name smokingAllowed -Type Edm.Boolean
     New-AzureSearchField -Name lastRenovationDate -Type Edm.DateTimeOffset
     New-AzureSearchField -Name rating -Type Edm.Int32
     New-AzureSearchField -Name location -Type Edm.GeographyPoint
 }
```
 
#### Create a new index with the fields above

```powershell 
New-AzureSearchIndex -Name hotels -Fields $fields -Verbose -JsonRequest
New-AzureSearchIndex -Name hotels -Fields $fields -Verbose
```

#### Get the index created above

```powershell 
Get-AzureSearchIndex -Name hotels -Verbose
```

#### Upload some dummy data

```powershell
Add-AzureSearchHotelsDocument -hotelId 01 -hotelName nicerHotel -category business -description "very nice hotel" -rating 1 -
Add-AzureSearchHotelsDocument -hotelId 02 -hotelName nicerHotel2 -category business -description "very nice hotel2" -rating 2
Add-AzureSearchHotelsDocument -hotelId 03 -hotelName nicerHotel3 -category business -description "very nice hotel3" -rating 3
```

#### Update and upload some data

``powershell 
Merge-AzureSearchHotelsDocument -hotelId 02 -hotelName nicehotel2-2 -description updated
Add-AzureSearchDocument -KeyFieldName hotelId -KeyFieldValue 04 -IndexName hotels -DocumentData @{description="Not VeryNice";
Merge-AzureSearchDocument  -KeyFieldName hotelId -KeyFieldValue 04 -IndexName hotels -DocumentData @{description="Not VeryNic
Merge-AzureSearchDocument  -KeyFieldName hotelId -KeyFieldValue 05 -IndexName hotels -MergeOrUpload -Verbose
Merge-AzureSearchDocument  -KeyFieldName hotelId -KeyFieldValue 05 -IndexName hotels -DocumentData @{description="Not VeryNic
```

#### Remove some documents

```powershell
Remove-AzureSearchDocument -KeyFieldName hotelId -KeyFieldValue 04 -IndexName hotels
```

#### Search a document

```powershell 
Search-AzureSearch -IndexName hotels -SearchString *
```
