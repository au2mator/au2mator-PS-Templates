
$APIKey="9b9bc5f5-7e8e-eb5e-b834-58ba96034ca1" #change to yur API Key
$ServiceID="45" #change to your Service ID

$BaseURL="http://localhost/api" #change to your au2mator URL


$Header = @{
    'Content-Type' = "application/json"
    'X-Api-Key'    = "$APIKey"
    'accept'= "*/*"
}  

#Start Request
$Post_URL="$BaseURL/RequestApi/StartRequest"


#the Request Body
#user the internal Question Keys as reference.
$JsonBody = @"
{
"targetUserId":"au2mator.local\\seidlm",
  "serviceId": $ServiceID,
  "requestParameters": [
    {
      "parameterName": "c_Number1",
      "parameterValue": "5"
    },
    {
      "parameterName": "c_Number2",
      "parameterValue": "2"
    },
    {
      "parameterName": "c_Number3",
      "parameterValue": "3"
      }
  ],
  "initiatedBy":"au2mator.local\\seidlm"
}
"@

$Return=Invoke-RestMethod -Method POST -Uri $Post_URL -Headers $Header -Body $JsonBody



#Check Request
$URL="http://localhost/api/RequestApi/RequestStatus/$($Return.data.requestId)"
Invoke-RestMethod -Method GET -Uri $URL -Headers $Header 
 
