/**
 * Class Description: Controller class cung cấp các phương thức xử lý Interaction cho LWC
 * @created  : 2026/01/03 Toannd61
 * @modified :    
 */
public with sharing class FEC_InteractionController {
    
    // @AuraEnabled(cacheable=true)
    // public static List<Case> getAllInteractions(String nationalID, String primaryPhone) {
    //     try {
    //         return [
    //             SELECT Id, 
    //                 CaseNumber, FEC_ID_Search__c, FEC_Channel__c, FEC_Sub_Channel__c,
    //                    FEC_Interaction_Start_On__c, FEC_Interaction_End_On__c,
    //                    FEC_Interaction_Duration__c, CreatedBy.Name, CreatedBy.Id, FEC_Created_On__c,
    //                    Type, RecordType.Name, FEC_Final_Status__c, FEC_External_Interaction_ID__c,
    //                    FEC_Phone_Number__c, FEC_Interaction_Email__c
    //             FROM Case
    //             WHERE RecordType.DeveloperName = 'Interaction'
    //             AND FEC_National_ID_Passport_ID__c = :nationalID
    //             AND FEC_Phone_Number__c = :primaryPhone
    //             ORDER BY FEC_Created_On__c DESC
    //             LIMIT 10
    //         ];
    //     } catch (Exception e) {
    //         throw new AuraHandledException('Error retrieving interactions: ' + e.getMessage());
    //     }
    // }

    /**
     * Method Description: Lấy danh sách Interaction theo National ID và Primary Phone
     * @param nationalId National ID của khách hàng
     * @param primaryPhone Số điện thoại chính của khách hàng
     * @return List<Case> Danh sách Interaction
     * @created: 2026/01/03 Toannd61
     * @modified:  
     */
    @AuraEnabled
    public static List<Case> getInteraction(String nationalId, String primaryPhone) {
        try {
            // Query interaction records from Case object
            return [
                SELECT Id, 
                FEC_ID_Search__c, 
                FEC_Channel__c, 
                FEC_Interaction_Subchannel__c, 
                FEC_Interaction_Start_On__c,
                CreatedById,
                CreatedBy.Name,
                FEC_Interaction_Duration__c,
                FEC_Interaction_End_On__c,
                Status,
                FEC_External_Interaction_ID__c,
                FEC_Phone_Number__c,
                FEC_Interaction_Email__c
                FROM Case
                WHERE RecordType.DeveloperName = :FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME
                AND FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c = :nationalId
                AND FEC_Account_or_Contract__r.FEC_Primary_Phone__c = :primaryPhone
                ORDER BY FEC_Interaction_Start_On__c DESC
                LIMIT 10
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    
}