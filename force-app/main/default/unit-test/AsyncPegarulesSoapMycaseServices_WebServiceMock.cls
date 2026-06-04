/**
 * WebServiceMock for pegarulesSoapMycaseServices async SOAP callouts.
 */
@IsTest
global class AsyncPegarulesSoapMycaseServices_WebServiceMock implements WebServiceMock {

    global void doInvoke(
        Object stub,
        Object request,
        Map<String, Object> response,
        String endpoint,
        String soapAction,
        String requestName,
        String responseNS,
        String responseName,
        String responseType
    ) {
        pegarulesSoapMycaseServices.ResultType result = new pegarulesSoapMycaseServices.ResultType();
        result.Code = '0';
        result.Message = 'OK';

        if (matches(requestName, responseType, 'CancelCSCase')) {
            pegarulesSoapMycaseServices.CancelCSCaseResponseType resp =
                new pegarulesSoapMycaseServices.CancelCSCaseResponseType();
            resp.Result = result;
            putResponse(response, responseName, responseType, resp);
            return;
        }
        if (matches(requestName, responseType, 'GetCSCaseDetail')) {
            pegarulesSoapMycaseServices.GetCSCaseDetailResponseType resp =
                new pegarulesSoapMycaseServices.GetCSCaseDetailResponseType();
            resp.Result = result;
            resp.CaseInfo = new pegarulesSoapMycaseServices.CaseDetailType();
            resp.CaseInfo.CaseID = 'CASE-DTL';
            putResponse(response, responseName, responseType, resp);
            return;
        }
        if (matches(requestName, responseType, 'GetCSCaseStatus')) {
            pegarulesSoapMycaseServices.GetCSCaseStatusResponseType resp =
                new pegarulesSoapMycaseServices.GetCSCaseStatusResponseType();
            resp.Result = result;
            resp.CaseInfo = new pegarulesSoapMycaseServices.CaseStatusType();
            resp.CaseInfo.CaseID = 'CASE-STS';
            resp.CaseInfo.Status = 'Open';
            putResponse(response, responseName, responseType, resp);
            return;
        }
        if (matches(requestName, responseType, 'GetCSMasterDataByCode')) {
            pegarulesSoapMycaseServices.GetCSMasterDataByCodeResponseType resp =
                new pegarulesSoapMycaseServices.GetCSMasterDataByCodeResponseType();
            resp.Result = result;
            resp.DataList = new pegarulesSoapMycaseServices.DataListType();
            resp.DataList.Data = new List<pegarulesSoapMycaseServices.DataType>{
                buildData('CODE1', 'Value1')
            };
            putResponse(response, responseName, responseType, resp);
            return;
        }
        if (matches(requestName, responseType, 'CreateCSCase')) {
            pegarulesSoapMycaseServices.CreateCSCaseResponseType resp =
                new pegarulesSoapMycaseServices.CreateCSCaseResponseType();
            resp.Result = result;
            resp.CaseInfo = new pegarulesSoapMycaseServices.CaseCreatedInfoType();
            resp.CaseInfo.CaseID = 'CASE-NEW';
            putResponse(response, responseName, responseType, resp);
            return;
        }
        if (matches(requestName, responseType, 'GetCSMasterData')) {
            pegarulesSoapMycaseServices.GetCSMasterDataResponseType resp =
                new pegarulesSoapMycaseServices.GetCSMasterDataResponseType();
            resp.Result = result;
            resp.DataList = new pegarulesSoapMycaseServices.DataListType();
            resp.DataList.Data = new List<pegarulesSoapMycaseServices.DataType>{
                buildData('MD1', 'Master1')
            };
            putResponse(response, responseName, responseType, resp);
        }
    }

    private static Boolean matches(String requestName, String responseType, String operation) {
        if (requestName == operation) {
            return true;
        }
        String suffix = '.' + operation + 'ResponseType';
        return responseType != null
            && (responseType.endsWith(suffix) || responseType == 'pegarulesSoapMycaseServices.' + operation + 'ResponseType');
    }

    private static void putResponse(
        Map<String, Object> response,
        String responseName,
        String responseType,
        Object payload
    ) {
        response.put('response_x', payload);
        if (String.isNotBlank(responseName)) {
            response.put(responseName, payload);
        }
        if (String.isNotBlank(responseType)) {
            response.put(responseType, payload);
        }
    }

    private static pegarulesSoapMycaseServices.DataType buildData(String code, String value) {
        pegarulesSoapMycaseServices.DataType row = new pegarulesSoapMycaseServices.DataType();
        row.Code = code;
        row.Value = value;
        return row;
    }
}
