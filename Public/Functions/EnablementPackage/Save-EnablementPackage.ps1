function Save-EnablementPackage {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [Alias ('DownloadFolder','Path')]
        [string]$DownloadPath = "$env:TEMP",

        [ValidateSet('22H2','21H2','21H1','20H2','1909')]
        [Alias('Build')]
        [string]$OSBuild = '21H1',

        [ValidateSet('x64','x86')]
        [string]$OSArch = 'x64'
    )
    #=================================================
    #   Get-EnablementPackage
    #=================================================
    $Result = Get-EnablementPackage -OSBuild $OSBuild -OSArch $OSArch
    #=================================================
    #   SaveWebFile
    #=================================================
    if ($Result) {
        if (Test-Path "$DownloadPath\$($Result.FileName)") {
            Get-Item "$DownloadPath\$($Result.FileName)"
        }
        elseif (Test-WebConnection -Uri "$($Result.FileUri)") {
            $SaveWebFile = Save-WebFile -SourceUrl $Result.FileUri -DestinationDirectory "$DownloadPath" -DestinationName $Result.FileName

            if (Test-Path $SaveWebFile.FullName) {
                Get-Item $SaveWebFile.FullName
            }
            else {
                Write-Warning "Could not download the Enablement Package"
            }
        }
        else {
            Write-Warning "Could not verify an Internet connection for the Enablement Package"
        }
    }
    else {
        Write-Warning "Unable to determine a suitable Enablement Package"
    }
}
