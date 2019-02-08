# Atlassian Jira Service Desk Data Center

Jira Service Desk Data Center gives you uninterrupted access to JIRA Service Desk with performance at scale, disaster recovery and instant scalability when hosting our applications in your Azure private cloud account.

## Deploy to Azure Portal

[![Deploy Jira Service Desk Data Center to Azure Portal](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fbitbucket.org%2Fatlassian%2Fatlassian-azure-deployment%2Fraw%2Fmaster%2Fjira%2Fazuredeploy.json)

**_NB. Jira Service Desk uses the same ARM templates as Jira Software. Ensure you select the "servicedesk" option from the Jira-Product parameter droplist._**

![alt text](../jira/images/ServiceDeskJiraOption.png "Jira Service Desk Option")

NB. The current Azure deployment utilises certain Azure functionality like App Insights, Azure Monitoring, SQL Analytics etc that are still in Preview mode and not available in most regions. To ensure you can utilise these technologies deploy into the following regions:  

1. Canada Central  
2. Central India  
3. East US  
4. Southeast Asia  
5. UK South  
6. West Europe  
7. West US 2  


You can of course disable App Insights, Analytics etc via the template parameters to allow installation to your desired region.

Further information on parameters and other installation options for the Atlassian Azure solution can be found at our [Support Page](https://hello.atlassian.net/wiki/spaces/DC/pages/369608838/Azure+Support+Page)  

## View Azure Deployment Results

View deployment output values in Azure Portal for endpoints, DB url etc.  
![alt text](../jira/images/JiraDeploymentResults.png "Jira Service Desk Deployment Results")
