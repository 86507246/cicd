# Atlassian Data Center Azure Templates

## Purpose
This repository contains Azure ARM templates to install the following [Atlassian Data Center](https://www.atlassian.com/enterprise/data-center) products:  

1. [BitBucket Data Center](https://www.atlassian.com/software/bitbucket/enterprise/data-center)  
2. [Confluence Data Center](https://www.atlassian.com/software/confluence/enterprise/data-center)  
3. [Jira Software Data Center](https://www.atlassian.com/enterprise/data-center/jira)  
4. [Jira Service Desk Data Center](https://www.atlassian.com/software/jira/service-desk/enterprise/data-center)  

## Key Features
These templates will be utilise Azure Cloud features to create a resilient and scaleable solution:  

*  Only Azure "managed" features/functionality used to provide scaleablity, monitoring and backup/recovery features "out of the box."  
*  Secure solution - security and accessibility principles/rules applied to ensure all customer data is protected.  
*  Optional SSL and CNAME/domain name support.  
*  Advanced monitoring with integrated Azure Application Insights, Azure Monitor.  
*  Advanced analytics with integrated Azure Application Insights, Azure SQL Analytics, Azure Gateway Analytics.  
*  Log collection/aggregation.  
*  Choice of Azure SQL DB or Postgres databases.  
*  Choice of supplying existing Azure SQL DB or Postgres database.  
*  Integrated Azure Accelerated Networking for enhanced cluster performance.  
*  Recommended HW/cluster sizing or fully configurable HW options.  

 
![Azure Architecture](images/AzureArchitecture.png "Azure Architecture")

Further information on the Atlassian Azure solution, features, install options, FAQs etc can be found at our [Support Page](https://hello.atlassian.net/wiki/spaces/DC/pages/369608838/Azure+Support+Page)  


## Installation
Each Atlassian application folder contains specific instructions on how to deploy the individual application so always check there first. As well as this repository, the Atlassian apps can also be found on the Azure Marketplace.

### Jumpbox SSH Key Parameter
However, for all apps, you'll always need to specify a `jumpboxSshKey` parameter in order to be able to connect (via SSH) to the jumpbox/bastion node (and then onto the Cluster nodes). This key is your device's SSH public key (normally found at `~/.ssh/id_rsa.pub`). Cut/paste this value into the `jumpboxSshKey` parameter like so:
```
    {
        "parameters": {
            "jumpboxSshKey":
                "value": "ssh-rsa AAAAo2D7KUiFoodDCJ4VhimXqG..."
            }
        }
    }
```

## Development
Please see the development options [DEVELOPING.md](DEVELOPING.md) or [DEVELOPING2.md](DEVELOPING2.md) for more information on how you can use the update/develop the templates.

## Contributors

Pull requests, issues and comments welcome. For pull requests:

* Add tests for new features and bug fixes
* Follow the existing style
* Separate unrelated changes into multiple pull requests

See the existing issues for things to start contributing.

For bigger changes, make sure you start a discussion first by creating
an issue and explaining the intended change.

Atlassian requires contributors to sign a Contributor License Agreement,
known as a CLA. This serves as a record stating that the contributor is
entitled to contribute the code/documentation/translation to the project
and is willing to have it used in distributions and derivative works
(or is willing to transfer ownership).

Prior to accepting your contributions we ask that you please follow the appropriate
link below to digitally sign the CLA. The Corporate CLA is for those who are
contributing as a member of an organization and the individual CLA is for
those contributing as an individual.

* [CLA for corporate contributors](https://na2.docusign.net/Member/PowerFormSigning.aspx?PowerFormId=e1c17c66-ca4d-4aab-a953-2c231af4a20b)
* [CLA for individuals](https://na2.docusign.net/Member/PowerFormSigning.aspx?PowerFormId=3f94fbdc-2fbe-46ac-b14c-5d152700ae5d)
