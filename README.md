# Azure Deployment Template

## Dependencies
* Node (`brew install node`)
* Gulp
* Azure CLI (`curl -L https://aka.ms/InstallAzureCli | bash`)

## Configuration
1. Put your SSH PublicKey (`~/.ssh/id_rsa.pub`) into the file `azuredeploy.parameters.json` in the relevant "jumpboxSshKey" property.
2. Execute `echo "$(id -P | cut -d: -f1)-" > .prefix`, this will prefix all resource groups with that name.
3. By default, JIRA is the product that is deployed. If you are working on Confluence, run `echo confluence > .product`. This will make the deployment use confluence's ARM templates.

## How to run a deployment
1. Run `az login`
2. Run `npm i` to install dependencies
3. Run `npm start` to start the deployment

## How to remove deployed environment
1. Run `npm stop`

## Making changes
If you make changes to any file, you have to put the changed file into the blobstore that is used for provisioning.
Either create a new blobstore or reuse an existing one.

If you create a new blobstore, you have to update the parameters "provisioningStorageName" and "provisioningStorageToken"
in the file `azuredeploy.parameters.json`.

## Keep parameters clean

The deployment requrires to have `azuredeploy.parameters.json` in the repository. That means that you need to make sure you don't commit your custom values into it during development.

To avoid this hassle just create `azuredeploy.parameters.local.json` in product specific directory, it is ignored by git and it overrides the repo version of `azuredeploy.parameters.json`

## Redeploying your changes
Just run `npm start` again - it will delete the old resource group (stored in the file `.group`) and run a new deployment.

## Using SSH to connect to nodes
You can only access JIRA nodes via the NAT gateway. To connect to a node directly via the NAT gateway, you can use a
SSH command like this:
```
ssh -o 'ProxyCommand=ssh -i ~/.ssh/id_rsa jiraadmin@jiranat_address_.australiaeast.cloudapp.azure.com nc %h %p' jiraadmin@10.0.2.4
```

The password for the `jiraadmin` user on JIRA nodes is `JIRA@dmin`.

## Building a zip for publishing
Run `gulp publish` to build a zip in the `target/` directory. Similarly with running a deployment, if you have a `.product` file with 'confluence' in it,
then the publish will build the confluence deployment files. If you want to run the publish directly regardless of the `.product` file,
use `gulp publish-jira` or `gulp publish-confluence`.
