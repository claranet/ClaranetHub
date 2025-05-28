<# 
.SYNOPSIS
	PowerCLI Login to vCloud Director using API Token
.DESCRIPTION
	PowerCLI Login to vCloud Director using API Token
.NOTES 
    Name: TokenConnect-CIServer.ps1
    Author: Martin Weber (martin.weber@claranet.com)
    Created: 28.05.2025
    Modified: 28.05.2025

.PARAMETER Server
  The Hostname of your vcloud director server
.PARAMETER Token
  The API Token created for the user
.PARAMETER Org
  Optional - The organization to login, default is provider
.PARAMETER RunAsync
	
.EXAMPLE
  ./TokenConnect-CIServer.ps1 -Server vcd.example.com -Token "$3Cre1" -Org my-org
.LINK
	https://blogs.vmware.com/cloudprovider/2022/03/cloud-director-api-token.html
  https://techdocs.broadcom.com/us/en/vmware-cis/cloud-director/vmware-cloud-director/10-5/generate-an-api-access-token-for-vcd.html
#>

param(
  [Parameter(mandatory)]
  [string]$Server,
  [Parameter(mandatory)]
  [string]$Token,
  [string]$Org
)

# As Provider
$Uri = "https://$($Server)/oauth/provider/token"
if($Org) {
  $Uri = "https://$($Server)/oauth/tenant/$($Org)/token"
}

# Payload
$Body = "grant_type=refresh_token&refresh_token=$($Token)"

$Headers = @{
  'Accept' = 'application/json'
  'ContentType' = 'application/x-www-form-urlencoded'
}

$Token_Data = Invoke-RestMethod -Method Post -Uri $Uri -Headers $Headers -Body $Body

$SessionId = "$($Token_Data.token_type) $($Token_Data.access_token)"
Connect-CIServer -Server $Server -SessionId $SessionId