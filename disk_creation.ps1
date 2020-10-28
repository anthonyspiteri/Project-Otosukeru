$disk = Get-Disk -Number 1
Set-Disk -InputObject $disk -IsOffline $false
Initialize-Disk -InputObject $disk
New-Partition $disk.Number -UseMaximumSize -DriveLetter V
Format-Volume -DriveLetter V -FileSystem NTFS -NewFileSystemLabel "v-Power" -Confirm:$false

$disk = Get-Disk -Number 2
Set-Disk -InputObject $disk -IsOffline $false
Initialize-Disk -InputObject $disk
New-Partition $disk.Number -UseMaximumSize -DriveLetter R
Format-Volume -DriveLetter V -FileSystem ReFS -AllocationUnitSize 65536 -NewFileSystemLabel "REPO-01" -Confirm:$false

$disk = Get-Disk -Number 3
Set-Disk -InputObject $disk -IsOffline $false
Initialize-Disk -InputObject $disk
New-Partition $disk.Number -UseMaximumSize -DriveLetter R
Format-Volume -DriveLetter V -FileSystem ReFS -AllocationUnitSize 65536 -NewFileSystemLabel "REPO-02" -Confirm:$false
