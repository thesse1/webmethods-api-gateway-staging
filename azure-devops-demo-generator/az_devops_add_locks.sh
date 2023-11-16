project=$1

echo
echo Updating environments
echo =====================
echo

az devops invoke --area environments --resource environments --route-parameters project=$project --http-method GET --api-version 7.2-preview -o json | jq .value[].id | while read line
do
    echo Updating environment: $line
    jq -c --arg id "$line" '.resource.id=$id' add-exclusive-lock-template.json > add-exclusive-lock.json
    az devops invoke --area PipelinesChecks --resource configurations --route-parameters project=$project --http-method POST --api-version 7.2-preview -o json --in-file add-exclusive-lock.json
    rm add-exclusive-lock.json
done
