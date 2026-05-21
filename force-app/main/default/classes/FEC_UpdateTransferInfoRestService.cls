/**
 * Apex REST Service: Update Call Transfer Information (inbound from Pega Collections)
 * URL    : POST /services/apexrest/collections/v1/call-transfer
 * Caller : Pega Collection system
 *
 * Request:
 *   CollActionCode    – mã hành động collection
 *   CollActionDate    – datetime dạng "yyyyMMddTHHmmss.SSS GMT"
 *   CollOperator      – email/agent thực hiện
 *   CollRemarks       – ghi chú
 *   CollSubActionCode – mã sub-action
 *   RequestorID       – định danh hệ thống gọi (e.g. "PegaCollection")
 *   ServiceCaseID     – mã Case trong SF (FEC_ID_Search__c, e.g. "S-72309698")
 *
 * Response:
 *   Description – mô tả kết quả
 *   RequestorID – echo lại RequestorID từ request
 *   Status      – "Success" / "Error"
 *   TransID     – UUID giao dịch
 */
@RestResource(urlMapping='/collections/v1/call-transfer')
global without sharing class FEC_UpdateTransferInfoRestService {

    // ─── Request DTO ─────────────────────────────────────────────────────────

    global class UpdateTransferInfoRequest {
        global String CollActionCode;
        global String CollActionDate;
        global String CollOperator;
        global String CollRemarks;
        global String CollSubActionCode;
        global String RequestorID;
        global String ServiceCaseID;
    }

    // ─── Response DTO ────────────────────────────────────────────────────────

    global class UpdateTransferInfoResponse {
        global String Description;
        global String RequestorID;
        global String Status;
        global String TransID;
    }

    // ─── Main Handler ────────────────────────────────────────────────────────

    @HttpPost
    global static void doPost() {
        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader(
            FEC_ConstantCommon.HTTP_HEADER_CONTENT_TYPE,
            FEC_ConstantCommon.API_CONTENT_TYPE_JSON
        );

        String transId        = FEC_CommonUltils.generateTransactionUUID();
        String requestBodyStr = req.requestBody?.toString();
        UpdateTransferInfoRequest  reqBody  = null;
        UpdateTransferInfoResponse response = null;

        try {
            reqBody = (UpdateTransferInfoRequest) JSON.deserialize(
                requestBodyStr,
                UpdateTransferInfoRequest.class
            );

            String validationError = validate(reqBody);
            if (validationError != null) {
                response = buildResponse(
                    FEC_ConstantCommon.KEY_ERROR,
                    validationError,
                    reqBody?.RequestorID,
                    transId
                );
                res.statusCode   = FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST;
                res.responseBody = Blob.valueOf(JSON.serialize(response));
                return;
            }

            List<Case> cases = [
                SELECT Id, FEC_ID_Search__c
                FROM   Case
                WHERE  FEC_ID_Search__c = :reqBody.ServiceCaseID
                LIMIT  1
            ];

            if (cases.isEmpty()) {
                response = buildResponse(
                    FEC_ConstantCommon.KEY_ERROR,
                    FEC_ConstantCommon.UPDATE_TRANSFER_ERR_SERVICE_CASE_NOT_FOUND_PREFIX
                        + reqBody.ServiceCaseID,
                    reqBody.RequestorID,
                    transId
                );
                res.statusCode   = FEC_ConstantCommon.HTTP_STATUS_OK;
                res.responseBody = Blob.valueOf(JSON.serialize(response));
                return;
            }

            Case c = cases[0];
            c.FEC_Coll_Action_Code__c     = reqBody.CollActionCode;
            c.FEC_Coll_Sub_Action_Code__c = reqBody.CollSubActionCode;
            c.FEC_Coll_Remarks__c         = reqBody.CollRemarks;
            c.FEC_Coll_Agent__c           = reqBody.CollOperator;
            c.FEC_Coll_Action_Date__c     = parsePegaDatetime(reqBody.CollActionDate);

            Database.update(c, AccessLevel.SYSTEM_MODE);

            response = buildResponse(
                FEC_ConstantCommon.SUCCESS_MESSAGE,
                FEC_ConstantCommon.UPDATE_TRANSFER_MSG_SUCCESS,
                reqBody.RequestorID,
                transId
            );
            res.statusCode   = FEC_ConstantCommon.HTTP_STATUS_OK;
            res.responseBody = Blob.valueOf(JSON.serialize(response));

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                '[UpdateTransferInfo] ' + e.getMessage() + '\n' + e.getStackTraceString());
            response = buildResponse(
                FEC_ConstantCommon.KEY_ERROR,
                e.getMessage(),
                reqBody?.RequestorID,
                transId
            );
            res.statusCode   = FEC_ConstantCommon.ERROR_CODE_500_NUM;
            res.responseBody = Blob.valueOf(JSON.serialize(response));
        } finally {
            logRequest(reqBody, requestBodyStr, response);
        }
    }

    // ─── Validation ──────────────────────────────────────────────────────────

    private static String validate(UpdateTransferInfoRequest req) {
        if (req == null) {
            return FEC_ConstantCommon.UPDATE_TRANSFER_VAL_REQUEST_BODY_REQUIRED;
        }
        if (String.isBlank(req.ServiceCaseID)) {
            return FEC_ConstantCommon.UPDATE_TRANSFER_VAL_SERVICE_CASE_ID_REQUIRED;
        }
        if (String.isBlank(req.RequestorID)) {
            return FEC_ConstantCommon.UPDATE_TRANSFER_VAL_REQUESTOR_ID_REQUIRED;
        }
        if (String.isBlank(req.CollActionCode)) {
            return FEC_ConstantCommon.UPDATE_TRANSFER_VAL_COLL_ACTION_CODE_REQUIRED;
        }
        return null;
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static UpdateTransferInfoResponse buildResponse(
        String status,
        String description,
        String requestorId,
        String transId
    ) {
        UpdateTransferInfoResponse resp = new UpdateTransferInfoResponse();
        resp.Status      = status;
        resp.Description = description;
        resp.RequestorID = requestorId;
        resp.TransID     = transId;
        return resp;
    }

    /**
     * Parse Pega datetime format: "yyyyMMddTHHmmss.SSS GMT"
     * e.g. "20260413T085557.495 GMT" → 2026-04-13T08:55:57Z
     * Falls back to ISO 8601 if format does not match.
     */
    @TestVisible
    private static Datetime parsePegaDatetime(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String trimmed = raw.trim();
        try {
            // Pega format: 8 date chars + 'T' at index 8
            Integer tIdx = trimmed.indexOf('T');
            if (tIdx == 8) {
                String datePart = trimmed.substring(0, 8);   // yyyyMMdd
                String afterT   = trimmed.substring(9);       // HHmmss[.SSS] [TZ]
                String timePart = afterT.split('\\.')[0].trim(); // HHmmss
                if (timePart.length() >= 6) {
                    String isoStr = datePart.substring(0, 4) + '-'
                        + datePart.substring(4, 6) + '-'
                        + datePart.substring(6, 8) + 'T'
                        + timePart.substring(0, 2) + ':'
                        + timePart.substring(2, 4) + ':'
                        + timePart.substring(4, 6) + 'Z';
                    return (Datetime) JSON.deserialize(
                        '"' + isoStr + '"', Datetime.class
                    );
                }
            }
        } catch (Exception ignore) {}

        // Fallback: ISO 8601
        try {
            return (Datetime) JSON.deserialize('"' + trimmed + '"', Datetime.class);
        } catch (Exception ignore) {}

        return null;
    }

    // ─── Logging ─────────────────────────────────────────────────────────────

    private static void logRequest(
        UpdateTransferInfoRequest  reqBody,
        String requestBodyStr,
        UpdateTransferInfoResponse response
    ) {
        try {
            FEC_CommonUltils.logException(
                FEC_ConstantCommon.UPDATE_TRANSFER_REST_SERVICE_NAME,
                FEC_ConstantCommon.UPDATE_TRANSFER_REST_SERVICE_NAME,
                'ServiceCaseID=' + (reqBody?.ServiceCaseID ?? '') +
                ' | Status='    + (response?.Status  ?? '') +
                ' | TransID='   + (response?.TransID ?? ''),
                requestBodyStr
            );
        } catch (Exception e) {
            System.debug('FEC_DEBUG logRequest error: ' + e.getMessage());
        }
    }
}
