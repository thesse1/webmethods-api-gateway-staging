project=$1

echo
echo Updating variable groups
echo ========================
echo

az pipelines variable-group list --project $project | jq .[].id | while read line
do
    echo Updating variable group: $line
	az pipelines variable-group update --project $project --group-id $line --authorize true
done

echo
echo Updating environments
echo =====================
echo

az devops invoke --area environments --resource environments --route-parameters project=$project --http-method GET --api-version 7.2-preview -o json | jq .value[].id | while read line
do
    echo Updating environment: $line
    az devops invoke --area pipelinePermissions --resource pipelinePermissions --route-parameters project=$project resourceType=environment resourceId=$line --in-file set-authorization.json --http-method PATCH --api-version 7.2-preview
done
