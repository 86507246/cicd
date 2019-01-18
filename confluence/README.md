# Atlassian Confluence Data Center

Confluence Data Center gives you uninterrupted access to Confluence with performance at scale, disaster recovery and instant scalability when hosting our applications in your Azure private cloud account.

## Confluence Architecture

The original version of the Azure templates created a standalone Synchrony cluster as part of the deployment. These templates follow the now recommended approach of letting Confluence manage Synchrony for you. This will reduce setup maintenance and cost. For more information see the [Set up a Synchrony Cluster for Confluence Data Center](https://confluence.atlassian.com/doc/set-up-a-synchrony-cluster-for-confluence-data-center-958779073.html) article.

## Deploy to Azure Portal

[![Deploy Confluence Data Center to Azure Portal](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fbitbucket.org%2Fatlassian%2Fatlassian-azure-deployment%2Fraw%2Fmaster%2Fconfluence%2Fazuredeploy.json)

NB. The current Azure deployment utilises certain Azure functionality like App Insights, Azure Monitoring, SQL Analytics etc that are still in Preview mode and not available in most regions. To ensure you can utilise these technologies deploy into the following regions:
1. East US
2. West Europe
3. Southeast Asia
4. Canada Central
5. Central India

You can of course disable App Insights, Analytics etc via the template parameters to allow installation to your desired region.

Further information on parameters and other installation options for the Atlassian Azure solution can be found at our [Support Page](https://hello.atlassian.net/wiki/spaces/DC/pages/369608838/Azure+Support+Page)  

## View Azure Deployment Results

View deployment output values in Azure Portal for endpoints, DB url etc.  
![Confluence Deployment Results](images/ConfDeploymentResults.png "Confluence Deployment Results")
