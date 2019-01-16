# Atlassian Azure Templates

## Note
Please note that these templates are for evaluation or 'proof of concept' deployments. These are not currently recommended for a production deployment 'as is' and will require adjustment to meet your needs.

## Purpose
This repository contains Azure ARM templates to install the following Atlassian products:
1. Jira Software Data Center
2. Jira Service Desk Data Center
3. Confluence Data Center
4. BitBucket Data Center

These templates will be utilise Azure Cloud features to create a resilient and scaleable solution:

![alt text](images/AzureArchitecture.png "Azure Architecture")

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
Please see the [DEVELOPING.md](DEVELOPING.md) for more information on how you can use the update/develop the templates.
