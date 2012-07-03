PSAzureBlobDirCopy Installation Instructions 

Create a new folder in called PSAzureBlobDirCopy in your modules directory e.g 
	C:\Windows\System32\WindowsPowerShell\v1.0\Modules\PSAzureBlobDirCopy

Download the latest version of 
	PSAzureBlobDirCopy.psm1
	Microsoft.WindowsAzure.StorageClient.dll
from https://github.com/stevenaskwith/PSAzureBlobDirCopy into the new directory

Launch a PowerShell console and run 
	import-module PSAzureBlobDirCopy
To confirm module loaded correctly run
	Get-Command -Module PSAzureBlobDirCopy

THIS CODE IS PROVIDED “AS IS” AND INFERS NO WARRANTIES OR RIGHTS, USE AT YOUR OWN RISK	