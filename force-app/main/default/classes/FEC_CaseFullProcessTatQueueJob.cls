/**
 * SOQL 101: cache/dedupe theo transaction, tránh query lặp khi submit NOC bulk.
 */
public without sharing class FEC_CaseFullProcessTatQueueJob implements Queueable {
    private final List<Id> caseIds;

    public FEC_CaseFullProcessTatQueueJob(Set<Id> caseIds) {
        this.caseIds = caseIds == null ? new List<Id>() : new List<Id>(caseIds);
    }

    public void execute(QueueableContext qc) {
        if (caseIds == null || caseIds.isEmpty()) {
            return;
        }
        FEC_CaseTatFullProcessSvc.syncCasesFromRoutingHistory(new Set<Id>(caseIds));
    }
}
