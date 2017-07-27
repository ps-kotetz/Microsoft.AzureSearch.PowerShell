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

#### Remove the existing Index called _zipcodenew_

```powershell
Remove-AzureSearchIndex -Name "zipcodenew" -verbose
```

#### Create some fields for the index

```powershell
$fields = & {
        New-AzureSearchField -Name countryID -Type Edm.String -Retrievable -Searchable
        New-AzureSearchField -Name zipCode -Type Edm.String -Retrievable -Searchable
        New-AzureSearchField -Name zipCodeFull -Type Edm.String -IsKey -Retrievable -Searchable
        New-AzureSearchField -Name stateName -Type Edm.String -Retrievable -Searchable
        New-AzureSearchField -Name cityName -Type Edm.String -Retrievable -Searchable 
        New-AzureSearchField -Name townName -Type Edm.String -Retrievable -Searchable 
        New-AzureSearchField -Name stateNameKanji -Type Edm.String -Retrievable -Searchable
        New-AzureSearchField -Name cityNameKanji -Type Edm.String -Retrievable -Searchable 
        New-AzureSearchField -Name townNameKanji -Type Edm.String -Retrievable -Searchable
}
```
 
#### Create a new index with the fields above

```powershell
New-AzureSearchIndex -Name zipcodenew -Fields $fields -Verbose
```

#### Get the index created above

```powershell 
Get-AzureSearchIndex -Name zipcodenew -Verbose
```

#### Upload a random document

```powershell
Add-AzureSearchZipcodenewDocument -countryID 134 -zipCode 345 -zipCodeFull 445544 -stateName "aaa" -cityName "bbbb" -townName "ccc" -stateNameKanji "jjj" -cityNameKanji "llll" -townNameKanji "uuuuu"
```

###### You see the function ```Add-AzureSearchZipcodenewDocument ``` is created automatically with index creation. It saves us from forgetting the fields names. Isn't it cool? 

#### Upload more data from [Japanese Zip Code List] (http://www.post.japanpost.jp/zipcode/dl/readme.html)
##### Download the .csv file, delete all after the 9th column, and save it as "data.csv"

```powershell
$mycsv = Import-Csv .\data.csv
foreach($r in $mycsv)
{
    Add-AzureSearchZipcodenewDocument -zipCodeFull $r.zipCodeFull -countryID $r.countryID -zipCode $r.zipCode -stateName $r.stateName -cityName $r.cityName -townName $r.townName -stateNameKanji $r.stateNameKanji -cityNameKanji $r.cityNameKanji -townNameKanji $r.townNameKanji
}
```

#### Update a document

```powershell
Merge-AzureSearchZipcodenewDocument -zipCodeFull 445544 -stateName ccccc -cityName dddd
Merge-AzureSearchDocument -KeyFieldName zipCodeFull -KeyFieldValue 445544 -IndexName zipcodenew -DocumentData @{townName="llll"}
```

#### Remove a document

```powershell
Remove-AzureSearchDocument -KeyFieldName zipCodeFull -KeyFieldValue 445544 -IndexName zipcodenew
```

#### Look up the postal information of Microsoft Japan office by the name of the town

```powershell
Search-AzureSearch -IndexName zipcodenew -SearchString "コウナン" -FieldSelection *

# output:
@search.score  : 1.6635711
countryID      : 13103
zipCode        : 108
zipCodeFull    : 1080075
stateName      : トウキョウト
cityName       : ミナトク
townName       : コウナン(ツギノビルヲノゾク)
stateNameKanji : 
cityNameKanji  : 
townNameKanji  : 
```

#### Look up the postal information of Microsoft Japan office by the zip code

```powershell
Search-AzureSearch -IndexName zipcodenew -SearchString 1080075 -FieldSelection *

# output:
@search.score  : 2.6617138
countryID      : 13103
zipCode        : 108
zipCodeFull    : 1080075
stateName      : トウキョウト
cityName       : ミナトク
townName       : コウナン(ツギノビルヲノゾク)
stateNameKanji : 
cityNameKanji  : 
townNameKanji  :
```

#### Look up how many areas which have a zip code in the same district by passing the _AzureSearch_ output to a local variable

```powershell
$others = Search-AzureSearch -IndexName zipcodenew -SearchString "ミナトク" -FieldSelection *
$others.Length

# output:
50
```

#### Look up how many _towers_ in the same district 

```powershell
$tmp | Where-Object {$_.townName -like '*タワー*'}

#output:
@search.score  : 0.24716201
countryID      : 13103
zipCode        : 107
zipCodeFull    : 1076390
stateName      : トウキョウト
cityName       : ミナトク
townName       : アカサカアカサカビズタワー(チカイ・カイソウフメイ)
stateNameKanji : 
cityNameKanji  : 
townNameKanji  : 

@search.score  : 0.24716201
countryID      : 13103
zipCode        : 107
zipCodeFull    : 1076301
stateName      : トウキョウト
cityName       : ミナトク
townName       : アカサカアカサカビズタワー(1カイ)
stateNameKanji : 
cityNameKanji  : 
townNameKanji  : 

@search.score  : 0.24716201
countryID      : 13103
zipCode        : 107
zipCodeFull    : 1076302
stateName      : トウキョウト
cityName       : ミナトク
townName       : アカサカアカサカビズタワー(2カイ)
stateNameKanji : 
cityNameKanji  : 
townNameKanji  : 
```
