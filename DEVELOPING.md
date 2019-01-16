
## Dependencies
* Node (`brew install node`), version 7.6+ for support for `async`
* Gulp
* Azure CLI (`curl -L https://aka.ms/InstallAzureCli | bash` or `brew install azure-cli`)

## Configuration
1. Before making changes to the configuration, be sure to have read about keeping parameters clean in the respective section below.
2. Put your SSH public key (`~/.ssh/id_rsa.pub`) as the `jumpboxSshKey` property (or `sshKey` for Bitbucket, at the moment), in the product-specific file `$product/azuredeploy.parameters.local.json`, like so:

       {
           "parameters": {
               "jumpboxSshKey":
                   "value": "ssh-rsa AAAAo2D7KUiFoodDCJ4VhimXqG..."
               }
           }
       }
3. For Bitbucket, also set an admin password, which is the password that would allow you to SSH _from_ the jumpbox into the actual nodes: `"adminPassword: { "value": "..." }`
4. Execute `echo "$(whoami)-" > .prefix`. This will prefix all resource groups with your username. This file, just like `.product` in the next step, is expected in the main directory, i.e. not a product subdirectory.
5. By default, JIRA is the product that is deployed. If you are working on Confluence or Bitbucket Server, run `echo confluence > .product` or `echo bitbucket > .product` accordingly. This will make the deployment to use product-specific ARM templates.

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

The process deployment requires to have `azuredeploy.parameters.json` in the repository. That means that you need to make sure that you don't commit your custom values into the repository during development.

To avoid this hassle create you can `azuredeploy.parameters.local.json` in a product specific directory, it is ignored by git and it overrides the repo version of `azuredeploy.parameters.json` when you run deployment with `npm start`

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
use `gulp publish-jira`, `gulp publish-confluence` or `gulp publish-bitbucket`.
