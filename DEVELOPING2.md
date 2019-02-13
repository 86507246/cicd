## Introduction
These development instructions are an alternative to the ones found in [DEVELOPING.md](DEVELOPING.md). More suited to programmers comfortable with command line/bash programming with no need to install NodeJS/Gulp dependencies. Choose one that suits you.


## Dependencies  
* Azure CLI (`curl -L https://aka.ms/InstallAzureCli | bash` or `brew install azure-cli`)  
* AzCopy (https://github.com/Azure/azure-storage-azcopy)  


## Configuration  
* Clone this Bitbucket repos  
```
cd ~/git
git clone git@bitbucket.org:atlassian/atlassian-azure-deployment.git
``` 
* Create a blobstore (https://docs.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-cli) in a new storage account. This storage account should be kept in separate resource group from any deployment.   
```
az group create --name smontogmeryatlassian --location eastus
az storage account create --name atlassianupload --resource-group smontogmeryatlassian --location eastus --sku Standard_LRS
...
 "primaryEndpoints": {
    "blob": "https://atlassianupload.blob.core.windows.net/",
    "dfs": null,
    "file": "https://atlassianupload.file.core.windows.net/",
    "queue": "https://atlassianupload.queue.core.windows.net/",
    "table": "https://atlassianupload.table.core.windows.net/",
    "web": null
  },
...
```
* Create SAS token (https://docs.microsoft.com/en-us/cli/azure/storage/account?view=azure-cli-latest#az-storage-account-generate-sas)  
```
az storage account generate-sas --account-name atlassianupload --services bfqt --resource-types sco --permissions cdlruwap --expiry $(date --date "next year" '+%Y-%m-%dT%H:%MZ')
"se=2020-02-13T15%3A37Z&sp=rwdlacup&sv=2018-03-28&ss=bfqt&srt=sco&sig=XanVOenVIroHQFbkyUjk6E9nuHFEm1Rpyu3N2AiOOX0%3D"
```
* Create a container for each Atlassian app eg jiratemplateupload for Jira, confluenceupload for Confluence etc:  
```
az storage container create --name jiratemplateupload --account-name atlassianupload --sas-token 'se=2020-02-13T15%3A37Z&sp=rwdlacup&sv=2018-03-28&ss=bfqt&srt=sco&sig=XanVOenVIroHQFbkyUjk6E9nuHFEm1Rpyu3N2AiOOX0%3D'
```
* Use AzCopy to upload changed/developed Jira templates/scripts to blobstore (do this before each deployment). NB The use of the blob primary endpoint and the question mark prefix on the SAS token.  
```
~/apps/azcopy/azcopy --quiet --source ~/git/atlassian-azure-deployment/jira/ --destination https://atlassianupload.blob.core.windows.net/jiratemplateupload/ --recursive --dest-sas '?se=2020-02-13T15%3A37Z&sp=rwdlacup&sv=2018-03-28&ss=bfqt&srt=sco&sig=XanVOenVIroHQFbkyUjk6E9nuHFEm1Rpyu3N2AiOOX0%3D'
```
* Since you will be using the same AzCopy command often, I suggest you cut/paste this command into a new script file eg ~/atlassian/bin/jiraupload  
* Create a local directory for your templates and copy the default azuredeploy.parameters.json to your own copy ie  
```
mkdir -p ~/atlassian/templates
cp azuredeploy.parameters.json ~/atlassian/templates/jira.msql.parameters.json
```
* NB that the blob primary endpoint becomes the "_artifactsLocation" parameter. By default this parameter will point to the master branch in this Bitbucket repos.  
* NB that the generated SAS token becomes the "_artifactsLocationSasToken" parameter.  
* NB your SSH public key (`~/.ssh/id_rsa.pub`) becomes the "jumpboxSshKey" parameter.  
* Edit the new ~/atlassian/templates/jira.msql.parameters.json file and update the above 3 parameters (with target location) to have something like:  
```
{
    "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location": {
            "value": "canadacentral"
        },
        "_artifactsLocation": {
            "value": "https://atlassianupload.blob.core.windows.net/jiratemplateupload/"
        },
        "_artifactsLocationSasToken": {
            "value": "?sv=2017-11-09&ss=bfqt&srt=sco&sp=rwdlacup&se=2028-10-24T23:00:00Z&st=2018-10-24T23:00:00Z&spr=https,http&sig=vGvcjMRxHZFlD69KxUytEkuWwG8ojUehkgdRupyLVME%3D"
        },
        "jiraClusterSize": {
            "value": "small"
        },
        "clusterSshPassword": {
            "value": "JIRA@dmin"
        },
        "dbPassword": {
            "value": "P@55w0rd"
        },
        "jiraAdminUserPassword": {
            "value": "admin"
        }
        "jumpboxSshKey": {
                "value": "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABA...."
        }
    }
}
```
* You have now configured a Jira parameters file specific to your own environment. Deploying your latest changes will be be done by the following:  
```
cd ~/git/atlassian-azure-deployment/jira
az group create --resource-group smontgomeryjira --location canadacentral
~/atlassian/bin/jiraupload && az group deployment create --resource-group smontgomeryjira --template-file azuredeploy.json --parameters ~/atlassian/templates/jira.msql.parameters.json
```
* You can now use this paramaters template as a basis for other templates eg have a separate parameters template for Confluence, Service Desk, Postgres or SQL DB etc that can be reused in future.  
* Deleting a deployment is simply a case of deleting the resource group ie  
```
 az group delete --resource-group smontgomeryjira 
```

