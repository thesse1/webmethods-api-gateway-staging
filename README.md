# About API Gateway Staging

> Note: This document is not 100% up-to-date. It describes an older version of the API Gateway Staging solution which you can find here: https://github.com/thesse1/webmethods-api-gateway-staging/tree/bbce669eebec59196359393a5a35bafb2fa38300. I will update the documentation as soon as I can.

> Note: This version of the API Gateway Staging solution depends on Azure DevOps Service. An older version of the solution which supports Azure DevOps Server 2019 can be found in the azure_devops_server_2019 branch: https://github.com/thesse1/webmethods-api-gateway-staging/tree/azure_devops_server_2019.

The webMethods API Gateway Staging solution allows to extract API Gateway assets from a DESIGN environment (local or shared/central), add them to a Git repository and automatically promote them to DEV, TEST and PROD environments, controlled by Azure DevOps build pipelines. During the promotion, the assets are first imported on a BUILD environment where they are automatically validated and tested (based on Postman collections) and specifically prepared for the intended target environment (also based on Postman collections). After this procedure, the modified assets are exported again from BUILD environment and imported on the target environment (DEV, TEST or PROD).

The solution also includes a script (and pipelines) for automatically extracting the general configuration of API Gateway instances. This includes the configuration of the API Gateway destination, the Transaction logging global policy and multiple administrative settings. The configuration can be added to the repository and imported on API Gateway instances using Azure DevOps build pipelines for quickly setting up new API Gateway instances or for resetting existing instances.

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
 - Alias values are set to target-stage-specific values
 - Text values in other API Gateway assets (like APIs, policies and applications) are set to target-stage-specific values
 - APIs should have separate sets of applications (with different identifiers) on different stages. The correct deployment of these applications should be enforced automatically. All applications are created on a local development environment or the central DESIGN environment with names ending with "_DEV", "_TEST" or "_PROD" indicating their intended usage. All applications should be exported and managed in Git, but only the intended applications should be imported on the respective DEV, TEST and PROD environments.
 - APIs must not contain any local, API-level Log Invocation policies in order to prevent any privacy issues caused by too detailed transaction logging
 - API mocking is turned off for deployments on TEST and PROD environments
 - API tags are added to all APIs indicating the build ID, the build name and the pipeline name (for auditability)

![GitHub Logo](/images/Overview.png)

This is implemented by validating and manipulating the assets on dedicated BUILD environments: Initially, all assets (including all applications) are imported on the BUILD environment. Then the local, API-level policy actions are scanned for any unwanted Log Invocation policies, all applications except for _DEV, _TEST or _PROD, respectively, are automatically deleted from the BUILD environment, alias values and test values in other assets are overwritten, API tags are inserted, and API mocking is disabled (for TEST and PROD target environments). Finally, the API project is exported again from the BUILD environment (now only including the right applications for the target environment and aliases with the right values and APIs with the right API tags and, if applicable, API mocking turned off) and imported on the target environment.

More of these design-time policies could easily be developed by extending the underlying Postman collections.

In addition to the deployment ("promotion") of assets to DEV, TEST and PROD, the solution also includes pipelines for deploying API projects to the central DESIGN environment - without validations, manipulations and API tests. This allows for (re-)setting the DESIGN environment to the current (or some former) state of the API development - selectively for the assets defined in one API project. Older states (Git commits) can be retrieved temporarily for inspecting former stages of the development or permanently for re-basing the development of the API project on an earlier version.

Finally, the solution also includes a pipeline for exporting API projects from the central DESIGN environment. The pipeline will automatically commit the exported project to the HEAD of the selected repository branch.

The solution supports separate stages for hosting internal and external APIs. The respective stages are called DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and PROD_EXT. Both internal and external APIs can be configured on the same local development instance or the central DESIGN instance. They must be assigned to the "Internal" and/or the "External" API group in order to be eligible for deployment to internal and/or external API Gateway DEV/TEST/PROD instances. ("Internal" and "External" must be added to the apiGroupingPossibleValues extended setting in API Gateway for making these values eligible as API groups.) APIs assigned to both the "Internal" and the "External" API group are eligible for deployment on internal and external API Gateway instances.

The solution supports target stages with multiple "instances", for example in different regions. (Each instance can itself be an API Gateway cluster.) The "instances" within one stage will always get the same configuration and the same set of APIs. Applications can by synchronized within stages using HAFT, cf. https://documentation.softwareag.com/webmethods/api_gateway/yai10-15/webhelp/yai-webhelp/#page/yai-webhelp%2Fco-haft_reference_arch.html.

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
  - configuration: Contains folders with the API Gateway configuration assets exported from DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and PROD_EXT instances along with the definition of the exported asset sets
  - environments: Contains folders with Postman environment definitions for API Gateway instances in the DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and PROD_EXT stages. Each folder includes the definitions for one set of environments. The solution comes with two sample sets:
    - webm_io: Set of webMethods.io API Gateways hosted on the Software AG cloud
    - azure_demo_01: Set of API Gateways deployed to Azure Kubernetes Service clusters
  - images: Diagrams and screenshots used in this documentation
  - pipelines: Contains the Azure DevOps pipeline definitions and pipeline templates for deploying API Gateway assets on DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and PROD_EXT environments, for initializing the environments, for exporting assets, for updating API definitions, for configuring HAFT, for publishing APIs to API Portal / Developer Portal and for log purging
  - postman/collections/utilities: Contains Postman collections for importing API Gateway assets, for preparing (cleaning) the BUILD environment, for preparing the API Gateway assets on BUILD for the target environment, for initializing API Gateway instances with environment-specific configurations, and for log purging
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

Alternatively, the developer can also use the `Export arbitrary/selected API project from DESIGN` pipelines and the `Deploy arbitrary/selected API projects` pipelines to export/import APIs from/to the central DESIGN environment into/from Git. In addition to that, the `Export API Gateway Configuration` pipeline and the `Configure API Gateways` pipeline can be used for exporting or importing the general configuration from/to DESIGN, BUILD, DEV, TEST or PROD.

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

## Target-stage-specific value substitutions

The API Gateway Staging solution offers three mechanisms for injecting target-stage-specific values into the definitions of the API Gateway assets when they are prepared on the BUILD environment for their target stages:

### Value substitution using using Azure DevOps Replace Tokens extension

Any text field in any asset on the DESIGN stage can include placeholders in the format `#{placeholder_name}#` at any point in the text field content. These placeholders will be replaced during the build phase on the BUILD environment by the `Deploy arbitrary/selected API projects` pipelines by values specific for the intended target stage of this build. The values are pulled from Azure DevOps pipeline variables which can be managed in the Azure DevOps variable groups DEV_INT_value_substitutions, DEV_EXT_value_substitutions, TEST_INT_value_substitutions, TEST_EXT_value_substitutions, PROD_INT_value_substitutions and TEST_EXT_value_substitutions.

This facilitates a separation of concern between API configuration experts managing the asset definitions in API Gateway and API providers managing the actual parameter values for their APIs on the different target stages directly in Azure DevOps without having to work on the API Gateway DESIGN (or in the repository code). On the other hand, this means that the target-stage-specific values will not be managed in Git, but directly in the Azure DevOps project.

Confidential values like passwords in outbound authentication policies can be secured by hiding their values in the Azure DevOps variable groups.

> Note: Placeholders are only allowed in text fields. If you try to place placeholders in numeric fields, the API Gateway UI will not let you save the asset.

> Note: Placing placeholders into asset definitions on the DESIGN environment might result in the API not working on the DESIGN stage anymore. For example, placing a placeholder into the API description does not cause any problem, but placing a placeholder into the endpoint URI in a routing policy will break the policy. The API will not be testable anymore on DESIGN, but it will work fine on the target stages and also on BUILD for the automatic test cases. (Replacing the placeholders takes place before running the automatic test scenario.)

> Note: You can find a sample for this mechanism in the sample SwaggerPetstore API, see below.

### aliases.json configuration of target-stage-specific alias values

Each API project can include one aliases.json file in the API project root folder specifying aliases used by the API(s) in the API project which should be overwritten with environment-specific values. In addition to that, there can be one global aliases.json file in the /apis root folder for overwriting values of aliases used by APIs in multiple API projects.

For each target environment, the aliases.json files must include JSON objects applicable for the API Gateway Alias Management Service API PUT /alias/{aliasId} request payload, cf. https://documentation.softwareag.com/webmethods/api_gateway/yai10-15/webhelp/yai-webhelp/#page/yai-webhelp%2Fco-restapi_alias_mgmt.html.

In order to avoid conflicts, each alias may only be configured to be overwritten either in the global aliases.json file in the /apis root folder or in the aliases.json files in the API project root folders.

Alias names cannot be changed by this functionality.

Aliases for which no values are defined (for the current target environment) in the global aliases.json file or in the API project's aliases.json file will be deployed with their original alias values from the DESIGN environment.

This facilitates the setting of specific alias values for every target stage directly in the code. All values for one alias can conveniently be managed in one place - for text fields as well as for numeric or boolean values and without breaking the testability of the API on the DESIGN environment.

> Note: Automatic tests on BUILD will be executed with the alias values as defined on the DESIGN environment. The target-stage-specific replacement of alias values based on the aliases.json files takes place after the execution of the automatic test scenario.

> Note: Confidential values should not be managed using this mechanism as they would be included in clear text in the aliases.json files in Git.

> Note: You can find a sample for this mechanism in the sample Ping API, see below.

### Value substitution using using Azure DevOps Replace Tokens extension for aliases.json files

Both the global and the API-project-specific aliases.json files can also include placeholders in the format `#{placeholder_name}#`.

This allows for a mix of the first and the second mechanism for injecting target-stage-specific values. You can define alias definitions for all target stages with some fixed values in the aliases.json files including some placeholders for values which should be replaced based on Azure DevOps pipeline variables (maybe for a better separation of concern or for better hiding confidential values).

> Note: Automatic tests on BUILD will be executed with the alias values as defined on the DESIGN environment. The target-stage-specific replacement of alias values based on the aliases.json files takes place after the execution of the automatic test scenario.

> Note: Inside the aliases.json files, placeholders can be placed inside the values of text fields, but also in numeric and boolean field values.

> Note: Technically, an aliases.json file with placeholders in the values of numeric or boolean fields does not represent a valid JSON document, so your editor might complain when opening or saving such a file. But the placeholders will be replaced by the correct numeric or boolean values before the files are interpreted as JSON documents, so this does not cause any problem at pipeline runtime.

> Note: You can find a sample for this mechanism in the sample PostmanEcho API, see below.

### TODO: Place this in the respective sample description

For example,
 - the value of the variable petstore-routing-alias.DEV_INT.description will automatically replace the description of the PetStore_Routing_Alias on DEV_INT, overwriting the value defined in the global aliases.json file,
 - the value of the variable postman-echo-routing-alias.TEST_EXT.readTimeout will automatically replace the readTimeout value of the PostmanEcho_Routing_Alias on TEST_EXT, overwriting the value defined in the global aliases.json file,
 - the value of the variable petstore-routing-alias-108.PROD_INT.description will automatically replace the description of the PetStore_Routing_Alias_1_0_8 for the API version 1.0.8 on PROD_INT, overwriting the value defined in the aliases.json file of the petstore-versioning API project,
 - the value of the variable postman-echo-security-alias.TEST_EXT.httpAuthCredentials.userName will automatically replace the username stored in the PostmanEcho_Security_Alias on TEST_EXT, overwriting the value defined in the aliases.json file of the security-alias API project.

For example,
 - the value of the variable postman-echo-security-alias.PROD_EXT.httpAuthCredentials.password will automatically replace the password stored in the PostmanEcho_Security_Alias on PROD_EXT, overwriting the value defined in the aliases.json file of the security-alias API project.

> Note: The password in an HTTP Transport security alias must be provided in base-64-encoded form, so the value of the (secret) replacement variable must also be provided in base-64-encoded form.

# Sample content included in this repository

## export_payload.json export query for API projects

The set of assets exported by gateway_import_export_utils.bat --exportapi (and by the `Export arbitrary/selected API project from DESIGN` pipelines) is defined by the export_payload.json in the API project root folder. It must be a JSON document applicable for the API Gateway Archive Service API POST /archive request payload, cf. https://documentation.softwareag.com/webmethods/api_gateway/yai10-15/webhelp/yai-webhelp/#page/yai-webhelp%2Fco-exp_imp_archive.html. It will typically contain a list of asset types ("types") to be exported and a query ("scope") based on the IDs of the selected assets.

The /apis folder contains sample API projects with the following export_payload.json files:

TODO

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

This example will select the API with asset ID f3d2a3c1-0f83-43ab-a6ec-215b93e2ecf5 (the Petstore demo API with API key authentication and consumer application identification). It will automatically also include all applications defined for this API, and it will include the PetStore_Routing_Alias simple alias configured for routing API requests to the native Petstore API at https://petstore.swagger.io/v2. This API and all other instances of the Petstore demo API are assigned to the Internal API group, so they can be deployed on DEV_INT, TEST_INT and PROD_INT.

### petstore-basicauth

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

### petstore-versioning

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

This API project includes two APIs, actually two versions of the same API. They must be configured separately in the export_payload.json of the API project. The two API versions are using two different (simple) aliases, PetStore_Routing_Alias_1_0_8 and PetStore_Routing_Alias_1_0_9, for routing API requests to the native Petstore API.

### postman-echo

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

### postman-mocking

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

### multiple-tenants

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

### postman-echo-oauth2

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

> Note: The local OAuth2 scope itself cannot be promoted from stage to stage using this mechanism, because it is configured in the general "local" system alias for the internal OAuth2 Authorization Server. OAuth2 scopes needed for the API(s) in an API project can be configured in the API project's scopes.json file, see below.

### postman-echo-jwt

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

The Ping API directly invokes the /invoke/wm.server:ping endpoint on the local underlying Integration Server of the API Gateway without using any routing alias. The API is assigned to the Internal and to the External API group, so it can be deployed on all DEV, TEST and PROD instances.

### number-conversion

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

This is an example for a SOAP API incl. test request in APITest.json. The API is assigned to the Internal and to the External API group, so it can be deployed on all DEV, TEST and PROD instances.

### odata-tutorial

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

This is an example for an OData API incl. test requests in APITest.json. The API is assigned to the Internal and to the External API group, so it can be deployed on all DEV, TEST and PROD instances.

### star-wars

```
{
  "types": [
    "api"
  ],
  "scope": [
    {
      "attributeName": "id",
      "keyword": "334cdaea-c550-443b-9d44-07d101fc32a7"
    }
  ]
}
```

This is an example for a GraphQL API incl. test request in APITest.json. The API is assigned to the Internal and to the External API group, so it can be deployed on all DEV, TEST and PROD instances.

### internal-external

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

### invalid-app-name

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

### invalid-logging-policy

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

### missing-api-group

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

## scopes.json configuration of OAuth2 scopes for API projects

Each API project can include one scopes.json file in the API project root folder specifying the OAuth2 scopes needed by the API(s) in the API project. The file will be parsed right before importing the other API Gateway assets of the API project and the scopes are injected into the local OAuth2 Authorization Server configuration. ("UPSERT": Existing scope definitions with the same name will be overwritten, new scope definitions with new names will be added.)

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

## TODO aliases.json configuration of environment-specific alias values

### Global aliases.json file

```
{
  "petstore-routing-alias": {
    "id" : "a593c88b-4e0a-4e4e-85ec-7e19d90ca332",
    "DEV_INT": {
      "name" : "PetStore_Routing_Alias",
      "description" : "Petstore alias on DEV_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "TEST_INT": {
      "name" : "PetStore_Routing_Alias",
      "description" : "Petstore alias on TEST_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "PROD_INT": {
      "name" : "PetStore_Routing_Alias",
      "description" : "Petstore alias on PROD_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    }
  },
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

The global aliases.json file in the /apis folder contains alias values for the respective DEV, TEST and PROD environments for the PetStore_Routing_Alias simple alias used in (most of the) Petstore APIs and for the PostmanEcho_Routing_Alias endpoint alias used in the PostmanEcho APIs.

### petstore-versioning

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

This file contains environment-specific values for the PetStore_Routing_Alias_1_0_8 and the PetStore_Routing_Alias_1_0_9 aliases used only by the two API versions in this API project.

### security-alias

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
        "userName" : "PostmanEcho_DEV_EXT",
        "password" : "TXlQYXNzd29yZF9ERVYtRVhU"
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
        "userName" : "PostmanEcho_TEST_EXT",
        "password" : "TXlQYXNzd29yZF9TVEFHRS1FWFQ="
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
        "userName" : "PostmanEcho_PROD_EXT",
        "password" : "TXlQYXNzd29yZF9QUk9ELUVYVA=="
      }
    }
  }
}
```

This file contains environment-specific values for the PostmanEcho_Security_Alias HTTP Transport security alias used only by the PostmanEcho_Security_Alias API in this API project.

> Note: The password in an HTTP Transport security alias must be provided in base-64-encoded form.

### incorrect-alias-name

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

### duplicate-alias

```
{
  "petstore-routing-alias": {
    "id" : "a593c88b-4e0a-4e4e-85ec-7e19d90ca332",
    "DEV_INT": {
      "name" : "PetStore_Routing_Alias",
      "description" : "Petstore alias on DEV_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "TEST_INT": {
      "name" : "PetStore_Routing_Alias",
      "description" : "Petstore alias on TEST_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    },
    "PROD_INT": {
      "name" : "PetStore_Routing_Alias",
      "description" : "Petstore alias on PROD_INT",
      "type" : "simple",
      "owner" : "Administrator",
      "value" : "https://petstore.swagger.io/v2"
    }
  }
}
```

This file contains environment-specific values for the PetStore_Routing_Alias alias which is already overwritten by the global aliases.json file in the /apis root folder. The build pipeline will detect this and return with an error message.

### alias-not-found

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

### missing-alias-id

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

### missing-alias-name

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

The set of assets exported by gateway_import_export_utils.bat --exportconfig (and by the export_configuration_from_stage pipeline) is defined by the export_payload.json in the configuration root folder. It must be a JSON document applicable for the API Gateway Archive Service API POST /archive request payload, cf. https://api.webmethodscloud.eu/#sagapis/apiDetails/c.restObject.API-Portal._N0usdLdEelRUwr3rpYDZg.-1. It will typically contain a list of asset types ("types") to be exported and a query ("scope") based on the IDs of the selected assets.

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
      "keyword": "errorProcessing|logConfig|gatewayDestinationConfig|elasticsearchDestinationConfig|keystore|settings|extended"
    }
  ],
  "condition" : "or"
}
```

This configuration includes the standard Transaction logging global policy configured (see below) and enabled, the global URL alias set to `api/${apiName}/${apiVersion}`, the proxy bypass addresses (only localhost), the API fault configured to the standard API Gateway error message template, the application logs configured as per the API Gateway standard (but with Kibana logger silent), the API Gateway destination (internal Elasticsearch database) events configuration as per the API Gateway standard (but with performance data publish interval of 5 minutes), the Elasticsearch destination (external Elasticsearch database) configuration, the default outbound and inbound keystores and truststores, and the (extended) settings.

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

Each API Gateway configuration can include one scopes.json file in the configuration root folder specifying the OAuth2 scopes intended for the APIs on this API Gateway instance. The file will be parsed right before importing the other API Gateway assets of the API Gateway configuration and the scopes are injected into the local OAuth2 Authorization Server configuration. ("UPSERT": Existing scope definitions with the same name will be overwritten, new scope definitions with new names will be added.)

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

## APITest.json Postman test collection

The next common scenario for an API developer is to assert the changes made to the APIs do not break their customer scenarios. This is achieved using Postman test collections, cf. https://learning.postman.com/docs/getting-started/introduction/. In a Postman test collection, the developer can group test requests that should be executed against the API under test every time a change is to be propagated to DEV, TEST or PROD. The collection can be defined and executed in a local instance of the Postman REST client, cf. https://learning.postman.com/docs/sending-requests/intro-to-collections/. The requests in a test collection should include scripted test cases asserting that the API response is as expected (response status, payload elements, headers etc.), cf. https://learning.postman.com/docs/writing-scripts/test-scripts/. Test scripts can also extract values from the response and store them in Postman variable for later use, https://learning.postman.com/docs/sending-requests/variables/. For example, the first request might request and get an OAuth2 access token and store it in a Postman variable; later requests can use the token in the variable for authenticating against their API. Test collections can even define request workflows including branches and loops, cf. https://learning.postman.com/docs/running-collections/building-workflows/. The automatic execution of Postman collections can be tested in the Postman REST client itself, cf. https://learning.postman.com/docs/running-collections/intro-to-collection-runs/.

Each API project must include one Postman test collection under the name APITest.json in its root folder. This test collection will be executed automatically on the BUILD environment for every deployment on DEV, TEST and PROD. It can be created by exporting a test collection in the Postman REST client and storing it directly in the API project's root folder under the name APITest.json.

> Note: The test requests in the Postman collection must use the following environment variables for addressing the API Gateway. Otherwise, the requests will not work in the automatic execution on the BUILD environment. Developers can import and use the environment definitions in the Postman REST client from the /environments folder.

| Environment variable | README |
| ------ | ------ |
| {{ip}} |  IP address of the API Gateway, must be used in the URL line of the test requests, e.g., https://{{ip}}:{{port}}/gateway/SwaggerPetstore/1.0/pet/123 |
| {{port}} |  Port number of the API Gateway, must be used in the URL line of the test requests, e.g., https://{{ip}}:{{port}}/gateway/SwaggerPetstore/1.0/pet/123 |
| {{hostname}} | Hostname of the API Gateway, must be used in the Host header of the test requests, e.g., Host: {{hostname}} |

> Note: The APITest.json Postman test collections will be executed automatically on the BUILD environment by the deployment pipelines before alias value replacement. So, they will be executed with aliases holding values as they are imported from the repository, i.e., with the values defined on the central DESIGN environment or the local development environment. Make sure that these values are set appropriately for the tests to be executed on the BUILD environment.

The /apis folder contains sample API projects with the following test collections:

### petstore

The petstore test collection sends POST, GET and DELETE requests against the SwaggerPetstore API. It contains tests validating the response code and the petId returned in the response body.

> Note: As of 15.06.2021, we have detected a malfunction in the native Petstore API breaking the GET and DELETE requests defined in the APITest.json Postman test collection for Petstore APIs: The GET and DELETE requests will intermittently (ca. 50% of the time) fail to address the pet by id. We have therefore manipulated all APITest.json Postman test collections for Petstore APIs skipping the GET and DELETE requests and only running the POST requests. The original versions of the test collections are retained as APITest_full_test.json.

### petstore-basicauth

The petstore-basicauth test collection invokes POST, GET and DELETE requests for testuser_01, testuser_02 (member of testgroup_02) and testuser_03 (member of testgroup_03, assigned to testteam_03).

### petstore-versioning

The petstore-versioning test collection invokes POST, GET and DELETE requests for both API versions.

### postman-echo

The postman-echo test collection sends POST, GET and DELETE requests against the Postman Echo API. It contains tests validating the response code and the echoed request elements (payload and query parameter) in the response body.

### postman-mocking

The postman-mocking test collection sends POST, GET and DELETE requests against the Postman Echo Mock API. It contains tests validating the response code and the echoed request elements (payload and query parameter) in the response body and the "source" attribute included only in the mock response.

### multiple-tenants

The multiple-tenants test collection invokes all three APIs for Tenant1 and Tenant2, respectively. The requests contain tests for the correct tenant query parameter echoed in the response body.

### postman-echo-oauth2

The postman-echo-oauth2 test collection invokes the API Gateway pub.apigateway.oauth2/getAccessToken service to retrieve an OAuth2 token. It stores the token in a Postman variable and uses it in the subsequent POST, GET and DELETE requests against the API.

### postman-echo-jwt

The postman-echo-jwt test collection invokes the API Gateway /rest/pub/apigateway/jwt/getJsonWebToken endpoint to retrieve a JSON Web Token. It stores the token in a Postman variable and uses it in the subsequent POST, GET and DELETE requests against the API.

### ping

The ping test collection invokes the Ping API GET request and validates the response code and the presence of the date attribute returned by the ping request.

### security-alias

The security-alias test collection sends POST, GET and DELETE requests against the Postman Echo API. It contains tests validating the response code and the echoed request elements (payload and query parameter and Authorization HTTP request header set by the Outbound Authentication policy using the PostmanEcho_Security_Alias HTTP Transport security alias) in the response body.

### test-failure

The test-failure test collection sends POST, GET and DELETE requests against the SwaggerPetstore API. The requests include tests which are designed to fail: The POST and the GET request tests are asking for an unexpected status code or petId, respectively. The DELETE request includes an incorrect API key provoking an Unauthorized application request error. The build pipeline will detect this and reject the API project with an error message.

# Azure DevOps pipelines

## Pipelines for API projects

The key to proper DevOps is continuous integration and continuous deployment. Organizations use standard tools such as Jenkins, GitLab and Azure DevOps to design their integration and assuring continuous delivery.

The API Gateway Staging solution includes two Azure DevOps build pipelines for deploying API projects from the Azure DevOps repository (or GitHub repository) to DESIGN, DEV, TEST and PROD environments and one pipeline for exporting API projects from DESIGN into the Azure DevOps repository (or GitHub repository).

In each deployment pipeline, the API Gateway assets configured in the API project will be imported on the BUILD environment (after cleaning it from remnants of the last deployment). For a deployment to DEV, TEST and PROD, it will then execute the API tests configured in the API project's APITest.json Postman test collection. If one of the tests fail, the deployment will be aborted. (No tests will be executed for deployments to DESIGN.)

For a deployment to DEV, TEST and PROD, the pipeline will now validate and manipulate the assets on the BUILD environment (using API Gateway's own APIs) to prepare them for the target environment:
- All policy actions will be scanned for unwanted API-level Log Invocation policies
- All applications with names not ending with _DEV, _TEST or _PROD, respectively, will be removed
- The remaining applications will be unsuspended (if necessary) to make sure they can be used on the target environment
- Aliases will be overwritten with the values retrieved from the global aliases.json file or the local API project's aliases.json file (perhaps after value replacement via pipeline variables)
- It will be assured that all APIs are assigned to the Internal API group or the External API group, respectively
- Incorrect clientId and clientSecret values in OAuth2 strategies will be fixed as a workaround for a defect identified in API Gateway 10.7 Fix 5 and 6
- Three API tags will be added to every API indicating the build ID, the build name and the pipeline name. These tags can later be used in the API Gateway UI on the target environments to understand when and how (and by whom) every API was promoted to the environment
- For a deployment to TEST or PROD, API mocking will be disabled

For a deployment to DESIGN, the pipeline will execute only one step to prepare OAuth2 strategies for the target environment:
- Incorrect clientId and clientSecret values in OAuth2 strategies will be fixed as a workaround for a defect identified in API Gateway 10.7 Fix 5 and 6

More manipulations or tests (e.g., enforcement of API standards) can be added later.

Finally, the (validated and manipulated) API Gateway assets will be exported from the BUILD environment and imported on the target environment (DESIGN, DEV, TEST or PROD).

> Note: If the imported assets already exist on the target environment (i.e., assets with same IDs), they will be overwritten for the following asset types: APIs, policies, policy actions, applications, scope mappings, aliases, users, groups and teams. Any assets of any other types, like configuration items, will not be overwritten.

Every deployment pipeline will publish the following artifacts:
- BUILD_import: The API Gateway asset archive (ZIP file) containing the assets initially imported on the BUILD environment
- BUILD_export_for_DESIGN, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT, PROD_EXT: The API Gateway asset archive (ZIP file) containing the assets exported from the BUILD environment (after manipulations)
- DESIGN_import, DEV_INT_import etc.: The API Gateway asset archive (ZIP file) containing the assets imported on DESIGN, DEV_INT etc. These artifacts should be identical with BUILD_export_for_DESIGN, BUILD_export_for_DEV_INT etc.
- test_results: The results of the Postman tests in junitReport.xml form

The export pipeline will publish the following artifact:
- DESIGN_export: The API Gateway asset archive (ZIP file) containing the assets exported from the DESIGN environment

These artifacts will be stored by Azure DevOps for some time. They will enable auditing and bug fixing of pipeline builds.

In addition to that, the test results are published into the Azure DevOps test results framework.

All pipelines must be triggered manually by clicking on `Run pipeline`. No triggers are defined to start the pipelines automatically.

> Note: Only one API Gateway Staging pipeline may run at one point in time. Parallel running builds might interfere while using the BUILD environment at the same time. Before starting an API Gateway Staging pipeline, make sure that there is no API Gateway Staging pipeline currently executing. If you want to promote an API to multiple stages, you can select multiple stages when starting the deploy_to_stages pipeline. It will execute the stages sequentially.

The API Gateway Staging solution was originally developed for Azure DevOps Server 2019. This version offers no simple way to prevent parallel invocations of build pipelines. In later versions, this could be accomplished using Environments and Exclusive Locks.

Each deployment pipelines consists of two jobs for build and deployment which can be executed on different agents using different credentials. Each job only contains steps connecting the agent with one API Gateway (either BUILD or DESIGN/DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT). The pipeline can be executed in distributed deployments in which different agents must be used for accessing the different API Gateway environments.

### deploy_to_stages

This pipeline will propagate the APIs and other API Gateway assets in the selected API project to the selected target environment.

The following parameters can/must be provided for this pipeline:

| Parameter | README |
| ------ | ------ |
| Branch | Select the Git branch from which the assets should be imported |
| Commit | Optional: Select the commit from which the assets should be imported. You must provide the commit's full SHA, see below. By default, the pipeline will import the HEAD of the selected branch |
| tenant | Tenant in which to deploy the API project |
| api_project | Case-sensitive name of the API project to be propagated |
| Stages to run | DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and/or PROD_EXT |

### deploy_to_config

This pipeline will import the APIs and other API Gateway assets in the selected API project to the DESIGN environment. It will not execute any tests, and it will not validate or prepare the assets for the target environment (no deletion of applications, no unsuspending of applications, no API tagging). The purpose of this pipeline is to reset the DESIGN environment to a defined (earlier) state.

The following parameters can/must be provided for this pipeline:

| Parameter | README |
| ------ | ------ |
| Branch | Select the Git branch from which the assets should be imported |
| Commit | Optional: Select the commit from which the assets should be imported. You must provide the commit's full SHA, see below. By default, the pipeline will import the HEAD of the selected branch |
| tenant | Tenant in which to deploy the API project |
| api_project | Case-sensitive name of the API project to be propagated |

### Selecting a specific commit to be deployed

When queuing a deployment pipeline, you can select the specific commit that should be checked out on the build agent, i.e., the configuration of the API Gateway assets to be imported to the BUILD environment. You have to provide the commit's full SHA which can be found out like this:
- In the repository history identify the selected commit and click on ``More Actions...``

![GitHub Logo](/images/More_Actions.png)

- Select ``Copy full SHA``

![GitHub Logo](/images/Copy_full_SHA.png)

- Go back to the pipeline and click on `Run pipeline`. Paste the value from the clipboard into the Commit form entry field

![GitHub Logo](/images/Paste.png)

![GitHub Logo](/images/SHA_pasted.png)

> Note: It will not work with the shortened commit ID displayed in the UI. You have to use the "full SHA".

### `Export arbitrary API project from DESIGN`

This pipeline will export the APIs and other API Gateway assets in the selected API project from DESIGN, and it will automatically commit the changes to the HEAD of the selected branch of the Azure DevOps repository (or GitHub repository).

The following parameters can/must be provided for this pipeline:

| Parameter | README |
| ------ | ------ |
| Branch | Select the Git branch into which the assets should be committed |
| Commit | Leave this blank |
| tenant | Tenant in which to export the API project |
| api_project | Case-sensitive name of the API project to be exported |
| commitMessage | The change will be committed with this commit message |

### `Export seletced API project from DESIGN`

This pipeline will export the APIs and other API Gateway assets in the selected API project from DESIGN, and it will automatically commit the changes to the HEAD of the selected branch of the Azure DevOps repository (or GitHub repository).

The following parameters can/must be provided for this pipeline:

| Parameter | README |
| ------ | ------ |
| Branch | Select the Git branch into which the assets should be committed |
| Commit | Leave this blank |
| tenant | Tenant in which to export the API project |
| api_project | Case-sensitive name of the API project to be exported |
| commitMessage | The change will be committed with this commit message |

### Drop-down list for api_project

As an alternative for the api_project free-text field, it would also be possible to define the names of existing API projects as possible values in the pipeline definition. Azure DevOps would then present a drop-down list which lets the user select the API project to be deployed from a configurable list of candidates which would be more convenient and less error-prone than having to type the full name of the API project correctly in the form entry field. But this candidate list would have to be updated for every new/renamed/removed API project.

## Pipelines for API Gateway configurations

The API Gateway Staging solution includes one Azure DevOps build pipeline for deploying API Gateway configurations from the Azure DevOps repository (or GitHub repository) to DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and/or PROD_EXT environments and one pipeline for exporting the API Gateway configurations from DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT or PROD_EXT into the Azure DevOps repository (or GitHub repository).

In each pipeline, the API Gateway assets configured in the environment configuration folder will be imported on / exported from the target environment.

Every pipeline will publish the following artifact:
- DESIGN_configuration, BUILD_configuration etc.: The API Gateway asset archive (ZIP file) containing the assets imported on DESIGN, BUILD etc.

These artifacts will be stored by Azure DevOps for some time. They will enable auditing and bug fixing of pipeline builds.

After importing the API Gateway assets, the configuration deployment pipelines will execute some steps for initializing the API Gateway:
- Configuration of environment-specific loadbalancer URL
- Configuration of environment-specific proxy
- Configuration of environment-specific OAuth2 and JWT configuration parameters in the local Authorization Server and JWT Provider alias
  - OAuth2 authorization code and access token expiration interval
  - JWT issuer, signing algorithm, token expiration interval, keystore alias and key alias

Further configuration steps can be added later.

All pipelines must be triggered manually by clicking on `Run pipeline`. No triggers are defined to start the pipelines automatically.

### configure_stages

This pipeline will import the API Gateway configuration assets on the DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and/or PROD_EXT environment.

The following parameters can/must be provided for this pipeline:

| Parameter | README |
| ------ | ------ |
| Branch | Select the Git branch from which the assets should be imported |
| Commit | Optional: Select the commit from which the assets should be imported. You must provide the commit's full SHA, see above. By default, the pipeline will import the HEAD of the selected branch |
| tenant | Tenant in which to import the API Gateway configuration |
| Stages to run | DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and/or PROD_EXT |

### export_configuration_from_stage

This pipeline will export the API Gateway configuration assets from DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT or PROD_EXT, and it will automatically commit the changes to the HEAD of the selected branch of the Azure DevOps repository (or GitHub repository).

The following parameters can/must be provided for this pipeline:

| Parameter | README |
| ------ | ------ |
| Branch | Select the Git branch into which the assets should be committed |
| Commit | Leave this blank |
| tenant | Tenant in which to export the API Gateway configuration |
| sourceType | DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT or PROD_EXT |
| commitMessage | The change will be committed with this commit message |

## Pipeline for log purging

The API Gateway Staging solution includes one Azure DevOps build pipeline for automatically purging the API Gateway logs stored in the internal Elasticsearch database on DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and/or PROD_EXT. It will purge
 - all logs (except for audit logs) older than 28 days: transactionalEvents, monitorEvents, errorEvents, performanceMetrics, threatProtectionEvents, lifecycleEvents, policyViolationEvents, applicationlogs, mediatorTraceSpan
 - all audit logs older than Jan. 1st of the preceding calendar year: auditlogs. (This is implementing the requirement to purge all audit data on the end of the following calendar year.)

### purge_data_from_stages

This pipeline can be configured to run in defined iterations, e.g., once every day:

![GitHub Logo](/images/run_schedule.png)

Please note that the "Only schedule builds if the source or pipeline has changed" option should be disabled. Otherwise, the pipeline would only run after changes in the repository.

The API Gateway Staging solution was developed for Azure DevOps Server 2019. In later versions, it will be possible to configure the schedule directly in the pipeline definition YAML file.

The following parameters can/must be provided for this pipeline:

| Parameter | README |
| ------ | ------ |
| Branch | Select the master branch |
| Commit | Leave this blank |
| tenant | Tenant in which to purge the API Gateway analytics data |
| Stages to run | DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and/or PROD_EXT |

# Usage examples

When using the API Gateway Staging solution, there are two options for exporting/importing from/to the API Gateway DESIGN stage (or a local development environment): Developers can either use a local repository (clone), export/import the API projects using the gateway_import_export_utils.bat script and synchronize their local repository (pull/push) with the central repository used by the Azure DevOps pipelines, or they can directly export/import API projects from/to the API Gateway DESIGN stage using the `Export arbitrary/selected API project from DESIGN` / `Deploy arbitrary/selected API project` pipelines.

## Example 1: Change an existing API

Let's consider this example: An API developer wants to make a change to the Petstore API.

### Option A: Using a local repository

  - All of the APIs of the organization are available in VCS in the /apis folder. This flat file representation of the APIs should be converted and imported into the developer's local development API Gateway environment or the central DESIGN environment for changes to be made. The developer uses the /bin/gateway_import_export_utils.bat Windows batch script to do this and import this API (and related assets like applications) to the local development environment or the central DESIGN environment.

  ```sh 
bin>gateway_import_export_utils.bat --importapi --api_name petstore --apigateway_url https://apigw-config.acme.com --apigateway_username hesseth --apigateway_password ***
  ```

  - The API Developer makes the necessary changes to the Petstore API on the local development environment or the central DESIGN environment. 

  - The API developer needs to ensure that the change that was made does not cause regressions. For this, the user needs to run the set of function/regression tests over his change in Postman REST client before the change gets propagated to the next stage.

  - Optional, but highly recommended: The developer creates a new feature branch for the change in the VCS.

  - Now this change made by the API developer has to be pushed back to the VCS system such that it propagates to the next stage. The developer uses the /bin/gateway_import_export_utils.bat Windows batch script to prepare this, export the configured API Gateway artifacts for the API project from the local development environment or the central DESIGN environment and store the asset definitions to the local repository /apis folder. This can be done by executing the following command.

  ```sh 
bin>gateway_import_export_utils.bat --exportapi --api_name petstore --apigateway_url https://apigw-config.acme.com --apigateway_username hesseth --apigateway_password ***
  ```

  - If the developer made any changes to the Postman test collection in the Postman REST client, he/she would now have to export the collection and store it under APITest.json in the API project root folder.
  
  - After this is done, the changes from the developer's local repository are committed to the VCS.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to DEV_INT or DEV_EXT using the deploy_to_stages pipeline.

  - The changed API can now be tested on DEV_INT or DEV_EXT environment.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to TEST_INT or TEST_EXT using the deploy_to_stages pipeline.

  - The changed API can now be tested on TEST_INT or TEST_EXT environment.

  - After successful testing, someone can now merge the feature branch into the master branch and propagate the changes by publishing the API project from the master branch to PROD_INT or PROD_EXT using the deploy_to_stages pipeline.

### Option B: Using the export/import pipelines

  - All of the APIs of the organization are available in VCS in the /apis folder. This flat file representation of the APIs should be converted and imported into the central DESIGN environment for changes to be made. The developer executes the deploy_to_config pipeline for the petstore API project.

  - The API Developer makes the necessary changes to the Petstore API on the central DESIGN environment. 

  - The API developer needs to ensure that the change that was made does not cause regressions. For this, the user needs to run the set of function/regression tests over his change in Postman REST client before the change gets propagated to the next stage.

  - Optional, but highly recommended: The developer creates a new feature branch for the change in the VCS.

  - Now this change made by the API developer has to be pushed back to the VCS system such that it propagates to the next stage. The developer executes the `Export arbitrary/selected API project from DESIGN` pipeline for the petstore API project.

  - If the developer made any changes to the Postman test collection in the Postman REST client, he/she would now have to export the collection and store it under APITest.json in the API project root folder and commit the change.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to DEV_INT or DEV_EXT using the deploy_to_stages pipeline.

  - The changed API can now be tested on DEV_INT or DEV_EXT environment.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to TEST_INT or TEST_EXT using the deploy_to_stages pipeline.

  - The changed API can now be tested on TEST_INT or TEST_EXT environment.

  - After successful testing, someone can now merge the feature branch into the master branch and propagate the changes by publishing the API project from the master branch to PROD_INT or PROD_EXT using the deploy_to_stages pipeline.

## Example 2: Create a new API in an existing API project

Let's consider this example: An API developer wants to create a new API and add it to an existing API project.

### Option A: Using a local repository

  - The developer would first have to update the API Gateway artifacts of the existing API project on the local development environment or the central DESIGN environment. The developer uses the /bin/gateway_import_export_utils.bat Windows batch script to do this and import the existing API project (and related assets like applications) to the local development environment or the central DESIGN environment.

  ```sh 
bin>gateway_import_export_utils.bat --importapi --api_name petstore --apigateway_url https://apigw-config.acme.com --apigateway_username hesseth --apigateway_password ***
  ```

  - The developer would then create the new API on the local development environment or the central DESIGN environment making sure it is correctly assigned to the Internal API group and/or to the External API group.

  - The developer would then import the API project's collection of function/regression tests from the APITest.json file into his/her local Postman REST client and add requests and tests for the new API.

  - Optional, but highly recommended: The developer creates a new feature branch for the change in the VCS.

  - The developer will now have to add the ID of the new API to the export_payload.json file in the root folder of the existing API project. The API ID can be extracted from the URL of the API details page in the API Gateway UI.

  - Now this change made by the API developer has to be pushed back to the VCS system such that it propagates to the next stage. The developer uses the /bin/gateway_import_export_utils.bat Windows batch script to prepare this, export the configured API Gateway artifacts for the API project from the local development environment or the central DESIGN environment and store the asset definitions to the local repository /apis folder. This can be done by executing the following command.

  ```sh 
bin>gateway_import_export_utils.bat --exportapi --api_name petstore --apigateway_url https://apigw-config.acme.com --apigateway_username hesseth --apigateway_password ***
  ```

  - The developer would now export the Postman test collection in the Postman REST client and store it under APITest.json in the API project root folder.

  - After this is done, the changes from the developer's local repository are committed to the VCS.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to DEV_INT or DEV_EXT using the deploy_to_stages pipeline.

  - The new API can now be tested on DEV_INT or DEV_EXT environment.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to TEST_INT or TEST_EXT using the deploy_to_stages pipeline.

  - The new API can now be tested on TEST_INT or TEST_EXT environment.

  - After successful testing, someone can now merge the feature branch into the master branch and propagate the changes by publishing the API project from the master branch to PROD_INT or PROD_EXT using the deploy_to_stages pipeline.

### Option B: Using the export/import pipelines

  - The developer would first have to update the API Gateway artifacts of the existing API project on the central DESIGN environment. The developer executes the deploy_to_config pipeline for the petstore API project.

  - The developer would then create the new API on the central DESIGN environment making sure it is correctly assigned to the Internal API group and/or to the External API group.

  - The developer would then import the API project's collection of function/regression tests from the APITest.json file into his/her local Postman REST client and add requests and tests for the new API.

  - Optional, but highly recommended: The developer creates a new feature branch for the change in the VCS.

  - The developer will now have to add the ID of the new API to the export_payload.json file in the root folder of the existing API project and commit the change. The API ID can be extracted from the URL of the API details page in the API Gateway UI.

  - Now this change made by the API developer has to be pushed back to the VCS system such that it propagates to the next stage. The developer executes the `Export arbitrary/selected API project from DESIGN` pipeline for the petstore API project.

  - The developer would now export the Postman test collection in the Postman REST client and store it under APITest.json in the API project root folder and commit the change.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to DEV_INT or DEV_EXT using the deploy_to_stages pipeline.

  - The new API can now be tested on DEV_INT or DEV_EXT environment.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to TEST_INT or TEST_EXT using the deploy_to_stages pipeline.

  - The new API can now be tested on TEST_INT or TEST_EXT environment.

  - After successful testing, someone can now merge the feature branch into the master branch and propagate the changes by publishing the API project from the master branch to PROD_INT or PROD_EXT using the deploy_to_stages pipeline.

## Example 3: Create a new API in a new API project

Let's consider this example: An API developer wants to create a new API and add it to a new API project.

### Option A: Using a local repository

  - The developer would create the new API on the local development environment or the central DESIGN environment.

  - The developer would then create a new collection of function/regression tests for the API project in the local Postman REST client with requests and tests for the new API.

  - Optional, but highly recommended: The developer creates a new feature branch for the change in the VCS.

  - The developer will now have to create a new API project folder under /apis with a new export_payload.json file including the ID of the new API. The API ID can be extracted from the URL of the API details page in the API Gateway UI. The developer will also have to create an empty assets folder in the API project root folder which will later hold the asset definitions exported from the local development environment or the central DESIGN environment.

  - Now the new API has to be committed to the VCS system such that it propagates to the next stage. The developer uses the /bin/gateway_import_export_utils.bat Windows batch script to prepare this, export the configured API Gateway artifacts for the API project from the local development environment or the central DESIGN environment and store the asset definitions to the local repository /apis folder. This can be done by executing the following command.

  ```sh 
bin>gateway_import_export_utils.bat --exportapi --api_name new_api --apigateway_url https://apigw-config.acme.com --apigateway_username hesseth --apigateway_password ***
  ```

  - The developer would now export the Postman test collection in the Postman REST client and store it under APITest.json in the API project root folder.
  
  - After this is done, the changes from the developer's local repository are committed to the VCS.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to DEV_INT or DEV_EXT using the deploy_to_stages pipeline.

  - The new API can now be tested on DEV_INT or DEV_EXT environment.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to TEST_INT or TEST_EXT using the deploy_to_stages pipeline.

  - The new API can now be tested on TEST_INT or TEST_EXT environment.

  - After successful testing, someone can now merge the feature branch into the master branch and propagate the changes by publishing the API project from the master branch to PROD_INT or PROD_EXT using the deploy_to_stages pipeline.

### Option B: Using the export/import pipelines

  - The developer would create the new API on the central DESIGN environment.

  - The developer would then create a new collection of function/regression tests for the API project in the local Postman REST client with requests and tests for the new API.

  - Optional, but highly recommended: The developer creates a new feature branch for the change in the VCS.

  - The developer will now have to create a new API project folder under /apis with a new export_payload.json file including the ID of the new API and commit the change. The API ID can be extracted from the URL of the API details page in the API Gateway UI. The developer will also have to create an empty assets folder in the API project root folder and commit the change. The folder will later hold the asset definitions exported from the central DESIGN environment.

  - Now the new API has to be committed to the VCS system such that it propagates to the next stage. The developer executes the `Export arbitrary/selected API project from DESIGN` pipeline for the petstore API project.

  - The developer would now export the Postman test collection in the Postman REST client and store it under APITest.json in the API project root folder and commit the change.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to DEV_INT or DEV_EXT using the deploy_to_stages pipeline.

  - The new API can now be tested on DEV_INT or DEV_EXT environment.

  - Someone will now propagate the changes by publishing the API project from the feature branch (or the master branch if no feature branch was created) to TEST_INT or TEST_EXT using the deploy_to_stages pipeline.

  - The new API can now be tested on TEST_INT or TEST_EXT environment.

  - After successful testing, someone can now merge the feature branch into the master branch and propagate the changes by publishing the API project from the master branch to PROD_INT or PROD_EXT using the deploy_to_stages pipeline.

# Implementation notes

## Pipeline definitions and pipeline templates for API projects

The pipeline definition files (YAML) for the three Azure DevOps pipelines for API projects can be found in the /pipelines folder.

| Pipeline | Pipeline definition | README |
| ------ | ------ | ------ |
| deploy_to_stages | api-deploy-to-stages.yml | |
| deploy_to_config | api-deploy-to-DESIGN.yml | |
| `Export arbitrary API project from DESIGN` | api-export-arbitrary-api-from-DESIGN.yml | |
| `Export selected API project from DESIGN` | api-export-selected-api-from-DESIGN.yml | |

The three deployment pipeline definitions are using central pipeline templates defined in api-build-template.yml, api-deploy-template.yml, store-build-template.yml, store-build-artifactory-template.yml and retrieve-build-template.yml, and the export pipeline definition api-export-api-from-DESIGN.yml is using the api-export-api-template.yml and the commit-template.yml pipeline templates:

| Template | README |
| ------ | ------ |
| api-build-template.yml | Includes all steps for preparing the deployable on the BUILD environment (including import, test execution, asset manipulation and export) |
| api-deploy-template.yml | Includes all steps for importing the deployable on the DESIGN/DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT environment |
| store-build-template.yml | Stores the deployable in Azure DevOps |
| store-build-artifactory-template.yml | Stores the deployable in Artifactory (optional) |
| retrieve-build-template.yml | Retrieves the deployable from Azure DevOps |
| api-export-api-template.yml | Exports the API project from the DESIGN environment |
| commit-template.yml | Commits the results to the repository |

The deployment pipeline deploy_to_stages contains six stages for deploying an API project to DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and/or PROD_EXT. The deployment pipeline deploy_to_config contains one stage for deployment to DESIGN. It is extracted into a separate pipeline in order to avoid accidental overwriting of API assets on DESIGN. Each stage in these pipelines invokes api-build-template.yml and store-build-template.yml in one job on one agent, and then retrieve-build-template.yml and api-deploy-template.yml in another job (potentially) on another agent.

The invocation of store-build-artifactory-template.yml is commented out. It can be activated when a service connection to a JFrog Artifactory repository is configured in Azure DevOps.

The export pipelines `Export arbitrary/selected API project from DESIGN` invoke api-export-arbitrary-api-from-DESIGN.yml/api-export-selected-api-from-DESIGN.yml and commit-template.yml sequentially in one stage in one job on one agent.

All five deployment pipeline templates need the following parameters to be set in the calling pipeline (where applicable):

| Parameter | README |
| ------ | ------ |
| api_project | Case-sensitive name of the API project to be propagated |
| build_environment | Name of the environment definition file in /environments folder for the BUILD environment, e.g., build_environment_demo.json |
| target_environment | Name of the environment definition file in /environments folder for the target environment, e.g., config_environment_demo.json, dev_int_environment_demo.json etc. |
| target_type | DESIGN, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT or PROD_EXT |
| test_condition | Whether to execute the automatic tests (${{true}} or ${{false}}), should be ${{true}} for DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT and ${{false}} for DESIGN |
| prepare_condition | Whether to prepare the API Gateway artifacts for the target environment (${{true}} or ${{false}}), should be ${{true}} for all environments |

The export pipeline template needs the following parameters:

| Parameter | README |
| ------ | ------ |
| api_project | Case-sensitive name of the API project to be exported |
| source_environment | Name of the environment definition file in /environments folder for the source environment, e.g., config_environment_demo.json |
| source_type | DESIGN |

The commit pipeline template needs the following parameter:

| Parameter | README |
| ------ | ------ |
| commitMessage | The change will be committed with this commit message |

The pipeline templates execute the following major steps:

### api-build-template.yml

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

### api-deploy-template.yml

| Step | README |
| ------ | ------ |
| Prepare list of scopes to be imported | Parse scopes.json in API project root folder using jq |
| Import the Deployable to API Gateway DESIGN/DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT | Executing the ImportAPI.json Postman collection in /postman/collections/utilities/import |

### store-build-template.yml

| Step | README |
| ------ | ------ |
| Build Upload | Using publish task |

### store-build-artifactory-template.yml

| Step | README |
| ------ | ------ |
| Artifactory Build Upload | Using ArtifactoryGenericUpload@2 Artifactory plug-in task |

### retrieve-build-template.yml

| Step | README |
| ------ | ------ |
| Build Download | Using download task |

### api-export-api-template.yml

| Step | README |
| ------ | ------ |
| Export the Deployable from API Gateway DESIGN | Using a bash script calling curl to invoke the API Gateway Archive Service API |
| Extract the flat representation from the API Deployable for API project xxx | Using ExtractFiles@1 Azure DevOps standard task for extracting ZIP archives |
| Remove the API Deployable again | Using DeleteFiles@1 Azure DevOps standard task for deleting the ZIP archive |

### commit-template.yml

| Step | README |
| ------ | ------ |
| Set Git user e-mail and name | Set Git user e-mail and name to the e-mail and name of the Azure DevOps user who triggered the build pipeline |
| Git add, commit and push | Add and commit all changes and push to the HEAD of the selected repository branch |

The status and logs for each step can be inspected on the build details page in Azure DevOps Server. The imported/exported API Gateway archives and the test results can be inspected by clicking on `Artifacts`. The test results can be inspected in the `Tests` tab.

The Postman collections are executed using the Postman command-line execution component Newman, cf. https://learning.postman.com/docs/running-collections/using-newman-cli/command-line-integration-with-newman/.

## Pipeline definitions and pipeline templates for API Gateway configurations

The pipeline definition files (YAML) for the two Azure DevOps pipelines for API Gateway configurations can also be found in the /pipelines folder.

| Pipeline | Pipeline definition | README |
| ------ | ------ | ------ |
| configure_stages | api-configure-stages.yml | |
| export_configuration_from_stage | api-export-config-from-stage.yml | |

The configuration pipeline definition api-configure-stages.yml is using a central pipeline template defined in api-configure-template.yml, and the export pipeline definition api-export-config-from-stage.yml is using the api-export-config-template.yml and the commit-template.yml pipeline templates:

| Template | README |
| ------ | ------ |
| api-configure-template.yml | Includes all steps for importing the deployable on the DESIGN/BUILD/DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT environment and for initializing the environment |
| api-export-config-template.yml | Exports the API Gateway configuration from the DESIGN/BUILD/DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT environment |
| commit-template.yml | Commits the results to the repository |

The import pipeline configure_stages contains eight stages for importing the configuration on DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and/or PROD_EXT. Each stage invokes api-configure-template.yml in one single job.

The export pipeline export_configuration_from_stage contains one stage for exporting the configuration from DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT or PROD_EXT. It is not possible to run multiple stages in this pipeline, because the Git commit would fail when selecting more than one stage. The single stage invokes api-export-config-template.yml and commit-template.yml sequentially in one job on one agent.

The configuration pipeline template needs the following parameters to be set in the calling pipeline:

| Parameter | README |
| ------ | ------ |
| environment | Name of the environment definition file in /environments folder for the target environment, e.g., config_environment_demo.json, build_environment_demo.json, dev_int_environment_demo.json etc. |
| type | Case-sensitive name of the environment type to be configured or updated (DESIGN, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT or PROD_EXT) |

The export pipeline template needs the following parameters:

| Parameter | README |
| ------ | ------ |
| environment | Name of the environment definition file in /environments folder for the source environment, e.g., config_environment_demo.json, build_environment_demo.json, dev_int_environment_demo.json etc. |
| type | DESIGN, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT or PROD_EXT |

The commit pipeline template needs the following parameter:

| Parameter | README |
| ------ | ------ |
| commitMessage | The change will be committed with this commit message |

The pipeline templates execute the following major steps:

### api-configure-template.yml

| Step | README |
| ------ | ------ |
| Create the API Deployable from the flat representation for DESIGN/BUILD/DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT configuration | Using ArchiveFiles@2 Azure DevOps standard task for creating ZIP archives |
| Prepare list of scopes to be imported | Parse scopes.json in API Gateway configuration root folder using jq |
| Import the Deployable to API Gateway DESIGN/BUILD/DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT | Executing the ImportConfig.json Postman collection in /postman/collections/utilities/import |
| Initialize API Gateway DESIGN/BUILD/DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT | Executing the Initialize_DESIGN/BUILD/DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT.json Postman collection in /postman/collections/utilities/initialize |

### api-export-config-template.yml

| Step | README |
| ------ | ------ |
| Export the Deployable from API Gateway DESIGN | Using a bash script calling curl to invoke the API Gateway Archive Service API |
| Extract the flat representation from the API Deployable | Using ExtractFiles@1 Azure DevOps standard task for extracting ZIP archives |
| Remove the API Deployable again | Using DeleteFiles@1 Azure DevOps standard task for deleting the ZIP archive |

### commit-template.yml

| Step | README |
| ------ | ------ |
| Set Git user e-mail and name | Set Git user e-mail and name to the e-mail and name of the Azure DevOps user who triggered the build pipeline |
| Git add, commit and push | Add and commit all changes and push to the HEAD of the selected repository branch |

The status and logs for each step can be inspected on the build details page in Azure DevOps Server. The imported/exported API Gateway archives can be inspected by clicking on `Artifacts`.

The Postman collections are executed using the Postman command-line execution component Newman, cf. https://learning.postman.com/docs/running-collections/using-newman-cli/command-line-integration-with-newman/.

## Pipeline definition and pipeline template for log purging

The pipeline definition file (YAML) for the Azure DevOps pipeline for log purging can also be found in the /pipelines folder.

| Pipeline | Pipeline definition | README |
| ------ | ------ | ------ |
| purge_data_from_stages | api-purge-data-from-stages.yml | |

The pipeline definition is using a pipeline template defined in api-purge-data-template.yml:

| Template | README |
| ------ | ------ |
| api-purge-data-template.yml | Purges the log data on the DESIGN/BUILD/DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT environment |

The pipeline invokes the template eight times in eight separate stages on separate agents - once for every environment.

The pipeline template needs the following parameters to be set in the calling pipeline:

| Parameter | README |
| ------ | ------ |
| environment | Name of the environment definition file in /environments folder for the environment, e.g., config_environment_demo.json, build_environment_demo.json, dev_int_environment_demo.json etc. |
| type | Case-sensitive name of the environment type (DESIGN, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT or PROD_EXT) |

The pipeline template executes the following major steps:

### api-purge-data-template.yml

| Step | README |
| ------ | ------ |
| Purge Data on API Gateway DESIGN/BUILD/DEV_INT/DEV_EXT/TEST_INT/TEST_EXT/PROD_INT/PROD_EXT | Executing the PurgeData.json Postman collection in /postman/collections/utilities/purge |

The status and logs for each step can be inspected on the build details page in Azure DevOps Server.

The Postman collection is executed using the Postman command-line execution component Newman, cf. https://learning.postman.com/docs/running-collections/using-newman-cli/command-line-integration-with-newman/.

## Variable groups and variable templates

All variable groups are referenced in the variable templates in /{tenant}/variables:

| Variable template | Referenced variable group for playground tenant | Referenced variable group for realworld tenant |
| ------ | ------ | ------ |
| /{tenant}/variables/BUILD/variables-template.yml | wm_test_apigw_staging_build | wm_environment_build |
| /{tenant}/variables/DESIGN/variables-template.yml | wm_test_apigw_staging_config | wm_environment_config |
| /{tenant}/variables/DEV_INT/variables-template.yml | wm_test_apigw_staging_dev_int | wm_environment_dev_intern |
| /{tenant}/variables/DEV_EXT/variables-template.yml | wm_test_apigw_staging_dev_ext | wm_environment_dev_extern |
| /{tenant}/variables/TEST_INT/variables-template.yml | wm_test_apigw_staging_stage_int | wm_environment_stage_intern |
| /{tenant}/variables/TEST_EXT/variables-template.yml | wm_test_apigw_staging_stage_ext | wm_environment_stage_extern |
| /{tenant}/variables/PROD_INT/variables-template.yml | wm_test_apigw_staging_prod_int | wm_environment_prod_intern |
| /{tenant}/variables/PROD_EXT/variables-template.yml | wm_test_apigw_staging_prod_ext | wm_environment_prod_extern |
| /{tenant}/variables/variables-aliases-template.yml | wm_test_apigw_staging_aliases | wm_apigw_staging_aliases |
| /{tenant}/variables/variables-artifactory-template.yml | wm_test_apigw_staging_artifactory | wm_apigw_staging_artifactory |

The reference of variables-artifactory-template.yml is commented out. It can be activated when a service connection to a JFrog Artifactory repository is configured in Azure DevOps.

This allows you to use variable groups with different names (or add further variables directly in the variable templates). The correct names of the variable groups would only have to be provided in the respective pipeline templates.

### wm_test_apigw_staging_config, build, dev_int, dev_ext, stage_int, stage_ext, prod_int, prod_ext and wm_environment_config, build, dev_intern, dev_extern, stage_intern, stage_extern, prod_intern, prod_extern

These variable groups are used by
 - the configuration and the export pipelines for API Gateway configurations
 - the deployment pipelines for API projects
 - the export pipeline for API projects
 - the log purging pipeline

Each variable group holds variable values specific for one API Gateway environment (DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT, PROD_EXT).

| Variable | README |
| ------ | ------ |
| agent_pool | The Azure DevOps agent pool to be used for accessing the API Gateway environment. For Microsoft-hosted agents: "Azure Pipelines". Select the right pool for self-hosted agents |
| agent_pool_vmImage | The VM image for Microsoft-hosted agents in the Azure Pipelines pool. For Microsoft-hosted agents: "$(pool_image)". Leave blank for self-hosted agents |
| environment | Name of the JSON file in the /environments folder for the API Gateway environment, e.g., config_environment_demo.json, build_environment_demo.json, dev_int_environment_demo.json etc. |
| exporter_user | User for exporting assets from API Gateway, e.g., Exporter. The user must have the "Export assets" privilege |
| exporter_password | The API Gateway password for the exporter user |
| importer_user | User for importing assets in API Gateway, e.g., Importer. The user must have the "Import assets" privilege |
| importer_password | The API Gateway password for the importer user |
| preparer_user | User for preparing assets on API Gateway BUILD, e.g., Preparer. The user must have the "Manage APIs", "Activate / Deactivate APIs", "Manage applications", "Manage aliases" and "Manage scope mapping" privileges |
| preparer_password | The API Gateway password for the preparer user |
| initializer_user | User for initializing the API Gateway, e.g., Initializer. The user must have the "Manage general administration configurations" and "Manage aliases" privileges |
| initializer_password | The API Gateway password for the initializer user |
| purger_user | User for initializing the API Gateway, e.g., Purger. The user must have the "Manage purge and restore runtime events" privilege |
| purger_password | The API Gateway password for the purger user |

### wm_test_apigw_staging_artifactory and wm_apigw_staging_artifactory (optional)

These variable groups are used by the deployment pipelines for API projects. The value of the useArtifactory variable decides whether they store build results in Artifactory - in addition to storing them in Azure DevOps.

| Variable | README |
| ------ | ------ |
| useArtifactory | true or false |
| artifactoryService | Name of the Artifactory service connection in Azure |
| artifactoryFolder | Name of the Artifactory base-folder (repository) |

### wm_test_apigw_staging_aliases and wm_apigw_staging_aliases

These variable groups are used by the deployment pipelines for API projects. They are containers for variables used in the replacement of alias values. Variable names must follow the naming convention described above in section [Overwrite alias values with pipeline variables](#overwrite-alias-values-with-pipeline-variables).

| Variable | README |
| ------ | ------ |
| {top-level attribute with a symbolic name of the alias in aliases.json file}.{target environment}.{name of the alias value to be replaced} | Replacement value |

> Note: These variable groups must be defined with at least one (dummy) variable even if you are not planning to use variable-based replacement of alias values.

## Environment configurations

The environments used in the API Gateway Staging solution are configured in the /environments folder. For each environment (DESIGN, BUILD, DEV_INT, DEV_EXT, TEST_INT, TEST_EXT, PROD_INT and PROD_EXT), there is a Postman environment definition JSON file, for example:

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

Direct invocation (curl) in the api-build-template.yml, api-export-api-template.yml and api-export-config-template.yml pipeline templates:
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
