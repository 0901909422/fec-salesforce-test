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
                FEC_Primary_Phone__c
            FROM FEC_Customer_History__c
            WHERE Id = :historyId   
            LIMIT 1
        ];

        FEC_CustomerIntegrationService.syncCustomer(
            hist,
            cifNumber,
            phone,
            accountNumber
        );
    }
}