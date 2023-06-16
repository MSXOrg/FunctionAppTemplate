Function Get-ACRRefreshToken {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $RegistryURL
    )
    # Get the access token for the Azure Resource Manager API
    $context = Get-AzContext
    $tenantId = $context.Tenant.Id
    $ARMaccessToken = (Get-AzAccessToken).Token

    $Params = @{
        Uri     = "https://$RegistryURL/oauth2/exchange"
        Method  = 'POST'
        Headers = @{
            'Content-Type' = 'application/x-www-form-urlencoded'
        }
        Body    = @{
            grant_type   = 'access_token'
            service      = $RegistryURL
            tenant       = $tenantId
            access_token = $ARMaccessToken
        }
    }
    $response = Invoke-RestMethod @Params
    $refreshToken = $response.refresh_token
    return $refreshToken
}

Function Get-ACRAccessToken {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $RegistryURL,
        [Parameter()]
        [string] $RefreshToken,
        [Parameter()]
        [string] $Scope
    )
    $Params = @{
        Uri     = "https://$RegistryURL/oauth2/token"
        Method  = 'POST'
        Headers = @{
            'Content-Type' = 'application/x-www-form-urlencoded'
        }
        Body    = @{
            grant_type    = 'refresh_token'
            service       = $RegistryURL
            scope         = $scope
            refresh_token = $RefreshToken
        }
    }
    $response = Invoke-RestMethod @Params
    $AccessToken = $response.access_token
    return $AccessToken
}

Function Get-ACRManifest {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $RegistryURL,
        [Parameter()]
        [string] $RepositoryName,
        [Parameter()]
        [string] $Reference,
        [Parameter()]
        [string] $AccessToken = '',
        [Parameter()]
        [ValidateSet('oci', 'docker')]
        [string] $ManifestType = 'oci'
    )

    $Accept = $ManifestType -eq 'oci' ? 'application/vnd.oci.image.manifest.v1+json' : 'application/vnd.docker.distribution.manifest.v2+json'

    $Params = @{
        Uri     = "https://$RegistryURL/v2/$RepositoryName/manifests/$Reference"
        Method  = 'GET'
        Headers = @{
            'Authorization' = "Bearer $AccessToken"
            'Accept'        = $Accept
        }
    }
    $response = Invoke-RestMethod @Params
    return $response
}

Function Get-ACRAdditionalTags {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $RegistryURL,
        [Parameter()]
        [string] $RepositoryName,
        [Parameter()]
        [string] $Reference
    )

    $RegistryName = $RegistryURL.Split('.')[0]
    $Manifests = Get-AzContainerRegistryManifest -RegistryName $RegistryName -RepositoryName $RepositoryName | Select-Object -ExpandProperty ManifestsAttributes
    $Manifest = $Reference.StartsWith('sha256:') ? ($Manifests | Where-Object Digest -EQ $Reference) : ($Manifests | Where-Object Tags -Contain $Reference)
    $Manifest = Get-AzContainerRegistryManifest -RegistryName $RegistryName -RepositoryName $RepositoryName -Name $Manifest.Digest
    $AdditionalTags = $Manifest.Attributes.Tags
    return $AdditionalTags
}
