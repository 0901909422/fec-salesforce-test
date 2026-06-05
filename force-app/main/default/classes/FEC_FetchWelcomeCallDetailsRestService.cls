/**Thangtv
 * Apex REST: Fetch Welcome Call details for Pega Collection.
 * Spec: REST_API_FetchWelcomeCallDetails_Salesforce.md (v1.1)
 *
 * URL: POST /services/apexrest/collections/v1/welcome-call-details
 */
@RestResource(urlMapping='/collections/v1/welcome-call-details')
global without sharing class FEC_FetchWelcomeCallDetailsRestService {

    private static final String SERVICE_NAME = 'FetchWelcomeCallDetails';
    private static final String WELCOME_CALL_BUSINESS_PROCESS_NAME = 'Welcome Call';
    private static final String CODE_SUCCESS_FOUND = '0';
    private static final String CODE_SUCCESS_NOT_FOUND = '1';
    private static final String CODE_FAILURE_BLANK_CONTRACT = '-1';
    private static final String CODE_FAILURE_CANNOT_OPEN = '-2';
    private static final String DESC_DATA_FOUND = 'Data-Found';
    private static final String DESC_DATA_NOT_FOUND = 'Data not found';
    private static final String DESC_CONTRACT_BLANK = 'Contract number is blank';
    private static final String DESC_CANNOT_OPEN = 'Cannot open Case details';

    global class FetchWelcomeCallDetailsRequest {
        global String RequestorID;
        global String TransID;
        global String DateTime_x;
        global String ContractNumber;
    }

    global class SysResponseType {
        global String RequestorID;
        global String TransID;
        global String DateTime_x;
        global String Status;
        global String Code;
        global String Description;
    }

    global class WelcomeCallCaseDetailsType {
        global String ContractNumber;
        global String CustomerName;
        global String PrimaryPhone;
        global String CreateOperator;
        global String UpdateDateTime;
        global String StatusWork;
        global String SubCategory;
    }

    global class FetchWelcomeCallDetailsResponse {
        global SysResponseType Sys;
        global List<WelcomeCallCaseDetailsType> WelcomeCallCaseDetails;
    }

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader(
            FEC_ConstantCommon.HTTP_HEADER_CONTENT_TYPE,
            FEC_ConstantCommon.API_CONTENT_TYPE_JSON
        );

        String requestBodyStr = req.requestBody != null ? req.requestBody.toString() : null;
        FetchWelcomeCallDetailsRequest reqBody = null;
        FetchWelcomeCallDetailsResponse response = null;
        Integer httpStatus = FEC_ConstantCommon.HTTP_STATUS_OK;

        try {
            if (String.isBlank(requestBodyStr)) {
                httpStatus = FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST;
                response = buildFailureResponse(
                    null,
                    null,
                    null,
                    CODE_FAILURE_BLANK_CONTRACT,
                    DESC_CONTRACT_BLANK
                );
                writeResponse(res, httpStatus, response);
                return;
            }

            reqBody = parseRequest(requestBodyStr);

            if (reqBody == null || String.isBlank(reqBody.ContractNumber)) {
                httpStatus = FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST;
                response = buildFailureResponse(
                    reqBody != null ? reqBody.RequestorID : null,
                    reqBody != null ? reqBody.TransID : null,
                    reqBody != null ? reqBody.DateTime_x : null,
                    CODE_FAILURE_BLANK_CONTRACT,
                    DESC_CONTRACT_BLANK
                );
                writeResponse(res, httpStatus, response);
                return;
            }

            response = processRequest(reqBody);
            writeResponse(res, httpStatus, response);
        } catch (JSONException je) {
            httpStatus = FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST;
            response = buildFailureResponse(
                null,
                null,
                null,
                CODE_FAILURE_BLANK_CONTRACT,
                'Invalid JSON: ' + je.getMessage()
            );
            writeResponse(res, httpStatus, response);
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                '[FetchWelcomeCallDetails] ' + e.getMessage() + '\n' + e.getStackTraceString()
            );
            httpStatus = FEC_ConstantCommon.ERROR_CODE_500_NUM;
            response = buildFailureResponse(
                reqBody != null ? reqBody.RequestorID : null,
                reqBody != null ? reqBody.TransID : null,
                reqBody != null ? reqBody.DateTime_x : null,
                CODE_FAILURE_CANNOT_OPEN,
                e.getMessage()
            );
            writeResponse(res, httpStatus, response);
        } finally {
            logRequest(requestBodyStr, response);
        }
    }

    private static FetchWelcomeCallDetailsResponse processRequest(
        FetchWelcomeCallDetailsRequest reqBody
    ) {
        String transId = String.isNotBlank(reqBody.TransID)
            ? reqBody.TransID.trim()
            : FEC_CommonUltils.generateTransactionUUID();

        try {
            List<Case> cases = queryWelcomeCallCases(reqBody.ContractNumber.trim());

            if (cases.isEmpty()) {
                return buildSuccessResponse(
                    reqBody.RequestorID,
                    transId,
                    reqBody.DateTime_x,
                    CODE_SUCCESS_NOT_FOUND,
                    DESC_DATA_NOT_FOUND,
                    null
                );
            }

            List<WelcomeCallCaseDetailsType> details = mapCasesToDetails(cases);
            return buildSuccessResponse(
                reqBody.RequestorID,
                transId,
                reqBody.DateTime_x,
                CODE_SUCCESS_FOUND,
                DESC_DATA_FOUND,
                details
            );
        } catch (Exception e) {
            return buildFailureResponse(
                reqBody.RequestorID,
                transId,
                reqBody.DateTime_x,
                CODE_FAILURE_CANNOT_OPEN,
                DESC_CANNOT_OPEN
            );
        }
    }

    @TestVisible
    private static Boolean simulateCannotOpenCase = false;

    private static List<Case> queryWelcomeCallCases(String contractNumber) {
        if (Test.isRunningTest() && simulateCannotOpenCase) {
            throw new QueryException('Simulated query failure');
        }
        return [
            SELECT
                Id,
                FEC_Contract_Number__c,
                FEC_Customer_Name__c,
                FEC_Phone_Number__c,
                FEC_Case_Status__c,
                Status,
                LastModifiedDate,
                CreatedBy.Email
            FROM Case
            WHERE FEC_Contract_Number__c = :contractNumber
                AND FEC_Business_Process__r.Name = :WELCOME_CALL_BUSINESS_PROCESS_NAME
            ORDER BY LastModifiedDate DESC
        ];
    }

    private static List<WelcomeCallCaseDetailsType> mapCasesToDetails(List<Case> caseRecords) {
        List<WelcomeCallCaseDetailsType> detailsList = new List<WelcomeCallCaseDetailsType>();
        for (Case c : caseRecords) {
            WelcomeCallCaseDetailsType details = new WelcomeCallCaseDetailsType();
            details.ContractNumber = c.FEC_Contract_Number__c;
            details.CustomerName = c.FEC_Customer_Name__c;
            details.PrimaryPhone = c.FEC_Phone_Number__c;
            details.CreateOperator = c.CreatedBy != null ? c.CreatedBy.Email : null;
            details.UpdateDateTime = c.LastModifiedDate != null
                ? c.LastModifiedDate.format(FEC_ConstantCommon.DATE_FORMAT)
                : null;
            details.StatusWork = String.isNotBlank(c.FEC_Case_Status__c)
                ? c.FEC_Case_Status__c
                : c.Status;
            details.SubCategory = null;
            detailsList.add(details);
        }
        return detailsList;
    }

    private static FetchWelcomeCallDetailsResponse buildSuccessResponse(
        String requestorId,
        String transId,
        String requestDateTime,
        String code,
        String description,
        List<WelcomeCallCaseDetailsType> details
    ) {
        FetchWelcomeCallDetailsResponse resp = new FetchWelcomeCallDetailsResponse();
        resp.Sys = buildSys(
            requestorId,
            transId,
            requestDateTime,
            FEC_ConstantCommon.SUCCESS_MESSAGE,
            code,
            description
        );
        resp.WelcomeCallCaseDetails = details;
        return resp;
    }

    private static FetchWelcomeCallDetailsResponse buildFailureResponse(
        String requestorId,
        String transId,
        String requestDateTime,
        String code,
        String description
    ) {
        FetchWelcomeCallDetailsResponse resp = new FetchWelcomeCallDetailsResponse();
        resp.Sys = buildSys(
            requestorId,
            transId,
            requestDateTime,
            FEC_ConstantCommon.KEY_ERROR,
            code,
            description
        );
        resp.WelcomeCallCaseDetails = null;
        return resp;
    }

    private static SysResponseType buildSys(
        String requestorId,
        String transId,
        String requestDateTime,
        String status,
        String code,
        String description
    ) {
        SysResponseType sys = new SysResponseType();
        sys.RequestorID = normalizeRequestorId(requestorId);
        sys.TransID = transId;
        sys.DateTime_x = formatResponseDateTime(requestDateTime);
        sys.Status = status;
        sys.Code = code;
        sys.Description = description;
        return sys;
    }

    private static String normalizeRequestorId(String requestorId) {
        if (String.isBlank(requestorId)) {
            return requestorId;
        }
        return requestorId.replace(FEC_ConstantCommon.STR_DASH, FEC_ConstantCommon.STR_EMPTY);
    }

    @TestVisible
    private static String formatResponseDateTime(String requestDateTime) {
        if (String.isNotBlank(requestDateTime)) {
            return requestDateTime.trim();
        }
        return FEC_CommonUltils.formatTransferCallRequestDateTime(System.now());
    }

    private static void writeResponse(
        RestResponse res,
        Integer httpStatus,
        FetchWelcomeCallDetailsResponse response
    ) {
        res.statusCode = httpStatus;
        res.responseBody = Blob.valueOf(serializeResponse(response));
    }

    private static void logRequest(
        String requestBodyStr,
        FetchWelcomeCallDetailsResponse response
    ) {
        try {
            HttpResponse apiResponse = new HttpResponse();
            Integer statusCode = response != null && response.Sys != null
                ? FEC_ConstantCommon.HTTP_STATUS_OK
                : FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST;
            apiResponse.setStatusCode(statusCode);
            apiResponse.setBody(response != null ? serializeResponse(response) : '');

            FEC_CommonUltils.logApi(
                SERVICE_NAME,
                SERVICE_NAME,
                FEC_ConstantCommon.API_METHOD_POST,
                requestBodyStr,
                apiResponse,
                response != null ? response.Sys.Description : null
            );
        } catch (Exception e) {
            System.debug('FEC_DEBUG logRequest error: ' + e.getMessage());
        }
    }

    @TestVisible
    private static FetchWelcomeCallDetailsRequest parseRequest(String requestBodyStr) {
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(requestBodyStr);
        FetchWelcomeCallDetailsRequest reqBody = new FetchWelcomeCallDetailsRequest();
        if (payload == null) {
            return reqBody;
        }
        reqBody.RequestorID = (String) payload.get('RequestorID');
        reqBody.TransID = (String) payload.get('TransID');
        reqBody.DateTime_x = (String) payload.get('DateTime');
        reqBody.ContractNumber = (String) payload.get('ContractNumber');
        return reqBody;
    }

    @TestVisible
    private static String serializeResponse(FetchWelcomeCallDetailsResponse response) {
        Map<String, Object> envelope = new Map<String, Object>();
        if (response == null) {
            return JSON.serialize(envelope);
        }

        Map<String, Object> sysMap = new Map<String, Object>();
        if (response.Sys != null) {
            sysMap.put('RequestorID', response.Sys.RequestorID);
            sysMap.put('TransID', response.Sys.TransID);
            sysMap.put('DateTime', response.Sys.DateTime_x);
            sysMap.put('Status', response.Sys.Status);
            sysMap.put('Code', response.Sys.Code);
            sysMap.put('Description', response.Sys.Description);
        }
        envelope.put('Sys', sysMap);

        if (response.WelcomeCallCaseDetails == null) {
            envelope.put('WelcomeCallCaseDetails', null);
            return JSON.serialize(envelope);
        }

        List<Object> detailsList = new List<Object>();
        for (WelcomeCallCaseDetailsType detail : response.WelcomeCallCaseDetails) {
            Map<String, Object> detailMap = new Map<String, Object>();
            detailMap.put('ContractNumber', detail.ContractNumber);
            detailMap.put('CustomerName', detail.CustomerName);
            detailMap.put('PrimaryPhone', detail.PrimaryPhone);
            detailMap.put('CreateOperator', detail.CreateOperator);
            detailMap.put('UpdateDateTime', detail.UpdateDateTime);
            detailMap.put('StatusWork', detail.StatusWork);
            detailMap.put('SubCategory', detail.SubCategory);
            detailsList.add(detailMap);
        }
        envelope.put('WelcomeCallCaseDetails', detailsList);
        return JSON.serialize(envelope);
    }
}