#Download and Install AWSCLI for Powershell 
Import-Module "C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1"
# Packages can be installed manually after downloading from http://sdk-for-net.amazonwebservices.com/latest/AWSToolsAndSDKForNet.msi
#Set-ExecutionPolicy RemoteSigned
#Download and Install AWS SDK for .NET from https://sdk-for-net.amazonwebservices.com/latest/AWSToolsAndSDKForNet.msi
#Set-AWSCredentials -AccessKey AKIAJNQ3T4RJGDPR724A -SecretKey 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
Add-Type -Path 'C:\Program Files (x86)\AWS SDK for .NET\past-releases\Version-2\Net45\AWSSDK.dll'
# Lets import our list of computers
$computers = $env:computername
$InstanceId=(New-Object System.Net.WebClient).DownloadString("http://169.254.169.254/latest/meta-data/instance-id")
#$InstanceHostname=(New-Object System.Net.WebClient).DownloadString("http://169.254.169.254/latest/meta-data/hostname")
$InstanceHostname = $env:computername
# Lets create our variables
$HostInfo = @()


# Lets loop through our computer list from computers
foreach ($computer in $computers) {
    # Lets get our stats
    # Lets create a re-usable WMI method for CPU stats
    $ProcessorStats = Get-WmiObject win32_processor -computer $computer
    $ComputerCpu = $ProcessorStats.LoadPercentage 
    # Lets create a re-usable WMI method for memory stats
    $OperatingSystem = Get-WmiObject win32_OperatingSystem -computer $computer
    # Lets grab the free memory
    $FreeMemory = $OperatingSystem.FreePhysicalMemory
    # Lets grab the total memory
    $TotalMemory = $OperatingSystem.TotalVisibleMemorySize
    # Lets do some math for percent
    $MemoryAvailable = ($FreeMemory/ $TotalMemory) * 100
    $PercentMemoryAvailable = "{0:N2}" -f $MemoryAvailable
    $PercentMemoryUsed = 100 - $PercentMemoryAvailable 

    #Cloudwatch Matrix
    $dimension1 = New-Object Amazon.CloudWatch.Model.Dimension
    $dimension1.Name = "Instance ID"
    $dimension1.Value = $InstanceId
    $dimension3 = New-Object Amazon.CloudWatch.Model.Dimension
    $dimension3.Name = "Instance Name"
    $dimension3.Value = $InstanceHostname
    $dat = New-Object Amazon.CloudWatch.Model.MetricDatum
    $dat.Timestamp = (Get-Date).ToUniversalTime()
    $dat.MetricName = "UsedMemory"
    $dat.Dimensions.Add($dimension1)
    $dat.Dimensions.Add($dimension3)
    $dat.Unit = "Percent"
    $dat.Value = $PercentMemoryUsed
    #$dat
    Write-CWMetricData -Namespace "WindowsCustomMatrix" -MetricData $dat -Region ap-south-1
}



#Disk Monitoring

$driveLetters = Get-WmiObject win32_logicaldisk | select DeviceID
$Volumes = Get-WmiObject win32_volume | Where-object {$_.DriveLetter -ne $null -and $_.Capacity -ne $null} | Select Name,Label

#$Volumes

foreach ($driveLetter in $Volumes)
{
    $drive = Get-WmiObject Win32_Volume | where {$_.Name -eq $driveLetter.Name}
    $usedDiskSpace = $drive.Capacity - $drive.FreeSpace
    $usedDiskSpacePrct = [math]::Round(($usedDiskSpace / $drive.Capacity) * 100,1)
    $usedDiskSpacePct = "{0:N2}" -f $usedDiskSpacePrct
 


    #Cloudwatch Matrix
    $dimension1 = New-Object Amazon.CloudWatch.Model.Dimension
    $dimension1.Name = "Instance ID"
    $dimension1.Value = $InstanceId
    $dimension2 = New-Object Amazon.CloudWatch.Model.Dimension
    $dimension2.Name = "Drive"
    $dimension2.Value = "$($driveLetter.Name) - $($driveLetter.Label)"
    $dimension3 = New-Object Amazon.CloudWatch.Model.Dimension
    $dimension3.Name = "Instance Name"
    $dimension3.Value = $InstanceHostname
    $dat = New-Object Amazon.CloudWatch.Model.MetricDatum

    $dat.Timestamp = (Get-Date).ToUniversalTime()
    $dat.MetricName = "DiskUtilization"
    $dat.Dimensions.Add($dimension1)
    $dat.Dimensions.Add($dimension2)
    $dat.Dimensions.Add($dimension3)
    $dat.Unit = "Percent"
    $dat.Value = $usedDiskSpacePct
    Write-CWMetricData -Namespace "WindowsCustomMatrix" -MetricData $dat -Region ap-south-1
   
}