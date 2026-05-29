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
   ===============================================================
   2.0      2026-05-06     LongNH76             Update
 
****************************************************************************************/

public with sharing class FEC_FullCustomerIntegrationJob
    implements Queueable, Database.AllowsCallouts {

    private static final Integer MAX_SYNCS_PER_RUN = 200;

    public class SyncRequest {
        public Id historyId;
        public String cifNumber;
        public String phone;
        public String accountNumber;

        public SyncRequest(
            Id historyId,
            String cifNumber,
            String phone,
            String accountNumber
        ) {
            this.historyId = historyId;
            this.cifNumber = cifNumber;
            this.phone = phone;
            this.accountNumber = accountNumber;
        }
    }

    private Id historyId;
    private String cifNumber;
    private String phone;
    private String accountNumber;
    private List<SyncRequest> syncRequests;

    public FEC_FullCustomerIntegrationJob(
        Id historyId,
        String cifNumber,
        String phone,
        String accountNumber
    ) {
        this.historyId = historyId;
        this.cifNumber = cifNumber;
        this.phone = phone;
        this.accountNumber = accountNumber;
    }

    public FEC_FullCustomerIntegrationJob(List<SyncRequest> syncRequests) {
        this.syncRequests = syncRequests;
    }

    public void execute(QueueableContext context) {
        if (syncRequests != null && !syncRequests.isEmpty()) {
            Map<Id, SyncRequest> uniqueByHistoryId = new Map<Id, SyncRequest>();
            for (SyncRequest req : syncRequests) {
                if (req != null && req.historyId != null) {
                    uniqueByHistoryId.put(req.historyId, req);
                }
            }

            List<SyncRequest> toProcess = uniqueByHistoryId.values();
            if (toProcess.isEmpty()) {
                return;
            }

            syncOne(toProcess[0]);

            List<SyncRequest> deferred = new List<SyncRequest>();
            for (Integer i = 1; i < toProcess.size(); i++) {
                deferred.add(toProcess[i]);
            }
            if (!deferred.isEmpty()) {
                System.enqueueJob(new FEC_FullCustomerIntegrationJob(deferred));
            }
            return;
        }

        syncOne(
            new SyncRequest(historyId, cifNumber, phone, accountNumber)
        );
    }

    private void syncOne(SyncRequest req) {
        if (req == null || req.historyId == null) {
            return;
        }

        FEC_Customer_History__c hist =
            FEC_CustomerIntegrationService.queryHistoryForSync(req.historyId);

        FEC_CustomerIntegrationService.ResultDTO result =
            FEC_CustomerIntegrationService.syncCustomer(
                hist,
                req.cifNumber,
                req.phone,
                req.accountNumber
            );

        if (result != null) {
            if (String.isNotBlank(result.customerName)) {
                hist.FEC_Customer_Name__c = result.customerName;
            }
            if (String.isNotBlank(result.nationalId)) {
                hist.FEC_National_ID_Passport_ID__c = result.nationalId;
            }
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
        List<Case> cases = [
            SELECT Id
            FROM Case
            WHERE FEC_Account_or_Contract__c = :req.historyId
        ];
        if (!cases.isEmpty()) {
            for (Case c : cases) {
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