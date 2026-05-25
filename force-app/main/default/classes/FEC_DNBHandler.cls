/***
 * FEC_DNBHandler
 * Author: HieuTT74
 * Created Date: 2026-04-09 14:16:00
 */

public without sharing class FEC_DNBHandler {
    public class CaseInfoResponse {
        @AuraEnabled public String customerName;
        @AuraEnabled public String nationalId;
        @AuraEnabled public String primaryPhoneNumber;
        @AuraEnabled public String interactionPhoneNumber;
        @AuraEnabled public String interactionMaskedPhone;
        @AuraEnabled public String interactionEmail;
        @AuraEnabled public String interactionMaskedEmail;
        @AuraEnabled public String channel;
        @AuraEnabled public String contractId;
        @AuraEnabled public Integer processActionCount;
        @AuraEnabled public String viewMode;
    }
    
    public class CaseInfoNonExistingResponse {
        @AuraEnabled public String customerName;
        @AuraEnabled public String nationalId;
        @AuraEnabled public String interactionPhoneNumber;
        @AuraEnabled public String interactionMaskedPhone;
        @AuraEnabled public String interactionEmail;
        @AuraEnabled public String interactionMaskedEmail;
        @AuraEnabled public String channel;
        @AuraEnabled public String contractId;
        @AuraEnabled public Integer processActionCount;
        @AuraEnabled public String viewMode;
    }
    
    public class DNBResponseItem {
        @AuraEnabled public String id;
        @AuraEnabled public String doNotBother;
        @AuraEnabled public String expectedExcludeTime;
        @AuraEnabled public String reason2;
        @AuraEnabled public String channel;
        @AuraEnabled public String type;
        @AuraEnabled public String typeValue;
    }
    
    @AuraEnabled
    public static CaseInfoResponse getCaseData(Id caseId) {
        // Simulate fetching data from server
        Case caseRecord = [
      SELECT Id, FEC_Customer_Name__c,
      FEC_Account_or_Contract__r.FEC_Search_Result_National_ID__c ,
      FEC_Phone_Number__c, FEC_Interaction__r.FEC_Phone_Number__c,
      FEC_Interaction__r.FEC_Interaction_Masked_Phone__c,
      FEC_Interaction__r.FEC_Interaction_Email__c,
      FEC_Interaction__r.FEC_Interaction_Masked_Email__c, FEC_Channel__c,
      FEC_Account_Contract_Number_Text__c, FEC_Process_Action_Count__c,
      FEC_Interaction_View_Mode__c FROM Case WHERE Id = : caseId LIMIT 1
    ];
        
        CaseInfoResponse response = new CaseInfoResponse();
        response.customerName = caseRecord.FEC_Customer_Name__c;
        response.nationalId =
            caseRecord.FEC_Account_or_Contract__r.FEC_Search_Result_National_ID__c;
        response.primaryPhoneNumber = caseRecord.FEC_Phone_Number__c;
        response.interactionPhoneNumber =
            caseRecord.FEC_Interaction__r.FEC_Phone_Number__c;
        response.interactionMaskedPhone =
            caseRecord.FEC_Interaction__r.FEC_Interaction_Masked_Phone__c;
        response.interactionEmail =
            caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c;
        response.interactionMaskedEmail =
            caseRecord.FEC_Interaction__r.FEC_Interaction_Masked_Email__c;
        response.channel = caseRecord.FEC_Channel__c;
        response.contractId = caseRecord.FEC_Account_Contract_Number_Text__c;
        response.processActionCount = caseRecord.FEC_Process_Action_Count__c == null
            ? 0
            : Integer.valueOf(caseRecord.FEC_Process_Action_Count__c);
        response.viewMode = caseRecord.FEC_Interaction_View_Mode__c;
        return response;
    }
    
    @AuraEnabled
    public static CaseInfoNonExistingResponse getCaseNonExistingData(Id caseId) {
        // Simulate fetching data from server
        Case caseRecord = [
      SELECT Id, FEC_Customer_Name__c,
      FEC_Account_or_Contract__r.FEC_Search_Result_National_ID__c,
      FEC_Phone_Number__c, FEC_Interaction__r.FEC_Phone_Number__c,
      FEC_Interaction__r.FEC_Interaction_Masked_Phone__c,
      FEC_Interaction__r.FEC_Interaction_Email__c,
      FEC_Interaction__r.FEC_Interaction_Masked_Email__c, FEC_Channel__c,
      FEC_Account_Contract_Number_Text__c, FEC_Process_Action_Count__c,
      FEC_Interaction_View_Mode__c FROM Case WHERE Id = : caseId LIMIT 1
    ];
        
        CaseInfoNonExistingResponse response = new CaseInfoNonExistingResponse();
        response.customerName = caseRecord.FEC_Customer_Name__c;
        response.nationalId =
            caseRecord.FEC_Account_or_Contract__r.FEC_Search_Result_National_ID__c;
        response.interactionPhoneNumber =
            caseRecord.FEC_Interaction__r.FEC_Phone_Number__c;
        response.interactionMaskedPhone =
            caseRecord.FEC_Interaction__r.FEC_Interaction_Masked_Phone__c;
        response.interactionEmail =
            caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c;
        response.interactionMaskedEmail =
            caseRecord.FEC_Interaction__r.FEC_Interaction_Masked_Email__c;
        response.channel = caseRecord.FEC_Channel__c;
        response.contractId = caseRecord.FEC_Account_Contract_Number_Text__c;
        response.processActionCount = caseRecord.FEC_Process_Action_Count__c == null
            ? 0
            : Integer.valueOf(caseRecord.FEC_Process_Action_Count__c);
        response.viewMode = caseRecord.FEC_Interaction_View_Mode__c;
        return response;
    }
    
    @AuraEnabled
    public static Boolean checkDNB(
    Id categoryId, Id subCategoryId, Id subCodeId) {
        try {
            // Không có input → false
            if (categoryId == null && subCategoryId == null && subCodeId == null) {
                return false;
            }
            
            // Build query động theo input có giá trị
            String soql = 'SELECT Id, Name, FEC_Do_Not_Bother__c '
                + 'FROM FEC_Nature_of_Case__c WHERE ';
            
            List<String> conditions = new List<String>();
            
            if (categoryId != null) {
                conditions.add('FEC_Category__c = :categoryId');
            }
            if (subCategoryId != null) {
                conditions.add('FEC_Sub_Category__c = :subCategoryId');
            }
            if (subCodeId != null) {
                conditions.add('FEC_Sub_Code__c = :subCodeId');
            }
            
            soql += String.join(conditions, ' AND ') + ' LIMIT 1';
            
            List<FEC_Nature_of_Case__c> results = Database.query(soql);
            
            if (results.isEmpty())
                return false;
            
            return results[0].FEC_Do_Not_Bother__c;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static FEC_GetDNBCalloutService.DNBResult getDNBResult(String caseId) {
        Case caseRecord = [
      SELECT Id, FEC_Phone_Number__c,
      FEC_Interaction__r.FEC_Interaction_Email__c,
      FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c FROM Case WHERE
          Id = : caseId LIMIT 1
    ];
        
        String phoneNumber = caseRecord.FEC_Phone_Number__c;
        String email = caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c;
        String nationalId =
            caseRecord.FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c;
        
        // ===== Create request =====
        FEC_GetDNBCalloutService.DNBRequest req =
            new FEC_GetDNBCalloutService.DNBRequest();
        
        req.phone = normalizePhone(phoneNumber);
        req.nid = nationalId;
        req.email = email; // allowed in your updated validation
        
        // ===== Call service =====
        FEC_GetDNBCalloutService.DNBResult res =
            FEC_GetDNBCalloutService.getDNB(req);
        
        // ===== Debug output =====
        System.debug('=== FINAL RESULT ===');
        System.debug('Success: ' + res.success);
        System.debug('Message: ' + res.errorMessage);
        System.debug('HTTP Status: ' + res.httpStatus);
        
        // ===== System layer =====
        if (res.sys2 != null) {
            System.debug('code2: ' + res.sys2.code);
            System.debug('message2: ' + res.sys2.message);
            System.debug('trans_id: ' + res.sys2.trans_id);
        }
        
        // ===== Business layer =====
        if (res.result != null) {
            System.debug('Result size: ' + res.result.size());
            
            for (FEC_GetDNBCalloutService.ResultItem item : res.result) {
                System.debug('--- ITEM ---');
                System.debug('Full name: ' + item.full_name);
                System.debug('NID: ' + item.nid);
                System.debug('Type: ' + item.type);
                System.debug('Value: ' + item.type_value);
            }
        } else {
            System.debug('Result is NULL');
        }
        return res;
    }
    
    @AuraEnabled
    public static FEC_PsDNBServiceCallout.DNBResult createDNB(
    List<Object> payload) {
        try {
            if (payload == null || payload.isEmpty()) {
                throw new AuraHandledException('Payload is empty');
            }
            
            List<FEC_PsDNBServiceCallout.DNBRequest> reqList =
                new List<FEC_PsDNBServiceCallout.DNBRequest>();
            
            for (Object obj : payload) {
                Map<Object, Object> item = (Map<Object, Object>) obj;
                
                FEC_PsDNBServiceCallout.DNBRequest req =
                    new FEC_PsDNBServiceCallout.DNBRequest();
                
                req.reason = (String) item.get('reason');
                req.full_name = (String) item.get('full_name');
                req.nid = (String) item.get('nid');
                req.do_not_bother = (Boolean) item.get('do_not_bother');
                req.type = (String) item.get('type');
                req.type_value = (String) item.get('type_value');
                req.contract_id = (String) item.get('contract_id');
                reqList.add(req);
            }
            
            // return FEC_PsDNBServiceCallout.notifyPsDNB(reqList);
            
            FEC_PsDNBServiceCallout.DNBResult result =
                FEC_PsDNBServiceCallout.notifyPsDNB(reqList);
            
            /*
             * Persist DB if success
             */
            if (result != null && Integer.valueOf(result.code) == 0) {
                saveDNBUpdates(payload);
            }
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Create DNB failed: ' + e.getMessage());
        }
    }
    
    /// Check DNB for Case
    private static FEC_GetDNBCalloutService.DNBResult checkDNB(
    String phone, String nid, String email) {
        FEC_GetDNBCalloutService.DNBRequest req =
            new FEC_GetDNBCalloutService.DNBRequest();
        
        req.phone = String.isNotBlank(phone) ? normalizePhone(phone) : '';
        
        req.nid = String.isNotBlank(nid) ? nid : '';
        
        req.email = String.isNotBlank(email) ? email : '';
        
        FEC_GetDNBCalloutService.DNBResult res =
            FEC_GetDNBCalloutService.getDNB(req);
        
        if (res == null) {
            res = new FEC_GetDNBCalloutService.DNBResult();
            
            res.success = false;
            
            res.errorMessage = 'Service returned null';
        }
        
        return res;
    }
    
    // HieuTt74 - 2026-05-17: Update fix lỗi Do Not Bother API callout + Insert
    // DNB record
    
    private static void saveDNBUpdates(List<Object> payload) {
        if (payload == null || payload.isEmpty()) {
            return;
        }
        
        Map<Id, Map<Object, Object>> payloadMap =
            new Map<Id, Map<Object, Object>>();
        
        for (Object obj : payload) {
            Map<Object, Object> item = (Map<Object, Object>) obj;
            
            String dnbId = (String) item.get('dnb_id');
            
            if (String.isBlank(dnbId)) {
                continue;
            }
            
            payloadMap.put((Id) dnbId, item);
        }
        
        if (payloadMap.isEmpty()) {
            return;
        }
        
        List<FEC_Do_Not_Bother__c> records = [

      SELECT Id, FEC_Action__c, FEC_Current_Status__c, FEC_Previous_Status__c,
      FEC_Updated_Reason__c,
      FEC_Remarks__c

          FROM FEC_Do_Not_Bother__c

              WHERE Id IN : payloadMap.keySet()
    ];
        
        List<FEC_Do_Not_Bother__c> updates = new List<FEC_Do_Not_Bother__c>();
        
        for (FEC_Do_Not_Bother__c record : records) {
            Map<Object, Object> item = payloadMap.get(record.Id);
            
            /*
             * Save previous status
             */
            record.FEC_Previous_Status__c = record.FEC_Current_Status__c;
            
            /*
             * Activate
             */
            if (record.FEC_Current_Status__c == 'Active') {
                record.FEC_Current_Status__c = 'Extend Expiry Date';
                
            } else if (record.FEC_Current_Status__c == 'Extend Expiry Date') {
                record.FEC_Current_Status__c = 'Extend Expiry Date';
            }
            
            /*
             * User action
             */
            record.FEC_Action__c = true;
            
            /*
             * User reason
             */
            String mappedReason =
                mapReasonLabel((String) item.get('reason'));
            
            record.FEC_Updated_Reason__c =
                mappedReason;
            
            /*
             * Sync original reason
             */
            record.FEC_Original_Reason__c =
                mappedReason;
            
            /*
             * Remarks
             */
            record.FEC_Remarks__c = (String) item.get('remarks');
            
            updates.add(record);
        }
        
        if (!updates.isEmpty()) {
            update updates;
        }
    }
    
    private class DNBRowTemplate {
        public String channel;
        
        public String type;
        
        public String value;
    }
    
    @AuraEnabled
    public static FEC_GetDNBCalloutService.DNBResult getDNBResultForHandling(
    String caseId) {
        FEC_GetDNBCalloutService.DNBResult finalRes;
        
        // ===== Check existing =====
        List<FEC_Do_Not_Bother__c> existingDNB = [
      SELECT Id FROM FEC_Do_Not_Bother__c WHERE FEC_Case__c = : caseId LIMIT 1
    ];
        
        // ===== Get Case =====
        List<Case> caseRecord = [
      SELECT Id, FEC_Phone_Number__c, FEC_Interaction__c,
      FEC_Interaction__r.FEC_Phone_Number__c,
      FEC_Interaction__r.FEC_Interaction_Email__c,
      FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c FROM Case WHERE
          Id = : caseId LIMIT 1
    ];
        
        // ===== Build request =====
        FEC_GetDNBCalloutService.DNBRequest req =
            new FEC_GetDNBCalloutService.DNBRequest();
        
        req.phone = String.isNotBlank(caseRecord[0].FEC_Phone_Number__c)
            ? normalizePhone(caseRecord[0].FEC_Phone_Number__c)
            : '';
        
        req.nid =
            (caseRecord[0].FEC_Account_or_Contract__r != null
            && String.isNotBlank(
            caseRecord[0]
            .FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c))
            ? caseRecord[0]
            .FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c
            : '';
        
        req.email =
            (caseRecord[0].FEC_Interaction__r != null
            && String.isNotBlank(
            caseRecord[0].FEC_Interaction__r.FEC_Interaction_Email__c))
            ? caseRecord[0].FEC_Interaction__r.FEC_Interaction_Email__c
            : '';
        
        // ===== Call API =====
        FEC_GetDNBCalloutService.DNBResult res =
            FEC_GetDNBCalloutService.getDNB(req);
        
        // ===== Ensure NOT NULL =====
        if (res == null) {
            finalRes = new FEC_GetDNBCalloutService.DNBResult();
            finalRes.success = false;
            finalRes.errorMessage = 'Service returned null';
            return finalRes;
        }
        
        // ===== FORCE VISIBILITY =====
        System.debug('===== RAW RESPONSE =====');
        System.debug(res.rawResponse);
        System.debug('===== PARSED RESULT =====');
        System.debug(JSON.serializePretty(res));
        
        // ===== If API FAIL → RETURN FULL RESPONSE (NO INSERT) =====
        if (!res.success) {
            return res; // 🔥 IMPORTANT: return as-is
        }
        
        // ===== Skip insert if already exists =====
        if (!existingDNB.isEmpty()) {
            res.errorMessage = 'DNB already exists';
            return res;
        }
        
        // ===== Business layer =====
        /*
         * Build fixed business rows
         */
        List<DNBRowTemplate> fixedRows =
            buildExistingTemplates(caseRecord[0]);
        
        /*
         * API lookup
         */
        Map<String, FEC_GetDNBCalloutService.ResultItem> apiMap =
            buildResultMap(res.result);
        
        List<FEC_Do_Not_Bother__c> dnbToInsert = new List<FEC_Do_Not_Bother__c>();
        
        for (DNBRowTemplate row : fixedRows) {
            FEC_Do_Not_Bother__c dnb = new FEC_Do_Not_Bother__c();
            
            dnb.FEC_Case__c = caseId;
            
            /*
             * Fixed mapping
             */
            dnb.FEC_DNB_Channel__c = row.channel;
            
            dnb.FEC_Type__c = row.type;
            
            dnb.FEC_Phone_Email__c = row.value;
            
            /*
             * Default workflow state
             */
            dnb.FEC_Previous_Status__c = 'Inactive';
            
            dnb.FEC_Action__c = false;
            
            dnb.FEC_Updated_Reason__c = 'Already have a loan from another company';
            
            dnb.FEC_Remarks__c = '';
            
            /*
             * Match API
             */
            String key =
                mapType(row.channel) + '_' + normalizeCompareValue(row.value);
            
            FEC_GetDNBCalloutService.ResultItem apiItem = apiMap.get(key);
            
            if (apiItem != null) {
                dnb.FEC_Current_Status__c =
                    apiItem.do_not_bother ? 'Active' : 'Inactive';
                
                dnb.FEC_Original_Reason__c = apiItem.reason;
                
                /*
                 * Expiry Date
                 */
                if (String.isNotBlank(apiItem.expected_exclude_time)
                && apiItem.expected_exclude_time != 'N/A') {
                    try {
                        dnb.FEC_Expiry_Date__c =
                            FEC_CommonUltils.parseDate(apiItem.expected_exclude_time);
                        
                    } catch (Exception e) {
                        System.debug('Date parse error: ' + e.getMessage());
                    }
                }
                
            } else {
                /*
                 * Default inactive
                 */
                dnb.FEC_Current_Status__c = 'Inactive';
            }
            
            dnbToInsert.add(dnb);
        }
        
        /*
         * Insert rows
         */
        if (!dnbToInsert.isEmpty()) {
            try {
                insert dnbToInsert;
                
            } catch (Exception e) {
                res.success = false;
                
                res.errorMessage = 'Insert failed: ' + e.getMessage();
            }
        }
        
        return res;
    }
    
    @AuraEnabled
    public static FEC_GetDNBCalloutService.DNBResult
    getDNBResultForHandlingNonExisting(String caseId, String nid) {
        FEC_GetDNBCalloutService.DNBResult finalRes;
        
        // ===== Check existing =====
        List<FEC_Do_Not_Bother__c> existingDNB = [
      SELECT Id FROM FEC_Do_Not_Bother__c WHERE FEC_Case__c = : caseId LIMIT 1
    ];
        
        // ===== Get Case =====
        List<Case> caseRecord = [
      SELECT Id, FEC_Phone_Number__c, FEC_Interaction__c,
      FEC_Interaction__r.FEC_Phone_Number__c,
      FEC_Interaction__r.FEC_Interaction_Email__c,
      FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c FROM Case WHERE
          Id = : caseId LIMIT 1
    ];
        
        // ===== Build request =====
        FEC_GetDNBCalloutService.DNBRequest req =
            new FEC_GetDNBCalloutService.DNBRequest();
        
        req.phone = String.isNotBlank(caseRecord[0].FEC_Phone_Number__c)
            ? normalizePhone(caseRecord[0].FEC_Phone_Number__c)
            : '';
        
        req.nid = nid;
        
        req.email =
            (caseRecord[0].FEC_Interaction__r != null
            && String.isNotBlank(
            caseRecord[0].FEC_Interaction__r.FEC_Interaction_Email__c))
            ? caseRecord[0].FEC_Interaction__r.FEC_Interaction_Email__c
            : '';
        
        // ===== Call API =====
        FEC_GetDNBCalloutService.DNBResult res =
            FEC_GetDNBCalloutService.getDNB(req);
        
        // ===== Ensure NOT NULL =====
        if (res == null) {
            finalRes = new FEC_GetDNBCalloutService.DNBResult();
            finalRes.success = false;
            finalRes.errorMessage = 'Service returned null';
            return finalRes;
        }
        
        // ===== FORCE VISIBILITY =====
        System.debug('===== RAW RESPONSE =====');
        System.debug(res.rawResponse);
        System.debug('===== PARSED RESULT =====');
        System.debug(JSON.serializePretty(res));
        
        // ===== If API FAIL → RETURN FULL RESPONSE (NO INSERT) =====
        if (!res.success) {
            return res; // 🔥 IMPORTANT: return as-is
        }
        
        // ===== Skip insert if already exists =====
        if (!existingDNB.isEmpty()) {
            res.errorMessage = 'DNB already exists';
            return res;
        }
        
        // ===== Business layer =====
        /*
         * Build fixed business rows
         */
        List<DNBRowTemplate> fixedRows =
            buildNonExistingTemplates(caseRecord[0]);
        
        /*
         * API lookup
         */
        Map<String, FEC_GetDNBCalloutService.ResultItem> apiMap =
            buildResultMap(res.result);
        
        List<FEC_Do_Not_Bother__c> dnbToInsert = new List<FEC_Do_Not_Bother__c>();
        
        for (DNBRowTemplate row : fixedRows) {
            FEC_Do_Not_Bother__c dnb = new FEC_Do_Not_Bother__c();
            
            dnb.FEC_Case__c = caseId;
            
            /*
             * Fixed mapping
             */
            dnb.FEC_DNB_Channel__c = row.channel;
            
            dnb.FEC_Type__c = row.type;
            
            dnb.FEC_Phone_Email__c = row.value;
            
            /*
             * Default workflow state
             */
            dnb.FEC_Previous_Status__c = 'Inactive';
            
            dnb.FEC_Action__c = false;
            
            dnb.FEC_Updated_Reason__c = 'Already have a loan from another company';
            
            dnb.FEC_Remarks__c = '';
            
            /*
             * Match API
             */
            String key =
                mapType(row.channel) + '_' + normalizeCompareValue(row.value);
            
            FEC_GetDNBCalloutService.ResultItem apiItem = apiMap.get(key);
            
            if (apiItem != null) {
                dnb.FEC_Current_Status__c =
                    apiItem.do_not_bother ? 'Active' : 'Inactive';
                
                dnb.FEC_Original_Reason__c = apiItem.reason;
                
                /*
                 * Expiry Date
                 */
                if (String.isNotBlank(apiItem.expected_exclude_time)
                && apiItem.expected_exclude_time != 'N/A') {
                    try {
                        dnb.FEC_Expiry_Date__c =
                            FEC_CommonUltils.parseDate(apiItem.expected_exclude_time);
                        
                    } catch (Exception e) {
                        System.debug('Date parse error: ' + e.getMessage());
                    }
                }
                
            } else {
                /*
                 * Default inactive
                 */
                dnb.FEC_Current_Status__c = 'Inactive';
            }
            
            dnbToInsert.add(dnb);
        }
        
        /*
         * Insert rows
         */
        if (!dnbToInsert.isEmpty()) {
            try {
                insert dnbToInsert;
                
            } catch (Exception e) {
                res.success = false;
                
                res.errorMessage = 'Insert failed: ' + e.getMessage();
            }
        }
        
        return res;
    }
    
    
    
    @AuraEnabled
    public static FEC_GetDNBCalloutService.DNBResult checkDNBExisting(
    Id caseId) {
        // ===== Get Case =====
        List<Case> caseRecords = [
      SELECT Id, FEC_Phone_Number__c,FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c,
      FEC_Interaction__r.FEC_Interaction_Email__c FROM Case WHERE
          Id = : caseId LIMIT 1
    ];
        
        Case caseRecord = caseRecords.isEmpty() ? null : caseRecords[0];
        
        // ===== Build request =====
        FEC_GetDNBCalloutService.DNBRequest req =
            new FEC_GetDNBCalloutService.DNBRequest();
        
        req.phone = String.isNotBlank(caseRecord.FEC_Phone_Number__c)
            ? normalizePhone(caseRecord.FEC_Phone_Number__c)
            : '';
        
        req.nid =  caseRecord.FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c != null
            ? caseRecord.FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c
            : '';
        
        req.email = caseRecord.FEC_Interaction__r != null && caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c != null
            ? caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c
            : '';
        
        // ===== Call API =====
        FEC_GetDNBCalloutService.DNBResult res =
            FEC_GetDNBCalloutService.getDNB(req);
        
        if (res == null) {
            res = new FEC_GetDNBCalloutService.DNBResult();
            
            res.success = false;
            
            res.errorMessage = 'Service returned null';
        }
        
        return res;
    }
    
    
    @AuraEnabled
    public static FEC_GetDNBCalloutService.DNBResult checkDNBNonExisting(
    Id caseId, String nid) {
        // ===== Get Case =====
        Case caseRecord = [
      SELECT Id, FEC_Case_Phone_Number__c,
      FEC_Interaction__r.FEC_Interaction_Email__c FROM Case WHERE
          Id = : caseId LIMIT 1
    ];
        
        // ===== Build request =====
        FEC_GetDNBCalloutService.DNBRequest req =
            new FEC_GetDNBCalloutService.DNBRequest();
        
        req.phone = String.isNotBlank(caseRecord.FEC_Case_Phone_Number__c)
            ? normalizePhone(caseRecord.FEC_Case_Phone_Number__c)
            : '';
        
        req.nid = nid;
        
        req.email = caseRecord.FEC_Interaction__r != null && caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c != null
            ? caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c
            : '';
        
        // ===== Call API =====
        FEC_GetDNBCalloutService.DNBResult res =
            FEC_GetDNBCalloutService.getDNB(req);
        
        if (res == null) {
            res = new FEC_GetDNBCalloutService.DNBResult();
            
            res.success = false;
            
            res.errorMessage = 'Service returned null';
        }
        
        return res;
    }
    
    @AuraEnabled
    public static void createDNBRowsNonExisting(
    Id caseId, String nid, String rawResult) {
        List<FEC_Do_Not_Bother__c> existing = [
      SELECT Id FROM FEC_Do_Not_Bother__c WHERE FEC_Case__c = : caseId LIMIT 1
    ];
        
        if (!existing.isEmpty()) {
            return;
        }
        
        Case caseRecord = [
      SELECT Id, FEC_Phone_Number__c, FEC_Interaction__c,
      FEC_Interaction__r.FEC_Interaction_Email__c FROM Case WHERE
          Id = : caseId LIMIT 1
    ];
        
        List<FEC_Do_Not_Bother__c> rows = new List<FEC_Do_Not_Bother__c>();
        
        /*
         * CALL
         */
        rows.add(buildNonExistingRow(
            caseId, 'Call', 'PHONE', caseRecord.FEC_Phone_Number__c));
        
        /*
         * SMS
         */
        rows.add(buildNonExistingRow(
            caseId, 'SMS', 'SMS', caseRecord.FEC_Phone_Number__c));
        
        /*
         * EMAIL
         */
        if (caseRecord.FEC_Interaction__r != null
            && String.isNotBlank(
        caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c)) {
            rows.add(buildNonExistingRow(caseId, 'Email', 'EMAIL',
            caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c));
        }
        
        insert rows;
    }
    
    private static FEC_Do_Not_Bother__c buildNonExistingRow(
    Id caseId, String channel, String type, String value) {
        FEC_Do_Not_Bother__c dnb = new FEC_Do_Not_Bother__c();
        
        dnb.FEC_Case__c = caseId;
        
        dnb.FEC_DNB_Channel__c = channel;
        
        dnb.FEC_Type__c = type;
        
        dnb.FEC_Phone_Email__c = value;
        
        dnb.FEC_Current_Status__c = 'Inactive';
        
        dnb.FEC_Previous_Status__c = 'Inactive';
        
        dnb.FEC_Action__c = false;
        
        dnb.FEC_Updated_Reason__c = 'Already have a loan from another company';
        
        dnb.FEC_Remarks__c = '';
        
        return dnb;
    }
    
    public class DNBResultWrapper {
        @AuraEnabled public Id id;
        
        @AuraEnabled public String channel;
        
        @AuraEnabled public String type;
        
        @AuraEnabled public String phoneEmail;
        
        @AuraEnabled public Boolean action;
        
        @AuraEnabled public String updatedReason;
        
        @AuraEnabled public String remarks;
    }
    
    @AuraEnabled(cacheable = false)
    public static List<DNBResultWrapper> getDNBResultTable(Id caseId) {
        List<FEC_Do_Not_Bother__c> records = [

      SELECT Id,

      FEC_DNB_Channel__c, FEC_Type__c, FEC_Phone_Email__c,

      FEC_Action__c,

      FEC_Updated_Reason__c, FEC_Remarks__c,

      /*
       * DETAIL
       */
      FEC_Previous_Status__c, FEC_Expiry_Date__c, FEC_Original_Reason__c,

      LastModifiedBy.Name,
      LastModifiedDate

          FROM FEC_Do_Not_Bother__c

              WHERE FEC_Case__c = : caseId AND FEC_Action__c = true

      ORDER BY LastModifiedDate DESC
    ];
        
        List<DNBResultWrapper> result = new List<DNBResultWrapper>();
        
        for (FEC_Do_Not_Bother__c row : records) {
            DNBResultWrapper item = new DNBResultWrapper();
            
            item.id = row.Id;
            
            item.channel = row.FEC_DNB_Channel__c;
            
            item.type = row.FEC_Type__c;
            
            item.phoneEmail = row.FEC_Phone_Email__c;
            
            item.action = row.FEC_Action__c;
            
            item.updatedReason = row.FEC_Updated_Reason__c;
            
            item.remarks = row.FEC_Remarks__c;
            
            result.add(item);
        }
        
        return result;
    }
    
    @AuraEnabled
    public static void updateFieldDoNotBother(Id caseId, String selectedOption) {
        if (caseId == null) {
            throw new AuraHandledException('Case Id is required');
        }
        /*
         * Map UI value
         */
        String dnbValue = selectedOption == 'yes' ? 'Yes' : 'No';
        
        update new Case(Id = caseId, FEC_Is_DNB__c = dnbValue);
    }
    
    @AuraEnabled
    public static Integer updateDNBProcessCount(Id caseId, Boolean isSuccess) {
        Case caseRecord = [

      SELECT Id,
      FEC_Process_Action_Count__c

          FROM Case

              WHERE Id = : caseId

                  LIMIT 1
    ];
        
        Integer count = caseRecord.FEC_Process_Action_Count__c == null
            ? 0
            : Integer.valueOf(caseRecord.FEC_Process_Action_Count__c);
        
        /*
         * SUCCESS
         */
        if (isSuccess) {
            count = 0;
            
        } else {
            count++;
        }
        
        caseRecord.FEC_Process_Action_Count__c = count;
        
        update caseRecord;
        
        return count;
    }
    
    //------------------------------------------------------------------------------------
    
    @AuraEnabled
    public static FEC_GetDNBCalloutService.DNBResult getDNBResultC360(
    String caseId) {
        FEC_GetDNBCalloutService.DNBResult finalRes;
        
        // ===== Check existing =====
        List<FEC_Do_Not_Bother__c> existingDNB = [
      SELECT Id FROM FEC_Do_Not_Bother__c WHERE FEC_Case__c = : caseId LIMIT 1
    ];
        
        // ===== Get Case =====
        Case caseRecord = [
      SELECT Id, FEC_Phone_Number__c,
      FEC_Interaction__r.FEC_Interaction_Email__c,
      FEC_Account_or_Contract__c,
      FEC_Account_or_Contract__r.FEC_Search_Result_National_ID__c FROM Case WHERE
          Id = : caseId LIMIT 1
    ];
        
        // ===== Build request =====
        FEC_GetDNBCalloutService.DNBRequest req =
            new FEC_GetDNBCalloutService.DNBRequest();
        
        req.phone = String.isNotBlank(caseRecord.FEC_Phone_Number__c)
            ? caseRecord.FEC_Phone_Number__c
            : '';
        
        req.nid = (caseRecord.FEC_Account_or_Contract__r != null
            && String.isNotBlank(caseRecord.FEC_Account_or_Contract__r
            .FEC_Search_Result_National_ID__c))
            ? caseRecord.FEC_Account_or_Contract__r.FEC_Search_Result_National_ID__c
            : '';
        
        req.email = (caseRecord.FEC_Interaction__r != null
            && String.isNotBlank(
            caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c))
            ? caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c
            : '';
        
        // ===== Call API =====
        FEC_GetDNBCalloutService.DNBResult res =
            FEC_GetDNBCalloutService.getDNB(req);
        
        // ===== Ensure NOT NULL =====
        if (res == null) {
            finalRes = new FEC_GetDNBCalloutService.DNBResult();
            finalRes.success = false;
            finalRes.errorMessage = 'Service returned null';
            return finalRes;
        }
        
        // ===== FORCE VISIBILITY =====
        System.debug('===== RAW RESPONSE =====');
        System.debug(res.rawResponse);
        System.debug('===== PARSED RESULT =====');
        System.debug(JSON.serializePretty(res));
        
        // ===== If API FAIL → RETURN FULL RESPONSE (NO INSERT) =====
        if (!res.success) {
            return res; // 🔥 IMPORTANT: return as-is
        }
        
        // ===== Skip insert if already exists =====
        if (!existingDNB.isEmpty()) {
            res.errorMessage = 'DNB already exists';
            return res;
        }
        
        // ===== Business layer =====
        if (res.result != null && !res.result.isEmpty()) {
            List<FEC_Do_Not_Bother__c> dnbToInsert = new List<FEC_Do_Not_Bother__c>();
            
            for (FEC_GetDNBCalloutService.ResultItem item : res.result) {
                FEC_Do_Not_Bother__c dnbRecord = new FEC_Do_Not_Bother__c();
                dnbRecord.FEC_Case__c = caseId;
                
                // safer boolean check
                Boolean isActive = item.do_not_bother;
                
                dnbRecord.FEC_Current_Status__c = isActive
                    ? FEC_ConstantCommon.DNB_STATUS_ACTIVE
                    : FEC_ConstantCommon.DNB_STATUS_INACTIVE;
                dnbRecord.FEC_Original_Reason__c = item.reason;
                dnbRecord.FEC_DNB_Channel__c = item.source;
                dnbRecord.FEC_Type__c = item.type;
                dnbRecord.FEC_Phone_Email__c = item.type_value;
                dnbRecord.FEC_Customer_History__c =caseRecord.FEC_Account_or_Contract__c;
                if (String.isNotBlank(item.expected_exclude_time)
                && item.expected_exclude_time != 'N/A') {
                    try {
                        dnbRecord.FEC_Expiry_Date__c =
                            FEC_CommonUltils.parseDate(item.expected_exclude_time);
                    } catch (Exception e) {
                        System.debug('Date parse error: ' + e.getMessage());
                    }
                }
                
                dnbToInsert.add(dnbRecord);
            }
            
            if (!dnbToInsert.isEmpty()) {
                try {
                    insert dnbToInsert;
                } catch (Exception e) {
                    res.errorMessage = 'Insert failed: ' + e.getMessage();
                    res.success = false;
                }
            }
        } else {
            res.errorMessage = 'No data returned from API';
        }
        
        return res;
    }
    
    @AuraEnabled
    public static List<DNBResponseItem> getListDNBs(String caseId) {
        List<DNBResponseItem> dnbList = new List<DNBResponseItem>();
        
        try {
            List<FEC_Do_Not_Bother__c> dnbRecords = [
        SELECT Id, FEC_Current_Status__c, FEC_Expiry_Date__c,
        FEC_Original_Reason__c, FEC_DNB_Channel__c, FEC_Type__c, FEC_Remarks__c,
        FEC_Phone_Email__c FROM FEC_Do_Not_Bother__c WHERE
            FEC_Case__c = : caseId
      ];
            
            for (FEC_Do_Not_Bother__c record : dnbRecords) {
                DNBResponseItem item = new DNBResponseItem();
                item.id = record.Id;
                item.doNotBother = record.FEC_Current_Status__c;
                item.expectedExcludeTime = record.FEC_Expiry_Date__c != null
                    ? String.valueOf(record.FEC_Expiry_Date__c)
                    : null;
                item.reason2 = record.FEC_Original_Reason__c;
                item.type = record.FEC_Type__c;
                item.channel = record.FEC_DNB_Channel__c;
                item.typeValue = record.FEC_Phone_Email__c;
                dnbList.add(item);
            }
            
        } catch (Exception e) {
            System.debug('Error fetching DNB records: ' + e.getMessage());
        }
        return dnbList;
    }
    
    private static String normalizePhone(String phone) {
        if (String.isBlank(phone)) {
            return null;
        }
        
        /*
         * Remove all non-digit chars
         */
        String cleaned = phone.replaceAll('[^0-9]', '');
        
        /*
         * 0xxxxxxxxx -> 84xxxxxxxxx
         */
        if (cleaned.startsWith('0')) {
            cleaned = '84' + cleaned.substring(1);
        }
        
        return cleaned;
    }
    
    private static List<DNBRowTemplate> buildExistingTemplates(Case caseRecord) {
        List<DNBRowTemplate> rows = new List<DNBRowTemplate>();
        
        String primaryPhone = normalizePhone(caseRecord.FEC_Phone_Number__c);
        
        String interactionPhone =
            normalizePhone(caseRecord.FEC_Interaction__r != null
            ? caseRecord.FEC_Interaction__r.FEC_Phone_Number__c
            : null);
        
        String interactionEmail = caseRecord.FEC_Interaction__r != null
            ? caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c
            : null;
        
        /*
         * Primary Phone - CALL
         */
        rows.add(createTemplate('Call', 'Primary Phone', primaryPhone));
        
        /*
         * Primary Phone - SMS
         */
        rows.add(createTemplate('SMS', 'Primary Phone', primaryPhone));
        
        /*
         * Interaction Phone - CALL
         */
        rows.add(createTemplate('Call', 'Interaction Phone', interactionPhone));
        
        /*
         * Interaction Phone - SMS
         */
        rows.add(createTemplate('SMS', 'Interaction Phone', interactionPhone));
        
        /*
         * Interaction Email
         */
        rows.add(createTemplate('Email', 'Interaction Email', interactionEmail));
        
        return rows;
    }
    
    private static List<DNBRowTemplate> buildNonExistingTemplates(
    Case caseRecord) {
        List<DNBRowTemplate> rows = new List<DNBRowTemplate>();
        
        String phone = normalizePhone(caseRecord.FEC_Phone_Number__c);
        
        String email = caseRecord.FEC_Interaction__r != null
            ? caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c
            : null;
        
        /*
         * CALL
         */
        rows.add(createTemplate('Call', 'Interaction Phone', phone));
        
        /*
         * SMS
         */
        rows.add(createTemplate('SMS', 'Interaction Phone', phone));
        
        /*
         * EMAIL
         */
        rows.add(createTemplate('Email', 'Interaction Email', email));
        
        
        return rows;
    }
    
    private static List<FEC_Do_Not_Bother__c> mergeDNBRows(Id caseId,
    List<DNBRowTemplate> templates,
    List<FEC_GetDNBCalloutService.ResultItem> apiResults) {
        Map<String, FEC_GetDNBCalloutService.ResultItem> apiMap =
            buildResultMap(apiResults);
        
        List<FEC_Do_Not_Bother__c> rows = new List<FEC_Do_Not_Bother__c>();
        
        /*
         * FIXED ROWS
         */
        for (DNBRowTemplate template : templates) {
            FEC_Do_Not_Bother__c row = buildFixedRow(caseId, template);
            
            String key = mapType(template.channel) + '_'
                + normalizeCompareValue(template.value);
            
            FEC_GetDNBCalloutService.ResultItem apiItem = apiMap.get(key);
            
            if (apiItem != null) {
                applyAPIData(row, apiItem);
                
                /*
                 * remove matched
                 */
                apiMap.remove(key);
            }
            
            rows.add(row);
        }
        
        /*
         * UNMATCHED ROWS
         */
        for (FEC_GetDNBCalloutService.ResultItem item : apiMap.values()) {
            rows.add(buildDynamicRow(caseId, item));
        }
        
        return rows;
    }
    
    
    private static void applyAPIData(
    FEC_Do_Not_Bother__c row, FEC_GetDNBCalloutService.ResultItem item) {
        row.FEC_Current_Status__c = item.do_not_bother ? 'Active' : 'Inactive';
        
        row.FEC_Original_Reason__c = item.reason;
        
        if (String.isNotBlank(item.expected_exclude_time)
        && item.expected_exclude_time != 'N/A') {
            try {
                row.FEC_Expiry_Date__c =
                    FEC_CommonUltils.parseDate(item.expected_exclude_time);
                
            } catch (Exception e) {
                System.debug('Date parse error: ' + e.getMessage());
            }
        }
    }
    
    private static FEC_Do_Not_Bother__c buildDynamicRow(
    Id caseId, FEC_GetDNBCalloutService.ResultItem item) {
        
        List<Case> cases = [
      SELECT Id,  FEC_Account_or_Contract__c
          FROM Case
              WHERE Id = : caseId
          LIMIT 1
    ];
        FEC_Do_Not_Bother__c row = new FEC_Do_Not_Bother__c();
        
        row.FEC_Case__c = caseId;
        
        row.FEC_DNB_Channel__c =
            mapChannel(item.type);
        
        row.FEC_Type__c = 'Insert from DB';
        
        row.FEC_Phone_Email__c = item.type_value;
        
        row.FEC_Customer_History__c = cases[0].FEC_Account_or_Contract__c;
        applyAPIData(row, item);
        
        return row;
    }
    
    @AuraEnabled
    public static void createExistingDNBRows(Id caseId) {
        /*
         * Prevent duplicate
         */
        List<FEC_Do_Not_Bother__c> existing = [
      SELECT Id FROM FEC_Do_Not_Bother__c WHERE FEC_Case__c = : caseId LIMIT 1
    ];
        
        if (!existing.isEmpty()) {
            return;
        }
        
        /*
         * Get case data
         */
        Case caseRecord = [
      SELECT Id, FEC_Phone_Number__c,

      FEC_Interaction__r.FEC_Phone_Number__c,
      FEC_Interaction__r.FEC_Interaction_Email__c,

      FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c

          FROM Case

              WHERE Id = : caseId

          LIMIT 1
    ];
        
        /*
         * Call DNB API
         */
        FEC_GetDNBCalloutService.DNBResult res = checkDNB(
            
        caseRecord.FEC_Phone_Number__c,
        
        caseRecord.FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c,
        
        caseRecord.FEC_Interaction__r != null
            ? caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c
            : null);
        
        /*
         * API FAIL
         */
        if (res == null || !res.success) {
            throw new AuraHandledException(
                
            res != null ? res.errorMessage : 'Check DNB failed');
        }
        
        /*
         * Build existing templates
         */
        List<DNBRowTemplate> templates = buildExistingTemplates(caseRecord);
        
        /*
         * Merge API + templates
         */
        List<FEC_Do_Not_Bother__c> rows = mergeDNBRows(
            
        caseId,
        
        templates,
        
        res.result);
        
        /*
         * Insert DB
         */
        if (!rows.isEmpty()) {
            insert rows;
        }
    }
    
    @AuraEnabled
    public static void createNonExistingDNBRows(Id caseId, String nid) {
        /*
         * Prevent duplicate
         */
        List<FEC_Do_Not_Bother__c> existing = [
      SELECT Id FROM FEC_Do_Not_Bother__c WHERE FEC_Case__c = : caseId LIMIT 1
    ];
        
        if (!existing.isEmpty()) {
            return;
        }
        
        /*
         * Get case data
         */
        Case caseRecord = [
      SELECT Id, FEC_Phone_Number__c,

      FEC_Interaction__r.FEC_Interaction_Email__c,
    FEC_Account_or_Contract__c
          FROM Case

              WHERE Id = : caseId

          LIMIT 1
    ];
        
        /*
         * Check DNB
         */
        FEC_GetDNBCalloutService.DNBResult res = checkDNB(
            
        caseRecord.FEC_Phone_Number__c,
        
        nid,
        
        caseRecord.FEC_Interaction__r != null
            ? caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c
            : null);
        
        /*
         * API FAIL
         */
        if (res == null || !res.success) {
            throw new AuraHandledException(
                
            res != null ? res.errorMessage : 'Check DNB failed');
        }
        
        /*
         * Build non-existing templates
         */
        List<DNBRowTemplate> templates = buildNonExistingTemplates(caseRecord);
        
        /*
         * Merge API + templates
         */
        List<FEC_Do_Not_Bother__c> rows = mergeDNBRows(
            
        caseId,
        
        templates,
        
        res.result);
        
        /*
         * Insert DB
         */
        if (!rows.isEmpty()) {
            insert rows;
        }
    }
    
    private static DNBRowTemplate createTemplate(
    String channel, String type, String value) {
        DNBRowTemplate row = new DNBRowTemplate();
        
        row.channel = channel;
        row.type = type;
        row.value = value;
        
        return row;
    }
    
    private static Map<String, FEC_GetDNBCalloutService.ResultItem>
    buildResultMap(List<FEC_GetDNBCalloutService.ResultItem> result) {
        Map<String, FEC_GetDNBCalloutService.ResultItem> mapResult =
            new Map<String, FEC_GetDNBCalloutService.ResultItem>();
        
        if (result == null) {
            return mapResult;
        }
        
        for (FEC_GetDNBCalloutService.ResultItem item : result) {
            if (item == null) {
                continue;
            }
            
            String key = item.type + '_' + normalizeCompareValue(item.type_value);
            
            mapResult.put(key, item);
        }
        
        return mapResult;
    }
    
    private static String normalizeCompareValue(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        
        /*
         * EMAIL
         */
        if (value.contains('@')) {
            return value.trim().toLowerCase();
        }
        
        /*
         * PHONE
         */
        return normalizePhone(value);
    }
    
    private static String mapType(String channel) {
        switch
        on channel {
            when 'Call' {
                return 'PHONE';
            }
            
            when 'SMS' {
                return 'SMS';
            }
            
            when 'Email' {
                return 'EMAIL';
            }
            
            when else {
                return 'PHONE';
            }
        }
    }
    
    private static String mapReasonLabel(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        
        Map<String, String> reasonMap = new Map<String, String>{
            
            'not_interested' => 'Not interested',
            
            'receiving_too_many_calls_sms_emails' =>
                'Receiving too many calls/ SMS/ Emails, ...',
            
            'already_have_a_loan_from_another_company' =>
                'Already have a loan from another company',
            
            'already_being_served_by_1_fec_employee' =>
                'Already being served by 1 FEC employee',
            
        'other_reason' => 'Other reason'};
        
        return reasonMap.containsKey(value) ? reasonMap.get(value) : value;
    }
    
    private static FEC_Do_Not_Bother__c
        buildFixedRow(
        Id caseId,
    DNBRowTemplate template
    ) {
        
        List<Case> cases = [
      SELECT Id,  FEC_Account_or_Contract__c
          FROM Case
              WHERE Id = : caseId
          LIMIT 1
    ];
        
        FEC_Do_Not_Bother__c dnb =
            new FEC_Do_Not_Bother__c();
        
        dnb.FEC_Case__c = caseId;
        
        dnb.FEC_DNB_Channel__c =
            template.channel;
        
        dnb.FEC_Type__c =
            template.type;
        
        dnb.FEC_Phone_Email__c =
            template.value;
        
        dnb.FEC_Current_Status__c =
            'Inactive';
        
        dnb.FEC_Previous_Status__c =
            'Inactive';
        
        dnb.FEC_Action__c = false;
        
        dnb.FEC_Updated_Reason__c =
            'Already have a loan from another company';
        
        dnb.FEC_Original_Reason__c =
            'already_have_a_loan_from_another_company';
        
        dnb.FEC_Remarks__c = '';
        
        dnb.FEC_Customer_History__c = cases[0].FEC_Account_or_Contract__c;
        return dnb;
    }
    
    private static String mapChannel(
        String type
    ) {
        
        if (String.isBlank(type)) {
            return 'Call';
        }
        
        switch on type.toUpperCase() {
            
            when 'PHONE' {
                return 'Call';
            }
            
            when 'SMS' {
                return 'SMS';
            }
            
            when 'EMAIL' {
                return 'Email';
            }
            
            when else {
                return 'Call';
            }
        }
    }
}