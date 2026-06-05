/**
 * Apex REST Service: Update Disbursement Status
 * URL: /UpdateServiceCases/v1/Update_Disbursement_Status
 * Method: POST
 * Author: tungnm37
 */
@RestResource(urlMapping='/UpdateServiceCases/v1/Update_Disbursement_Status')
global without sharing class FEC_UpdateDisbursementStatusRestService {

    // ─── Request DTOs ───────────────────────────────────────────────────────

    global class SysInfo {
        global String TransID;
        global String RequestorID;
        global String RequestDateTime;
    }

    global class UpdateDisbursementStatusRequest {
        global SysInfo Sys;
        global String CRMID;
        global String DISB_STATUS;
        global String DISB_DT;
        global String Desc_Field; // maps to DESC in JSON
    }

    // ─── Response DTO ───────────────────────────────────────────────────────

    global class UpdateDisbursementStatusResponse {
        global String Code;
        global String Message;

        global UpdateDisbursementStatusResponse(String code, String message) {
            this.Code = code;
            this.Message = message;
        }
    }

    // ─── Constants ──────────────────────────────────────────────────────────

    // tungnm37: dùng constants từ FEC_ConstantCommon cho Case status
    private static final String DISB_STATUS_WITHDRAWN          = 'Withdrawn';
    private static final String DISB_STATUS_CANCELLED_CUSTOMER = 'Cancelled_By_Customer';
    private static final String DISB_STATUS_AUTO_CANCELLED     = 'Auto_Cancelled';

    private static final Set<String> VALID_DISB_STATUSES = new Set<String>{
        DISB_STATUS_WITHDRAWN,
        DISB_STATUS_CANCELLED_CUSTOMER,
        DISB_STATUS_AUTO_CANCELLED
    };

    private static final String CODE_SUCCESS          = '200';
    private static final String CODE_BAD_REQUEST      = '400';
    private static final String CODE_CASE_NOT_FOUND   = '105';
    private static final String CODE_BUSINESS_ERROR   = '201';
    private static final String CODE_INTERNAL_ERROR   = '500';
    // ─── Main Handler ────────────────────────────────────────────────────────

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        UpdateDisbursementStatusResponse response;
        UpdateDisbursementStatusRequest reqBody;
        String requestBodyStr = req.requestBody?.toString();

        try {
            // Parse request
            Map<String, Object> rawMap = (Map<String, Object>) JSON.deserializeUntyped(requestBodyStr);
            reqBody = new UpdateDisbursementStatusRequest();
            if (rawMap.containsKey('Sys')) {
                Map<String, Object> sysMap = (Map<String, Object>) rawMap.get('Sys');
                reqBody.Sys = new SysInfo();
                reqBody.Sys.TransID = (String) sysMap.get('TransID');
                reqBody.Sys.RequestorID = (String) sysMap.get('RequestorID');
                reqBody.Sys.RequestDateTime = (String) sysMap.get('DateTime');
            }
            reqBody.CRMID = (String) rawMap.get('CRMID');
            reqBody.DISB_STATUS = (String) rawMap.get('DISB_STATUS');
            reqBody.DISB_DT = (String) rawMap.get('DISB_DT');
            reqBody.Desc_Field = (String) rawMap.get('DESC');

            // Validate
            response = validate(reqBody);
            if (response != null) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(response));
                logRequest(reqBody, requestBodyStr, response);
                return;
            }

            // Query Case by CRMID
            List<Case> cases = [
                SELECT Id, FEC_ID_Search__c, FEC_Disbursement_Status__c,
                       FEC_Disbursement_Date__c, FEC_Remarks__c,
                       Status, FEC_Final_Status__c
                FROM Case
                WHERE FEC_ID_Search__c = :reqBody.CRMID
                LIMIT 1
            ];

            if (cases.isEmpty()) {
                response = new UpdateDisbursementStatusResponse(CODE_CASE_NOT_FOUND, System.Label.FEC_UpdateDisb_Msg_CRMID_Invalid);
                res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(response));
                logRequest(reqBody, requestBodyStr, response);
                return;
            }

            Case c = cases[0];

            // Business rule: Case đã đóng (Resolved-Completed hoặc trạng thái cuối)
            Set<String> closedStatuses = new Set<String>{
                FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
                FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED,
                FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED,
                FEC_ConstantCommon.CASE_STATUS_RESOLVED_REJECTED,
                FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANNOT_CONTACT_CUSTOMER
            };
            if (closedStatuses.contains(c.Status)) {
                response = new UpdateDisbursementStatusResponse(
                    CODE_BUSINESS_ERROR,
                    String.format(System.Label.FEC_UpdateDisb_Msg_AlreadyResolved, new List<String>{ reqBody.CRMID })
                );
                res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(response));
                logRequest(reqBody, requestBodyStr, response);
                return;
            }

            // Update Case
            c.FEC_Disbursement_Status__c = reqBody.DISB_STATUS;
            if (String.isNotBlank(reqBody.DISB_DT)) {
                try {
                    c.FEC_Disbursement_Date__c = Date.valueOf(reqBody.DISB_DT);
                } catch (Exception e) {
                    System.debug('FEC_DEBUG DISB_DT parse error: ' + e.getMessage());
                }
            }
            if (String.isNotBlank(reqBody.Desc_Field)) {
                c.FEC_Remarks__c = reqBody.Desc_Field;
            }

            // Update status based on DISB_STATUS - tungnm37: dùng FEC_ConstantCommon
            if (DISB_STATUS_WITHDRAWN.equals(reqBody.DISB_STATUS)) {
                c.Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED;
            } else if (DISB_STATUS_CANCELLED_CUSTOMER.equals(reqBody.DISB_STATUS)) {
                c.Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED;
            } else if (DISB_STATUS_AUTO_CANCELLED.equals(reqBody.DISB_STATUS)) {
                c.Status = FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED;
            }

            Database.update(c, AccessLevel.SYSTEM_MODE);

            response = new UpdateDisbursementStatusResponse(CODE_SUCCESS, System.Label.FEC_UpdateDisb_Msg_Success);
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(response));

        } catch (Exception e) {
            System.debug('FEC_DEBUG UpdateDisbursementStatus error: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            response = new UpdateDisbursementStatusResponse(CODE_INTERNAL_ERROR, System.Label.FEC_UpdateDisb_Msg_InternalError);
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(response));
        } finally {
            logRequest(reqBody, requestBodyStr, response);
        }
    }

    // ─── Validation ──────────────────────────────────────────────────────────

    private static UpdateDisbursementStatusResponse validate(UpdateDisbursementStatusRequest req) {
        if (req == null || req.Sys == null) {
            return new UpdateDisbursementStatusResponse(CODE_BAD_REQUEST, System.Label.FEC_UpdateDisb_Msg_InvalidRequest);
        }
        // REQ-001
        if (String.isBlank(req.Sys.TransID)) {
            return new UpdateDisbursementStatusResponse(CODE_BAD_REQUEST, System.Label.FEC_UpdateDisb_Msg_TransID_Required);
        }
        // REQ-002
        if (String.isBlank(req.Sys.RequestorID)) {
            return new UpdateDisbursementStatusResponse(CODE_BAD_REQUEST, System.Label.FEC_UpdateDisb_Msg_RequestorID_Required);
        }
        // REQ-003: DateTime phải đúng định dạng ISO 8601
        if (String.isBlank(req.Sys.RequestDateTime) || !Pattern.matches(
            '^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?(Z|[+-]\\d{2}:\\d{2})?$',
            req.Sys.RequestDateTime
        )) {
            return new UpdateDisbursementStatusResponse(CODE_BAD_REQUEST, System.Label.FEC_UpdateDisb_Msg_DateTime_Invalid);
        }
        try {
            String normalized = req.Sys.RequestDateTime.replaceAll('(Z|[+-]\\d{2}:\\d{2})$', '').replace('T', ' ');
            if (normalized.contains('.')) {
                normalized = normalized.substringBefore('.');
            }
            Datetime.valueOfGmt(normalized);
        } catch (Exception e) {
            return new UpdateDisbursementStatusResponse(CODE_BAD_REQUEST, System.Label.FEC_UpdateDisb_Msg_DateTime_Invalid);
        }
        // REQ-004
        if (String.isBlank(req.CRMID)) {
            return new UpdateDisbursementStatusResponse(CODE_BAD_REQUEST, System.Label.FEC_UpdateDisb_Msg_CRMID_Required);
        }
        // REQ-005
        if (String.isBlank(req.DISB_STATUS) || !VALID_DISB_STATUSES.contains(req.DISB_STATUS)) {
            return new UpdateDisbursementStatusResponse(CODE_BAD_REQUEST, System.Label.FEC_UpdateDisb_Msg_DisbStatus_Invalid);
        }
        // REQ-006: DISB_DT phải đúng định dạng yyyy-MM-dd
        if (String.isBlank(req.DISB_DT) || !Pattern.matches('^\\d{4}-\\d{2}-\\d{2}$', req.DISB_DT)) {
            return new UpdateDisbursementStatusResponse(CODE_BAD_REQUEST, System.Label.FEC_UpdateDisb_Msg_DisbDT_Invalid);
        }
        try {
            Date.valueOf(req.DISB_DT);
        } catch (Exception e) {
            return new UpdateDisbursementStatusResponse(CODE_BAD_REQUEST, System.Label.FEC_UpdateDisb_Msg_DisbDT_Invalid);
        }
        return null;
    }

    // ─── Log ─────────────────────────────────────────────────────────────────

    private static void logRequest(
        UpdateDisbursementStatusRequest reqBody,
        String requestBodyStr,
        UpdateDisbursementStatusResponse response
    ) {
        try {
            FEC_CommonUltils.logException(
                'tungnm37',
                'FEC_UpdateDisbursementStatusRestService',
                FEC_ConstantCommon.DISB_LOG_CRMID + (reqBody?.CRMID ?? FEC_ConstantCommon.STR_EMPTY) +
                FEC_ConstantCommon.DISB_LOG_STATUS + (reqBody?.DISB_STATUS ?? FEC_ConstantCommon.STR_EMPTY) +
                FEC_ConstantCommon.DISB_LOG_RESPONSE + (response != null ? JSON.serialize(response) : FEC_ConstantCommon.STR_EMPTY),
                requestBodyStr
            );
        } catch (Exception e) {
            System.debug('FEC_DEBUG logRequest error: ' + e.getMessage());
        }
    }
}
