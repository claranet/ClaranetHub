# vCloud Director Code-Snippets

## Use API Token to authenticate PowerCLI to VCD

Using SAML in VCD also impact the login method for PowerCLI. If you don' have a local user, you are unable to login via SAML credentials.

You have to [create a API token](https://blogs.vmware.com/cloudprovider/2022/03/cloud-director-api-token.html) in you User Preferences.

Use the Script to login in your vCloud Director using API Token:
[TokenConnect-CIServer.ps1](./TokenConnect-CIServer.ps1)

## Make Manual Request to get more Data from VCD

Sometimes, some API Actions are not covered by PowerCLI. In this case you can use the browser development tools to track which api is used.
But how to pass token to a manual request?

All required informations are stored in the session object in $global:DefaultCIServers.

```powershell
# Login to Server
Connect-CIServer -Server <my-server> -Org <org> -User <user>

# Fetch Server Details
$apiHost = $global:DefaultCIServers[0].ServiceUri
$apiVersion = $global:DefaultCIServers[0].ExtensionData.Client.Version
$apiSecret = $global:DefaultCIServers[0].SessionSecret
$baseUrl = "https://$($apiHost.Host)/cloudapi/1.0.0/"

# Prepare the Headers
$Headers = @{
  "Authorization" = $apiSecret
  "Accept" = "application/json;version=$($apiVersion)"
}
```


Here is a full example to fetch all Certificates from a organization as system provider

```powershell
# Fetch a org
$Org = Get-Org | Select -First 1

# Build base Informations
$apiHost = $global:DefaultCIServers[0].ServiceUri
$apiVersion = $global:DefaultCIServers[0].ExtensionData.Client.Version
$apiSecret = $global:DefaultCIServers[0].SessionSecret
$baseUrl = "https://$($apiHost.Host)/cloudapi/1.0.0"

# The headers
# note to set CONEXT informations as provider admin ;-)
$Headers = @{
  "Authorization" = $apiSecret
  "Accept" = "application/json;version=$($apiVersion)"
  "X-VMWARE-VCLOUD-AUTH-CONTEXT" = $Org.Name
  "X-VMWARE-VCLOUD-TENANT-CONTEXT" = $Org.Id
}

# build the url and invoke the request
$url = "$($baseUrl)/ssl/certificateLibrary"
$r = Invoke-WebRequest -Method GET -Headers $Headers $url
$r.Content | ConvertFrom-Json
```