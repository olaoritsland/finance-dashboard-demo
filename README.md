# Finance Dashboard Demo

This project enables you to quickly set up Azure resources necessary to integrate with popular accounting systems and make the data available to users in Power BI. The project is designed to be reusable and extensible to other sources.

## Getting Started

These instructions will enable you to set up the resources you require in your own Azure subscription. The instructions are designed for PwC Norway users with a Visual Studio Enterprise Subscription with monthly free credits of $150. Most configurations are set up in order to be as cheap as possible and with moderate use it should be possible to use less than your free credits. However, please monitor your costs to avoid any surprises.

Note that this does not create a production-ready solution! Most settings are optimized for cheapness, not robustness or security. However, only a few changes in the configurations are necessary to create  a production-ready solution.

### Prerequisites

To complete the setup, you will require:

* An Azure account linked to a Visual Studio Enterprise Subscription
* A private GitHub user |ccount
* Git for Windows (this guide assumes you have Git for Windows, but you can use any Git command line tool)

#### Visual Studio Enterprise Subscription
This guide assumes that you have a Visual Studio Enterprise Subscription. If you do not have one, please fill out the [Visual Studio subscription enrollment form](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/master/utils/readme/Visual%20Studio%20Subscription%20Enrollment%20Form.docx) and send the email below to pwcuser@microsoft.com, with the form attached.

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

#### GitHub account

If you do not already have one, you will need to [create a GitHub account](https://github.com/join)

#### Git for Windows

You will require a Git command line tool to clone this repository and push it to your private GitHub. You can download the latest version from [here](https://gitforwindows.org/). During the installation you will need to go through some steps in the configuration. For most users, the following choices should be fine:

![Git Setup](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/git_setup.png)

When the download has finished, open Git Bash. To connect to GitHub you may either use [SSH](https://help.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh) or run the commands below, where you replace `yourusername` and `youremail@domain.com` with your GitHub username and the email address associated with your GitHub account.

```
# Create a directory called Git within your home directory
mkdir git

# Change your current directory to the folder you created
cd git/

# Configure GitHub username
git config --global user.name "yourusername"

# Configure GitHub email address
git config --global user.email "youremail@domain.com"
```

### Setup

This setup and the scripts used are designed to be executed in Cloud Shell. Therefore, this guide assumes that you work in Cloud Shell. If you prefer to develop locally instead, you may need to make some changes.

**1. Create a new private repository on your GitHub account and name it finance-dashboard-demo. Use these settings:**
   
![Create Private Repo](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/create_private_repo.png)

**2. Clone this GitHub repository and save it on your machine. Replace `<my-username>` with your GitHub username:**

Navigate to the location that you want to save the local version of the repository and run the commands below

```
# Clone this repository
git clone "https://github.com/PWCNORWAY/finance-dashboard-demo.git"

# Move into the repository
cd finance-dashboard-demo/

# Remove origin and your private repo as origin
git remote rm origin
git remote add origin "https://github.com/<my-username>/finance-dashboard-demo.git"

# Push to remote git master branch
git push -u origin master
```

[Note: After pushing to your remote repository you will likely receive an email from GitHub stating that a deployment failed. This is because a GitHub action is set up in the repository which triggers deployment of a Python project to Azure Functions every time something is pushed to your repository. This deployment is not currently authenticated, but we will fix this later]

**3. Go to portal.azure.com and log in with your PwC credentials**

**4. Open the cloud shell and select Bash:**

![Launch cloud shell](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/launch_cloud_shell.gif)

**5. Upload *arm_template.json* and *db-template.bacpac*:**

![Upload files](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/upload_files.gif)

*arm_template.json* contains the textual representation of the Azure Data Factory you will set up.

*db-template.bacpac* contains the information necessary to create an Azure SQL Database with a set of predefined tables.

**6. Open the editor in Cloud Shell by clicking the {} icon and paste the contents of *azure_set_up_script.sh* from your local repository**

[Note: It may seem unnecessary to copy the content, paste it and save it to file instead of uploading the file to clouddrive and editing it. However, this is an easy way to avoid that the shell script fails because of [Windows-style line endings](https://stackoverflow.com/questions/426397/do-line-endings-differ-between-windows-and-linux)].

**7. You should edit the following variable names in the script:**

* `PROJECT_NAME` - Should be only alphanumeric characters. As both Azure Storage Account and Azure Key Vault names must be unique, and they are both prefixed with `PROJECT_NAME`, it is an advantage if `PROJECT_NAME` is prefixed with a value, e.g. your name, rather than just "test"
* `DBSERVER_ADMIN_PASSWORD`

**8. Use Crtl+S to save the script and name it *azure_set_up_script.sh*. Execute the script in the Cloud Shell by running `bash azure_set_up_script.sh`:**

![Script](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/script.gif)

**9. If the script executes without error, you are finished with the setup and should skip to the next part. If not, delete the resource group you have just created by executing the code below. Remember to replace the value after `PROJECT_NAME=` with your *PROJECT_NAME*:**
```
## Note! Deletes the resource group you have created. Only run this if you experience errors
PROJECT_NAME=<your-project-name>
RESOURCE_GROUP=$PROJECT_NAME-RG
SUBSCRIPTION=$(az account list --query "[].{Name:name, ID:id}[?contains(Name,'Visual Studio')].ID" -o tsv)

# Delete all assets
az group delete --resource-group $RESOURCE_GROUP --subscription $SUBSCRIPTION
```
After deleting the resource group, restart the Cloud Shell and try to run the code statement by statement by copying and pasting into Cloud Shell. If there are errors, look at the error messages and see if you can figure out what happened. Remember that some resources require names to be in a certain format or be unique. If you cannot find the reason for your error, do not hesitate to contact me (oystein.hellenes.grov@pwc.com)

### Azure Functions Configuration

As part of the Azure setup script you set up a Python 3.7 Function App. In order for this Function App to be... well... functional, you will need to deploy some code to it.

It is a bit of work to set up a local development environment for Azure Function, as you can see from [this quickstart](https://docs.microsoft.com/en-us/azure/azure-functions/functions-create-first-azure-function-azure-cli?tabs=bash%2Cbrowser&pivots=programming-language-python). If you want to develop Azure Functions using Python yourself, you will need to go through the setup process. However, if you just want to deploy the Azure Function from this repository to your own resource group it's much simpler!

In the repository there is a file called `.github/workflows/linux-python-functionapp-on-azure.yml`. This file contains instructions for deploying the code in the `azfunc` directory to your GitHub function whenever a change is pushed to the repository. For this to work, we need to give GitHub permission to deploy to your Function App: 

1. The Azure setup script created an Azure Function App for you. Go to portal.azure.com and type `Function App` in the search bar and select your function app, which should be called *[your-project-name]-func*

2. In the top menu, select *Get publish profile*, open the downloaded file and copy its content:

![Get publish profile](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/get_publish_profile.gif)

[Note! The content of this file is sensitive and, therefore, I don't show the file. You should open the file you downloaded and copy the content]

3. Go to the GitHub repository *finance-dashboard-demo* on your private GitHub, and go to *Settings* &rarr; *Secrets* &rarr; *Add a new secret*

![Add secret](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/add_secret.gif)

4. Name your secret `AZURE_FUNCTIONAPP_PUBLISH_PROFILE` and paste the content of the *.PublishSettings* file in the value field.

![Set secret](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/set_secret.gif)

5. Go to `.github/workflows/linux-python-functionapp-on-azure.yml` in your forked GitHub repository and click *Edit*.

![Set yaml](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/edit_yaml.gif)

6. On line 14, replace `findemo-func'` in `AZURE_FUNCTIONAPP_NAME: 'findemo-func'` with the name of your Function App.

### Data Factory Configuration

### PowerBI Configuration

## Contributing

### Step 1

- **Option 1**
    - 🍴 Fork this repo! (not currently permitted in the organization)

- **Option 2**
    - 👯 Clone this repo to your local machine using `https://github.com/PWCNORWAY/finans-dashboard-demo.git`

### Step 2

- **HACK AWAY!** 🔨🔨🔨

## Authors

* **Øystein Hellenes Grov** - *Initial work* - [ogr003](https://github.com/ogr003)

See also the list of [contributors](https://github.com/PWCNORWAY/finans-dashboard-demo/contributors) who participated in this project.

## Acknowledgments

* The Azure Function for the 24SevenOffice integration uses the excellent `python-24so` library, which is available [here](https://github.com/loyning/python-24so)
