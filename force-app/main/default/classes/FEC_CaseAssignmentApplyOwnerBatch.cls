/**
 * Áp Owner cho Case theo từng batch transaction (Database.Batchable), tránh xích Queueable —
 * trong cùng transaction với enqueue job tiếp theo dễ cộng dồn với enqueue từ trigger Case
 * và vượt giới hạn queueable/async.
 */
public without sharing class FEC_CaseAssignmentApplyOwnerBatch implements Database.Batchable<Integer>, Database.Stateful {
    private final Id fecAssignmentId;
    private final String fecAssignmentName;
    private final Integer runNumber;
    private final List<Id> caseIds;
    private final List<Id> newOwnerIds;
    private final List<Id> summaryUserIds;
    private final List<Integer> summaryCounts;
    private Integer executeFailureCount = 0;

    public FEC_CaseAssignmentApplyOwnerBatch(
        Id fecAssignmentId,
        String fecAssignmentName,
        Integer runNumber,
        List<Id> caseIds,
        List<Id> newOwnerIds,
        List<Id> summaryUserIds,
        List<Integer> summaryCounts
    ) {
        this.fecAssignmentId = fecAssignmentId;
        this.fecAssignmentName = fecAssignmentName == null ? '' : fecAssignmentName;
        this.runNumber = runNumber;
        this.caseIds = caseIds == null ? new List<Id>() : caseIds.clone();
        this.newOwnerIds = newOwnerIds == null ? new List<Id>() : newOwnerIds.clone();
        this.summaryUserIds = summaryUserIds == null ? new List<Id>() : summaryUserIds.clone();
        this.summaryCounts = summaryCounts == null ? new List<Integer>() : summaryCounts.clone();
    }

    public Iterable<Integer> start(Database.BatchableContext bc) {
        List<Integer> indices = new List<Integer>();
        Integer n = caseIds.size();
        for (Integer i = 0; i < n; i++) {
            indices.add(i);
        }
        return indices;
    }

    public void execute(Database.BatchableContext bc, List<Integer> indexScope) {
        if (
            fecAssignmentId == null ||
            indexScope == null ||
            indexScope.isEmpty() ||
            caseIds.isEmpty()
        ) {
            return;
        }
        List<Case> batch = new List<Case>();
        try {
            for (Integer idx : indexScope) {
                if (idx == null || idx < 0 || idx >= caseIds.size()) {
                    continue;
                }
                batch.add(new Case(Id = caseIds[idx], OwnerId = newOwnerIds[idx]));
            }
            if (!batch.isEmpty()) {
                for (Case c : batch) {
                    if (c != null && c.Id != null) {
                        FEC_CaseBusinessService.registerSkipOwnerChangeRoutingHistory(c.Id);
                    }
                }
                update batch;
            }
        } catch (Exception ex) {
            executeFailureCount++;
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (fecAssignmentId == null || caseIds.isEmpty()) {
            return;
        }

        AsyncApexJob aj = [
            SELECT NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
            LIMIT 1
        ];

        Integer frameworkErrors = aj.NumberOfErrors == null ? 0 : aj.NumberOfErrors;
        if (frameworkErrors > 0 || executeFailureCount > 0) {
            return;
        }

        Map<Id, Integer> countsMap = new Map<Id, Integer>();
        Integer pairLen = summaryUserIds.size();
        Integer countLen = summaryCounts.size();
        for (Integer i = 0; i < pairLen && i < countLen; i++) {
            countsMap.put(summaryUserIds[i], summaryCounts[i]);
        }

        FEC_CaseAssignmentAutoDistributeService.insertAssignmentRunLog(
            fecAssignmentId,
            fecAssignmentName,
            runNumber,
            caseIds.size(),
            countsMap
        );
    }
}