# Finance Dashboard Demo

This project enables you to quickly set up Azure resources necessary to integrate with popular accounting systems and make the data available to users in Power BI. The project is designed to be reusable and extensible to other sources.

## Getting Started

These instructions will enable you to set up the resources you require in your own Azure subscription. The instructions are designed for PwC Norway users with a Visual Studio Enterprise Subscription with monthly free credits of $150. Most configurations are set up in order to be as cheap as possible and with moderate use it should be possible to use less than your free credits. However, please monitor your costs to avoid any surprises.

Note that this does not create a production-ready solution! Most settings are optimized for cheapness, not robustness or security. However, only a few changes in the configurations are necessary to create a production-ready solution.

### Prerequisites

To complete the setup, you will require:

* An Azure account linked to a Visual Studio Enterprise Subscription
* A private GitHub account
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

This setup and the scripts used are designed to be executed in Cloud Shell. Therefore, this guide assumes that you work in Cloud Shell. If you prefer to develop locally instead, you will need to make some changes that are not covered here.

**1. Create a new private repository on your GitHub account and name it finance-dashboard-demo. Use these settings:**
   
![Create Private Repo](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/create_private_repo.png)

**2. Clone this GitHub repository and save it on your machine. Replace `<my-username>` with your GitHub username:**

Open Git Bash and navigate to the location that you want to save the local version of the repository and run the commands below:

```
# Clone this repository
git clone "https://github.com/PWCNORWAY/finance-dashboard-demo.git"

# Move into the repository
cd finance-dashboard-demo/

# Remove origin and set your private repo as origin
git remote rm origin
git remote add origin "https://github.com/<my-username>/finance-dashboard-demo.git"

# Push to remote branch and set up tracking
git push --all origin -u
```

[Note: After pushing to your remote repository you will likely receive an email from GitHub stating that a deployment failed. This is because a GitHub action is set up in the repository which triggers deployment of a Python project to Azure Functions every time something is pushed to your repository. This deployment is not currently authenticated, but we will fix this later]

**3. Go to portal.azure.com and log in with your PwC credentials**

**4. Open the cloud shell and select Bash:**

![Launch cloud shell](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/launch_cloud_shell.gif)

[Note: You must have a storage account associated with your Cloud Shell. If you are promped to create a storage account, select OK and proceeed. The first time you open the Cloud Shell you will be prompted to choose between Bash and PowerShell and your should select Bash for this guide.]

**5. Upload *arm_template.json* from your local repository:**

![Upload files](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/upload_files.gif)

*arm_template.json* contains the textual representation of the Azure Data Factory you will set up.

**6. Open the editor in Cloud Shell by clicking the {} icon and paste the contents of *azure_setup_script.sh* from your local repository**

[Note: It may seem unnecessary to copy the content, paste it and save it to file instead of uploading the file to clouddrive and editing it. However, this is an easy way to avoid that the shell script fails because of [Windows-style line endings](https://stackoverflow.com/questions/426397/do-line-endings-differ-between-windows-and-linux)].

If you want to familiarize yourself with the content of this setup script, you can take a look at the markdown version *azure_setup_script.md* which contains more verbose comments.

**7. Use Crtl+S to save the script and name it *azure_setup_script.sh*. Execute the script in the Cloud Shell by running `bash azure_setup_script.sh`:**

![Script](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/script.gif)

**8. The script will prompt you to set the following variables:**

* `PROJECT_NAME` - Should be only alphanumeric characters. As both Azure Storage Account and Azure Key Vault names must be unique, and they are both prefixed with `PROJECT_NAME`, it is an advantage if `PROJECT_NAME` is prefixed with a value, e.g. your name, rather than just "test"

* `MY_IP_ADDRESS` - Input your public IP address. You will find it by googling "my ip"

* `DBSERVER_ADMIN_PASSWORD` - Must adhere to SQL Server password requirements. The password should have at least eight characters, not contain the username and contain at least three of these four characters:

   * A lowercase letter

   * An uppercase letter

   * A number

   * A special character like !, $, % or #

[Note: If the sql server setup does not accept your password, it will automatically be changed to @PwCBergen2020!]

**9. If the script executes without error, you are finished with this part of the setup and should skip to the next part. If not, consider the advice below:**

Check the command line output to see which operation failed. Key Vault creation sometimes fails with a HTTP error. This is normally resolved by restarting the Cloud Shell and retrying. SQL Server creation may fail if it is not possible to create a server in the region at the given time. This can normally be fixed by switching to a different region, like for instance setting `RESOURCE_LOCATION=westus`.

When you have figured out the reason for the error, run the code statement-by-statement from where the script failed. To make this easier, the variables that were stored when execution failed is available in the file *variables.txt*, and you can copy these by opening the file in the Cloud Editor. If you cannot find the reason for your error and restarting the Cloud Shell does not fix your issue, do not hesitate to contact me (oystein.hellenes.grov@pwc.com).

### Azure Functions Configuration

As part of the Azure setup script you set up a Python 3.7 Function App. In order for this Function App to be callable, you will need to deploy some code to it.

A few installations are necessary to set up a local development environment for Azure Function, as you can see from [this quickstart](https://docs.microsoft.com/en-us/azure/azure-functions/functions-create-first-azure-function-azure-cli?tabs=bash%2Cbrowser&pivots=programming-language-python). If you want to develop Azure Functions using Python yourself, you will need to go through the setup process. However, if you just want to deploy the Azure Function from this repository to your own resource group it's much simpler!

In the repository there is a file called `.github/workflows/linux-python-functionapp-on-azure.yml`. This file contains instructions for deploying the code in the `azfunc` directory to your Azure Function whenever a change is pushed to the repository. For this to work, we need to give GitHub permission to deploy to your Function App: 

**1. The Azure setup script created an Azure Function App for you. Go to portal.azure.com and type *Function App* in the search bar and select your function app, which should be called *[your-project-name]-func***

**2. In the top menu, select *Get publish profile*, open the downloaded file and copy its content:**

![Get publish profile](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/get_publish_profile.gif)

[Note! The content of this file is sensitive and, therefore, I don't show the file. You should open the file you downloaded and copy the content]

**3. Go to the GitHub repository *finance-dashboard-demo* on your private GitHub, and go to *Settings* &rarr; *Secrets* &rarr; *Add a new secret***

![Add secret](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/add_secret.gif)

**4. Name your secret `AZURE_FUNCTIONAPP_PUBLISH_PROFILE` and paste the content of the *.PublishSettings* file in the value field.**

![Set secret](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/set_secret.gif)

**5. Go to `.github/workflows/linux-python-functionapp-on-azure.yml` in your forked GitHub repository and click *Edit*.**

![Set yaml](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/edit_yaml.gif)

**6. On line 14, replace `findemo-func'` in `AZURE_FUNCTIONAPP_NAME: 'findemo-func'` with the name of your Function App.**

**7. When you have completed the steps below, your changes are pushed to the remote repository and the GitHub Action which publishes your Azure Function is prompted. It will be approximately five minutes after completion of the Github Action until the functions are available.**

**8. Go to portal.azure.com and type *Function App* in the search bar and select your function app. Wait and refresh until the functions *get_account_list* and *get_transactions* appear under *Functions (Read Only)* in the left menu**

### Data Factory Configuration

Once you have Azure Function set up, the Data Factory is available for use. You may now trigger the full refresh orchestration pipelines to populate your Azure SQL Database.
You will trigger the main orchestration pipeline, which is baded on data from 24SevenOffice test clients and the demo orchestration pipeline which is based on generated data stored in flat files.

**1. Go to adf.azure.com**

**2. Select your Data Factory**

![Select Data Factory](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/select_adf.PNG)

**3. Go to *Pipelines* &rarr; *Trigger Orchestration* &rarr; *ORC_FULL_REFRESH* and select *Add trigger* &rarr; *Trigger now*. Keep the default parameter values and select *OK***

![Trigger pipeline](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/trigger_pipeline.gif)

**4. Repeat the step above for the demo version of the pipeline by selecting *Pipelines* &rarr; *Demo* &rarr; *DEMO_ORC_FULL_REFRESH* and selecting *Add trigger* &rarr; *Trigger now***

**5. Select the monitor icon in the left tab to monitor the execution of your pipeline runs**

![Monitor](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/monitor.PNG)

Once the orchestration has completed, the tables are available for use. If you would like to, you may inspect and query them in a database tool, like for instance [SQL Server Management Studio](https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms?view=sql-server-ver15).

### PowerBI Configuration

When the Data Factory loads have completed you can connect Power BI to the SQL Database you have set up using the Power BI file [demo_dashboard.pbix](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/master/dashboards/demo_dashboard.pbix). The database connection in the file is parameterized, so you only need to change the SQL server name, SQL database name and the schema that you want to connect to. It is better to use the demo data than the 24SevenOffice test data for this purpose.

**1. Open the Power BI file demo_dashboard.pbix**

**2. Select *Rediger spørringer* &rarr; *Rediger parametere***

![Rediger spoerringer](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/rediger_spoerringer.gif)

**3. Replace the values for *sql_server_connection* and *sql_db_name* with your own**

*sql_server_connection* has the format `[your-sqlserver-name].database.windows.net`. Replace `[your-sqlserver-name]` with the name of your SQL server.

**4. If you are prompted to log in, select *Database* in the left menu and log in with your SQL database credentials**

![Log in](https://github.com/PWCNORWAY/finance-dashboard-demo/blob/media/database_login.png)

**5. You should now be able to get data from your database. If you have problems it may be because your public IP address has changed since you set up the Azure connection. To fix this go to portal.azure.com, search for *sql servers*, select your sql server, select *Firewalls and virtual networks* under *Security*, click *Add client IP* and save**

## Contributing

### Contributing to the project

Our goal is to develop the project further by improving the integrations and ETL flows we have already set up and add integrations with more accounting systems. If you want to contribute, please contact me (oystein.hellenes.grov@pwc.com) for more information.

We are looking to set up a shared Azure user subscription for PwC Bergen in order to make cooperation easier. Currently, you may allow other users access to your resource group, but your subscription will be charged for the activity in the resource group. 

### Contributing to this GitHub repo

#### Step 1

- **Option 1**
    - 🍴 Fork this repo! (not currently permitted in the organization)

- **Option 2**
    - 👯 Clone this repo to your local machine using `https://github.com/PWCNORWAY/finans-dashboard-demo.git`

#### Step 2

- **HACK AWAY!** 🔨🔨🔨

## Authors

* **Øystein Hellenes Grov** - *Initial work* - [ogr003](https://github.com/ogr003)

See also the list of [contributors](https://github.com/PWCNORWAY/finans-dashboard-demo/contributors) who participated in this project.

## Acknowledgments

* The Azure Function for the 24SevenOffice integration uses the excellent `python-24so` library, which is available [here](https://github.com/loyning/python-24so)
