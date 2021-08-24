@echo OFF

set no_proxy=*

set CURRENT_DIR=%~dp0..

set ACTION=%1
SHIFT 

:loop
IF NOT "%1"=="" (
  IF "%1"=="--tenant" (
      SET TENANT=%2
      SHIFT
  )
  IF "%1"=="--api_name" (
      SET PROJECT_NAME=%2
      SHIFT
  ) ELSE IF "%1"=="--environment" (
      SET ENVIRONMENT=%2
      SHIFT
  )
  IF "%1"=="--apigateway_url" (
      SET GATEWAY_URL=%2
      SHIFT
  )
	IF "%1"=="--apigateway_username" (
      SET GATEWAY_USERNAME=%2
      SHIFT
  )
	IF "%1"=="--apigateway_password" (
      SET GATEWAY_PASSWORD=%2
      SHIFT
  )
  SHIFT
  GOTO :loop
)

IF "%ACTION%" == "--importapi" (
    goto importapi
) ELSE IF "%ACTION%" == "--exportapi" (
    goto exportapi
) ELSE IF "%ACTION%" == "--importconfig" (
    goto importconfig
) ELSE IF "%ACTION%" == "--exportconfig" (
    goto exportconfig
) ELSE (
  echo "Action %ACTION% does not exist"
  goto :EOF
)

:importapi
IF EXIST %CURRENT_DIR%\%TENANT%\apis\%PROJECT_NAME%\assets (
 powershell Compress-Archive -Path %CURRENT_DIR%\%TENANT%\apis\%PROJECT_NAME%\assets\* -DestinationPath %CURRENT_DIR%\%PROJECT_NAME%.zip -Force
 curl -k -i -X POST %GATEWAY_URL%/rest/apigateway/archive?overwrite=*,aliases -H "Content-Type: application/zip" -H "Accept:application/json" --data-binary @"%CURRENT_DIR%\%PROJECT_NAME%.zip" --user %GATEWAY_USERNAME%:%GATEWAY_PASSWORD%
 del "%CURRENT_DIR%\%PROJECT_NAME%.zip"
 goto :EOF
) ELSE (
  echo "Folder %CURRENT_DIR%\%TENANT%\apis\%PROJECT_NAME%\assets does not exist"
  echo "API with name %PROJECT_NAME% does not exist"
  goto :EOF
)

:exportapi
IF EXIST %CURRENT_DIR%\%TENANT%\apis\%PROJECT_NAME%\assets (
  rmdir "%CURRENT_DIR%\%TENANT%\apis\%PROJECT_NAME%\assets" /s /q
  mkdir "%CURRENT_DIR%\%TENANT%\apis\%PROJECT_NAME%\assets"
  curl %GATEWAY_URL%/rest/apigateway/archive -k -d @"%CURRENT_DIR%\%TENANT%\apis\%PROJECT_NAME%\export_payload.json" --output %CURRENT_DIR%\%PROJECT_NAME%.zip --user %GATEWAY_USERNAME%:%GATEWAY_PASSWORD% -H "x-HTTP-Method-Override: GET" -H "Content-Type:application/json"
  powershell Expand-Archive -Path %CURRENT_DIR%\%PROJECT_NAME%.zip -DestinationPath %CURRENT_DIR%\%TENANT%\apis\%PROJECT_NAME%\assets -Force
  del "%CURRENT_DIR%\%PROJECT_NAME%.zip"
  goto :EOF
) ELSE (
  echo "Folder %CURRENT_DIR%\%TENANT%\apis\%PROJECT_NAME%\assets does not exist"
  echo "API with name %PROJECT_NAME% does not exist"
  goto :EOF
)

:importconfig
IF EXIST %CURRENT_DIR%\%TENANT%\configuration\%ENVIRONMENT%\assets (
 powershell Compress-Archive -Path %CURRENT_DIR%\%TENANT%\configuration\%ENVIRONMENT%\assets\* -DestinationPath %CURRENT_DIR%\%ENVIRONMENT%.zip -Force
 curl -k -i -X POST %GATEWAY_URL%/rest/apigateway/archive?overwrite=* -H "Content-Type: application/zip" -H "Accept:application/json" --data-binary @"%CURRENT_DIR%\%ENVIRONMENT%.zip" --user %GATEWAY_USERNAME%:%GATEWAY_PASSWORD%
 del "%CURRENT_DIR%\%ENVIRONMENT%.zip"
 goto :EOF
) ELSE (
  echo "Folder %CURRENT_DIR%\%TENANT%\configuration\%ENVIRONMENT%\assets does not exist"
  echo "Environment with name %ENVIRONMENT% does not exist"
  goto :EOF
)

:exportconfig
IF EXIST %CURRENT_DIR%\%TENANT%\configuration\%ENVIRONMENT%\assets (
  rmdir "%CURRENT_DIR%\%TENANT%\configuration\%ENVIRONMENT%\assets" /s /q
  mkdir "%CURRENT_DIR%\%TENANT%\configuration\%ENVIRONMENT%\assets"
  curl %GATEWAY_URL%/rest/apigateway/archive -k -d @"%CURRENT_DIR%\%TENANT%\configuration\%ENVIRONMENT%\export_payload.json" --output %CURRENT_DIR%\%ENVIRONMENT%.zip --user %GATEWAY_USERNAME%:%GATEWAY_PASSWORD% -H "x-HTTP-Method-Override: GET" -H "Content-Type:application/json"
  powershell Expand-Archive -Path %CURRENT_DIR%\%ENVIRONMENT%.zip -DestinationPath %CURRENT_DIR%\%TENANT%\configuration\%ENVIRONMENT%\assets -Force
  del "%CURRENT_DIR%\%ENVIRONMENT%.zip"
goto :EOF
) ELSE (
  echo "Folder %CURRENT_DIR%\%TENANT%\configuration\%ENVIRONMENT%\assets does not exist"
  echo "Environment with name %ENVIRONMENT% does not exist"
  goto :EOF
)