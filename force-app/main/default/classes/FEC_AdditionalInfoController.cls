/**
 * @description Controller để truy vấn dữ liệu từ FEC_Additional_Info__c.
 * Cung cấp dữ liệu cho LWC tab Additional Info trong fecMasterData.
 */
public with sharing class FEC_AdditionalInfoController {

    /**
     * @description Lấy danh sách bản ghi FEC_Additional_Info__c, sắp xếp theo CreatedDate giảm dần, tối đa 200 bản ghi.
     * Áp dụng FLS enforcement bằng Security.stripInaccessible.
     * @return List<FEC_Additional_Info__c>
     */
    @AuraEnabled(cacheable=true)
    public static List<FEC_Additional_Info__c> getAdditionalInfoRecords() {
        List<FEC_Additional_Info__c> records = [
            SELECT Name,
                   FEC_Case__c,
                   FEC_Case__r.CaseNumber,
                   FEC_Callback__c,
                   FEC_Callback_Reason__c,
                   FEC_Card_Not_Received_Reason__c,
                   FEC_Card_Retention_Decline_Reason__c,
                   FEC_Delivery_Msg_Received__c,
                   FEC_Dissatisfaction_Reason_1__c,
                   FEC_Dissatisfaction_Reason_2__c,
                   FEC_Gender__c,
                   FEC_Q9_Customer_Issue_Resolved__c,
                   FEC_Q10_Reason_Issue_Not_Resolved__c,
                   FEC_Q11_Staff_Support_Enthusiasm__c,
                   FEC_Q12_Reason_Low_Staff_Enthusiasm__c,
                   FEC_Q13_Staff_Support_Satisfaction__c,
                   FEC_Q13_Reason_for_Low_Rating__c,
                   FEC_Q14_Reason_for_Office_Visit__c,
                   FEC_Q15_NPS_Score__c,
                   FEC_Q16_BOT_Dissatisfaction_Reason__c,
                   FEC_Q17_Dissatisfied_Process_Service__c,
                   FEC_Q18_Staff_Dissatisfaction_Reason__c,
                   FEC_Q19_Staff_Type__c,
                   FEC_Q20_CS_Staff_Dissatisfaction_Reason__c,
                   FEC_Q20_Survey_Refusal_Reason__c,
                   FEC_Q21_Recommendation_Likelihood__c,
                   FEC_Q22_Improvement_Suggestions__c,
                   FEC_Q23_Satisfaction_Level__c,
                   FEC_Q24_Collections_Feedback__c,
                   FEC_Q25_Sales_Improvement_1__c,
                   FEC_Q26_Sales_Improvement_2__c,
                   FEC_Q27_Sales_Improvement_3__c,
                   FEC_Q28_UW_Improvement__c,
                   FEC_Q29_Spending_Increase_Suggestion__c,
                   FEC_Reason_Decline_IPP_Conversion__c,
                   FEC_Settlement_Request_Category__c,
                   FEC_Sync_Error__c,
                   FEC_Unmet_Need_Reason__c,
                   FEC_Verify_Information__c,
                   FEC_Correct_Customer_Full_Name__c,
                   FEC_Incorrect_Customer_Full_Name__c,
                   FEC_New_Citizen_ID_Number__c,
                   FEC_New_Place_of_Issue__c,
                   FEC_Old_Citizen_ID_Number__c,
                   FEC_Old_Place_of_Issue__c,
                   FEC_Registered_Phone_Number__c,
                   FEC_Correct_Date_of_Birth__c,
                   FEC_Incorrect_Date_of_Birth__c,
                   FEC_New_Issue_Date__c,
                   FEC_Old_Issue_Date__c,
                   FEC_Update_Reason__c,
                   CreatedDate
            FROM FEC_Additional_Info__c
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];

        return (List<FEC_Additional_Info__c>) Security.stripInaccessible(
            AccessType.READABLE, records
        ).getRecords();
    }

    /**
     * @description Xóa bản ghi FEC_Additional_Info__c theo Id.
     * Kiểm tra quyền xóa trước khi thực hiện DML.
     * @param recordId Id của bản ghi cần xóa
     */
    @AuraEnabled
    public static void deleteRecord(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is required');
        }

        if (!Schema.sObjectType.FEC_Additional_Info__c.isDeletable()) {
            throw new AuraHandledException('Insufficient permissions to delete');
        }

        try {
            delete [SELECT Id FROM FEC_Additional_Info__c WHERE Id = :recordId];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}