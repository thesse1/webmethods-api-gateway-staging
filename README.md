# About API Gateway Staging

> Note: This version of the API Gateway Staging solution depends on Azure DevOps Service. An older version of the solution which supports Azure DevOps Server 2019 can be found in the azure_devops_server_2019 branch: https://github.com/thesse1/webmethods-api-gateway-staging/tree/azure_devops_server_2019.

The webMethods API Gateway Staging solution allows to extract API Gateway assets from a DESIGN environment (local or shared/central), add them to a Git repository and automatically promote them to DEV, TEST and PROD environments, controlled by Azure DevOps build pipelines. During the promotion, the assets are first imported on a BUILD environment where they are automatically validated and tested (based on Postman collections) and specifically prepared for the intended target environment (also based on Postman collections). After this procedure, the modified assets are exported again from BUILD environment and imported on the target environment (DEV, TEST or PROD).

The solution also includes a script (and pipelines) for automatically extracting the general configuration of API Gateway environments. This includes the configuration of the API Gateway destination, the Transaction logging global policy and multiple administrative settings. The configuration can be added to the repository and imported on API Gateway environments using Azure DevOps build pipelines for quickly setting up new API Gateway environments or for resetting existing environments.

Finally, the solution also includes an Azure DevOps build pipeline for automatically purging the API Gateway logs stored in the internal Elasticsearch database. This pipeline can be configured to run in defined iterations, e.g., once every day.

This solution is based on https://github.com/thesse1/webmethods-api-gateway-devops which is by itself a fork of https://github.com/SoftwareAG/webmethods-api-gateway-devops.

## Some background

As each organization builds APIs using API Gateway for easy consumption and monetization, the continuous integration and delivery are integral part of the API Gateway solutions to meet the consumer demands. We need to automate the management of APIs and policies to speed up the deployment, introduce continuous integration concepts and place API artifacts under source code management. As new apps are deployed, the API definitions can change, and those changes have to be propagated to other external products like API Portal / Developer Portal. This requires the API owner to update the associated documentation and in most cases this process is a tedious manual exercise. In order to address this issue, it is a key to bring in DevOps style automation to the API life cycle management process in API Gateway. With this, enterprises can deliver continuous innovation with speed and agility, ensuring that new updates and capabilities are automatically, efficiently and securely delivered to their developers and partners in a timely fashion and without manual intervention. This enables a team of API Gateway policy developers to work in parallel developing APIs and policies to be deployed as a single API Gateway configuration.

This CI/CD or DevOps approach can be achieved in multiple ways:

### Using webMethods Deployer and Asset Build Environment

API Gateway asset binaries can be build using Asset Build Environment and promoted across stages using WmDeployer. More information on this way of CI/CD and DevOps automation can be found at https://tech.forums.softwareag.com/t/staging-promotion-and-devops-of-api-gateway-assets/237040.

### Using Promotion Management APIs

The promotion APIs that are exposed by API Gateway can be used for the DevOps automation. More information on these APIs can be found at https://github.com/SoftwareAG/webmethods-api-gateway/blob/master/apigatewayservices/APIGatewayPromotionManagement.json.

### Directly using the API Gateway Archive Service API for exporting and importing asset definitions

This approach is followed in this solution. Using the API Gateway Archive Service API, API Gateway assets and configuration items are exported from the source stage, stored and managed in Git, and then imported on the target stages.

In addition to this, the solution includes an automatic validation and adjustment of API Gateway assets for the deployment on different stages. It implements the following "design-time policies":
 - Alias values are set to target stage-specific values
 - Text values in other API Gateway assets (like APIs, policies and applications) are set to target stage-specific values
 - APIs should have separate sets of applications (with different identifiers) on different stages. The correct deployment of these applications should be enforced automatically. All applications are created on a local development environment or the central DESIGN environment with names ending with "_DEV", "_TEST" or "_PROD" indicating their intended usage. All applications should be exported and managed in Git, but only the intended applications should be imported on the respective DEV, TEST and PROD environments.
 - APIs must not contain any local, API-level Log Invocation policies in order to prevent any privacy issues caused by too detailed transaction logging
 - API mocking is turned off for deployments on TEST and PROD environments
 - API tags are added to all APIs indicating the build ID, the build name and the pipeline name (for auditability)

![GitHub Logo](/images/Overview.png)

This is implemented by validating and manipulating the assets on dedicated BUILD environments: Initially, all assets (including all applications) are imported on the BUILD environment. Then the local, API-level policy actions are scanned for any unwanted Log Invocation policies, all applications except for _DEV, _TEST or _PROD, respectively, are automatically deleted from the BUILD environment, alias values and test values in other assets are overwritten, API tags are inserted, and API mocking is disabled (for TEST and PROD target environments). Finally, the API project is exported again from the BUILD environment (now only including the right applications for the target environment and aliases with the right values and APIs with the right API tags and, if applicable, API mocking turned off) and imported on the target environment.

More of these design-time policies could easily be developed by extending the underlying Postman collections.

In addition to the deployment ("promotion") of assets to DEV, TEST and PROD, the solution also includes pipelines for deploying API projects to the central DESIGN environment - without validations, manipulations and API tests. This allows for (re-)setting the DESIGN environment to the current (or some former) state of the API development - selectively for the assets defined in one API project. Older states (Git commits) can be retrieved temporarily for inspecting former stages of the development or permanently for re-basing the development of the API project on an earlier version.

Finally, the solution also includes a pipeline for exporting API projects from the central DESIGN environment. The pipeline will automatically commit the exported project to the HEAD of the selected repository branch.

The solution supports separate stages for hosting internal and external APIs. The respective stages are called DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and PROD_EXT. Both internal and external APIs can be configured on the same local development environment or the central DESIGN environment. They must be assigned to the "Internal" and/or the "External" API group in order to be eligible for deployment to internal and/or external API Gateway DEV/TEST/PROD environments. ("Internal" and "External" must be added to the apiGroupingPossibleValues extended setting in API Gateway for making these values eligible as API groups.) APIs assigned to both the "Internal" and the "External" API group are eligible for deployment on internal and external API Gateway environments.

The solution supports target stages with multiple environments, for example in different regions. (Each environment can itself be a single API Gateway instance or an API Gateway cluster.) The environments within one stage will always get the same configuration and the same set of APIs. Applications can by synchronized within stages using HAFT, cf. https://documentation.softwareag.com/webmethods/api_gateway/yai10-15/webhelp/yai-webhelp/#page/yai-webhelp%2Fco-haft_reference_arch.html.

The following API Gateway assets and configurations can be moved across API Gateway stages:
 - Gateway APIs 
 - Policy Definitions/Policy Templates/Global Policies
 - Applications
 - Aliases
 - Plans
 - Packages
 - Subscriptions
 - Users/Groups/ACLs/Teams
 - General Configurations like Load balancer, Extended settings
 - Security configurations
 - Destination configurations
 - External accounts configurations

> Note: The solution only supports additive promotion of new assets or asset changes. It does not support the promotion of asset deletions. Assets can be deleted directly on the target environment (in the API Gateway UI or through the respective API Gateway asset management REST API). The recommended procedure for decommissioning APIs is to deactivate the API on the DESIGN environment and propagate that change to the target stages. This makes the decommissioning process more transparent and traceable.

## About this repository

This repository provides assets and scripts for implementing the CI/CD solution for API Gateway assets and general configurations. The artifacts in this repository use the API Gateway Archive Service API (and other API Gateway Service APIs) for automation of the DevOps flow.

The repository has the following top-level folders:
  - .postman: Created and managed directly by Postman when managing the Postman collections in a Postman workspace
  - apis: Contains projects with the API Gateway assets exported from DESIGN environment along with the definition of the projects' asset sets as well as alias and scope definitions
  - azure-devops-demo-generator: Template definition and supporting files for creating demo/seed ADO projects using the [Azure DevOps Demo Generator](https://azuredevopsdemogenerator.azurewebsites.net/)
  - bin: Windows batch script that exports/imports a defined set of API Gateway assets from/to DESIGN environment and stores the asset definition in file system (local clone of the Git repository)
  - configuration: Contains folders with the API Gateway configuration assets exported from DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and PROD_EXT environments along with the definition of the exported asset sets
  - environments: Contains folders with Postman environment definition files for API Gateway environments in the DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and PROD_EXT stages. Each folder includes the definitions for one set of environments. The solution comes with two sample sets:
    - webm_io: Set of webMethods.io API Gateways hosted on the Software AG cloud
    - azure_demo_01: Set of API Gateways deployed to Azure Kubernetes Service clusters
  - images: Diagrams and screenshots used in this documentation
  - pipelines: Contains the Azure DevOps pipeline definitions and pipeline templates for deploying API Gateway assets on DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and PROD_EXT environments, for initializing the environments, for exporting assets, for updating API definitions, for configuring HAFT, for publishing APIs to API Portal / Developer Portal and for log purging
  - postman/collections/utilities: Contains Postman collections for importing API Gateway assets, for preparing (cleaning) the BUILD environment, for preparing the API Gateway assets on BUILD for the target environment, for initializing API Gateway environments with environment-specific configurations, and for log purging
  - postman/collections/apitests: Contains Postman collections with API tests for every API project which are executed automatically for every API deployment
  - schemas: Contains an updated version of the Petstore API Swagger API specification for demonstrating automatic API update

The repository content can be committed to a Git repository (e.g., the Azure DevOps repository or a GitHub repository), it can be branched, merged, rolled-back like any other code repository. Every commit to any branch in the repository can be imported back to a local development environment, to the central DESIGN environment or promoted to DEV, TEST or PROD.

Larger organizations implementing the API Gateway Staging solution tend to split the content of this repository into separate repos for different groups working on the content. For example, you can create separate repos with the following folders:
 - pipelines and postman/collections/utilities for the pipeline developers
 - configuration and environments for the API Gateway administrators
 - apis and postman/collections/apitests for the API providers

## Develop and test APIs using API Gateway

The most common use case for an API Developer is to develop APIs on the central DESIGN environment (or on their local development environments), export them to a flat file representation and commit this to Git. Also, developers need to import their APIs from Git to the central DESIGN environment (or their local development environments) for further updates.

The gateway_import_export_utils.bat under /bin can be used for this. Using this batch script, the developers can export/import APIs from/to the central DESIGN environment (or their local development API Gateway) to/from their local Git repository and vice versa. In addition to that, the gateway_import_export_utils.bat batch script can also be used for exporting or importing a defined set of general configuration assets from/to local development environments, DESIGN, BUILD, DEV, TEST or PROD.

Alternatively, the developer can also use the `Export selected/arbitrary API project from DESIGN` pipelines and the `Deploy selected/arbitrary API project(s)` pipelines to export/import APIs from/to the central DESIGN environment into/from Git. In addition to that, the `Export API Gateway Configuration` pipeline and the `Configure API Gateway(s)` pipeline can be used for exporting or importing the general configuration from/to DESIGN, BUILD, DEV, TEST or PROD.

The set of assets exported by gateway_import_export_utils.bat --exportapi (and by the `Export selected/arbitrary API project from DESIGN` and `Export API Gateway Configuration` pipelines) is defined by the export_payload.json in the API project or the configuration root folder. It must be a JSON document applicable for the API Gateway Archive Service API POST /archive request payload, cf. https://documentation.softwareag.com/webmethods/api_gateway/yai10-15/webhelp/yai-webhelp/#page/yai-webhelp%2Fco-exp_imp_archive.html. It will typically contain a list of asset types ("types") to be exported and a query ("scope") based on the IDs of the selected assets.

### gateway_import_export_utils.bat

The gateway_import_export_utils.bat can be used for importing and exporting APIs (projects) in a flat file representation. The export_payload.json file in each project folder under /apis defines which API Gateway assets belong to this project. The assets will be imported/exported into/from their respective project folders under /apis.

| Parameter | README |
| ------ | ------ |
| importapi or exportapi |  To import or export from/to the flat file representation |
| api_name | The name of the API project to import or export |
| apigateway_url |  API Gateway URL to import to or export from |
| username |  The API Gateway username. The user must have the "Export assets" or "Import assets" privilege, respectively, for the --exportapi and --importapi option |
| password | The API Gateway user password |

Sample Usage for importing the Petstore API that is present as flat file representation under /apis/petstore/assets into API Gateway server at https://apigw-config.acme.com

```sh
bin>gateway_import_export_utils.bat --importapi --api_name petstore --apigateway_url https://apigw-config.acme.com --apigateway_username hesseth --apigateway_password ***
```

Sample Usage for exporting the Petstore API that is present on the API Gateway server at https://apigw-config.acme.com as flat file under /apis/petstore/assets

```sh
bin>gateway_import_export_utils.bat --exportapi --api_name petstore --apigateway_url https://apigw-config.acme.com --apigateway_username hesseth --apigateway_password ***
```

The batch script can also be used for importing and exporting general API Gateway configurations in a flat file representation. The export_payload.json file in each folder under /configuration defines which API Gateway assets belong to this configuration. The assets will be imported/exported into/from their respective folders under /configuration.

| Parameter | README |
| ------ | ------ |
| importconfig or exportconfig |  To import or export from/to the flat file representation |
| environment | The type of the environment to import or export (DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT or PROD_EXT) |
| apigateway_url |  API Gateway URL to import to or export from |
| username |  The API Gateway username. The user must have the "Export assets" or "Import assets" privilege, respectively, for the --exportconfig and --importconfig option |
| password | The API Gateway user password |

Sample Usage for importing the configuration that is present as flat file representation under /configuration/DESIGN/assets into API Gateway server at https://apigw-config.acme.com

```sh
bin>gateway_import_export_utils.bat --importconfig --environment DESIGN --apigateway_url https://apigw-config.acme.com --apigateway_username hesseth --apigateway_password ***
```

Sample Usage for exporting the configuration that is present on the API Gateway server at https://apigw-config.acme.com as flat file under /configuration/DESIGN/assets

```sh
bin>gateway_import_export_utils.bat --exportconfig --environment DESIGN --apigateway_url https://apigw-config.acme.com --apigateway_username hesseth --apigateway_password ***
```

## scopes.json configuration of OAuth2 scopes for API projects

Each API project can include one scopes.json file in the API project root folder specifying the OAuth2 scopes needed by the API(s) in the API project. The file will be parsed right before importing the other API Gateway assets of the API project and the scopes are injected into the local OAuth2 Authorization Server configuration. ("UPSERT": Existing scope definitions with the same name will be overwritten, new scope definitions with new names will be added.)

## scopes.json configuration of OAuth2 scopes for API Gateway configurations

Each API Gateway configuration can include one scopes.json file in the configuration root folder specifying the OAuth2 scopes intended for the APIs on this API Gateway environment. The file will be parsed right before importing the other API Gateway assets of the API Gateway configuration and the scopes are injected into the local OAuth2 Authorization Server configuration. ("UPSERT": Existing scope definitions with the same name will be overwritten, new scope definitions with new names will be added.)

## Target stage-specific value substitutions

The API Gateway Staging solution offers three mechanisms for injecting target stage-specific values into the definitions of the API Gateway assets when they are prepared on the BUILD environment for their target stages:

### Value substitution using using Azure DevOps Replace Tokens extension

Any text field in any asset on the DESIGN stage can include placeholders in the format `#{placeholder_name}#` at any point in the text field content. These placeholders will be replaced during the build phase on the BUILD environment by the `Deploy selected/arbitrary API project(s)` pipelines by values specific for the intended target stage of this build. The values are pulled from Azure DevOps pipeline variables which can be managed in the Azure DevOps variable groups API_Gateway_DEV_INT_value_substitutions, API_Gateway_DEV_EXT_value_substitutions, API_Gateway_TEST_INT_value_substitutions, API_Gateway_TEST_EXT_value_substitutions, API_Gateway_PROD_INT_value_substitutions and API_Gateway_PROD_EXT_value_substitutions.

This facilitates a separation of concern between API configuration experts managing the asset definitions in API Gateway and API providers managing the actual parameter values for their APIs on the different target stages directly in Azure DevOps without having to work on the API Gateway DESIGN (or in the repository code). On the other hand, this means that the target stage-specific values will not be managed in Git, but directly in the Azure DevOps project.

Confidential values like passwords in outbound authentication policies can be secured by hiding their values in the Azure DevOps variable groups.

> Note: Placeholders are only allowed in text fields. If you try to place placeholders in numeric fields, the API Gateway UI will not let you save the asset.

> Note: Placing placeholders into asset definitions on the DESIGN environment might result in the API not working on the DESIGN stage anymore. For example, placing a placeholder into the API description does not cause any problem, but placing a placeholder into the endpoint URI in a routing policy will break the policy. The API will not be testable anymore on DESIGN, but it will work fine on the target stages and also on BUILD for the automatic test cases. (Replacing the placeholders takes place before running the automatic test scenario.)

> Note: You can find a sample for this mechanism in the sample SwaggerPetstore API, see below.

### aliases.json configuration of target stage-specific alias values

Each API project can include one aliases.json file in the API project root folder specifying aliases used by the API(s) in the API project which should be overwritten with environment-specific values. In addition to that, there can be one global aliases.json file in the /apis root folder for overwriting values of aliases used by APIs in multiple API projects.

For each target environment, the aliases.json files must include JSON objects applicable for the API Gateway Alias Management Service API PUT /alias/{aliasId} request payload, cf. https://documentation.softwareag.com/webmethods/api_gateway/yai10-15/webhelp/yai-webhelp/#page/yai-webhelp%2Fco-restapi_alias_mgmt.html.

In order to avoid conflicts, each alias may only be configured to be overwritten either in the global aliases.json file in the /apis root folder or in the aliases.json files in the API project root folders.

Alias names cannot be changed by this functionality.

Aliases for which no values are defined (for the current target environment) in the global aliases.json file or in the API project's aliases.json file will be deployed with their original alias values from the DESIGN environment.

This facilitates the setting of specific alias values for every target stage directly in the code. All values for one alias can conveniently be managed in one place - for text fields as well as for numeric or boolean values and without breaking the testability of the API on the DESIGN environment.

> Note: Automatic tests on BUILD will be executed with the alias values as defined on the DESIGN environment. The target stage-specific replacement of alias values based on the aliases.json files takes place after the execution of the automatic test scenario.

> Note: Confidential values should not be managed using this mechanism as they would be included in clear text in the aliases.json files in Git.

> Note: You can find a sample for this mechanism in the sample Ping API, see below.

### Value substitution using using Azure DevOps Replace Tokens extension for aliases.json files

Both the global and the API-project-specific aliases.json files can also include placeholders in the format `#{placeholder_name}#`.

This allows for a mix of the first and the second mechanism for injecting target stage-specific values. You can define alias definitions for all target stages with some fixed values in the aliases.json files including some placeholders for values which should be replaced based on Azure DevOps pipeline variables (maybe for a better separation of concern or for better hiding confidential values).

> Note: Automatic tests on BUILD will be executed with the alias values as defined on the DESIGN environment. The target stage-specific replacement of alias values based on the aliases.json files takes place after the execution of the automatic test scenario.

> Note: Inside the aliases.json files, placeholders can be placed inside the values of text fields, but also in numeric and boolean field values.

> Note: Technically, an aliases.json file with placeholders in the values of numeric or boolean fields does not represent a valid JSON document, so your editor might complain when opening or saving such a file. But the placeholders will be replaced by the correct numeric or boolean values before the files are interpreted as JSON documents, so this does not cause any problem at pipeline runtime.

> Note: You can find a sample for this mechanism in the sample PostmanEcho API, see below.

# Sample content included in this repository

## export_payload.json export query for sample API projects

The /apis folder contains sample API projects with the following export_payload.json files:

### petstore

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "f3d2a3c1-0f83-43ab-a6ec-215b93e2ecf5"
    }
  ]
}
```

This example will select the API with asset ID f3d2a3c1-0f83-43ab-a6ec-215b93e2ecf5 (the SwaggerPetstore demo API with API key authentication and consumer application identification). It will automatically also include all applications defined for this API, and it will include the PetStore_Routing_Alias simple alias configured for routing API requests to the native Petstore API at https://petstore.swagger.io/v2. This API and all other instances of the Petstore demo API are assigned to the Internal API group, so they can be deployed on DEV_INT, TEST_INT and PROD_INT.

The description of the API and the description of the PetStore_Routing_Alias contain a placeholder `#{stage_name}#` which will be populated during build by the content of the stage_name pipeline variable.

In addition to that, the value of the PetStore_Routing_Alias contains the placeholder `#{petstore_route}#` which will be populated during build by the content of the petstore_route pipeline variable.

> Note: Because of the `#{petstore_route}#` in the PetStore_Routing_Alias, the API cannot be tested on DESIGN, but the placeholder will be replaced by the correct variable value during build before the automatic regression tests.

### petstore_basicauth

```
{
  "types": [
    "api","users","groups","accessprofiles"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "131ee26d-056a-432b-b30d-5e6ec4bb4a6a|f162fb3b-2429-48fb-983b-3fb7f7a15cae|e5d1d6c9-5eee-4f21-b26a-531a88740eeb|eb85bb2b-136e-4d14-a5cd-8186d6b49647"
    }
  ]
}
```

This example showcases HTTP Basic Authentication for the Petstore demo API. The following user, group and team are authorized to use the API: testuser_01, testgroup_02 (with testuser_02) and testteam_03 (assigned to testgroup_03 with testuser_03). API Gateway will not automatically include the authorized user, group and team in the export. Therefore, testuser_01, testgroup_02 and testteam_03 must be included in export_payload.json explicitly. The dependent assets (testuser_02, testgroup_03 and testuser_03) will be included automatically.

This API is also using the PetStore_Routing_Alias with the `#{stage_name}#` and `#{petstore_route}#` placeholders in its description and value, respectively.

> Note: This sample API cannot be deployed on any target environment in the webm_io environment set, because webMethods.io API does not support the Authorize User policy, but it can be deployed in the azure_demo_01 target environments.

> Note: Because of the `#{petstore_route}#` in the PetStore_Routing_Alias, the API cannot be tested on DESIGN, but the placeholder will be replaced by the correct variable value during build before the automatic regression tests.

### petstore_versioning

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "4ea2dcf0-66c5-469b-b822-fe4707c6f899"
    },
    {
      "attributeName": "id",
      "keyword": "4bd552e3-064f-444a-bc77-7560059c9955"
    }
  ],
  "condition" : "or"
}
```

This API project includes two APIs, actually two versions of the same API. They must be configured separately in the export_payload.json of the API project. The two API versions are using two different (simple) aliases, PetStore_Routing_Alias_1_0_8 and PetStore_Routing_Alias_1_0_9, for routing API requests to the native Petstore API.

The aliases PetStore_Routing_Alias_1_0_8 and PetStore_Routing_Alias_1_0_9 also contain the `#{stage_name}#` and `#{petstore_route}#` placeholders in their description and value, respectively.

> Note: Because of the `#{petstore_route}#` in the aliases, the APIs cannot be tested on DESIGN, but the placeholder will be replaced by the correct variable value during build before the automatic regression tests.

### postman_echo

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "d73d5702-6925-41a0-8c23-933326c27b96"
    }
  ]
}
```

This example features the Postman Echo API (https://learning.postman.com/docs/developer/echo-api/) which is often used for demonstrating API Management features. For each request type (POST, GET, DELETE), it extracts the header, query and path parameters and the request body from the request and echoes them back in the response payload. The API is using the PostmanEcho_Routing_Alias endpoint alias configured for routing API requests to the native PostmanEcho API at https://postman-echo.com. This API and all other instances of the PostmanEcho API are assigned to the External API group, so they can be deployed on DEV_EXT, TEST_EXT and PROD_EXT.

The description of the API contains a placeholder `#{stage_name}#` which will be populated during build by the content of the stage_name pipeline variable.

### postman_echo_mocking

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "d9dde2b3-481a-4660-9d92-f0d46d0d630e"
    }
  ]
}
```

This API project contains an instance of the Postman Echo API with API mocking enabled. API tests will be executed on the BUILD environment against the Mock API, and the API will be deployed on DEV with mocking enabled. For the deployment on TEST and PROD, mocking will be disabled.

### postman_echo_multiple_tenants

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "9be25215-20c6-4e8c-803a-d9ddac3394cc|328ae890-452f-43f1-9501-b708c7afc83f|0245c29f-e583-4ebd-824a-a4762ad85fbf"
    }
  ]
}
```

This API project demonstrates two ways of implementing multi-tenancy in API Gateway. It contains two APIs which are specifically designed for one tenant each:
 - Tenant1_PostmanEcho
 - Tenant2_PostmanEcho

In order to simulate different endpoints per tenant, the Tenant1_PostmanEcho API adds a tenant=Tenant1 query parameter to the native service endpoint, and the Tenant2_PostmanEcho API adds a tenant=Tenant2 query parameter to the native service endpoint. This query parameter is reflected in the response from the native service.

And the API project contains an API which can be used by both Tenant1 and Tenant2:
 - Common_PostmanEcho

This API will automatically identify the tenant by the incoming API key, and then it will "route" the request to the right endpoint by adding tenant=Tenant1 or tenant=Tenant2 to the native endpoint in a Context-based Routing policy.

### postman_echo_oauth2

```
{
  "types": [
    "api", "gateway_scope"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "4ceba5ec-f0bc-42c7-a431-40ec951aeecf|69fb0cfe-d549-4572-92d9-cb1131d45e61"
    }
  ]
}
```

This API is using OAuth2 for inbound authentication. Therefore, the developer must also include the scope mapping ("gateway_scope") in the export set.

> Note: The local OAuth2 scope itself cannot be promoted from stage to stage using this mechanism, because it is configured in the general "local" system alias for the internal OAuth2 Authorization Server. OAuth2 scopes needed for the API(s) in an API project can be configured in the API project's scopes.json file.

### postman_echo_jwt

```
{
  "types": [
    "api","users"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "ffd2bf1e-7d49-46a9-8278-a7d91a70d313|82182bb9-0184-4fc2-9eae-0c5a5b5023ab"
    }
  ]
}
```

This API is using JSON Web Tokens (JWT) for inbound authentication. It is configured to authorize requests with JWTs issued to the user testuser_jwt. The user itself must be included explicitly in the export set.

### postman_echo_security_alias

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "6831e46d-9f45-4096-a2cc-84dca749fbd4"
    }
  ]
}
```

In addition to the PostmanEcho_Routing_Alias, this API makes use of the PostmanEcho_Security_Alias defining username and password credentials used in an Outbound Auth - Transport policy.

### ping

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "1e137fbf-6334-4fdf-beb4-4899f644ab5b"
    }
  ]
}
```

The Ping API directly invokes the /invoke/wm.server:ping endpoint on the local underlying Integration Server of the API Gateway using Ping_Routing_Alias (simple alias). The API is assigned to the Internal and to the External API group, so it can be deployed on all DEV, TEST and PROD environments.

### number_conversion

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "211d57cf-dae3-4fbc-9836-c27b3c7f8182"
    }
  ]
}
```

This is an example for a SOAP API incl. test request in APITest.json. The API is assigned to the Internal and to the External API group, so it can be deployed on all DEV, TEST and PROD environments.

### odata_tutorial

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "a63d8dc0-f1af-4993-a376-2929c6cfa2bc"
    }
  ]
}
```

This is an example for an OData API incl. test requests in APITest.json. The API is assigned to the Internal and to the External API group, so it can be deployed on all DEV, TEST and PROD environments.

### countries

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "1cfe70d9-7723-4d79-91f4-30596fc9ba3e"
    }
  ]
}
```

This is an example for a GraphQL API incl. test request in APITest.json. The API is assigned to the Internal and to the External API group, so it can be deployed on all DEV, TEST and PROD environments.

> Note: This sample API cannot be deployed on any target environment in the webm_io environment set, because webMethods.io API does not seem to support GraphQL APIs (as of 16.05.2024), but it can be deployed in the azure_demo_01 target environments.

## export_payload.json export query for API projects representing negative test cases

These API projects cannot be deployed on any (target) stages. They are included in this collection to demonstrate various failure conditions and to test the API Gateway Staging solution's mechanisms for failure detection and error handling. 

### zzz_internal_external

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "f3d2a3c1-0f83-43ab-a6ec-215b93e2ecf5|d73d5702-6925-41a0-8c23-933326c27b96"
    }
  ]
}
```

This API project includes an instance of the internal Petstore API and an instance of the external PostmanEcho API. Therefore, this API project cannot be deployed on any DEV, TEST or PROD environment. The build pipeline will detect this and return with an error message.

### zzz_invalid_app_name

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "6c199d85-4384-4cb0-878d-eeaac4a27212"
    }
  ]
}
```

This API project includes an instance of the PostmanEcho API with an application called "Invalid_App_Name_INVALID". Therefore, this API project cannot be deployed on any DEV, TEST or PROD environment. The build pipeline will detect this and return with an error message.

### zzz_invalid_logging_policy

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "ee520a86-e1d9-4bb0-baca-6d02a351e5d6"
    }
  ]
}
```

This API project includes an instance of the PostmanEcho API with an unwanted local, API-level Log Invocation policy. Therefore, this API project cannot be deployed on any DEV, TEST or PROD environment. The build pipeline will detect this and return with an error message.

### zzz_missing_api_group

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "a5610e16-9843-4dce-aba7-95f74aa12155"
    }
  ]
}
```

This API project includes an instance of the PostmanEcho API which is not assigned to any API group. Therefore, this API project cannot be deployed on any DEV, TEST or PROD environment. The build pipeline will detect this and return with an error message.

### zzz_alias_not_found

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "f3d2a3c1-0f83-43ab-a6ec-215b93e2ecf5"
    }
  ]
}
```

This API project includes an invalid aliases.json file, see below.

### zzz_duplicate_alias

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "f3d2a3c1-0f83-43ab-a6ec-215b93e2ecf5"
    }
  ]
}
```

This API project includes an invalid aliases.json file, see below.

### zzz_incorrect_alias_name

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "4ea2dcf0-66c5-469b-b822-fe4707c6f899|4bd552e3-064f-444a-bc77-7560059c9955"
    }
  ]
}
```

This API project includes an invalid aliases.json file, see below.

### zzz_missing_alias_id

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "4ea2dcf0-66c5-469b-b822-fe4707c6f899|4bd552e3-064f-444a-bc77-7560059c9955"
    }
  ]
}
```

This API project includes an invalid aliases.json file, see below.

### zzz_incorrect_alias_name

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "4ea2dcf0-66c5-469b-b822-fe4707c6f899|4bd552e3-064f-444a-bc77-7560059c9955"
    }
  ]
}
```

This API project includes an invalid aliases.json file, see below.

### zzz_test_failure

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "4ea2dcf0-66c5-469b-b822-fe4707c6f899|4bd552e3-064f-444a-bc77-7560059c9955"
    }
  ]
}
```

This API project is companioned by an invalid test case, see below.

## scopes.json configuration of OAuth2 scopes for API projects

The postman-echo-oauth2 sample project includes the following scopes.json file configuring the scope name and description user by the API:

```
[
    {
        "name": "postman-echo",
        "description": "postman-echo scope definition"
    }
]
```

The JSON array can include multiple scope definitions.

## aliases.json configuration of environment-specific alias values

### Global aliases.json file

```
{
  "postman-echo-routing-alias": {
    "id" : "97c5a4c8-e253-4fed-bd57-dd6dae1450fd",
    "DEV_EXT": {
      "name" : "PostmanEcho_Routing_Alias",
      "description" : "PostmanEcho alias on DEV_EXT",
      "type" : "endpoint",
      "owner" : "Administrator",
      "endPointURI" : "https://postman-echo.com",
      "connectionTimeout" : 100,
      "readTimeout" : #{postman_echo_readTimeout}#,
      "suspendDurationOnFailure" : 0,
      "optimizationTechnique" : "None",
      "passSecurityHeaders" : false,
      "keystoreAlias" : "",
      "truststoreAlias" : ""
    },
    "TEST_EXT": {
      "name" : "PostmanEcho_Routing_Alias",
      "description" : "PostmanEcho alias on TEST_EXT",
      "type" : "endpoint",
      "owner" : "Administrator",
      "endPointURI" : "https://postman-echo.com",
      "connectionTimeout" : 50,
      "readTimeout" : #{postman_echo_readTimeout}#,
      "suspendDurationOnFailure" : 0,
      "optimizationTechnique" : "None",
      "passSecurityHeaders" : false,
      "keystoreAlias" : "",
      "truststoreAlias" : ""
    },
    "PROD_EXT": {
      "name" : "PostmanEcho_Routing_Alias",
      "description" : "PostmanEcho alias on PROD_EXT",
      "type" : "endpoint",
      "owner" : "Administrator",
      "endPointURI" : "https://postman-echo.com",
      "connectionTimeout" : 20,
      "readTimeout" : #{postman_echo_readTimeout}#,
      "suspendDurationOnFailure" : 0,
      "optimizationTechnique" : "None",
      "passSecurityHeaders" : false,
      "keystoreAlias" : "",
      "truststoreAlias" : ""
    }
  }
}
```

The global aliases.json file in the /apis folder contains alias values for the DEV_EXT, TEST_EXT and PROD_EXT target stages for the PostmanEcho_Routing_Alias endpoint alias used in the PostmanEcho APIs.

Note that the description and connectionTimeout attributes are set to different values for the three target stages. These values will be injected into the actual alias before importing it on the target environments.

Note that the readTimeout on all three target stages is represented by the placeholder `#{postman_echo_readTimeout}#`. It is replaced during build by the content of the postman_echo_readTimeout pipeline variable.

### ping

```
{
  "ping-routing-alias": {
    "id" : "02ee4daf-e735-4193-9fe1-50f94dafe92d",
    "DEV_INT": {
      "name" : "Ping_Routing_Alias",
      "description" : "Ping alias on DEV_INT",
      "type" : "endpoint",
      "owner" : "Administrator",
      "endPointURI" : "http://localhost:5555",
      "connectionTimeout" : 100,
      "readTimeout" : 1000,
      "suspendDurationOnFailure" : 0,
      "optimizationTechnique" : "None",
      "passSecurityHeaders" : false,
      "keystoreAlias" : "",
      "truststoreAlias" : ""
    },
    "DEV_EXT": {
      "name" : "Ping_Routing_Alias",
      "description" : "Ping alias on DEV_EXT",
      "type" : "endpoint",
      "owner" : "Administrator",
      "endPointURI" : "http://localhost:5555",
      "connectionTimeout" : 100,
      "readTimeout" : 1000,
      "suspendDurationOnFailure" : 0,
      "optimizationTechnique" : "None",
      "passSecurityHeaders" : false,
      "keystoreAlias" : "",
      "truststoreAlias" : ""
    },
    "TEST_INT": {
      "name" : "Ping_Routing_Alias",
      "description" : "Ping alias on TEST_INT",
      "type" : "endpoint",
      "owner" : "Administrator",
      "endPointURI" : "http://localhost:5555",
      "connectionTimeout" : 50,
      "readTimeout" : 500,
      "suspendDurationOnFailure" : 0,
      "optimizationTechnique" : "None",
      "passSecurityHeaders" : false,
      "keystoreAlias" : "",
      "truststoreAlias" : ""
    },
    "TEST_EXT": {
      "name" : "Ping_Routing_Alias",
      "description" : "Ping alias on TEST_EXT",
      "type" : "endpoint",
      "owner" : "Administrator",
      "endPointURI" : "http://localhost:5555",
      "connectionTimeout" : 50,
      "readTimeout" : 500,
      "suspendDurationOnFailure" : 0,
      "optimizationTechnique" : "None",
      "passSecurityHeaders" : false,
      "keystoreAlias" : "",
      "truststoreAlias" : ""
    },
    "PROD_INT": {
      "name" : "Ping_Routing_Alias",
      "description" : "Ping alias on PROD_INT",
      "type" : "endpoint",
      "owner" : "Administrator",
      "endPointURI" : "http://localhost:5555",
      "connectionTimeout" : 20,
      "readTimeout" : 200,
      "suspendDurationOnFailure" : 0,
      "optimizationTechnique" : "None",
      "passSecurityHeaders" : false,
      "keystoreAlias" : "",
      "truststoreAlias" : ""
    },
    "PROD_EXT": {
      "name" : "Ping_Routing_Alias",
      "description" : "Ping alias on PROD_EXT",
      "type" : "endpoint",
      "owner" : "Administrator",
      "endPointURI" : "http://localhost:5555",
      "connectionTimeout" : 20,
      "readTimeout" : 200,
      "suspendDurationOnFailure" : 0,
      "optimizationTechnique" : "None",
      "passSecurityHeaders" : false,
      "keystoreAlias" : "",
      "truststoreAlias" : ""
    }
  }
}
```

The local aliases.json file in the /apis/ping folder contains alias values for all six target stages for the Ping_Routing_Alias endpoint alias used in the Ping API.

Note that the description, connectionTimeout and readTimeout attributes are set to different values for target stages. These values will be injected into the actual alias before importing it on the target environments.

### postman_echo_security_alias

```
{
  "postman-echo-security-alias": {
    "id" : "02ff45f6-7221-45f8-a06c-5b99fc34227d",
    "DEV_EXT": {
      "name" : "PostmanEcho_Security_Alias",
      "description" : "PostmanEcho security alias on DEV_EXT",
      "type" : "httpTransportSecurityAlias",
      "owner" : "Administrator",
      "authType" : "HTTP_BASIC",
      "authMode" : "NEW",
      "httpAuthCredentials" : {
        "userName" : "#{postman_echo_username}#",
        "password" : "#{postman_echo_password_base64}#"
      }
    },
    "TEST_EXT": {
      "name" : "PostmanEcho_Security_Alias",
      "description" : "PostmanEcho security alias on TEST_EXT",
      "type" : "httpTransportSecurityAlias",
      "owner" : "Administrator",
      "authType" : "HTTP_BASIC",
      "authMode" : "NEW",
      "httpAuthCredentials" : {
        "userName" : "#{postman_echo_username}#",
        "password" : "#{postman_echo_password_base64}#"
      }
    },
    "PROD_EXT": {
      "name" : "PostmanEcho_Security_Alias",
      "description" : "PostmanEcho security alias on PROD_EXT",
      "type" : "httpTransportSecurityAlias",
      "owner" : "Administrator",
      "authType" : "HTTP_BASIC",
      "authMode" : "NEW",
      "httpAuthCredentials" : {
        "userName" : "#{postman_echo_username}#",
        "password" : "#{postman_echo_password_base64}#"
      }
    }
  }
}
```

This file contains environment-specific values for the PostmanEcho_Security_Alias HTTP Transport security alias used only by the PostmanEcho_Security_Alias API in this API project.

Note that the userName and password attributes are represented by placeholders. They are replaced during build by the content of the respective pipeline variables.

> Note: The password in an HTTP Transport security alias must be provided in base-64-encoded form, so the value of the (secret) replacement variable must also be provided in base-64-encoded form.

## aliases.json configuration of environment-specific alias values for negative test cases

### zzz_alias_not_found

```
{
  "petstore-routing-alias-108": {
    "id" : "b0b54919-fdbc-4571-b087-89a7a60109fd",
    "DEV_INT": {
      "name" : "PetStore_Routing_Alias_1_0_8",
      "description" : "Petstore alias for API version 1.0.8 on DEV_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "TEST_INT": {
      "name" : "PetStore_Routing_Alias_1_0_8",
      "description" : "Petstore alias for API version 1.0.8 on TEST_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "PROD_INT": {
      "name" : "PetStore_Routing_Alias_1_0_8",
      "description" : "Petstore alias for API version 1.0.8 on PROD_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    }
  },
  "petstore-routing-alias-109": {
    "id" : "eab70f61-16ba-4c5a-9575-140fbe5763c6",
    "DEV_INT": {
      "name" : "PetStore_Routing_Alias_1_0_9",
      "description" : "Petstore alias for API version 1.0.9 on DEV_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "TEST_INT": {
      "name" : "PetStore_Routing_Alias_1_0_9",
      "description" : "Petstore alias for API version 1.0.9 on TEST_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "PROD_INT": {
      "name" : "PetStore_Routing_Alias_1_0_9",
      "description" : "Petstore alias for API version 1.0.9 on PROD_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    }
  }
}
```

This file contains environment-specific values for the PetStore_Routing_Alias_1_0_8 and the PetStore_Routing_Alias_1_0_9 aliases which are not included in this API project. The build pipeline will detect this and return with an error message.

### zzz_duplicate_alias

```
{
  "postman-echo-routing-alias": {
    "id" : "97c5a4c8-e253-4fed-bd57-dd6dae1450fd",
    "DEV_EXT": {
      "name" : "PostmanEcho_Routing_Alias",
      "description" : "PostmanEcho alias on DEV_EXT",
      "type" : "endpoint",
      "owner" : "Administrator",
      "endPointURI" : "https://postman-echo.com",
      "connectionTimeout" : 100,
      "readTimeout" : 100,
      "suspendDurationOnFailure" : 0,
      "optimizationTechnique" : "None",
      "passSecurityHeaders" : false,
      "keystoreAlias" : "",
      "truststoreAlias" : ""
    },
    "TEST_EXT": {
      "name" : "PostmanEcho_Routing_Alias",
      "description" : "PostmanEcho alias on TEST_EXT",
      "type" : "endpoint",
      "owner" : "Administrator",
      "endPointURI" : "https://postman-echo.com",
      "connectionTimeout" : 50,
      "readTimeout" : 50,
      "suspendDurationOnFailure" : 0,
      "optimizationTechnique" : "None",
      "passSecurityHeaders" : false,
      "keystoreAlias" : "",
      "truststoreAlias" : ""
    },
    "PROD_EXT": {
      "name" : "PostmanEcho_Routing_Alias",
      "description" : "PostmanEcho alias on PROD_EXT",
      "type" : "endpoint",
      "owner" : "Administrator",
      "endPointURI" : "https://postman-echo.com",
      "connectionTimeout" : 20,
      "readTimeout" : 20,
      "suspendDurationOnFailure" : 0,
      "optimizationTechnique" : "None",
      "passSecurityHeaders" : false,
      "keystoreAlias" : "",
      "truststoreAlias" : ""
    }
  }
}
```

This file contains environment-specific values for the PostmanEcho_Routing_Alias alias which is already overwritten by the global aliases.json file in the /apis root folder. The build pipeline will detect this and return with an error message.

### zzz_incorrect_alias_name

```
{
  "petstore-routing-alias-108": {
    "id" : "b0b54919-fdbc-4571-b087-89a7a60109fd",
    "DEV_INT": {
      "name" : "PetStore_Routing_Alias_1_0_8_XXX",
      "description" : "Petstore alias for API version 1.0.8 on DEV_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "TEST_INT": {
      "name" : "PetStore_Routing_Alias_1_0_8_XXX",
      "description" : "Petstore alias for API version 1.0.8 on TEST_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "PROD_INT": {
      "name" : "PetStore_Routing_Alias_1_0_8_XXX",
      "description" : "Petstore alias for API version 1.0.8 on PROD_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    }
  },
  "petstore-routing-alias-109": {
    "id" : "eab70f61-16ba-4c5a-9575-140fbe5763c6",
    "DEV_INT": {
      "name" : "PetStore_Routing_Alias_1_0_9_XXX",
      "description" : "Petstore alias for API version 1.0.9 on DEV_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "TEST_INT": {
      "name" : "PetStore_Routing_Alias_1_0_9_XXX",
      "description" : "Petstore alias for API version 1.0.9 on TEST_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "PROD_INT": {
      "name" : "PetStore_Routing_Alias_1_0_9_XXX",
      "description" : "Petstore alias for API version 1.0.9 on PROD_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    }
  }
}
```

This file contains environment-specific values for the PetStore_Routing_Alias_1_0_8 and the PetStore_Routing_Alias_1_0_9 aliases with incorrect names not matching with the names in the original alias definitions. The build pipeline will detect this and return with an error message.

### zzz_missing_alias_id

```
{
  "petstore-routing-alias-108": {
    "DEV_INT": {
      "name" : "PetStore_Routing_Alias_1_0_8",
      "description" : "Petstore alias for API version 1.0.8 on DEV_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "TEST_INT": {
      "name" : "PetStore_Routing_Alias_1_0_8",
      "description" : "Petstore alias for API version 1.0.8 on TEST_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "PROD_INT": {
      "name" : "PetStore_Routing_Alias_1_0_8",
      "description" : "Petstore alias for API version 1.0.8 on PROD_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    }
  },
  "petstore-routing-alias-109": {
    "DEV_INT": {
      "name" : "PetStore_Routing_Alias_1_0_9",
      "description" : "Petstore alias for API version 1.0.9 on DEV_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "TEST_INT": {
      "name" : "PetStore_Routing_Alias_1_0_9",
      "description" : "Petstore alias for API version 1.0.9 on TEST_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "PROD_INT": {
      "name" : "PetStore_Routing_Alias_1_0_9",
      "description" : "Petstore alias for API version 1.0.9 on PROD_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    }
  }
}
```

This file contains environment-specific values for the PetStore_Routing_Alias_1_0_8 and the PetStore_Routing_Alias_1_0_9 aliases, but the alias IDs are missing. The build pipeline will detect this and return with an error message.

### zzz_missing_alias_name

```
{
  "petstore-routing-alias-108": {
    "id" : "b0b54919-fdbc-4571-b087-89a7a60109fd",
    "DEV_INT": {
      "description" : "Petstore alias for API version 1.0.8 on DEV_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "TEST_INT": {
      "description" : "Petstore alias for API version 1.0.8 on TEST_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "PROD_INT": {
      "description" : "Petstore alias for API version 1.0.8 on PROD_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    }
  },
  "petstore-routing-alias-109": {
    "id" : "eab70f61-16ba-4c5a-9575-140fbe5763c6",
    "DEV_INT": {
      "description" : "Petstore alias for API version 1.0.9 on DEV_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "TEST_INT": {
      "description" : "Petstore alias for API version 1.0.9 on TEST_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "PROD_INT": {
      "description" : "Petstore alias for API version 1.0.9 on PROD_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    }
  }
}
```

This file contains environment-specific values for the PetStore_Routing_Alias_1_0_8 and the PetStore_Routing_Alias_1_0_9 aliases, but the alias names are missing. The build pipeline will detect this and return with an error message.

## export_payload.json export query for API Gateway configurations

The /configuration folder contains sample configurations for DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and PROD_EXT environments, for example:

### DESIGN

```
{
  "types": [
    "policy", "url_alias", "proxy_bypass", "administrator_setting"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "GlobalLogInvocationPolicy"
    },
    {
      "attributeName": "entityId",
      "keyword": "proxyBypass"
    },
    {
      "attributeName": "configId",
      "keyword": "errorProcessing|logConfig|gatewayDestinationConfig|keystore|settings|extended|HTTPListener@5556"
    }
  ],
  "condition" : "or"
}
```

This configuration includes the standard Transaction logging global policy configured (see below) and enabled, the proxy bypass addresses (only localhost), the API fault configured to the standard API Gateway error message template, the application logs configured as per the API Gateway standard (but with Kibana logger silent), the API Gateway destination (internal Elasticsearch database) events configuration as per the API Gateway standard (but with performance data publish interval of 5 minutes), the default outbound and inbound keystores and truststores, and the (extended) settings.

The Transaction logging global policy is configured differently on the eight environments:

| Environment | Configuration of Transaction logging global policy |
| ------ | ------ |
| DESIGN | Always (on success and on failure) incl. HTTP headers and payloads |
| BUILD | Always (on success and on failure) incl. HTTP headers and payloads |
| DEV_INT, DEV_EXT | Always (on success and on failure) incl. HTTP headers and payloads |
| TEST_INT, TEST_EXT | Always (on success and on failure) excl. HTTP headers and payloads |
| PROD_INT, PROD_EXT | Always (on success and on failure) excl. HTTP headers and payloads |

Send native provider fault in the API fault is configured differently on the eight environments:

| Environment | Send native provider fault |
| ------ | ------ |
| DESIGN | True |
| BUILD | True |
| DEV_INT, DEV_EXT | True |
| TEST_INT, TEST_EXT | True |
| PROD_INT, PROD_EXT | False |

More configuration assets can be added later.

## scopes.json configuration of OAuth2 scopes for API Gateway configurations

Each /configuration folder contains a scopes.json file for demonstrating this feature, for example:

### DESIGN

```
[
    {
        "name": "design-scope",
        "description": "OAuth2 demo scope on DESIGN"
    }
]
```

The JSON array can include multiple scope definitions.

## APITest.json Postman test collections

The next common scenario for an API developer is to assert the changes made to the APIs do not break their customer scenarios. This is achieved using Postman test collections, cf. https://learning.postman.com/docs/getting-started/introduction/. In a Postman test collection, the developer can group test requests that should be executed against the API under test every time a change is to be propagated to DEV, TEST or PROD. The collection can be defined and executed in a local instance of the Postman REST client, cf. https://learning.postman.com/docs/sending-requests/intro-to-collections/. The requests in a test collection should include scripted test cases asserting that the API response is as expected (response status, payload elements, headers etc.), cf. https://learning.postman.com/docs/writing-scripts/test-scripts/. Test scripts can also extract values from the response and store them in Postman variable for later use, https://learning.postman.com/docs/sending-requests/variables/. For example, the first request might request and get an OAuth2 access token and store it in a Postman variable; later requests can use the token in the variable for authenticating against their API. Test collections can even define request workflows including branches and loops, cf. https://learning.postman.com/docs/running-collections/building-workflows/. The automatic execution of Postman collections can be tested in the Postman REST client itself, cf. https://learning.postman.com/docs/running-collections/intro-to-collection-runs/.

Each API project must include one Postman test collection under the name APITest.json in its API tests folder under /postman/collections/apitests. The name of the API tests folder under /postman/collections/apitests must be identical to the name of the corresponding API folder under /apis. This test collection will be executed automatically on the BUILD environment for every deployment on DEV, TEST and PROD. It can be created by exporting a test collection in the Postman REST client and storing it directly in the API project's tests folder under the name APITest.json.

> Note: The test requests in the Postman collection must use the following environment variables for addressing the API Gateway. Otherwise, the requests will not work in the automatic execution on the BUILD environment. Developers can import and use the environment definitions in the Postman REST client from the /environments folder.

| Environment variable | README |
| ------ | ------ |
| {{api-protocol}} |  Protocol to be used for the test (http or https), must be used in the URL line of the test requests, e.g., {{api-protocol}}://{{api-ip}}:{{api-port}}/gateway/SwaggerPetstore/1.0/pet/123 |
| {{api-ip}} |  IP address of the API Gateway, must be used in the URL line of the test requests, e.g., {{api-protocol}}://{{api-ip}}:{{api-port}}/gateway/SwaggerPetstore/1.0/pet/123 |
| {{api-port}} |  Port number of the API Gateway, must be used in the URL line of the test requests, e.g., {{api-protocol}}://{{api-ip}}:{{api-port}}/gateway/SwaggerPetstore/1.0/pet/123 |
| {{api-hostname}} | Hostname of the API Gateway, must be used in the Host header of the test requests, e.g., Host: {{api-hostname}} |

The distinction between {{api-ip}} and {{api-hostname}} enables supporting API Gateway environments which are not (yet) properly represented in DNS.

> Note: The APITest.json Postman test collections will be executed automatically on the BUILD environment by the deployment pipelines before alias value replacement (but after replacement of placeholders). So, they will be executed with aliases holding values as they are imported from the repository, i.e., with the values defined on the central DESIGN environment or the local development environment. Make sure that these values are set appropriately for the tests to be executed on the BUILD environment.

The /postman/collections/apitests folder contains API tests folders with APITest.json test collections for the following sample API projects:

### petstore

The petstore test collection sends POST, GET and DELETE requests against the SwaggerPetstore API. It contains tests validating the response code and the petId returned in the response body.

> Note: As of 15.06.2021, we have detected a malfunction in the native Petstore API breaking the GET and DELETE requests defined in the APITest.json Postman test collection for Petstore APIs: The GET and DELETE requests will intermittently (ca. 50% of the time) fail to address the pet by id. We have therefore manipulated all APITest.json Postman test collections for Petstore APIs skipping the GET and DELETE requests and only running the POST requests. The original versions of the test collections are retained as APITest_full_test.json.

### petstore_basicauth

The petstore_basicauth test collection invokes POST, GET and DELETE requests for testuser_01, testuser_02 (member of testgroup_02) and testuser_03 (member of testgroup_03, assigned to testteam_03).

### petstore_versioning

The petstore_versioning test collection invokes POST, GET and DELETE requests for both API versions.

### postman_echo

The postman_echo test collection sends POST, GET and DELETE requests against the Postman Echo API. It contains tests validating the response code and the echoed request elements (payload and query parameter) in the response body.

### postman_echo_mocking

The postman_echo_mocking test collection sends POST, GET and DELETE requests against the Postman Echo Mock API. It contains tests validating the response code and the echoed request elements (payload and query parameter) in the response body and the "source" attribute included only in the mock response.

### postman_echo_multiple_tenants

The postman_echo_multiple_tenants test collection invokes all three APIs for Tenant1 and Tenant2, respectively. The requests contain tests for the correct tenant query parameter echoed in the response body.

### postman_echo_oauth2

The postman_echo_oauth2 test collection invokes the API Gateway pub.apigateway.oauth2/getAccessToken service to retrieve an OAuth2 token. It stores the token in a Postman variable and uses it in the subsequent POST, GET and DELETE requests against the API.

### postman_echo_jwt

The postman_echo_jwt test collection invokes the API Gateway /rest/pub/apigateway/jwt/getJsonWebToken endpoint to retrieve a JSON Web Token. It stores the token in a Postman variable and uses it in the subsequent POST, GET and DELETE requests against the API.

### postman_echo_security_alias

The postman_echo_security_alias test collection sends POST, GET and DELETE requests against the Postman Echo API. It contains tests validating the response code and the echoed request elements (payload and query parameter and Authorization HTTP request header set by the Outbound Authentication policy using the PostmanEcho_Security_Alias HTTP Transport security alias) in the response body.

### ping

The ping test collection invokes the Ping API GET request and validates the response code and the presence of the date attribute returned by the ping request.

### number_conversion

The number_conversion test collection includes one POST request invoking the NumberToWords operation of the NumberConversion SOAP API. It validates the response code and the result of the number-to-words conversion.

### odata_tutorial

The odata_tutorial test collection includes 17 GET requests invoking the TripPinService OData API. It validates the response code for every request.

### countries

The countries test collection includes one POST request invoking the Countries GraphQL API sending a query for all countries with country names and the names of the countries' continents. It validates the response code and the name of the first country and its continent.

### zzz_test_failure

The zzz_test_failure test collection sends POST, GET and DELETE requests against the SwaggerPetstore API. The requests include tests which are designed to fail: The POST and the GET request tests are asking for an unexpected status code or petId, respectively. The DELETE request includes an incorrect API key provoking an Unauthorized application request error. The build pipeline will detect this and reject the API project with an error message.

# Azure DevOps pipelines

## Pipelines for API projects

The key to proper DevOps is continuous integration and continuous deployment. Organizations use standard tools such as Jenkins, GitLab and Azure DevOps to design their integration and assuring continuous delivery.

The API Gateway Staging solution includes two Azure DevOps build pipelines for deploying API projects from a Git repository to DESIGN, DEV, TEST and PROD environments and two pipelines for exporting API projects from DESIGN into the Git repository.

In each deployment pipeline, the API Gateway assets configured in the API project will be imported on a BUILD environment (after cleaning it from remnants of the last deployment). For a deployment to DEV, TEST and PROD, it will then execute the API tests configured in the API project's APITest.json Postman test collection. If one of the tests fail, the deployment will be aborted. (No tests will be executed for deployments to DESIGN.)

For a deployment to DEV, TEST and PROD, the pipeline will now validate and manipulate the assets on the BUILD environment (using API Gateway's own APIs) to prepare them for the target environment:
- All policy actions will be scanned for unwanted API-level Log Invocation policies
- All applications with names not ending with _DEV, _TEST or _PROD, respectively, will be removed
- The remaining applications will be unsuspended (if necessary) to make sure they can be used on the target environment
- Aliases will be overwritten with the values retrieved from the global aliases.json file or the local API project's aliases.json file (perhaps after value replacement via pipeline variables)
- It will be assured that all APIs are assigned to the Internal API group or the External API group, respectively
- Incorrect clientId and clientSecret values in OAuth2 strategies will be fixed as a workaround for a defect identified in API Gateway 10.7 Fix 5 and 6
- Three API tags will be added to every API indicating the pipeline ID, the build ID and the shortened commit SHA. These tags can later be used in the API Gateway UI on the target environments to understand when and how (and by whom) every API was promoted to the environment
- The API description will be augmented (at its start) with markdown links to the pipeline definition page, the build results page and the GitHub commit page for the change. Unfortunately, the API Gateway UI does not interpret the markdown, but when you publish the API to API Portal / Developer Portal, it will interpret the markdown and present the respective links to the portal users in their browser.
- For a deployment to TEST or PROD, API mocking will be disabled

For a deployment to DESIGN, the pipeline will execute only one step to prepare OAuth2 strategies for the target environment:
- Incorrect clientId and clientSecret values in OAuth2 strategies will be fixed as a workaround for a defect identified in API Gateway 10.7 Fix 5 and 6

More manipulations or tests (e.g., enforcement of API standards) can be added later.

After this, the (validated and manipulated) API Gateway assets will be exported from the BUILD environment and imported on the target stage (DESIGN, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT or PROD_EXT). If any target stage spans multiple environments, the assets will automatically be imported on each environment of the target stage.

The azure_demo_01 environment set includes two PROD_INT environments PROD_INT_01 and PROD_INT_02 and it includes two PROD_EXT environments PROD_EXT_01 and PROD_EXT_02. For every deployment on PROD_INT or PROD_EXT, the assets will be imported on PROD_INT_01 and PROD_INT_02, or PROD_EXT_01 and PROD_EXT_02, respectively.

> Note: If the imported assets already exist on the target environment (i.e., assets with same IDs), they will be overwritten for the following asset types: APIs, policies, policy actions, applications, scope mappings, aliases, users, groups and teams. Any assets of any other types, like configuration items, will not be overwritten.

Finally, if an API Portal / Developer Portal is configured on the target stage, the pipeline will iterate over all APIs included in the API project and republish every API to the API Portal / Developer Portal (if it is already published). It will republish the API with the same configuration (endpoints and communities) as it is currently published. API which are not (yes) published, will be skipped.

> Note: You cannot use this functionality for publishing new APIs. But once an API has been published by other means (e.g., manually) from the target environment to an API Portal / Developer Portal, its published version will automatically be kept in sync by this feature of the API Gateway Staging solution.

Every deployment pipeline will publish the following artifacts:
- {{target_stage}}_{{api_project}}_build_import: The API Gateway asset archive (ZIP file) containing the assets initially imported on the BUILD environment
- {{target_stage}}_{{api_project}}_build_result: The API Gateway asset archive (ZIP file) containing the assets exported from the BUILD environment (after manipulations) and imported on the target stage
- {{target_stage}}_{{api_project}}_test_results: The results of the Postman tests in junitReport.xml form

The export pipelines will publish the following artifact:
- DESIGN_{{api_project}}_export: The API Gateway asset archive (ZIP file) containing the assets exported from the DESIGN environment

These artifacts will be stored by Azure DevOps for some time. They will enable auditing and bug fixing of pipeline builds.

In addition to that, the test results are published into the Azure DevOps test results framework.

All pipelines must be triggered manually by clicking on `Run pipeline`. It is also possible to define triggers to start the pipelines automatically for specific events, e.g., Git commit, PR, successful completion of some other Azure DevOps pipeline (even in another Azure DevOps project in the same organization).

You might want to configure an API deployment pipeline (for DEV) to be triggered automatically by an API export. This will automatically test every new API (version) and keep the DEV environment in sync with the API configurations in the Git repository.

Parallel running build jobs using the same BUILD environment must be avoided because they might interfere with each other. By default, the API Gateway Staging solution will use Azure DevOps pipeline environments with exclusive locks in order to avoid running multiple build jobs on the same BUILD environment in parallel.

On the webm_io environment set with only one BUILD environment, this means that Azure DevOps will always only run one build job at a time.

The azure_demo_01 environment set includes seven BUILD environments BUILD_01, ..., BUILD_07 allowing for up to seven build jobs running in parallel. By default, the build jobs will be assigned to BUILD environments by target stages:

| Target stage | Assigned BUILD environment |
| ------ | ------ |
| DESIGN | BUILD_01 |
| DEV_INT | BUILD_02 |
| DEV_EXT | BUILD_03 |
| TEST_INT | BUILD_04 |
| TEST_EXT | BUILD_05 |
| PROD_INT | BUILD_06 |
| PROD_EXT | BUILD_07 |

Users can overwrite this behavior with the `Build on which BUILD environment?` parameter in the deployment pipelines. Instead of the default value (`Default Mapping`), they can directly select one of the seven BUILD environments. All build jobs in this pipeline will then use the selected build environment for building the API projects. Users can use this feature to speed up the deployment process by selecting a BUILD environment that is currently idle, bypassing the default mechansim of assigning build jobs to BUILD environments by target stage.

In addition to this mechanism (fixed build environments), the API Gateway Staging solution offers two alternative mechanisms for assigning build jobs to BUILD environments:
 - Dedicated build agents: This mechanism uses a separate Azure DevOps agent pool with seven build agents, each one assigned to one of the seven BUILD environments. Instead of assigning BUILD environments by target stage, this mechanism lets every build agent use its own, assigned BUILD environment when executing a build job. Azure DevOps will automatically assign the next build job to the next free build agent, leading to an optimal utilization of the seven BUILD environments.
 - Resource pooling (experimental): This mechanism tries to reach the same goal without using a separate agent pool for the build jobs. In this mechanism, each build job will try to pull a free BUILD environment from a pool of seven environments managed by an Azure DevOps variable group (API_Gateway_build_environments_availability). If there is currently no free environment available, the job will wait until a new environment becomes available.

You can switch between the three mechanisms by setting the default value for the build_job_assignment_mechanism parameter in inject-parameters-for-azure_demo_01.yml to fixed_build_environments, dedicated_build_agents or resource_pooling.

> Note: Please note that the three assignment mechanisms do not know about each other. Therefore, please wait and make sure that no build job is running and no build job is scheduled before switching the assignment mechanism. Otherwise, you might have multiple build jobs trying to use the same BUILD environment at the same point in time.

Each deployment pipeline consists of two jobs for build and deployment which can be executed on different agents, possibly from different agent pools. Each job only contains steps connecting the agent with one API Gateway environment (either BUILD/BUILD_01/.../BUILD_07 or DESIGN/DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_INT_01/PROD_INT_02/PROD_EXT/PROD_EXT_01/PROD_EXT_02). This way, the pipeline can be executed in distributed deployments in which different agents must be used for accessing the different API Gateway environments.

Please check the implementation notes section below on how to configure which agent pool is used for each API Gateway environment.

### `Deploy selected API project(s)`

This pipeline will propagate the APIs and other API Gateway assets in the selected API project(s) to the selected target stage(s).

The following parameters can/must be provided for this pipeline:

| Parameter | README |
| ------ | ------ |
| Branch/tag | Select the Git branch or tag from which the assets should be imported |
| Commit | Optional: Select the commit from which the assets should be imported. You must provide the commit's full SHA, see below. By default, the pipeline will import the HEAD of the selected branch |
| Deploy which API project(s)? | By default ("All"), this parameter selects all 13 demo APIs for deployment. Alternatively, the user can select one single API project for deployment |
| Deploy API(s) on API Gateway(s) in which environment set? | webm_io (default) or azure_demo_01 |
| Deploy on which target(s)? | By default ("All (except DESIGN)"), this parameter selects all six target stages for deployment. Alternatively, the user can select one single target stage or "All (including DESIGN)" for deployment. The default is set to "All (except DESIGN)" because you would normally not want to overwrite your APIs on the DESIGN environment |
| Build on which BUILD environment? | Only relevant for the webm_io environment set: By default ("Default Mapping"), the build jobs will be assigned to BUILD environments by target stage, see above. Alternatively, the user can select a specific BUILD environment for all build jobs in this pipeline execution. For the webm_io environment set, this parameter will be ignored |

Based on the selected parameter values, Azure DevOps (ADO) will create a list of ADO stages for the pipeline execution. Each ADO stage will represent a combination of an API project to be deployed on a target stage, e.g. `Build_petstore_and_deploy_it_on_DEV_INT`. This list will include all valid combinations of the selected API project(s) with the selected target stage(s), excluding invalid combinations, i.e., excluding
 - API projects with internal-only APIs on DEV_EXT, TEST_EXT or PROD_EXT
 - API projects with external-only APIs on DEV_INT, TEST_INT or PROD_INT
 - API project petstore_basicauth on any target environment in the webm_io environment set
 - API project countries on any target environment in the webm_io environment set

As an advanced feature, the user can click on `Stages to run` and select/deselect the ADO stages that should actually be executed in the pipeline run. For example, the user could select "All" api projects and "All (including DESIGN)" target stages and then freely decide under `Stages to run` which API project(s) should actually be deployed on which target stage(s) in this pipeline run.

### `Deploy arbitrary API project`

This pipeline will propagate the APIs and other API Gateway assets in the specified API project to the selected target stage(s).

The following parameters can/must be provided for this pipeline:

| Parameter | README |
| ------ | ------ |
| Branch/tag | Select the Git branch or tag from which the assets should be imported |
| Commit | Optional: Select the commit from which the assets should be imported. You must provide the commit's full SHA, see below. By default, the pipeline will import the HEAD of the selected branch |
| Deploy which API project? | Case-sensitive name of the API project to be deployed |
| Deploy API(s) on API Gateway(s) in which environment set? | webm_io (default) or azure_demo_01 |
| Deploy on which target(s)? | By default ("All (except DESIGN)"), this parameter selects all six target stages for deployment. Alternatively, the user can select one single target stage or "All (including DESIGN)" for deployment. The default is set to "All (except DESIGN)" because you would normally not want to overwrite your APIs on the DESIGN environment |
| Build on which BUILD environment? | Only relevant for the webm_io environment set: By default ("Default Mapping"), the build jobs will be assigned to BUILD environments by target stage, see above. Alternatively, the user can select a specific BUILD environment for all build jobs in this pipeline execution. For the webm_io environment set, this parameter will be ignored |

Based on the selected and specified parameter values, Azure DevOps (ADO) will create a list of ADO stages for the pipeline execution. Each ADO stage will represent a combination of an API project to be deployed on a target stage, e.g. `Build_petstore_and_deploy_it_on_DEV_INT`. This list will include all combinations of the specified API project with the selected target stage(s), without filtering for valid/invalid combinations. This pipeline can be used for executing the zzz_ negative test cases. It can also be used for new API projects which have not yet been accounted for in the definition of the `Deploy selected API project(s)` pipeline.

As an advanced feature, the user can click on `Stages to run` and select/deselect the ADO stages that should actually be executed in the pipeline run. For example, the user could select "All (including DESIGN)" target stages and then freely decide under `Stages to run` on which target stage(s) the specified API project should be deployed in this pipeline run.

### Selecting a specific commit to be deployed

When queuing a deployment pipeline, you can select the specific commit that should be checked out on the build agent, i.e., the configuration of the API Gateway assets to be imported to the BUILD environment. You have to provide the commit's full SHA. This way, you can always easily roll-back to any earlier state of the selected/specified API project.

> Note: It will not work with the shortened commit ID displayed in the GitHub or Azure DevOps UI. You have to use the full SHA.

### `Export seletced API project from DESIGN`

This pipeline will export the APIs and other API Gateway assets in the selected API project from DESIGN, and it will automatically commit the changes to the HEAD of the selected branch of the Git repository.

The following parameters can/must be provided for this pipeline:

| Parameter | README |
| ------ | ------ |
| Branch/tag | Select the Git branch into which the assets should be committed |
| Commit | Leave this blank |
| Export which API project? | Select the API project to be exported |
| Export API(s) from DESIGN API Gateway in which environment set? | webm_io (default) or azure_demo_01 |
| Message for the commit in Git? | The change will be committed with this commit message |

> Note: API Gateway export archives can only be imported on API Gateway environment on the same or higher fixlevel. As of 23.05.24, the environments on webm_io are on fixlevel 11.0 while the environment on azure_demo_01 are on fixlevel 10.15 fix 15. This means: When you export an API project from webm_io DESIGN environment, you will not be able to deploy this API project on any azure_demo_01 target environment.

### `Export arbitrary API project from DESIGN`

This pipeline will export the APIs and other API Gateway assets in the specified API project from DESIGN, and it will automatically commit the changes to the HEAD of the selected branch of the Git repository.

The following parameters can/must be provided for this pipeline:

| Parameter | README |
| ------ | ------ |
| Branch/tag | Select the Git branch into which the assets should be committed |
| Commit | Leave this blank |
| Export which API project? | Case-sensitive name of the API project to be exported |
| Export API(s) from DESIGN API Gateway in which environment set? | webm_io (default) or azure_demo_01 |
| Message for the commit in Git? | The change will be committed with this commit message |

This pipeline can be used for exporting new versions of the zzz_ negative test cases. It can also be used for new API projects which have not yet been accounted for in the definition of the `Export seletced API project from DESIGN` pipeline.

> Note: API Gateway export archives can only be imported on API Gateway environment on the same or higher fixlevel. As of 23.05.24, the environments on webm_io are on fixlevel 11.0 while the environment on azure_demo_01 are on fixlevel 10.15 fix 15. This means: When you export an API project from webm_io DESIGN environment, you will not be able to deploy this API project on any azure_demo_01 target environment.

## Pipelines for API Gateway configurations

The API Gateway Staging solution includes one Azure DevOps build pipeline for deploying API Gateway configurations from the Git repository to DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and/or PROD_EXT environments and one pipeline for exporting the API Gateway configurations from DESIGN, BUILD (BUILD_01, ..., BUILD_07), DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT (PROD_INT_01, PROD_INT_02) or PROD_EXT (PROD_EXT_01, PROD_EXT_02) into the Git repository.

In each pipeline, the API Gateway assets configured in the environment configuration folder(s) will be imported on the target stage(s) or exported from the source environment.

The configuration pipeline will publish the following artifact:
- DESIGN_import, BUILD_import etc.: The API Gateway asset archive (ZIP file) containing the assets imported on DESIGN, BUILD etc.

The configuration export pipeline will publish the following artifact:
- DESIGN_export, BUILD_export etc.: The API Gateway asset archive (ZIP file) containing the assets exported from DESIGN, BUILD etc.

These artifacts will be stored by Azure DevOps for some time. They will enable auditing and bug fixing of pipeline builds.

After importing the API Gateway assets, the configuration deployment pipelines will execute some steps for initializing the API Gateway:
- Configuration of environment-specific loadbalancer URLs
- Configuration of the (external) Elasticsearch destination
- Configuration of an environment-specific proxy server
- Configuration of environment-specific OAuth2 and JWT configuration parameters in the local Authorization Server and JWT Provider alias
  - OAuth2 authorization code and access token expiration interval
  - JWT issuer, signing algorithm, token expiration interval, keystore alias and key alias

Further configuration steps can be added later.

When configuring PROD_INT or PROD_EXT on the azure_demo_01 environment set, the pipeline will finally configure a HAFT ring between PROD_INT_01 and PROD_INT_02, or between PROD_EXT_01 and PROD_EXT_02, respectively.

All pipelines must be triggered manually by clicking on `Run pipeline`. It is also possible to define triggers to start the pipelines automatically for specific events, e.g., Git commit, PR, successful completion of some other Azure DevOps pipeline (even in another Azure DevOps project in the same organization).

### `Configure API Gateway(s)`

This pipeline will import the API Gateway configuration assets on the DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and/or PROD_EXT stages.

If any stage spans multiple environments, the assets will automatically be imported on each environment of the stage.

The azure_demo_01 environment set includes seven BUILD environments BUILD_01, ..., BUILD_07 and it includes two PROD_INT environments PROD_INT_01 and PROD_INT_02 and it includes two PROD_EXT environments PROD_EXT_01 and PROD_EXT_02. For every configuration of BUILD or PROD_INT or PROD_EXT, the assets will be imported on BUILD_01, ..., BUILD_07, or PROD_INT_01 and PROD_INT_02, or PROD_EXT_01 and PROD_EXT_02, respectively.

The following parameters can/must be provided for this pipeline:

| Parameter | README |
| ------ | ------ |
| Branch/tag | Select the Git branch or tag from which the assets should be imported |
| Commit | Optional: Select the commit from which the assets should be imported. You must provide the commit's full SHA, see above. By default, the pipeline will import the HEAD of the selected branch |
| Configure API Gateway(s) in which environment set? | webm_io (default) or azure_demo_01 |
| Configure which API Gateway stage(s)? | By default ("All"), this parameter selects all eight stages for configuration. Alternatively, the user can select one single stage |

Based on the selected parameter values, Azure DevOps (ADO) will create a list of ADO stages for the pipeline execution.

As an advanced feature, the user can click on `Stages to run` and select/deselect the ADO stages that should actually be executed in the pipeline run. For example, the user could select "All" stages and then freely decide under `Stages to run` which stage(s) should be configured in this pipeline run.

### `Export API Gateway Configuration`

This pipeline will export the API Gateway configuration assets from DESIGN, BUILD (BUILD_01, ..., BUILD_07), DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT (PROD_INT_01, PROD_INT_02) or PROD_EXT (PROD_EXT_01, PROD_EXT_02), and it will automatically commit the changes to the HEAD of the selected branch of the Git repository.

The following parameters can/must be provided for this pipeline:

| Parameter | README |
| ------ | ------ |
| Branch/tag | Select the Git branch into which the assets should be committed |
| Commit | Leave this blank |
| Export API Gateway configuration from which API Gateway? | All webm_io and azure_demo_01 environments |
| Message for the commit in Git? | The change will be committed with this commit message |

> Note: API Gateway export archives can only be imported on API Gateway environment on the same or higher fixlevel. As of 23.05.24, the environments on webm_io are on fixlevel 11.0 while the environment on azure_demo_01 are on fixlevel 10.15 fix 15. This means: When you export an API Gateway configuration from a webm_io environment, you will not be able to deploy this configuration on any azure_demo_01 environment.

## Pipeline for log purging

The API Gateway Staging solution includes one Azure DevOps build pipeline for automatically purging the API Gateway logs stored in the internal Elasticsearch database on DESIGN, BUILD (BUILD_01, ..., BUILD_07), DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT (PROD_INT_01, PROD_INT_02) and/or PROD_EXT (PROD_EXT_01, PROD_EXT_02). It will purge
 - all logs (except for audit logs) older than 28 days: transactionalEvents, monitorEvents, errorEvents, performanceMetrics, threatProtectionEvents, lifecycleEvents, policyViolationEvents, applicationlogs, mediatorTraceSpan
 - all audit logs older than Jan. 1st of the preceding calendar year: auditlogs. (This is implementing the requirement to purge all audit data on the end of the following calendar year.)

The pipeline can be triggered manually by clicking on `Run pipeline`. It is also configured to run automatically every day at 12:00am UTC (for webm_io on all stages).

### `Purge API Gateway Analytics Data`

If any stage spans multiple environments, the logs will automatically be purged on each environment of the stage.

The azure_demo_01 environment set includes seven BUILD environments BUILD_01, ..., BUILD_07 and it includes two PROD_INT environments PROD_INT_01 and PROD_INT_02 and it includes two PROD_EXT environments PROD_EXT_01 and PROD_EXT_02. For every log purging of BUILD or PROD_INT or PROD_EXT, the logs will be purged on BUILD_01, ..., BUILD_07, or PROD_INT_01 and PROD_INT_02, or PROD_EXT_01 and PROD_EXT_02, respectively.

The following parameters can/must be provided for this pipeline:

| Parameter | README |
| ------ | ------ |
| Branch/tag | Select any branch or tag |
| Commit | Leave this blank |
| Purge data from API Gateway(s) in which environment set? | webm_io (default) or azure_demo_01 |
| Purge data from which API Gateway stage(s)? | By default ("All"), this parameter selects all eight stages for configuration. Alternatively, the user can select one single stage |

## Pipelines for API updates

The API Gateway Staging solution includes two pipelines for demonstrating how API updating can be automated. They are hard-coded to update the SwaggerPetstore API on DESIGN based on an OpenAPI specification file stored in this repository in the /schemas folder or downloaded from https://petstore.swagger.io/v2/swagger.json. In order to demonstrate the effect of updating the API, the OpenAPI specification file in the /schemas folder (petstore_swagger_updated.json) only includes the endpoints starting with /pet, leaving out the endpoints starting with /store and /user. When you update the API with the local file and then with the URL, you can see on the DESIGN stage that the /store and /user endpoints are removed and then added again.

The pipelines must be triggered manually by clicking on `Run pipeline`. It is also possible to define triggers to start the pipelines automatically for specific events, e.g., Git commit, PR, successful completion of some other Azure DevOps pipeline (even in another Azure DevOps project in the same organization). For example, it could be triggered automatically for every new build of the underlying native API.

You might want to configure an API export pipeline to be triggered automatically by the API update.

### `Update Petstore API by File`

The following parameters can/must be provided for this pipeline:

| Parameter | README |
| ------ | ------ |
| Branch/tag | Select any branch or tag |
| Commit | Leave this blank |
| Update API in which environment set? | webm_io (default) or azure_demo_01 |
| Update which API? | By default ("f3d2a3c1-0f83-43ab-a6ec-215b93e2ecf5"), the pipeline will update the SwaggerPetstore API with this ID. Alternatively, the user can provide another API ID |
| Update using which file? | By default ("petstore_swagger_updated.json"), the pipeline will update the SwaggerPetstore API with this OpenAPI (Swagger 2.0) specification file. Alternatively, the user can provide another filename |

### `Update Petstore API by URL`

The following parameters can/must be provided for this pipeline:

| Parameter | README |
| ------ | ------ |
| Branch/tag | Select any branch or tag |
| Commit | Leave this blank |
| Update API in which environment set? | webm_io (default) or azure_demo_01 |
| Update which API? | By default ("f3d2a3c1-0f83-43ab-a6ec-215b93e2ecf5"), the pipeline will update the SwaggerPetstore API with this ID. Alternatively, the user can provide another API ID |
| Update using which URL? | By default ("https://petstore.swagger.io/v2/swagger.json"), the pipeline will update the SwaggerPetstore API with the OpenAPI (Swagger 2.0) specification under this URL. Alternatively, the user can provide another URL |

# Usage examples

When using the API Gateway Staging solution, there are two options for exporting/importing from/to the API Gateway DESIGN stage (or a local development environment): Developers can either use a local repository (clone), export/import the API projects using the gateway_import_export_utils.bat script and synchronize their local repository (pull/push) with the central repository used by the Azure DevOps pipelines, or they can directly export/import API projects from/to the API Gateway DESIGN stage using the `Export selected/arbitrary API project from DESIGN` / `Deploy selected/arbitrary API project(s)` pipelines.

## Example 1: Change an existing API

Let's consider this example: An API developer wants to make a change to the Petstore API.

### Option A: Using a local Git repository

  - The API developer should first pull the latest changes from the central Git repository into his/her local repository.

  - All of the APIs of the organization are available in Git in the /apis folder. This flat file representation of the APIs should be converted and imported into the developer's local development API Gateway environment or the central DESIGN environment for changes to be made. The developer uses the /bin/gateway_import_export_utils.bat Windows batch script to do this and import this API (and related assets like applications) to the local development environment or the central DESIGN environment.

```sh 
bin>gateway_import_export_utils.bat --importapi --api_name petstore --apigateway_url https://apigw-config.acme.com --apigateway_username hesseth --apigateway_password ***
```

  - The API Developer makes the necessary changes to the Petstore API on the local development environment or the central DESIGN environment. 

  - The API developer needs to ensure that the change that was made does not cause regressions. For this, the user needs to run the set of function/regression tests over his change in Postman REST client before the change gets propagated to the next stage.

  - Optional, but highly recommended: The developer creates a new feature branch for the change in Git.

  - Now this change made by the API developer has to be pushed back to Git such that it propagates to the next stage. The developer uses the /bin/gateway_import_export_utils.bat Windows batch script to prepare this, export the configured API Gateway artifacts for the API project from the local development environment or the central DESIGN environment and store the asset definitions to the local repository /apis folder. This can be done by executing the following command.

```sh 
bin>gateway_import_export_utils.bat --exportapi --api_name petstore --apigateway_url https://apigw-config.acme.com --apigateway_username hesseth --apigateway_password ***
```

  - If the developer made any changes to the Postman test collection in the Postman REST client, he/she would now have to export the collection and store it under APITest.json in the API tests folder under /postman/collections/apitests.
  
  - After this is done, the changes from the developer's local repository are pushed to the central Git repository.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to DEV_INT or DEV_EXT using the `Deploy selected/arbitrary API project(s)` pipeline.

  - The changed API can now be tested on DEV_INT or DEV_EXT environment.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to TEST_INT or TEST_EXT using the `Deploy selected/arbitrary API project(s)` pipeline.

  - The changed API can now be tested on TEST_INT or TEST_EXT environment.

  - After successful testing, someone can now merge the feature branch into the master branch and propagate the changes by publishing the API project from the master branch to PROD_INT or PROD_EXT using the `Deploy selected/arbitrary API project(s)` pipeline.

### Option B: Using the export/import pipelines

  - All of the APIs of the organization are available in Git in the /apis folder. This flat file representation of the APIs should be converted and imported into the central DESIGN environment for changes to be made. The developer executes the `Deploy selected/arbitrary API project(s)` pipeline to deploy the petstore API project on DESIGN.

  - The API Developer makes the necessary changes to the Petstore API on the central DESIGN environment. 

  - The API developer needs to ensure that the change that was made does not cause regressions. For this, the user needs to run the set of function/regression tests over his change in Postman REST client before the change gets propagated to the next stage.

  - Optional, but highly recommended: The developer creates a new feature branch for the change in Git.

  - Now this change made by the API developer has to be pushed back to Git such that it propagates to the next stage. The developer executes the `Export selected/arbitrary API project from DESIGN` pipeline for the petstore API project.

  - If the developer made any changes to the Postman test collection in the Postman REST client, he/she would now have to export the collection and store it under APITest.json in the API project root folder and commit the change.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to DEV_INT or DEV_EXT using the `Deploy selected/arbitrary API project(s)` pipeline.

  - The changed API can now be tested on DEV_INT or DEV_EXT environment.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to TEST_INT or TEST_EXT using the `Deploy selected/arbitrary API project(s)` pipeline.

  - The changed API can now be tested on TEST_INT or TEST_EXT environment.

  - After successful testing, someone can now merge the feature branch into the master branch and propagate the changes by publishing the API project from the master branch to PROD_INT or PROD_EXT using the `Deploy selected/arbitrary API project(s)` pipeline.

## Example 2: Create a new API in an existing API project

Let's consider this example: An API developer wants to create a new API and add it to an existing API project.

### Option A: Using a local Git repository

  - The API developer should first pull the latest changes from the central Git repository into his/her local repository.

  - The developer would then have to update the API Gateway artifacts of the existing API project on the local development environment or the central DESIGN environment. The developer uses the /bin/gateway_import_export_utils.bat Windows batch script to do this and import the existing API project (and related assets like applications) to the local development environment or the central DESIGN environment.

```sh 
bin>gateway_import_export_utils.bat --importapi --api_name petstore --apigateway_url https://apigw-config.acme.com --apigateway_username hesseth --apigateway_password ***
```

  - The developer would then create the new API on the local development environment or the central DESIGN environment making sure it is correctly assigned to the Internal API group and/or to the External API group and does not include any API-level Log Invocation policy.

  - The developer would then import the API project's collection of function/regression tests from the APITest.json file into his/her local Postman REST client and add requests and tests for the new API.

  - Optional, but highly recommended: The developer creates a new feature branch for the change in the VCS.

  - The developer will now have to add the ID of the new API to the export_payload.json file in the root folder of the existing API project. The API ID can be extracted from the URL of the API details page in the API Gateway UI.

  - Now this change made by the API developer has to be pushed back to Git such that it propagates to the next stage. The developer uses the /bin/gateway_import_export_utils.bat Windows batch script to prepare this, export the configured API Gateway artifacts for the API project from the local development environment or the central DESIGN environment and store the asset definitions to the local repository /apis folder. This can be done by executing the following command.

```sh 
bin>gateway_import_export_utils.bat --exportapi --api_name petstore --apigateway_url https://apigw-config.acme.com --apigateway_username hesseth --apigateway_password ***
```

  - The developer would now export the Postman test collection in the Postman REST client and store it under APITest.json in the API tests folder under /postman/collections/apitests.

  - After this is done, the changes from the developer's local repository are pushed to the central Git repository.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to DEV_INT or DEV_EXT using the `Deploy selected/arbitrary API project(s)` pipeline.

  - The new API can now be tested on DEV_INT or DEV_EXT environment.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to TEST_INT or TEST_EXT using the `Deploy selected/arbitrary API project(s)` pipeline.

  - The new API can now be tested on TEST_INT or TEST_EXT environment.

  - After successful testing, someone can now merge the feature branch into the master branch and propagate the changes by publishing the API project from the master branch to PROD_INT or PROD_EXT using the `Deploy selected/arbitrary API project(s)` pipeline.

### Option B: Using the export/import pipelines

  - The developer would first have to update the API Gateway artifacts of the existing API project on the central DESIGN environment. The developer executes the `Deploy selected/arbitrary API project(s)` pipeline to deploy the petstore API project on DESIGN.

  - The developer would then create the new API on the central DESIGN environment making sure it is correctly assigned to the Internal API group and/or to the External API group and does not include any API-level Log Invocation policy.

  - The developer would then import the API project's collection of function/regression tests from the APITest.json file into his/her local Postman REST client and add requests and tests for the new API.

  - Optional, but highly recommended: The developer creates a new feature branch for the change in Git.

  - The developer will now have to add the ID of the new API to the export_payload.json file in the root folder of the existing API project and commit the change. The API ID can be extracted from the URL of the API details page in the API Gateway UI.

  - Now this change made by the API developer has to be pushed back to Git such that it propagates to the next stage. The developer executes the `Export selected/arbitrary API project from DESIGN` pipeline for the petstore API project.

  - The developer would now export the Postman test collection in the Postman REST client and store it under APITest.json in the API tests folder under /postman/collections/apitests and commit the change.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to DEV_INT or DEV_EXT using the `Deploy selected/arbitrary API project(s)` pipeline.

  - The new API can now be tested on DEV_INT or DEV_EXT environment.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to TEST_INT or TEST_EXT using the `Deploy selected/arbitrary API project(s)` pipeline.

  - The new API can now be tested on TEST_INT or TEST_EXT environment.

  - After successful testing, someone can now merge the feature branch into the master branch and propagate the changes by publishing the API project from the master branch to PROD_INT or PROD_EXT using the `Deploy selected/arbitrary API project(s)` pipeline.

## Example 3: Create a new API in a new API project

Let's consider this example: An API developer wants to create a new API and add it to a new API project.

### Option A: Using a local Git repository

  - The API developer should first pull the latest changes from the central Git repository into his/her local repository.

  - The developer would create the new API on the local development environment or the central DESIGN environment.

  - The developer would then create a new collection of function/regression tests for the API project in the local Postman REST client with requests and tests for the new API.

  - Optional, but highly recommended: The developer creates a new feature branch for the change in Git.

  - The developer will now have to create a new API project folder under /apis with a new export_payload.json file including the ID of the new API. The API ID can be extracted from the URL of the API details page in the API Gateway UI. The developer will also have to create an empty assets folder in the API project root folder which will later hold the asset definitions exported from the local development environment or the central DESIGN environment.

  - Now the new API has to be committed to Git such that it propagates to the next stage. The developer uses the /bin/gateway_import_export_utils.bat Windows batch script to prepare this, export the configured API Gateway artifacts for the API project from the local development environment or the central DESIGN environment and store the asset definitions to the local repository /apis folder. This can be done by executing the following command.

```sh 
bin>gateway_import_export_utils.bat --exportapi --api_name new_api --apigateway_url https://apigw-config.acme.com --apigateway_username hesseth --apigateway_password ***
```

  - The developer would now export the Postman test collection in the Postman REST client and store it under APITest.json in the API tests folder under /postman/collections/apitests.
  
  - After this is done, the changes from the developer's local repository are pushed to the central Git repository.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to DEV_INT or DEV_EXT using the `Deploy arbitrary API project` pipeline.

  - The new API can now be tested on DEV_INT or DEV_EXT environment.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to TEST_INT or TEST_EXT using the `Deploy arbitrary API project` pipeline.

  - The new API can now be tested on TEST_INT or TEST_EXT environment.

  - After successful testing, someone can now merge the feature branch into the master branch and propagate the changes by publishing the API project from the master branch to PROD_INT or PROD_EXT using the `Deploy arbitrary API project` pipeline.

> Note: You cannot directly use the `Export selected API project from DESIGN` or the `Deploy selected API project(s)` pipelines for a new API project, because the new API project is not yet reflected properly in the pipeline definitions for these pipelines, but you can directly use the `Export arbitrary API project from DESIGN` and the `Deploy arbitrary API project` pipelines. Please check the section below on how to include the new API project in the pipeline definitions.

### Option B: Using the export/import pipelines

  - The developer would create the new API on the central DESIGN environment.

  - The developer would then create a new collection of function/regression tests for the API project in the local Postman REST client with requests and tests for the new API.

  - Optional, but highly recommended: The developer creates a new feature branch for the change in Git.

  - The developer will now have to create a new API project folder under /apis with a new export_payload.json file including the ID of the new API and commit the change. The API ID can be extracted from the URL of the API details page in the API Gateway UI. The developer will also have to create an assets folder with a dummy file in the API project root folder and commit the change. The folder will later hold the asset definitions exported from the central DESIGN environment.

> Note: The dummy file is necessary because Git will not include an empty folder in the commit. It will be overwritten automatically be the first export of the API project.

  - Now the new API has to be committed to Git such that it propagates to the next stage. The developer executes the `Export arbitrary API project from DESIGN` pipeline for the petstore API project.

  - The developer would now export the Postman test collection in the Postman REST client and store it under APITest.json in the API tests folder under /postman/collections/apitests and commit the change.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to DEV_INT or DEV_EXT using the `Deploy arbitrary API project` pipeline.

  - The new API can now be tested on DEV_INT or DEV_EXT environment.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to TEST_INT or TEST_EXT using the `Deploy arbitrary API project` pipeline.

  - The new API can now be tested on TEST_INT or TEST_EXT environment.

  - After successful testing, someone can now merge the feature branch into the master branch and propagate the changes by publishing the API project from the master branch to PROD_INT or PROD_EXT using the `Deploy arbitrary API project` pipeline.

> Note: You cannot directly use the `Export selected API project from DESIGN` or the `Deploy selected API project(s)` pipelines for a new API project, because the new API project is not yet reflected properly in the pipeline definitions for these pipelines, but you can directly use the `Export arbitrary API project from DESIGN` and the `Deploy arbitrary API project` pipelines. Please check the section below on how to include the new API project in the pipeline definitions.

### Add new API project to deployment and export pipelines

In order to add the new project to the `Export selected API project from DESIGN` and the `Deploy selected API project(s)` pipelines, you have to add the new project's name to the following pipeline definitions and pipeline templates:
 - /pipelines/export-selected-api-from-DESIGN.yml as a new possible value for the selected_api_project parameter
 - /pipelines/build-and-deploy-selected-apis.yml as a new possible value for the selected_api_project parameter
 - /pipelines/stage-templates/inject-parameters-for-azure_demo_01.yml and /pipelines/stage-templates/inject-parameters-for-webm_io.yml in the default values for the eligible_targets parameter:
   - If the new API is internal and external, add it to the api_projects list attribute marked with the comment "API projects with APIs that are both internal and external"
   - If the new API is internal only, add it to the api_projects list attribute marked with the comment "API projects with APIs that are internal only"
   - If the new API is external only, add it to the api_projects list attribute marked with the comment "API projects with APIs that are external only"
   - In any case, add it to the api_projects list attribute marked with the comment "API projects with APIs that are external only"

# Implementation notes

All pipeline definitions (YAML files) are making use of stage-level, job-level and step-level pipeline templates for implementing the pipeline functionality in small, re-usable components. Some of these templates are re-used in all pipeline definitions:

## Shared pipeline templates

### Stage templates

The following stage-level templates are used in all pipeline definitions for setting parameter values based on the selected environment set. They can be found in the /pipelines/stage-templates folder:

| Template | README |
| ------ | ------ |
| inject-parameters-for-webm_io.yml | Façade template injecting parameters for the webm_io environment set |
| inject-parameters-for-azure_demo_01.yml | Façade template injecting parameters for the azure_demo_01 environment set |

These templates take the following input parameters:

| Parameter | README |
| ------ | ------ |
| template | Name of the template to be invoked through the façade |
| parameters | Additional parameters to be forwarded to the template behind the façade |
| selected_api_project | Name of the selected API project or "All" (default) |
| selected_environment_set | webm_io or azure_demo_01 |
| selected_target | Name of the selected target stage or "All (execpt DESIGN)" (default) or "All (including DESIGN)" |
| selected_stage | Name of the selected stage or "All" (default) |
| selected_build_environment | Name of the selected BUILD environment (BUILD_01, ..., BUILD_07) or "Default Mapping" (default) |
| ignore_eligible_targets | Whether or not to restrict the deployment sets to valid combinations of API projects and target stages |

These templates are setting the following parameter values for all stage templates invoked through them:

| Parameter | README |
| ------ | ------ |
| design_stage | Parameter object representing the DESIGN stage |
| build_stage | Parameter object representing the BUILD stage |
| target_stages | List of objects representing the target stages (DESIGN, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT, PROD_EXT) |
| all_stages | List of objects representing all stages (DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT, PROD_EXT) if selected_stage = "All", otherwise list of one object representing the selected stage |
| build_environments_mapping | Parameter object representing the BUILD environments to be used for each target stage |
| build_job_assignment_mechanism | fixed_build_environments, dedicated_build_agents or resource_pooling |
| environment_set | webm_io or azure_demo_01 |
| deployment_sets | List of objects defining which API projects should be deployed on which target stages, based on selected_api_project, selected_target and ignore_eligible_targets |

Every parameter object representing an API Gateway stage contains the stage name and a list of sub-objects representing the API Gateway environments in this stage. Each of these environment objects contains the environment name and the pool_name and pool_image parameters defining the agent pool used for communicating with the API Gateway environment.

Additional parameter values:
 - The DESIGN stage and the BUILD stage objects contain boolean marker parameters is_design_stage and is_build_stage, respectively
 - The BUILD stage object contains build_pool_name and build_pool_image parameters for the agent pool running build jobs (for fixed_build_environments and resource_pooling). All BUILD environments of an environment set must be reachable from the same agent pool for the build job
 - In inject-parameters-for-azure_demo_01.yml, the BUILD stage object also contains dedicated_pool_name and dedicated_pool_image parameters for the pool of dedicated build agents used in the dedicated_build_agents assignment mechanism for BUILD environments
 - The PROD_INT and the PROD_EXT stage objects for the azure_demo_01 environment set contain boolean parameters configure_haft for indicating whether of not HAFT should be configured in this stage

Each object representing a deployment set contains two values:
 - api_projects: List of names of API projects
 - targets: List of names of target stages

## Pipeline definitions and pipeline templates for API projects

### Pipeline definitions

The pipeline definition files (YAML) for the four Azure DevOps pipelines for API projects can be found in the /pipelines folder.

| Pipeline | Pipeline definition |
| ------ | ------ |
| `Deploy selected API project(s)` | build-and-deploy-selected-apis.yml |
| `Deploy arbitrary API project` | build-and-deploy-arbitrary-api.yml |
| `Export selected API project from DESIGN` | export-selected-api-from-DESIGN.yml |
| `Export arbitrary API project from DESIGN` | export-arbitrary-api-from-DESIGN.yml |

### Stage templates

The stage-level pipeline templates used in these pipelines can be found in the /pipelines/stage-templates folder:

| Template | README |
| ------ | ------ |
| build-and-deploy-api.yml | Stage template implementing the stages for building and deploying (and publishing) the selected/specified API project(s) on the selected target stage(s) |
| export-api.yml | Stage template implementing the stage for exporting the selected/specified API project from DESIGN stage and committing its content to Git |

In addition to the parameters injected by the façade templates, the export-api.yml template has the following input parameters:

| Parameter | README |
| ------ | ------ |
| selected_api_project | Case-sensitive name of the API project to be exported |
| commit_message | The change will be committed with this commit message |

The build-and-deploy-api.yml template does not have any additional parameters.

### Job templates

The job-level pipeline templates used in these pipelines can be found in the /pipelines/job-templates folder:

| Template | README |
| ------ | ------ |
| build-api-using-fixed_build_environments.yml | Default job template for API project build job. For the azure_demo_01 environment set, build jobs will be assigned to BUILD environments based on the default mapping (see above) or to the BUILD environment specifically selected by the user. For the webm_io environment set, build jobs will always be assigned to the single BUILD environment. The build job (technically, it is a deployment) will use the API_Gateway_{{environment_set}}_{{build_environment}} ADO environment. All of these ADO environments are configured with an "exclusive lock" making sure that only one build job is using the environment at one point in time. |
| build-api-using-dedicated_build_agents.yml | Alternative job template for API project build job, only applicable for the azure_demo_01 environment set. Build jobs are executed on a separate ADO agent pool. This agent pool must have seven build agents named BUILD_01, ..., BUILD_07. Build jobs will be assigned to BUILD environments based on the name of the ADO build agent on which it is running, making sure that only one build agent is using a BUILD environment at one point in time. |
| build-api-using-resource_pooling.yml | Experimental: Alternative job template for API project build job, only applicable for the azure_demo_01 environment set. Build jobs are assigned to BUILD environments based on key-value pairs in the `API_Gateway_build_environments_availability` ADO variable group. The group must have seven variables BUILD_01, ..., BUILD_07, initially all with the value "Available". Before executing the actual build steps, the job will try to reserve an available BUILD environment by finding a variable with value "Available" and then setting its value to a string indicating the pipeline build and its target stage and API project. After the build, the job will set the value back to "Available", making the environment available for the next build job. |

### Step templates

The step-level pipeline templates used in these pipelines can be found in the /pipelines/step-templates folder:

| Template | README |
| ------ | ------ |
| build-api.yml | Includes all steps for preparing the deployable on the BUILD environment (including import, test execution, asset manipulation and export) |
| store-build.yml | Stores the deployable in Azure DevOps |
| retrieve-build.yml | Retrieves the deployable from Azure DevOps |
| deploy-api.yml | Includes all steps for importing the deployable on one target environment and for re-publishing the included APIs from there to API Portal / Developer Portal |
| export-api.yml | Exports the API project from the DESIGN environment |
| commit.yml | Commits the results to the repository |

Each ADO stage in the build-and-deploy-api.yml stage template invokes build-api.yml and store-build.yml in one job on one agent, and then retrieve-build.yml and deploy-api.yml for each target environment in separate jobs on (potentially) different agents.

The storing of build artifacts in JFrog Artifactory is commented out. It can be activated when a service connection to a JFrog Artifactory repository is configured in Azure DevOps.

The export-api.yml stage template invokes export-api.yml and commit.yml sequentially in one stage in one job on one agent.

The pipeline templates execute the following major steps:

#### build-api.yml

| Step | README |
| ------ | ------ |
| Create the API Deployable from the flat representation for API project xxx | Using ArchiveFiles@2 Azure DevOps standard task for creating ZIP archives |
| Delete all APIs, applications, strategies, scopes and aliases on API Gateway BUILD (except for the system aliases "ServiceConsulDefault", "EurekaDefault", "OKTA", "PingFederate" and "local") | Executing the Prepare_BUILD.json Postman collection in /postman/collections/utilities/prepare |
| Prepare list of scopes to be imported | Parse scopes.json in API project root folder using jq |
| Import the Deployable to API Gateway BUILD | Executing the ImportAPI.json Postman collection in /postman/collections/utilities/import |
| Run tests on API Gateway BUILD (if test_condition is ${{true}}) | Executing the APITest.json Postman collection in the API project's root folder |
| Replace alias values using pipeline variables | Using FileTransform@1 Azure DevOps standard task for replacing the values in all aliases.json files |
| Prepare list of project-specific aliases to be updated | Parse aliases.json in API project root folder using jq |
| Prepare list of global aliases to be updated | Parse aliases.json in /apis root folder using jq |
| Validate and prepare assets: Validate policy actions, application names and API groupings, update aliases, delete all non-DEV/TEST/PROD applications, unsuspend all remaining applications, fix incorrect clientId and clientSecret values in OAuth2 strategies, add build details as tags to APIs (if prepare_condition is ${{true}}) | Executing the Prepare_for_DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT.json Postman collection in /postman/collections/utilities/prepare will run all the steps described. Executing the Prepare_for_DESIGN.json Postman collection in postman/collections/utilities/prepare only runs the fix step for OAuth2 strategies |
| Export the Deployable from API Gateway BUILD | Using a bash script calling curl to invoke the API Gateway Archive Service API |

#### store-build.yml

| Step | README |
| ------ | ------ |
| Build Upload | Using publish task |

#### retrieve-build.yml

| Step | README |
| ------ | ------ |
| Build Download | Using download task |

#### deploy-api.yml

| Step | README |
| ------ | ------ |
| Prepare list of scopes to be imported | Parse scopes.json in API project root folder using jq |
| Import the Deployable to API Gateway DESIGN/DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT | Executing the ImportAPI.json Postman collection in /postman/collections/utilities/import |

#### export-api.yml

| Step | README |
| ------ | ------ |
| Export the Deployable from API Gateway DESIGN | Using a bash script calling curl to invoke the API Gateway Archive Service API |
| Extract the flat representation from the API Deployable for API project xxx | Using ExtractFiles@1 Azure DevOps standard task for extracting ZIP archives |
| Remove the API Deployable again | Using DeleteFiles@1 Azure DevOps standard task for deleting the ZIP archive |

#### commit.yml

| Step | README |
| ------ | ------ |
| Set Git user e-mail and name | Set Git user e-mail and name to the e-mail and name of the Azure DevOps user who triggered the build pipeline |
| Git add, commit and push | Add and commit all changes and push to the HEAD of the selected repository branch |

The status and logs for each step can be inspected on the build details page in Azure DevOps. The imported/exported API Gateway archives and the test results can be inspected by clicking on `Artifacts`. The test results can be inspected in the `Tests` tab.

The Postman collections are executed using the Postman command-line execution component Newman, cf. https://learning.postman.com/docs/running-collections/using-newman-cli/command-line-integration-with-newman/.

## Pipeline definitions and pipeline templates for API Gateway configurations

### Pipeline definitions

The pipeline definition files (YAML) for the two Azure DevOps pipelines for API Gateway configurations can also be found in the /pipelines folder.

| Pipeline | Pipeline definition |
| ------ | ------ |
| `Configure API Gateway(s)` | configure-api-gateway.yml |
| `Export API Gateway Configuration` | export-config.yml |

### Stage templates

The stage-level pipeline templates used in these pipelines can be found in the /pipelines/stage-templates folder:

| Template | README |
| ------ | ------ |
| configure-api-gateway.yml | Stage template implementing the stages for importing the deployable and for initializing the environments on the selected stage(s) |
| export-config.yml | Stage template implementing the stage for exporting the API Gateway configuration from the selected environment and committing its content to Git |

In addition to the parameters injected by the façade templates, the export-config.yml template has the following input parameters:

| Parameter | README |
| ------ | ------ |
| selected_source_environment | API Gateway environment from which to export the configuration |
| commit_message | The change will be committed with this commit message |

The configure-api-gateway.yml template does not have any additional parameters.

### Step templates

The step-level pipeline templates used in these pipelines can be found in the /pipelines/step-templates folder:

| Template | README |
| ------ | ------ |
| configure-api-gateway.yml | Includes all steps for importing the deployable on one environment and for initializing the environment |
| configure-haft-listener.yml | Configures HAFT listener on one environment |
| configure-haft-ring.yml | Configures HAFT ring on one environment |
| configure-haft-ring-validation.yml | Validates HAFT ring configuration on one environment |
| export-config.yml | Exports the API Gateway configuration from one API Gateway environment |
| commit.yml | Commits the results to the repository |

Each ADO stage in the configure-api-gateway.yml stage template invokes configure-api-gateway.yml for each environment in separate jobs on (potentially) different agents. For stages with configure_haft=true, the stage will then invoke configure-haft-listener.yml for each environment, then configure-haft-ring.yml for each environment and finally configure-haft-ring-validation.yml for each environment, all in separate jobs on (potentially) different agents.

The export-config.yml stage template invokes export-config.yml and commit.yml sequentially in one stage in one job on one agent.

The pipeline templates execute the following major steps:

#### configure-api-gateway.yml

| Step | README |
| ------ | ------ |
| Create the API Deployable from the flat representation for DESIGN/BUILD/DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT configuration | Using ArchiveFiles@2 Azure DevOps standard task for creating ZIP archives |
| Prepare list of scopes to be imported | Parse scopes.json in API Gateway configuration root folder using jq |
| Import the Deployable to API Gateway DESIGN/BUILD/DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT | Executing the ImportConfig.json Postman collection in /postman/collections/utilities/import |
| Initialize API Gateway DESIGN/BUILD/DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT | Executing the Initialize_DESIGN/BUILD/DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT.json Postman collection in /postman/collections/utilities/initialize |

#### configure-haft-listener.yml

| Step | README |
| ------ | ------ |

#### re-haft-ring.yml

| Step | README |
| ------ | ------ |

#### configure-haft-ring-validation.yml

| Step | README |
| ------ | ------ |

#### export-config.yml

| Step | README |
| ------ | ------ |
| Export the Deployable from API Gateway DESIGN | Using a bash script calling curl to invoke the API Gateway Archive Service API |
| Extract the flat representation from the API Deployable | Using ExtractFiles@1 Azure DevOps standard task for extracting ZIP archives |
| Remove the API Deployable again | Using DeleteFiles@1 Azure DevOps standard task for deleting the ZIP archive |

#### commit.yml

| Step | README |
| ------ | ------ |
| Set Git user e-mail and name | Set Git user e-mail and name to the e-mail and name of the Azure DevOps user who triggered the build pipeline |
| Git add, commit and push | Add and commit all changes and push to the HEAD of the selected repository branch |

The status and logs for each step can be inspected on the build details page in Azure DevOps Server. The imported/exported API Gateway archives can be inspected by clicking on `Artifacts`.

The Postman collections are executed using the Postman command-line execution component Newman, cf. https://learning.postman.com/docs/running-collections/using-newman-cli/command-line-integration-with-newman/.

## Pipeline definition and pipeline templates for log purging

### Pipeline definition

The pipeline definition file (YAML) for the Azure DevOps pipeline for log purging can also be found in the /pipelines folder.

| Pipeline | Pipeline definition |
| ------ | ------ |
| `Purge API Gateway Analytics Data` | purge-data.yml |

### Stage template

The stage-level pipeline template used in this pipeline can be found in the /pipelines/stage-templates folder:

| Template | README |
| ------ | ------ |
| purge-data.yml | Stage template implementing the stages for purging the log data on the selected stage(s) |

In addition to the parameters injected by the façade templates, the purge-data.yml template does not have any additional parameters.

### Step templates

The step-level pipeline template used in this pipeline can be found in the /pipelines/step-templates folder:

| Template | README |
| ------ | ------ |
| purge-data.yml | Includes all steps for purging the log data on one environment |

Each ADO stage in the purge-data.yml stage template invokes purge-data.yml for each environment in separate jobs on (potentially) different agents.

The pipeline template executes the following major step:

#### purge-data.yml

| Step | README |
| ------ | ------ |
| Purge Data on API Gateway DESIGN/BUILD/DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT | Executing the PurgeData.json Postman collection in /postman/collections/utilities/purge |

The status and logs for each step can be inspected on the build details page in Azure DevOps Server.

The Postman collection is executed using the Postman command-line execution component Newman, cf. https://learning.postman.com/docs/running-collections/using-newman-cli/command-line-integration-with-newman/.

## Pipeline definitions and pipeline templates for API updating

### Pipeline definitions

The pipeline definition files (YAML) for the Azure DevOps pipeline for API updating can also be found in the /pipelines folder.

| Pipeline | Pipeline definition |
| ------ | ------ |
| `Update Petstore API by File` | update-petstore_File.yml |
| `Update Petstore API by URL` | update-petstore_URL.yml |

### Stage template

The stage-level pipeline template used in these pipelines can be found in the /pipelines/stage-templates folder:

| Template | README |
| ------ | ------ |
| update-api.yml | Stage template implementing the stage for updating the SwaggerPetstore API on DESIGN |

In addition to the parameters injected by the façade templates, the update-api.yml template has the following input parameters:

| Parameter | README |
| ------ | ------ |
| api_id | API Gateway asset ID of the API to be updated |
| update_type | UpdateAPI_File or UpdateAPI_URL |
| update_url | Only relevant for UpdateAPI_URL: URL of the Swagger file to be imported |
| update_username | Only relevant for UpdateAPI_URL: Username for downloading the Swagger file |
| update_password | Only relevant for UpdateAPI_URL: Password for downloading the Swagger file |
| update_file | Only relevant for UpdateAPI_File: Name of the file to be imported (in folder /schemas) |

### Step templates

The step-level pipeline template used in this pipeline can be found in the /pipelines/step-templates folder:

| Template | README |
| ------ | ------ |
| update-api.yml | Includes all steps for updating the API on DESIGN |

Each ADO stage in the update-api.yml stage template invokes update-api.yml for each DESIGN environment in separate jobs on (potentially) different agents.

The pipeline template executes the following major step:

#### update-api.yml

| Step | README |
| ------ | ------ |
| Update API on API Gateway DESIGN | Executing the Update_API.json Postman collection in /postman/collections/utilities/update |

The status and logs for each step can be inspected on the build details page in Azure DevOps Server.

The Postman collection is executed using the Postman command-line execution component Newman, cf. https://learning.postman.com/docs/running-collections/using-newman-cli/command-line-integration-with-newman/.

## Variable groups

### Variable groups for user credentials

The API Gateway Staging solution is using variable groups for securely managing the credentials (username and password) for accessing the API Gateway environments and the external Elasticsearch instances.

TODO: There is one variable group `API_Gateway_{{environment_set}}_users` for each of the two environment sets, and there is one variable group `API_Gateway_{{environment_set}}_{{stage}}_users` for each stage, and there is one variable group `API_Gateway_{{environment_set}}_{{environment}}_users` for each environment. For stages with only one environment, the stage name and the environment name are identical, and there is only one variable grou for this stage/environment.

Each variable group holds variable values specific for one API Gateway environment set or stage or environment:

| Variable | README |
| ------ | ------ |
| exporter_user | User for exporting assets from API Gateway, e.g., Exporter. The user must have the "Export assets" privilege |
| exporter_password | The API Gateway password for the exporter user |
| importer_user | User for importing assets in API Gateway, e.g., Importer. The user must have the "Import assets" privilege |
| importer_password | The API Gateway password for the importer user |
| publisher_user | User for publishing assets in API Gateway to API Portal / Developer Portal, e.g., Publisher. The user must have the "Publish to API Portal" privilege |
| publisher_password | The API Gateway password for the publisher user |
| preparer_user | User for preparing assets on API Gateway BUILD, e.g., Preparer. The user must have the "Manage APIs", "Activate / Deactivate APIs", "Manage applications", "Manage aliases" and "Manage scope mapping" privileges |
| preparer_password | The API Gateway password for the preparer user |
| initializer_user | User for initializing the API Gateway, e.g., Initializer. The user must have the "Manage general administration configurations" and "Manage aliases" privileges |
| initializer_password | The API Gateway password for the initializer user |
| purger_user | User for purging analytics data in API Gateway, e.g., Purger. The user must have the "Manage purge and restore runtime events" privilege |
| purger_password | The API Gateway password for the purger user |
| updater_user | User for updating APIs in API Gateway, e.g., Updater. The user must have the "Manage APIs" privilege |
| updater_password | The API Gateway password for the updater user |
| elasticsearch_user | The user of the external Elasticsearch instance for ingesting the API Gateway analytics data |
| elasticsearch_password | The Elasticsearch password for the Elasticsearch user |

These variables can be defined in any of these variable groups (environment set, stage, environment), even on multiple levels. The variable groups are read in the following order:
 1. environment set
 2. stage
 3. environment

If a variable is defined on multiple levels, the pipeline will use the value from the last read (lower) level. That means you can conveniently define all user credentials in the `API_Gateway_{{environment_set}}_users` variable group for all environments in the environment set if they are all the same. Or you can define (or overwrite) them in the `API_Gateway_{{environment_set}}_{{stage}}_users` variable groups on stage level if you have different credentials for different stages. Or you can define (or overwrite) them in the `API_Gateway_{{environment_set}}_{{environment}}_users` variable groups on environment level if you have different credentials for different environment within one stage.

> Note: You can use the same API Gateway user (for example, Administrator) for all roles, but then you would still have to set all user and password variables for all roles of this user in the respective variable group(s).

> Note: Even if you have all credentials defined on a higher or lower level, you still have to create all _users variable groups for all three levels, because the pipelines will always try to read all these variable groups. Azure DevOps does not allow empty variable groups, so each variable group must define at least one (dummy) variable.

### Variable groups for value substitutions

The API Gateway Staging solution uses the `API_Gateway_{{target_stage}}_value_substitutions` variable groups for managing the values for the replacement of placeholders in the build process, see above.

### Variable group for resource pooling

The API Gateway Staging solution uses the `API_Gateway_build_environments_availability` variable group for implementing the resource pooling mechanism for assigning build jobs to BUILD environments, see above.

## Azure DevOps environments

TODO

## Environment configurations

The Postman environments used in the API Gateway Staging solution are configured in the /environments/{{environment_set}} folders. For each environment, there is a Postman environment definition JSON file, for example:

### build_environment_demo.json

```
{
  "id": "f313be5f-2640-22f7-36b6-3e79bba3c9e2",
  "name": "BuildEnvironment Demo",
  "values": [
    {
      "enabled": true,
      "key": "hostname",
      "value": "apigw-build.acme.com",
      "type": "text"
    },
    {
      "enabled": true,
      "key": "ip",
      "value": "1.2.3.4",
      "type": "text"
    },
    {
      "enabled": true,
      "key": "port",
      "value": "443",
      "type": "text"
    },
    {
      "enabled": true,
      "key": "insecureflag",
      "value": "--insecure",
      "type": "text"
    },
    {
      "key": "https_proxy_host",
      "value": "5.6.7.8",
      "type": "text",
      "enabled": true
    },
    {
      "key": "https_proxy_port",
      "value": "6789",
      "type": "text",
      "enabled": true
    }
  ],
  "timestamp": 1587036498482,
  "_postman_variable_scope": "environment",
  "_postman_exported_at": "2020-04-16T11:32:40.730Z",
  "_postman_exported_using": "Postman/5.5.5"
}
```

Each environment must include values for the hostname, ip, port and insecureflag environment variables. The https_proxy_host and https_proxy_port environment variables are optional. They must be provided only when a proxy server should be configured for the environment.

| Environment variable | README |
| ------ | ------ |
| {{ip}} |  IP address of the API Gateway |
| {{port}} |  Port number of the API Gateway |
| {{hostname}} | Hostname of the API Gateway |
| {{insecureflag}} | Set to --insecure if the API Gateway server does not provide valid SSL server certificate, otherwise leave blank |
| {{https_proxy_host}} |  Hostname or IP address of the proxy server to be configured for this environment |
| {{https_proxy_port}} |  Port number of the proxy server to be configured for this environment |

These environment variables are used in the postman/collections/utilities Postman collections and in the "Export the Deployable" steps (bash scripts with curl command), and they must also be used in the APITest.json Postman test collections in the API projects.

They are loaded automatically when the Postman collections are executed in the Azure DevOps pipelines, and they can (and should) also be used in the Postman REST client for local API testing and test developments.

The separate configuration of IP address and hostname is necessary in order to support cases in which the agent might not be able to find the API Gateway server by its hostname.

## Postman collections

The following Postman collections are executed automatically against the BUILD and the Target environment(s) (using Newman) in the deployment and configuration pipelines:

![GitHub Logo](/images/Pipelines_Utilities.png)

The PurgeData.json Postman collection is executed automatically against all environments (using Newman) in the log purging pipeline:

![GitHub Logo](/images/Pipelines_Utilities_PurgeData.png)

The export pipelines are not using any Postman collections.

## API Gateway Service APIs

The API Gateway Staging solution is using the following API Gateway Service APIs:

Direct invocation (curl) in the gateway_import_export_utils.bat script:
 - API Gateway Archive Service API for importing and exporting API Gateway assets

Direct invocation (curl) in the api-build.yml, api-export-api.yml and api-export-config.yml pipeline templates:
 - API Gateway Archive Service API for exporting API Gateway assets

In the ImportAPI.json and the ImportConfig.json Postman collections:
 - API Gateway Alias Management Service API for reading and updating the configuration of the local OAuth2 Authorization Server and JWT Provider alias
 - API Gateway Archive Service API for importing API Gateway assets

In the Initialize_{Target}.json Postman collections:
 - API Gateway Administration Service API for setting the loadbalancer configuration and for setting the HTTPS_Proxy outbound proxy configuration
 - API Gateway Alias Management Service API for reading and updating the configuration of the local OAuth2 Authorization Server and JWT Provider alias

In the Prepare_BUILD.json Postman collection:
 - API Gateway Application Management Service API for deleting all applications
 - API Gateway Service Management Service API for deactivating and deleting all APIs
 - API Gateway Alias Management Service API for deleting all aliases

In the Prepare_for_{Target}.json Postman collections:
 - API Gateway Policy Management Service API for validating API policies
 - API Gateway Application Management Service API for validating applications and for removing unwanted applications and for activating (unsuspending) the remaining applications
 - API Gateway Alias Management Service API for updating alias values
 - API Gateway Service Management Service API for validating and updating APIs

In the PurgeData.json Postman collection:
 - API Gateway Administration Service API for purging log data
