# Finance Dashboard Demo

This project enables you to quickly set up Azure resources necessary to integrate with popular accounting systems and make the data available to users in Power BI. The project is designed to be reusable and extensible to other sources.

## Getting Started

These instructions will enable you to set up the resources you require in your own Azure subscription. The instructions are designed for PwC Norway users with a Visual Studio Enterprise Subscription with monthly free credits of $150. Most configurations are set up in order to be as cheap as possible and with moderate use it should be possible to use less than your free credits. However, please monitor your costs to avoid any surprises.

### Prerequisites

This guide assumes that you have a Visual Studio Enterprise Subscription. If you do not have one, please fill out the form ... and send the email below to pwcuser@microsoft.com, with the form attached.

-------------------------------------------
Dear Sir or Madam,

I hereby confirm that I have familiarized myself and will comply with the following usage regulations:
* The subscription is single-user based
* The end-user license agreement prohibits the use of software in a business production environment, and is only to be used in a development/evaluation capacity
* Retail versions of licensed software are to be used in the production environment and must be obtained from the Microsoft Volume * Licensing Services Center (VLSC) download site
* That I will present a timely respond to the annual validations

Please find enclosed my MSDN Enrollment Form

Thank you for your time,

YOUR_NAME

-------------------------------------------

It may also be an advantage to have Git for Windows available. You can download the latest version from [here](https://gitforwindows.org/).

### Azure Setup

This setup and the scripts used are designed to be executed in Cloud Shell. Therefore, this guide assumes that you work in Cloud Shell. If you prefer to develop locally instead, you may need to make some changes.

1. Clone this GitHub repository and save it on your machine
2. Go to portal.azure.com and log in with your PwC credentials
3. Open the cloud shell and select Bash

4. Upload *arm_template.json* and *db-template.bacpac* as shown below. *arm_template.json* contains the textual representation of the Azure Data Factory you will set up. *db-template.bacpac* contains the information necessary to create an Azure SQL Database with the tables you will require
5. Open the editor in Cloud Shell by clicking the {} icon.
6. Open *azure_set_up_script.sh* in a text editor on your machine. Copy the content and paste it into the Cloud Shell editor. [Note: It may seem pointless to copy the content, paste it and save it to file instead of uploading the file to clouddrive and editing it. However, this is an easy way to avoid that the shell script fails because of Windows-style line endings].
7. You should edit the following variable names in the script: 
    * `PROJECT_NAME` - Should be only alphanumeric characters. As both Azure Storage Account and Azure Key Vault names must be unique, and they are both prefixed with `PROJECT_NAME`, it is an advantage if `PROJECT_NAME` is prefixed with a value, e.g. your name, rather than just "test"
    * `DBSERVER_ADMIN_PASSWORD`
8. Use Crtl+S to save the script and name it *azure_set_up_script.sh*
9. Execute the script in the cloud shell by running
```
bash azure_set_up_script.sh
```
10. If the script executes without error, you are finished with the setup and should skip to the next part. If not, delete the resource group you have just created by executing the code below. Remember to replace the value after `PROJECT_NAME=` with your *PROJECT_NAME*
```
## Note! Deletes the resource group you have created. Only run this if you experience errors
PROJECT_NAME=<your-project-name>
RESOURCE_GROUP=$PROJECT_NAME-RG
SUBSCRIPTION=$(az account list --query "[].{Name:name, ID:id}[?contains(Name,'Visual Studio')].ID" -o tsv)

# Delete all assets
az group delete --resource-group $RESOURCE_GROUP --subscription $SUBSCRIPTION
```
After deleting the resource group, restart the Cloud Shell and try to run the code statement by statement by copying and pasting into Cloud Shell. If there are errors, look at the error messages and see if you can figure out what happened. Remember that some resources require names to be in a certain format or be unique. If you cannot find the reason for your error, do not hesitate to contact me (oystein.hellenes.grov@pwc.com)

### Data Factory Configuration

### PowerBI Configuration

## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/PurpleBooth/b24679402957c63ec426) for details on our code of conduct, and the process for submitting pull requests to us.

### Step 1

- **Option 1**
    - 🍴 Fork this repo!

- **Option 2**
    - 👯 Clone this repo to your local machine using `https://github.com/PWCNORWAY/finans-dashboard-demo.git`

### Step 2

- **HACK AWAY!** 🔨🔨🔨

## Authors

* **Øystein Hellenes Grov** - *Initial work* - [ogr003](https://github.com/ogr003)

See also the list of [contributors](https://github.com/PWCNORWAY/finans-dashboard-demo/contributors) who participated in this project.

## Acknowledgments

* The Azure Function for the 24SevenOffice integration uses the excellent `python-24so` library, which is available [here](https://github.com/loyning/python-24so)
