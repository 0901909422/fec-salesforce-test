/***
 * FEC_DNBHandler
 * Author: HieuTT74
 * Created Date: 2026-04-09 14:16:00
 */

public with sharing class FEC_DNBHandler {
    
    public class CaseInfoResponse{
        @AuraEnabled public String customerName;
        @AuraEnabled public String nationalId;
        @AuraEnabled public String primaryPhoneNumber;
        @AuraEnabled public String interactionPhoneNumber;
        @AuraEnabled public String interactionMaskedPhone;
        @AuraEnabled public String interactionEmail;
        @AuraEnabled public String interactionMaskedEmail;
        @AuraEnabled public String channel;
    }

    public class CaseInfoNonExistingResponse{
        @AuraEnabled public String customerName;
        @AuraEnabled public String nationalId;
        @AuraEnabled public String interactionPhoneNumber;
        @AuraEnabled public String interactionMaskedPhone;
        @AuraEnabled public String interactionEmail;
        @AuraEnabled public String interactionMaskedEmail;
        @AuraEnabled public String channel;
    }
    
    public class DNBResponseItem {
        @AuraEnabled public String id;
        @AuraEnabled public String doNotBother;
        @AuraEnabled public String expectedExcludeTime;
        @AuraEnabled public String reason2;
        @AuraEnabled public String type;
        @AuraEnabled public String typeValue;
    }
    
    
    @AuraEnabled
    public static CaseInfoResponse getCaseData(Id caseId) {
        // Simulate fetching data from server
        Case caseRecord =  [SELECT Id, FEC_Customer_Name__c ,FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c  ,FEC_Phone_Number__c,  FEC_Interaction__r.FEC_Phone_Number__c, FEC_Interaction__r.FEC_Interaction_Masked_Phone__c  , FEC_Interaction__r.FEC_Interaction_Email__c, FEC_Interaction__r.FEC_Interaction_Masked_Email__c, FEC_Channel__c 
                            FROM Case
                            WHERE Id = :caseId
                            LIMIT 1];
        
        CaseInfoResponse response = new CaseInfoResponse();
        response.customerName = caseRecord.FEC_Customer_Name__c;
        response.nationalId = caseRecord.FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c;
        response.primaryPhoneNumber = caseRecord.FEC_Phone_Number__c;
        response.interactionPhoneNumber = caseRecord.FEC_Interaction__r.FEC_Phone_Number__c;
        response.interactionMaskedPhone = caseRecord.FEC_Interaction__r.FEC_Interaction_Masked_Phone__c;
        response.interactionEmail = caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c;
        response.interactionMaskedEmail = caseRecord.FEC_Interaction__r.FEC_Interaction_Masked_Email__c;
        response.channel = caseRecord.FEC_Channel__c;
        return response;
        
    }


    @AuraEnabled
    public static CaseInfoNonExistingResponse getCaseNonExistingData(Id caseId) {
        // Simulate fetching data from server
        Case caseRecord =  [SELECT Id, FEC_Customer_Name__c ,FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c  ,FEC_Phone_Number__c,  FEC_Interaction__r.FEC_Phone_Number__c, FEC_Interaction__r.FEC_Interaction_Masked_Phone__c  , FEC_Interaction__r.FEC_Interaction_Email__c, FEC_Interaction__r.FEC_Interaction_Masked_Email__c, FEC_Channel__c 
                            FROM Case
                            WHERE Id = :caseId
                            LIMIT 1];
        
        CaseInfoNonExistingResponse response = new CaseInfoNonExistingResponse();
        response.customerName = caseRecord.FEC_Customer_Name__c;
        response.nationalId = caseRecord.FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c;
        response.interactionPhoneNumber = caseRecord.FEC_Interaction__r.FEC_Phone_Number__c;
        response.interactionMaskedPhone = caseRecord.FEC_Interaction__r.FEC_Interaction_Masked_Phone__c;
        response.interactionEmail = caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c;
        response.interactionMaskedEmail = caseRecord.FEC_Interaction__r.FEC_Interaction_Masked_Email__c;
        response.channel = caseRecord.FEC_Channel__c;
        return response;
        
    }
    
    
    @AuraEnabled
    public static Boolean checkDNB(Id categoryId, Id subCategoryId, Id subCodeId) {
        try {
            if (categoryId != null) {
                if ([SELECT FEC_Do_Not_Bother__c FROM FEC_Category__c WHERE Id = :categoryId LIMIT 1].FEC_Do_Not_Bother__c) {
                    return true;
                }
            }
            
            if (subCategoryId != null) {
                if ([SELECT FEC_Do_Not_Bother__c FROM FEC_Sub_Category__c WHERE Id = :subCategoryId LIMIT 1].FEC_Do_Not_Bother__c) {
                    return true;
                }
            }
            
            if (subCodeId != null) {
                if ([SELECT FEC_Do_Not_Bother__c FROM FEC_Sub_Code__c WHERE Id = :subCodeId LIMIT 1].FEC_Do_Not_Bother__c) {
                    return true;
                }
            }
            
            return false;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static FEC_GetDNBCalloutService.DNBResult getDNBResult(String caseId) {
        
        Case caseRecord = [
                SELECT 
                    Id,
                    FEC_Phone_Number__c,
                    FEC_Interaction__r.FEC_Interaction_Email__c,
                    FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1];
        
        String phoneNumber = caseRecord.FEC_Phone_Number__c;
        String email = caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c;
        String nationalId = caseRecord.FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c;
        
        // ===== Create request =====
        FEC_GetDNBCalloutService.DNBRequest req =
            new FEC_GetDNBCalloutService.DNBRequest();
        
        req.phone = phoneNumber;
        req.nid   = nationalId;
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
            System.debug('code2: ' + res.sys2.code2);
            System.debug('message2: ' + res.sys2.message2);
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
    public static FEC_PsDNBServiceCallout.DNBResult createDNB(List<Object> payload) {
        try {
            if (payload == null || payload.isEmpty()) {
                throw new AuraHandledException('Payload is empty');
            }
            
            List<FEC_PsDNBServiceCallout.DNBRequest> reqList = new List<FEC_PsDNBServiceCallout.DNBRequest>();
            
            for (Object obj : payload) {
                Map<String, Object> item = (Map<String, Object>) obj;
                
                FEC_PsDNBServiceCallout.DNBRequest req = new FEC_PsDNBServiceCallout.DNBRequest();
                
                req.reason = (String) item.get('reason');
                req.full_name = (String) item.get('full_name');
                req.nid = (String) item.get('nid');
                req.do_not_bother = (Boolean) item.get('do_not_bother');
                req.type = (String) item.get('type');
                req.type_value = (String) item.get('type_value');
                
                reqList.add(req);
            }
            
            // 🔥 CALL SERVICE
            FEC_PsDNBServiceCallout.DNBResult result =
                FEC_PsDNBServiceCallout.notifyPsDNB(reqList);
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Create DNB failed: ' + e.getMessage());
        }
    }
    
    
    
    
    
    
    
    @AuraEnabled
    public static FEC_GetDNBCalloutService.DNBResult getDNBResultC360(String caseId) {
        
        FEC_GetDNBCalloutService.DNBResult finalRes;
        
        // ===== Check existing =====
        List<FEC_Do_Not_Bother__c> existingDNB = [
        SELECT Id 
        FROM FEC_Do_Not_Bother__c 
        WHERE FEC_Case__c = :caseId
        LIMIT 1
    ];
        
        // ===== Get Case =====
        Case caseRecord = [
        SELECT 
            Id,
            FEC_Phone_Number__c,
            FEC_Interaction__r.FEC_Interaction_Email__c,
            FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
    ];
        
        // ===== Build request =====
        FEC_GetDNBCalloutService.DNBRequest req = new FEC_GetDNBCalloutService.DNBRequest();
        req.phone = caseRecord.FEC_Phone_Number__c;
        req.nid   = caseRecord.FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c;
        req.email = caseRecord.FEC_Interaction__r.FEC_Interaction_Email__c;
        
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
                Boolean isActive = false;
                if (item.do_not_bother != null) {
                    isActive = String.valueOf(item.do_not_bother) == FEC_ConstantCommon.BOOLEAN_TRUE;
                }
                
                dnbRecord.FEC_Current_Status__c = isActive ? FEC_ConstantCommon.DNB_STATUS_ACTIVE : FEC_ConstantCommon.DNB_STATUS_INACTIVE;
                dnbRecord.FEC_Original_Reason__c = item.reason2;
                dnbRecord.FEC_DNB_Channel__c = item.type;
                dnbRecord.FEC_Phone_Email__c = item.type_value;
                
                if (item.expected_exclude_time != null) {
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
                SELECT Id,
                    FEC_Current_Status__c,
                    FEC_Expiry_Date__c,
                    FEC_Original_Reason__c,
                    FEC_DNB_Channel__c,
                    FEC_Phone_Email__c
                FROM FEC_Do_Not_Bother__c
                WHERE FEC_Case__c = :caseId
            ];
            
            for (FEC_Do_Not_Bother__c record : dnbRecords) {
                DNBResponseItem item = new DNBResponseItem();
                item.id = record.Id;
                item.doNotBother = record.FEC_Current_Status__c;
                item.expectedExcludeTime = record.FEC_Expiry_Date__c != null ? String.valueOf(record.FEC_Expiry_Date__c) : null;
                item.reason2 = record.FEC_Original_Reason__c;
                item.type = record.FEC_DNB_Channel__c;
                item.typeValue = record.FEC_Phone_Email__c;
                dnbList.add(item);
            }
            
        } catch (Exception e) {
            System.debug('Error fetching DNB records: ' + e.getMessage());
        }
        return dnbList;
        
    }
    
}