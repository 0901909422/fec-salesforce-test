/****************************************************************************************
 * File Name    : FEC_FullCustomerIntegrationJob.Apex
 * Author       : Quangdv7
 * Date         : 2026-03-30
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-03-30     Quangdv7             Create
   ===============================================================\
   2.0      2026-05-06     LongNH76             Update
 
****************************************************************************************/

public without sharing class FEC_FullCustomerIntegrationJob 
implements Queueable, Database.AllowsCallouts {

    private Id historyId;
    private String cifNumber;
    private String phone;
    private String accountNumber;

    public FEC_FullCustomerIntegrationJob(
        Id historyId, String cifNumber, String phone, String accountNumber
    ) {
        this.historyId = historyId;
        this.cifNumber = cifNumber;
        this.phone = phone;
        this.accountNumber = accountNumber;
    }

    public void execute(QueueableContext context) {

         FEC_Customer_History__c hist = [
            SELECT Id,
                   FEC_CIF_Number__c,
                   FEC_Account_Number__c,
                   FEC_Email__c,
                   FEC_Primary_Phone__c,
                   FEC_Customer_Name__c,
                   FEC_Date_of_Birth__c,
                   FEC_Gender__c,
                   FEC_National_ID_Passport_ID__c,
                   FEC_Plastic_ID__c
            FROM FEC_Customer_History__c
            WHERE Id = :historyId
            LIMIT 1
        ];

        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(hist, cifNumber, phone, accountNumber);

        // Old behavior (kept for reference):
        // hist.FEC_Customer_Name__c = result.customerName;
        // hist.FEC_National_ID_Passport_ID__c = result.nationalId;
        // hist.FEC_Gender__c = result.gender;
        // hist.FEC_Date_of_Birth__c = result.dateOfBirth;
        // hist.FEC_Primary_Phone__c = result.primaryPhone;
        // hist.FEC_Email__c = result.emailAddress;
        // hist.FEC_Plastic_ID__c = result.plasticID;

        // [CHANGE][Author : LongNH76] Null-safe update: chỉ ghi đè khi integration trả dữ liệu hợp lệ,
        // để không làm mất dữ liệu đã có trên Customer History ngay sau khi createHistory.
        if (result != null) {
            if (String.isNotBlank(result.customerName)) {
                hist.FEC_Customer_Name__c = result.customerName;
            }
            // if (String.isNotBlank(result.nationalId)) {
            //     hist.FEC_National_ID_Passport_ID__c = result.nationalId;
            // }
            if (String.isNotBlank(result.gender)) {
                hist.FEC_Gender__c = result.gender;
            }
            if (result.dateOfBirth != null) {
                hist.FEC_Date_of_Birth__c = result.dateOfBirth;
            }
            if (String.isNotBlank(result.primaryPhone)) {
                hist.FEC_Primary_Phone__c = result.primaryPhone;
            }
            if (String.isNotBlank(result.emailAddress)) {
                hist.FEC_Email__c = result.emailAddress;
            }
            if (String.isNotBlank(result.plasticID)) {
                hist.FEC_Plastic_ID__c = result.plasticID;
            }
        }
        update hist;

        // 15/04/2026 PhuongNT add
        List<Case> cases = [SELECT Id FROM Case WHERE FEC_Account_or_Contract__c = :historyId];
        if (!cases.isEmpty()) {
            for (Case c : cases) {
                // Old behavior (kept for reference):
                // c.FEC_Recipient_Name__c = result.customerName;
                // c.FEC_Phone_Number__c = result.primaryPhone;
                // c.FEC_Recipient_Phone_Number__c = result.primaryPhone;

                // [CHANGE][Author : LongNH76] Case sync cũng null-safe để tránh clear tên/SĐT khi API demographic trả rỗng.
                if (result != null && String.isNotBlank(result.customerName)) {
                    c.FEC_Recipient_Name__c = result.customerName;
                }
                if (result != null && String.isNotBlank(result.primaryPhone)) {
                    c.FEC_Phone_Number__c = result.primaryPhone;
                    c.FEC_Recipient_Phone_Number__c = result.primaryPhone;
                }
            }
            FEC_CaseTriggerHandler.isExecuting = true;
            update cases;
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }
}