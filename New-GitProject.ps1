<#
.SYNOPSIS
    Creates Projects in Gitlab instance
.PARAMETER envPrefix
    The instance's environment (PRE/PRO)
.PARAMETER projectName
    The name of the project repository you want to create
.PARAMETER groupName
    The name of the group (existing or not existing) where you want to put your project
.EXAMPLE
    BacardiGitLab-Management.ps1 -envPrefix PRE -groupName DevOps -projectName "devops-resources"
.OUTPUTS
    N/A
#>

param(
    [Parameter(Mandatory=$true)][string][ValidateSet("PRE","PRO")]$envPrefix,
    [Parameter(Mandatory=$true)][string]$projectName,
    [Parameter(Mandatory=$true)][string]$groupName
 )

 <#
 try {
     #Try to fetch personal access token from Azure Key Vault
    if (
    $PersonalAccessToken = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultSecret
    Write-Verbose -Message "Found secret $($PersonalAccessToken.Id)"
    } 
catch {
    Write-Error -Message $_
    break
}#>

#Map of allowed environment prefixes and associated subsription name & jumphost subnets
$spokeMap = @{
    "PRE" = @{"url"="pre-git.xxxxx.com"};
    "PRO" = @{"url"="git.xxxxx.com"};
}

$gitserver=$spokeMap[$envPrefix]["url"]
$pat="glpat-m-xxxxxxxx"

#Add headers to the request with our $Token set
$headers = @{
    'PRIVATE-TOKEN' = $pat
}


#Call VERSION API to test the URL
try {
    write-output "(0/4) Checking connection to https://$gitserver.... "
    $version = Invoke-RestMethod -Headers $headers -Uri https://$gitserver/api/v4/version
    write-host "SUCCESS: Connection to $gitserver is OK!`n"

}
catch [System.Net.WebException] {
    if($_.Exception.Response.StatusCode.value__ -eq 404) {
        write-host "Connection to gitlab instance '$gitserver' failed!"
    } else {
        write-host $_.Exception.Message
    } 
    exit
}

write-output "(1/5) Collecting data for deployment`n"
$groupPath = $groupName.ToLower() -replace '\s','-'
$projectPath = $projectName.ToLower() -replace '\s','-'

write-output "(2/5) Checking if the group $groupName already exists..."
$group = Invoke-RestMethod -Headers $headers -Uri "https://$gitserver/api/v4/groups?search=$groupName"
    if(!$group) {
        write-output "The group $groupName is not yet existing.. creating group...."
        $group = Invoke-RestMethod -Headers $headers -Method Post -Uri "https://$gitserver/api/v4/groups?path=$groupPath&name=$groupName&visibility=private"
        write-output "SUCCESS: Group has been successfully created!"
    }
    else {
        write-output "INFORMATION: Group already exists!"
    }
        #output custom object with group details
        [PSCustomObject]@{
        
            ID = $group.id
            GroupName = $group.name 
            Visibility = $group.visibility
            WebURL = $group.web_url
        
        }
        write-output ""

write-output "(3/5) Checking if project name $projectName already exists"
$proj = Invoke-RestMethod -Headers $headers -Uri "https://$gitserver/api/v4/projects?search=$projectName"
if (!$proj) {
    write-output "The project $projectName is not yet existing.. proceeding on its creation`n"
}
else { 
    write-output "INFORMATION: The project $projectName already exists!!`n"
    exit
}
   
write-output "(4/5) Creating new project repository"
#Create project
$groupID = $group.id
try {
    $createdProject = Invoke-RestMethod -Headers $headers -Method Post -Uri "https://$gitserver/api/v4/projects?namespace_id=$groupID&name=$projectName"
    write-output "SUCCESS: Project has been successfully created!`n"
}
catch {
    Write-Error -Message $_
    break
}

write-output "(5/5) Deployment completed. Detailed info outputed below:"
$projDetails = Invoke-RestMethod -Headers $headers -Uri "https://$gitserver/api/v4/projects?search=$createdProject.name"
$projDetails
