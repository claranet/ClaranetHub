<# 
.SYNOPSIS
	Move a CIVM from to given vApp.
.DESCRIPTION
	Move a CIVM from to given vApp.
.NOTES 
    Name: Move-CIVM.ps1
    Author: Martin Weber (martin.weber@claranet.com)
    Created: 05.12.2023
    Modified: 06.12.2023

.PARAMETER CIVM
  The VM to move. Can also be from pipeline input
.PARAMETER TargetVApp
  The target VApp Name or CIVApp Object
.PARAMETER NetworkMap
  Map the source network to new vApp Network.
  Format: "<Old Network>=<New Network>"
.PARAMETER RunAsync
	Run Task in Background and return. Otherwise the script will wait until teh created task is finished.
.EXAMPLE
  Get-CIVM "My-VM" | ./Move-CIVM.ps -TargetVApp (Get-CIVapp "New-VApp") -NetworkMap "Source Network=New Network"
.LINK
	https://vdc-repo.vmware.com/vmwb-repository/dcr-public/f4454f80-7a33-48a1-beda-1b34a8599fa6/b0985b70-3a35-4de3-9964-d7bdf3cfb3a5/GUID-D133B0BE-3383-444F-8D32-CA4028EF2278.html
#>

param(
  [Parameter(ValueFromPipeline, Mandatory)]
  [VMware.VimAutomation.Cloud.Types.V1.CIVM[]] $CIVM,
  [Parameter(Mandatory)]
  [VMware.VimAutomation.Cloud.Types.V1.CIVApp] $TargetVApp,
  [Parameter(Mandatory)]
  [ValidateScript( {$_.Split("=").Length -eq 2} )]
  [string[]]$NetworkMap,
  [Parameter()]
  [switch]$RunAsync
)

BEGIN {
  if(-not $global:DefaultCIServers.IsConnected) {
    Write-Error "Not connected to vCloud Server"
    exit 1
  }

# BEGIN Some Helper Fuctions

  # join string parts with "/" as separator - be sure each part ist trimmed and "/" are removed
  Function Join-URL( [string[]] $Parts ) { return $Parts.Trim().Trim("/") -join "/" }
  # return mapped network from given list
  Function Get-SideNetwork($network) { $NetworkMap | %{ if(($map=$_.Split("=")) -and $map[0] -eq $network) { return $map[1]} } }

  # Get the OrgVdc from a VApp - The "normal" CIVapp object does not conaint this information
  Function Get-CIVappOrgVDC {
    param( [Parameter(ValueFromPipeline, Mandatory)] $CIVapp )
    $link = $CIVapp.ExtensionData.Link | ?{$_.Rel -eq "up" -and $_.Type -eq "application/vnd.vmware.vcloud.vdc+xml" }
    $orgvdc_id = $link.Href.Split("/")[-1]
    return Get-OrgVDC -Id "urn:vcloud:vdc:$($orgvdc_id)"
  }
  # The the storage profile from target VDC with same name
  Function Get-TargetStorageProfile {
    param( $Name, $TargetVdc )
    return $TargetVdc.ExtensionData.VdcStorageProfiles.VdcStorageProfile |?{$_.Name -eq $Name}
  }
  # wait for task is completed
  Function WaitFor-Task {
    param( $Task )
    do {
      Start-Sleep 5
      $Task = Get-Task -Id $Task.Id
      Write-Progress -Activity $Task.Description -Status "$($Task.PercentComplete)%" -PercentComplete $Task.PercentComplete
    } while ($Task.State -eq "Running")
    return $Task
  }

# END Some Helper Fuctions

  $target_vdc = $TargetVApp | Get-CIVappOrgVDC
  
  [xml]$root = New-Object System.Xml.XmlDocument
  $base = $root.CreateElement("RecomposeVAppParams")
  $base.SetAttribute("xmlns", "http://www.vmware.com/vcloud/v1.5")
  $base.SetAttribute("xmlns:ovf", "http://schemas.dmtf.org/ovf/envelope/1")
  $base.SetAttribute("xmlns:rasd", "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData")
  $root.AppendChild($base) | Out-Null
}

PROCESS {
  $sourced_item = $root.CreateElement("SourcedItem")
  $base.AppendChild($sourced_item) | Out-Null
  $sourced_item.SetAttribute("sourceDelete", "true")

  $source = $root.CreateElement("Source")
  $sourced_item.AppendChild($source) | Out-Null
  $source.SetAttribute("href", $CIVM.Href)
  $source.SetAttribute("name", $CIVM.Name)

  $instation_params = $root.CreateElement("InstantiationParams")
  $sourced_item.AppendChild($instation_params) | Out-Null

# BEGIN Network Section
  $network_section = $root.CreateElement("NetworkConnectionSection")
  $instation_params.AppendChild($network_section) | Out-Null

  $info = $root.CreateNode("element", "ovf", "Info", "http://schemas.dmtf.org/ovf/envelope/1")
  $info.InnerText = "Network Connection Section"
  $network_section.AppendChild($info) | Out-Null
  
  $prim_network = $root.CreateElement("PrimaryNetworkConnectionIndex")
  $prim_network.InnerText = $CIVM.ExtensionData.GetNetworkConnectionSection().PrimaryNetworkConnectionIndex
  $network_section.AppendChild($prim_network) | Out-Null
  
  $network_config = $CIVM.ExtensionData.GetNetworkConnectionSection().NetworkConnection
  foreach($interface in $network_config) {
    #$dst_network = Get-MappedNetwork -SourceNetwork $interface.Network -TargetVdc $target_vdc
    $dst_network = Get-SideNetwork($interface.Network)
    
    $network = $root.CreateElement("NetworkConnection")
    $network.SetAttribute("network", $dst_network)

    $obj = $root.CreateElement("NetworkConnectionIndex")
    $obj.InnerText = $interface.NetworkConnectionIndex
    $network.AppendChild($obj) | Out-Null

    $obj = $root.CreateElement("IpAddress")
    $obj.InnerText = $interface.IpAddress
    $network.AppendChild($obj) | Out-Null
    
    $obj = $root.CreateElement("IsConnected")
    $obj.InnerText = $interface.IsConnected.ToString().ToLower()
    $network.AppendChild($obj) | Out-Null
    
    $obj = $root.CreateElement("MACAddress")
    $obj.InnerText = $interface.MACAddress
    $network.AppendChild($obj) | Out-Null
    
    $obj = $root.CreateElement("IpAddressAllocationMode")
    $obj.InnerText = $interface.IpAddressAllocationMode
    $network.AppendChild($obj) | Out-Null
    
    $obj = $root.CreateElement("NetworkAdapterType")
    $obj.InnerText = $interface.NetworkAdapterType
    $network.AppendChild($obj) | Out-Null

    $network_section.AppendChild($network) | Out-Null
  }
# END Network Section

# BEGIN End of Document
  $storage_profile = $root.CreateElement("StorageProfile")
  $sourced_item.AppendChild($storage_profile) | Out-Null
  $target_storage_profile = Get-TargetStorageProfile -Name $CIVM.ExtensionData.StorageProfile.Name -TargetVdc $target_vdc
  $storage_profile.SetAttribute("href", $target_storage_profile.Href)

  $replace_tpm = $root.CreateElement("ReplaceTpm")
  $sourced_item.AppendChild($replace_tpm) | Out-Null
  $replace_tpm.InnerText = "false"
# END End of Document
}

END {
  # BEGIN Build Payload and Push
  
    $url = Join-URL $TargetVApp.Href, "/action/recomposeVApp" 
    $PayLoad = $root.OuterXml

    try {
      $HEADER = @{
        "Accept" = "application/*+xml;version=39.0.0-alpha"
        "Content-Type" = "application/vnd.vmware.vcloud.recomposeVAppParams+xml;charset=utf-8"
        "Authorization" = $global:DefaultCIServers.SessionSecret
      }
      $res = Invoke-WebRequest -Method Post -Headers $HEADER -Body $PayLoad $url

      $obj = [xml]$res.Content
      $task_id = $obj.Task.Id
      $Task = Get-Task -Id $task_id
      if(-not $RunAsync) {
        $Task = WaitFor-Task -Task $Task
      }
      return $Task
    } catch {

      Get-Error
      $res.Content

      $url
      $PayLoad
    }
    
    
  # END Build Payload and Push
}
