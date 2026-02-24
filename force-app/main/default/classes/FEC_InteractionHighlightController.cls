public with sharing class FEC_InteractionHighlightController {
    
    @AuraEnabled(cacheable=true)
    public static InteractionHighlightData getInteractionHighlightData(String caseId) {
        try {
            InteractionHighlightData result = new InteractionHighlightData();
            
            Case caseRecord = [
                SELECT 
                    Id,
                    RecordType.Name,
                    FEC_Interaction__c,
                    FEC_Interaction_ID__c,
                    FEC_ID_Search__c,
                    FEC_Interaction_Status__c,
                    FEC_Channel__c,
                    FEC_Interaction_Subchannel__c,
                    FEC_Last_Updated_On__c,
                    FEC_Last_Updated_By__c,
                    FEC_Account_or_Contract__c,
                    FEC_Category__r.Name,
                    FEC_Complain_Type__c,
                    FEC_SubCategory__r.FEC_Code__c,
                    FEC_Case_Status__c,
                    FEC_Case_Created_On__c,
                    CreatedDate
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
            
            if (caseRecord == null) {
                return result;
            }
            
            // Nếu RecordType.Name khác "Interaction", lấy data từ FEC_Interaction__c
            Case interactionCase = caseRecord;
            if (caseRecord.RecordType.Name != 'Interaction' && caseRecord.FEC_Interaction__c != null) {
                List<Case> interactionCases = [
                    SELECT 
                        Id,
                        FEC_Interaction_ID__c,
                        FEC_ID_Search__c,
                        FEC_Interaction_Status__c,
                        FEC_Channel__c,
                        FEC_Interaction_Subchannel__c,
                        FEC_Last_Updated_On__c,
                        FEC_Last_Updated_By__c,
                        FEC_Account_or_Contract__c,
                        FEC_Category__r.Name,
                        FEC_Complain_Type__c,
                        FEC_SubCategory__r.FEC_Code__c,
                        FEC_Case_Status__c,
                        FEC_Case_Created_On__c,
                        CreatedDate
                    FROM Case
                    WHERE Id = :caseRecord.FEC_Interaction__c
                    LIMIT 1
                ];
                
                if (!interactionCases.isEmpty()) {
                    interactionCase = interactionCases[0];
                }
            }
            
            result.interactionId = interactionCase.FEC_Interaction_ID__c;
            result.caseId = interactionCase.Id;
            result.interactionIdSearch = interactionCase.FEC_ID_Search__c;
            if (String.isBlank(result.interactionId) && interactionCase.FEC_ID_Search__c != null) {
                result.interactionId = '<a href="/' + interactionCase.Id + '" target="_self">' + interactionCase.FEC_ID_Search__c + '</a>';
            }
            result.interactionStatus = interactionCase.FEC_Interaction_Status__c;
            result.interactionChannel = interactionCase.FEC_Channel__c;
            result.interactionSubStatus = interactionCase.FEC_Interaction_Subchannel__c;
            result.lastUpdatedOn = interactionCase.FEC_Last_Updated_On__c;
            result.lastUpdatedBy = interactionCase.FEC_Last_Updated_By__c;
            FEC_Customer_History__c customerHistory = null;
            if (interactionCase.FEC_Account_or_Contract__c != null) {
                List<FEC_Customer_History__c> histories = [
                    SELECT FEC_Customer_Name__c, FEC_National_ID_Passport_ID__c, FEC_Gender__c,
                           FEC_Date_of_Birth__c, FEC_Primary_Phone__c, FEC_Email__c, FEC_Customer_Segment__c
                    FROM FEC_Customer_History__c
                    WHERE Id = :interactionCase.FEC_Account_or_Contract__c
                    LIMIT 1
                ];
                
                if (!histories.isEmpty()) {
                    customerHistory = histories[0];
                    result.customerName = customerHistory.FEC_Customer_Name__c;
                    result.nationalId = customerHistory.FEC_National_ID_Passport_ID__c;
                    result.nationalIdMasked = FEC_CommonUltils.maskNationalIdOrPassport(customerHistory.FEC_National_ID_Passport_ID__c);
                    result.gender = customerHistory.FEC_Gender__c;
                    result.dateOfBirth = customerHistory.FEC_Date_of_Birth__c;
                    result.primaryPhone = customerHistory.FEC_Primary_Phone__c;
                    result.email = customerHistory.FEC_Email__c;
                    result.customerSegment = customerHistory.FEC_Customer_Segment__c;
                }
            }
            
            result.customerCategory = determineCustomerCategory(interactionCase, customerHistory);
            
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving interaction highlight data: ' + e.getMessage());
        }
    }
    
    private static String determineCustomerCategory(Case caseRecord, FEC_Customer_History__c customerHistory) {
        if (isSuspectedFraud(caseRecord)) return 'Suspected Fraud';
        if (isMedia(caseRecord)) return 'Media';
        if (isSeriousComplaint(caseRecord)) return 'Serious Complaint';
        if (isUnhappy(caseRecord)) return 'Unhappy';
        if (isVIP(caseRecord)) return 'VIP';
        return 'Neutral';
    }
    
    private static Boolean isSuspectedFraud(Case caseRecord) {
        if (caseRecord.FEC_Category__r?.Name != 'Complaint') return false;
        if (caseRecord.FEC_Complain_Type__c != 'Urgent' && caseRecord.FEC_Complain_Type__c != 'High Risk') return false;
        String code = caseRecord.FEC_SubCategory__r?.FEC_Code__c;
        if (code != 'CL01' && code != 'CC01') return false;
        Date createdDate = getCaseCreatedDate(caseRecord);
        if (createdDate == null || createdDate < Date.today().addMonths(-6)) return false;
        return !isExcludedStatus(caseRecord.FEC_Case_Status__c);
    }
    
    private static Boolean isMedia(Case caseRecord) {
        if (caseRecord.FEC_Category__r?.Name != 'Complaint') return false;
        if (caseRecord.FEC_Complain_Type__c != 'Urgent') return false;
        Date createdDate = getCaseCreatedDate(caseRecord);
        if (createdDate == null || createdDate < Date.today().addMonths(-3)) return false;
        return !isExcludedStatus(caseRecord.FEC_Case_Status__c);
    }
    
    private static Boolean isSeriousComplaint(Case caseRecord) {
        if (caseRecord.FEC_Category__r?.Name != 'Complaint') return false;
        if (caseRecord.FEC_Complain_Type__c != 'High Risk') return false;
        Date createdDate = getCaseCreatedDate(caseRecord);
        if (createdDate == null || createdDate < Date.today().addMonths(-3)) return false;
        return !isExcludedStatus(caseRecord.FEC_Case_Status__c);
    }
    
    private static Date getCaseCreatedDate(Case caseRecord) {
        if (caseRecord.FEC_Case_Created_On__c != null) {
            return caseRecord.FEC_Case_Created_On__c.date();
        }
        return null;
    }
    
    private static Boolean isExcludedStatus(String status) {
        if (String.isBlank(status)) return false;
        return status == 'Open' || status == 'Resolved-Cancelled' || status == 'Resolved-AutoCancelled';
    }
    
    private static Boolean isUnhappy(Case caseRecord) {
        List<String> namesToMatch = getAccountOrContractNamesToMatch(caseRecord);
        if (namesToMatch.isEmpty()) return false;
        List<FEC_Customer_Segmentation__c> segmentations = [
            SELECT Id
            FROM FEC_Customer_Segmentation__c
            WHERE Name IN :namesToMatch
            AND FEC_Customer_Segment__c = 'VIP'
            LIMIT 1
        ];
        return !segmentations.isEmpty();
    }

    private static Boolean isVIP(Case caseRecord) {
        List<String> namesToMatch = getAccountOrContractNamesToMatch(caseRecord);
        if (namesToMatch.isEmpty()) return false;
        List<FEC_Customer_Segmentation__c> segmentations = [
            SELECT Id
            FROM FEC_Customer_Segmentation__c
            WHERE Name IN :namesToMatch
            AND FEC_Survey_Points__c >= 1
            AND FEC_Survey_Points__c <= 3
            LIMIT 1
        ];
        return !segmentations.isEmpty();
    }

    private static List<String> getAccountOrContractNamesToMatch(Case caseRecord) {
        List<String> namesToMatch = new List<String>();
        if (caseRecord == null || caseRecord.FEC_Account_or_Contract__c == null) return namesToMatch;
        List<FEC_Customer_History__c> histories = [
            SELECT Name, FEC_Account_Number__c, FEC_Contract_Number__c
            FROM FEC_Customer_History__c
            WHERE Id = :caseRecord.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        if (histories.isEmpty()) return namesToMatch;
        FEC_Customer_History__c h = histories[0];
        if (String.isNotBlank(h.Name)) namesToMatch.add(h.Name);
        if (String.isNotBlank(h.FEC_Account_Number__c) && !namesToMatch.contains(h.FEC_Account_Number__c)) namesToMatch.add(h.FEC_Account_Number__c);
        if (String.isNotBlank(h.FEC_Contract_Number__c) && !namesToMatch.contains(h.FEC_Contract_Number__c)) namesToMatch.add(h.FEC_Contract_Number__c);
        return namesToMatch;
    }
    
    @AuraEnabled
    public static void logSensitiveAccess(String fieldName, Id caseId) {
        try {
            User u = [
                SELECT Username, UserRole.Name
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            
            FEC_CommonUltils.logSensitiveAccess(
                'Customer Information',
                fieldName,
                u.Username.split('@')[0],
                u.UserRole != null ? u.UserRole.Name : null,
                caseId
            );
        } catch (Exception e) {
            System.debug('Error logging sensitive access: ' + e.getMessage());
        }
    }
    
    public class InteractionHighlightData {
        @AuraEnabled public String interactionId;
        @AuraEnabled public String caseId;
        @AuraEnabled public String interactionIdSearch;
        @AuraEnabled public String customerCategory;
        @AuraEnabled public String customerName;
        @AuraEnabled public String nationalId;
        @AuraEnabled public String nationalIdMasked;
        @AuraEnabled public String gender;
        @AuraEnabled public Date dateOfBirth;
        @AuraEnabled public String primaryPhone;
        @AuraEnabled public String email;
        @AuraEnabled public String customerSegment;
        @AuraEnabled public String interactionStatus;
        @AuraEnabled public String interactionChannel;
        @AuraEnabled public String interactionSubStatus;
        @AuraEnabled public DateTime lastUpdatedOn;
        @AuraEnabled public String lastUpdatedBy;
    }
}