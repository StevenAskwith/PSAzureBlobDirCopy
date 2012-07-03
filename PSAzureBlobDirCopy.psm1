# PSAzureBlobDirCopy Module
# Version 1.0
# Written by Steven Askwith
# stevenaskwith.com
# 02/06/2012

# =============================================================================
# Useage
# =============================================================================

<#
Copy-BlobItem -s $source -d $destination -sak $SAK 
# e.g.
$SAK = "storage account key here"
Copy-BlobItem -s C:\temp\test.txt -d "http://yourbloburl.blob.core.windows.net/test/" -sak $SAK 
Copy-BlobItem -s "http://yourbloburl.blob.core.windows.net/test/test.txt" -d C:\temp\ -sak $SAK 


Get-BlobChildItem -path $path -sak $SAK [-recurse] [-screen]
# e.g.
$SAK = "storage account key here"
Get-BlobChildItem -path "http://yourbloburl.blob.core.windows.net/" -sak $SAK [-recurse] [-screen]

#>

# =============================================================================
# Error Action
# =============================================================================

$ErrorActionPreference = "Stop"

# =============================================================================
# Assemblies
# =============================================================================

#Add-Type -AssemblyName System
#Add-Type -AssemblyName System.Web

$scriptPath = Split-Path -parent $MyInvocation.MyCommand.Definition
Add-Type -Path ("$scriptPath\Microsoft.WindowsAzure.StorageClient.dll")

# =============================================================================
# Functions
# =============================================================================

function Copy-BlobItem 
(
	[Parameter(Mandatory=$true)][alias("s")][String]$source,
	[Parameter(Mandatory=$true)][alias("d")][String]$destination,
	[Parameter(Mandatory=$true)][String]$SAK,
	[switch][alias("r")]$recurse = $false 
)
{
	$sourceURI =  get-SourceDestinationURLInfo $source
	$destinationURI = get-SourceDestinationURLInfo $destination
	
	if($sourceURI.success -and !$destinationURI.success)
	{		
		# setup blob
		$creds = New-Object Microsoft.WindowsAzure.StorageCredentialsAccountAndKey($sourceURI.groups["SAN"],$SAK)
		$file = New-Object Microsoft.WindowsAzure.StorageClient.CloudBlob($source,$creds)

		# Clean up destination path
		$destination = $destination.TrimEnd("\")
		
		#Download File
		$timeTaken = Measure-Command {$file.DownloadToFile($destination + "\" + $sourceURI.groups["file"])}
		
		# Write status to screen
		Write-Host "Copied $source to $destination in $($timeTaken.TotalSeconds) seconds"
	}
	elseif(!$sourceURI.success -and $destinationURI.success)
	{
		# Parse out filename from source path
		$destinationFileName = ($source.split("\"))[-1]
		
		# Clean up destination URL and append file name
		$destination = $destination.TrimEnd("/")
		$destination = $destination + "/" + $destinationFileName
		
		# setup blob
		$creds = New-Object Microsoft.WindowsAzure.StorageCredentialsAccountAndKey($destinationURI.groups["SAN"],$SAK)
		$file = New-Object Microsoft.WindowsAzure.StorageClient.CloudBlob($destination,$creds)
		
		# Check containers exist in destination
		$URL = 	($destinationURI.groups["URL"]).ToString()
		$blobPath = New-Object Microsoft.WindowsAzure.StorageClient.CloudBlobClient($URL,$creds)
		($blobPath.GetContainerReference($destinationURI.groups["container"])).CreateIfNotExist() | Out-Null

		# Upload File
		$timeTaken = Measure-Command {$file.UploadFile($source)}
		
		# Write status to screen
		Write-Host "Copied $source to $destination in $($timeTaken.TotalSeconds) seconds"
	}
	else
	{
		Write-Host "No valid path/url combination provided"
	}
}

function Get-SourceDestinationURLInfo
(
	[Parameter(Mandatory=$true)][String]$pathToTest
)
{
	# Regex to match URL with a 'dotted' file
	#$Regex = "(?<URL>(?<protocol>https?)://(?<domain>(?<SAN>[-a-zA-Z0-9]+)[-a-zA-Z0-9.]+))/(?<stem>(?<container>[-a-zA-Z0-9]*)/?(?:[-a-zA-Z0-9]*/)*)?(?<file>[-a-zA-Z0-9]+\x2E[-a-zA-Z0-9]+)?"
	# Regex to match URL with a NON 'dotted' file
	$Regex = "(?<URL>(?<protocol>https?)://(?<domain>(?<SAN>[-a-zA-Z0-9]+)[-a-zA-Z0-9.]+))/?(?<stem>(?<container>[-a-zA-Z0-9]*)/?(?:[-a-zA-Z0-9]*/)*)?(?<file>[-a-zA-Z0-9\x2E]+)?"
	$Matches = [regex]::match($pathToTest,$Regex)
	return $Matches
}

function Get-URLStem
(
	[Parameter(Mandatory=$true)][String]$pathToTest
)
{
	$Matches = Get-SourceDestinationURLInfo $pathToTest
	return ($Matches.groups["stem"]).ToString()
}

function Get-CleanLocalPath
(
	[Parameter(Mandatory=$true)][String]$pathToTest
)
{
	$Regex = "(*)\?"
	$Matches = [regex]::match($pathToTest,$Regex)
	return $Matches.group[1]
}

function Get-BlobChildItem
(
	[Parameter(Mandatory=$true)][String]$path,
	[Parameter(Mandatory=$true)][String]$SAK,
	[switch][alias("r")]$recurse = $false,
	[switch][alias("s")]$screen = $false
)
{	
	$pathURI = get-SourceDestinationURLInfo $Path
	$container = ($pathURI.groups["container"]).ToString()
	if ($container.length -gt 0) # a container or sub directory has been specified
	{
		$timeTaken = Measure-Command {
			$results = @(Get-BlobContainerChildItem -path $path -SAK $SAK -recurse $recurse)
		}
	}
	elseif ($container.length -eq 0)  # a blob storage root has been specified
	{	
		$timeTaken = Measure-Command {
			$URL = 	($pathURI.groups["URL"]).ToString()
			$SAN = 	($pathURI.groups["SAN"]).ToString()		
			$creds = New-Object Microsoft.WindowsAzure.StorageCredentialsAccountAndKey($SAN,$SAK)
			$blobClient = New-Object Microsoft.WindowsAzure.StorageClient.CloudBlobClient($URL,$creds)
			$rootContainers = $blobClient.ListContainers()
			$rootContainersCount = 0
			$rootContainers | foreach {$rootContainersCount++}
			
			$results = @()
			$resultCount = 0
			
			if ($recurse) 
			{
				Write-Progress -Activity:"Indexing Containers..." -Status:"Completed $resultCount of $rootContainersCount" -PercentComplete:0
				foreach ($rootContainer in $rootContainers)
				{
					$result = Get-BlobContainerChildItem -path ($rootContainer.uri.AbsoluteUri) -SAK $SAK -recurse $recurse
					$results += $result
					
					# Displays the overall progress on the screen
					$resultCount++
					$percentComplete = [math]::round((($resultCount/$rootContainersCount) * 100), 0)
					Write-Progress -Activity:"Indexing Containers..." -Status:"Completed $resultCount of $rootContainersCount" -PercentComplete:$percentComplete
				}
				Write-Progress -Activity:"Indexing Containers..." -Status:"Completed" -Completed
			}
			else
			{
				foreach ($rootContainer in $rootContainers)
				{
					$result = New-Object Object

					Add-Member -memberType NoteProperty -name Mode 		-Value "c----" 								-inputObject $result
					Add-Member -memberType NoteProperty -name Name		-Value ($rootContainer.name)				-inputObject $result

					Add-Member -memberType NoteProperty -name Length	-Value ($rootContainer.Properties.Length) 	-inputObject $result
					Add-Member -memberType NoteProperty -name BlobDir	-Value ($rootContainer.name + "/") 			-inputObject $result
					Add-Member -memberType NoteProperty -name URI 		-Value ($rootContainer.uri)				 	-inputObject $result
					
					$results += $result
				}
			}
		}
	}
	
	# write to screen
	if($screen)
	{
		$results | ft mode,name,@{Expression={get-HumanReadableByteSize($_.Length)};Label="Length"},BlobDir,URI -AutoSize
		
		$sizes = $results | foreach {$_.Length}
		$TotalSize = ($sizes | measure-object -Sum).sum
		Write-Host "$($results.count) File(s) $(get-HumanReadableByteSize $TotalSize) in $($timeTaken.ToString("hh\:mm\:ss"))" 
		#$blobs | Format-Table @{Expression={($_.Name).split("/")[-1]};Label="Name"},@{Expression={$_.Parent.uri};Label="BlobDir"},@{Expression={get-HumanReadableByteSize($_.Properties.Length)};Label="Size"} -AutoSize
	}
	else # return results
	{
		return $results 
	}
}

function Get-BlobContainerChildItem
(
	[Parameter(Mandatory=$true)][String]$path,
	[Parameter(Mandatory=$true)][String]$SAK,
	[Parameter(Mandatory=$true)][bool]$recurse = $false
)
{	
	$pathURI = get-SourceDestinationURLInfo $Path
	$URL = 	($pathURI.groups["URL"]).ToString()

	# setup blob
	$creds = New-Object Microsoft.WindowsAzure.StorageCredentialsAccountAndKey($pathURI.groups["SAN"],$SAK)
	$blobPath = New-Object Microsoft.WindowsAzure.StorageClient.CloudBlobClient($URL,$creds)
	$blobDir = $blobPath.GetBlobDirectoryReference($pathURI.groups["stem"])

	if($recurse)
	{
		$bro = New-Object Microsoft.WindowsAzure.StorageClient.BlobRequestOptions
		$bro.UseFlatBlobListing = $recurse
		$blobs = $blobDir.ListBlobs($bro)
	}
	else
	{
		$blobs = $blobDir.ListBlobs()
	}
	
	$results = @()
	foreach ($blob in $blobs)
	{
		$result = New-Object Object
		
		if ($blob.ToString() -eq "Microsoft.WindowsAzure.StorageClient.CloudBlobDirectory")
		{
			Add-Member -memberType NoteProperty -name Mode 		-Value "d----" -inputObject $result
			Add-Member -memberType NoteProperty -name Name		-Value ($blob.Uri.ToString()).split("/")[-2]	-inputObject $result
		}
		else
		{
			Add-Member -memberType NoteProperty -name Mode 		-Value "-a---" -inputObject $result
			Add-Member -memberType NoteProperty -name Name		-Value ($blob.Uri.ToString()).split("/")[-1]	-inputObject $result
		}
		Add-Member -memberType NoteProperty -name Length	-Value ($blob.Properties.Length) 	-inputObject $result
		Add-Member -memberType NoteProperty -name BlobDir	-Value (Get-URLStem ($blob.Parent.Uri.ToString()))			-inputObject $result
		Add-Member -memberType NoteProperty -name URI 		-Value ($blob.uri)				 	-inputObject $result
		
		$results += $result
	}
	
	return $results
}

function get-HumanReadableByteSize
(
	[Parameter(Mandatory=$true)][int64]$bytes
)
{
	if 		($bytes -lt 1KB) 	{$bytes.ToString() + "B"}
	elseif 	($bytes -lt 1MB)	{"{0:N2}" -f ($bytes/1KB) + "KB"} 
	elseif 	($bytes -lt 1GB)	{"{0:N2}" -f ($bytes/1MB) + "MB"}
	elseif 	($bytes -lt 1TB)	{"{0:N2}" -f ($bytes/1GB) + "GB"}
	elseif 	($bytes -lt 1PB)	{"{0:N2}" -f ($bytes/1TB) + "TB"}
}


# Export Public Functions
Export-ModuleMember -function Copy-BlobItem,Get-BlobChildItem 