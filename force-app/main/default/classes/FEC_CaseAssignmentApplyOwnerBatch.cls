/**
 * Áp kết quả phân bổ Case Assignment theo từng batch transaction.
 * Hỗ trợ đổi Case Owner (không có Assignment) hoặc FEC_Assignment_Owner__c (có Assignment).
 */
public without sharing class FEC_CaseAssignmentApplyOwnerBatch implements Database.Batchable<Integer>, Database.Stateful {
    private final Id fecAssignmentId;
    private final String fecAssignmentName;
    private final Integer runNumber;
    private final List<Id> caseIds;
    private final List<Id> assignedUserIds;
    private final List<Boolean> updateCaseOwnerFlags;
    private final List<Id> assignmentIds;
    private final List<Id> summaryUserIds;
    private final List<Integer> summaryCounts;
    private Integer executeFailureCount = 0;

    public FEC_CaseAssignmentApplyOwnerBatch(
        Id fecAssignmentId,
        String fecAssignmentName,
        Integer runNumber,
        List<Id> caseIds,
        List<Id> assignedUserIds,
        List<Boolean> updateCaseOwnerFlags,
        List<Id> assignmentIds,
        List<Id> summaryUserIds,
        List<Integer> summaryCounts
    ) {
        this.fecAssignmentId = fecAssignmentId;
        this.fecAssignmentName = fecAssignmentName == null ? '' : fecAssignmentName;
        this.runNumber = runNumber;
        this.caseIds = caseIds == null ? new List<Id>() : caseIds.clone();
        this.assignedUserIds = assignedUserIds == null ? new List<Id>() : assignedUserIds.clone();
        this.updateCaseOwnerFlags = updateCaseOwnerFlags == null
            ? new List<Boolean>()
            : updateCaseOwnerFlags.clone();
        this.assignmentIds = assignmentIds == null ? new List<Id>() : assignmentIds.clone();
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

        List<DistributionTargetStub> batchTargets = new List<DistributionTargetStub>();
        try {
            for (Integer idx : indexScope) {
                if (idx == null || idx < 0 || idx >= caseIds.size()) {
                    continue;
                }
                Id caseId = caseIds[idx];
                Id assignedUserId = idx < assignedUserIds.size() ? assignedUserIds[idx] : null;
                if (caseId == null || assignedUserId == null) {
                    continue;
                }
                Boolean updateCaseOwner = idx < updateCaseOwnerFlags.size()
                    ? updateCaseOwnerFlags[idx]
                    : true;
                Id assignmentId = idx < assignmentIds.size() ? assignmentIds[idx] : null;
                batchTargets.add(
                    new DistributionTargetStub(caseId, assignedUserId, updateCaseOwner, assignmentId)
                );
            }
            if (!batchTargets.isEmpty()) {
                FEC_CaseAssignmentAutoDistributeService.applyDistributionResultsFromBatch(
                    fecAssignmentId,
                    batchTargets
                );
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

    public class DistributionTargetStub {
        public Id caseId;
        public Id assignedUserId;
        public Boolean updateCaseOwner;
        public Id assignmentRecordId;

        public DistributionTargetStub(
            Id caseId,
            Id assignedUserId,
            Boolean updateCaseOwner,
            Id assignmentRecordId
        ) {
            this.caseId = caseId;
            this.assignedUserId = assignedUserId;
            this.updateCaseOwner = updateCaseOwner;
            this.assignmentRecordId = assignmentRecordId;
        }
    }
}
