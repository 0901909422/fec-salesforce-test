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
 
****************************************************************************************/

public with sharing class FEC_FullCustomerIntegrationJob 
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
                   FEC_National_ID_Passport_ID__c
            FROM FEC_Customer_History__c
            WHERE Id = :historyId
            LIMIT 1
        ];

        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(hist, cifNumber, phone, accountNumber);
           
        hist.FEC_Customer_Name__c         = result.customerName;
        hist.FEC_National_ID_Passport_ID__c = result.nationalId;
        hist.FEC_Gender__c                = result.gender;
        hist.FEC_Date_of_Birth__c         = result.dateOfBirth;
        hist.FEC_Primary_Phone__c         = result.primaryPhone;
        hist.FEC_Email__c                 = result.emailAddress;
        update hist;

        // 15/04/2026 PhuongNT add
        List<Case> cases = [SELECT Id FROM Case WHERE FEC_Account_or_Contract__c = :historyId];
        if (!cases.isEmpty()) {
            for (Case c : cases) {
                c.FEC_Recipient_Name__c = result.customerName;
                c.FEC_Phone_Number__c = result.primaryPhone;
                c.FEC_Recipient_Phone_Number__c = result.primaryPhone;
            }
            FEC_CaseTriggerHandler.isExecuting = true;
            update cases;
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }
}