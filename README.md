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
Connect-AzureSearch -Key $AzureKey -ServiceName mshack2017 -Verbose
```

#### Remove the existing Index called zipcode

```powershell
Remove-AzureSearchIndex -Name "zipcode" -verbose
```

#### Create some fields for the index

```powershell
$fields = & {
    New-AzureSearchField -Name countryID -Type Edm.String
    New-AzureSearchField -Name zipCode -Type Edm.String
    New-AzureSearchField -Name zipCodeFull -Type Edm.String -IsKey -Retrievable    
    New-AzureSearchField -Name stateName -Type Edm.String
    New-AzureSearchField -Name cityName -Type Edm.String
    New-AzureSearchField -Name townName -Type Edm.String
    New-AzureSearchField -Name stateNameKanji -Type Edm.String
    New-AzureSearchField -Name cityNameKanji -Type Edm.String
    New-AzureSearchField -Name townNameKanji -Type Edm.String
}
```
 
#### Create a new index with the fields above

```powershell
New-AzureSearchIndex -Name zipcode -Fields $fields -Verbose
```

#### Get the index created above

```powershell 
Get-AzureSearchIndex -Name zipcode -Verbose
```

#### Upload a random document

```powershell
Add-AzureSearchZipcodeDocument -countryID 134 -zipCode 345 -zipCodeFull 445544 -stateName "aaa" -cityName "bbbb" -townName "ccc" -stateNameKanji "jjj" -cityNameKanji "llll" -townNameKanji "uuuuu"
```

#### Upload more data from [Japanese Zip Code List] (http://www.post.japanpost.jp/zipcode/dl/readme.html)
##### Download the .csv file, delete after 10th column, and save it as "data.csv"

```powershell
Import-Csv -UseCulture .\data.csv | Add-AzureSearchDocument -IndexName zipcode
```

#### Update a document

```powershell
Merge-AzureSearchZipcodeDocument -zipCodeFull 445544 -stateName ccccc -cityName dddd
Merge-AzureSearchDocument  -KeyFieldName zipCodeFull -KeyFieldValue 445544 -IndexName zipcode -DocumentData @{townName="llll"}
```

#### Remove some documents

```powershell
Remove-AzureSearchDocument -KeyFieldName zipCodeFull -KeyFieldValue 445544 -IndexName zipcode
```

#### Search a document

```powershell
Search-AzureSearch -IndexName zipcode -SearchString *港区
```
