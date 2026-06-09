// Service bulk — cập nhật FEC_Assignment__c khi Assignment Routing Action = Resolve/Reject (Import COF/GSR).
public with sharing class FEC_BCH_AssignmentResolveRejectService {

    public class ImportResolveRejectItem {
        public FEC_BatchCaseHandlingImportRow row;
        public Id caseId;
        public Id assignmentId;
        public String methodKey;
    }

    public class ResolveRejectContext {
        public Id caseId;
        public Id assignmentId;
        public Datetime submittedOn;
    }

    public class ApplyResult {
        public Id assignmentId;
        public Boolean success;
        public String errorMessage;

        public ApplyResult(Id assignmentId) {
            this.assignmentId = assignmentId;
            this.success = false;
        }
    }

    public static Boolean isResolveOrRejectMethodKey(String methodKey) {
        if (String.isBlank(methodKey)) {
            return false;
        }
        return methodKey == FEC_CaseBusinessService.RESOLVE
            || methodKey == FEC_CaseBusinessService.REJECT;
    }

    public static void collectFromImportRow(
        FEC_BatchCaseHandlingImportRow rr,
        Boolean cofOrGsr,
        Boolean assignmentOnly,
        Id caseId,
        Id assignmentRecordId,
        String methodKey,
        List<ImportResolveRejectItem> resolveRejectItems
    ) {
        if (rr == null ||
            cofOrGsr != true ||
            assignmentOnly != true ||
            assignmentRecordId == null ||
            caseId == null ||
            resolveRejectItems == null ||
            !isResolveOrRejectMethodKey(methodKey)) {
            return;
        }
        ImportResolveRejectItem item = new ImportResolveRejectItem();
        item.row = rr;
        item.caseId = caseId;
        item.assignmentId = assignmentRecordId;
        item.methodKey = methodKey;
        resolveRejectItems.add(item);
    }

    public static void applyImportBulk(List<ImportResolveRejectItem> resolveRejectItems) {
        if (resolveRejectItems == null || resolveRejectItems.isEmpty()) {
            return;
        }
        List<ResolveRejectContext> contexts = new List<ResolveRejectContext>();
        Map<Id, List<ImportResolveRejectItem>> rowsByAssignmentId = new Map<Id, List<ImportResolveRejectItem>>();
        for (ImportResolveRejectItem item : resolveRejectItems) {
            if (item == null || item.assignmentId == null || item.caseId == null || item.row == null) {
                continue;
            }
            ResolveRejectContext ctx = new ResolveRejectContext();
            ctx.caseId = item.caseId;
            ctx.assignmentId = item.assignmentId;
            ctx.submittedOn = System.now();
            contexts.add(ctx);
            if (!rowsByAssignmentId.containsKey(item.assignmentId)) {
                rowsByAssignmentId.put(item.assignmentId, new List<ImportResolveRejectItem>());
            }
            rowsByAssignmentId.get(item.assignmentId).add(item);
        }
        if (contexts.isEmpty()) {
            return;
        }
        List<ApplyResult> results = applyResolveRejectAssignmentsBulk(contexts);
        for (ApplyResult result : results) {
            if (result == null || result.success == true || result.assignmentId == null) {
                continue;
            }
            if (!rowsByAssignmentId.containsKey(result.assignmentId)) {
                continue;
            }
            for (ImportResolveRejectItem item : rowsByAssignmentId.get(result.assignmentId)) {
                if (item == null || item.row == null) {
                    continue;
                }
                item.row.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                item.row.errors = appendImportError(item.row.errors, result.errorMessage);
            }
        }
    }

    public static List<ApplyResult> applyResolveRejectAssignmentsBulk(List<ResolveRejectContext> contexts) {
        List<ApplyResult> results = new List<ApplyResult>();
        if (contexts == null || contexts.isEmpty()) {
            return results;
        }

        Id currentUserId = UserInfo.getUserId();
        Map<Id, ResolveRejectContext> ctxByAssignmentId = new Map<Id, ResolveRejectContext>();
        Set<Id> caseIdsToSync = new Set<Id>();

        for (ResolveRejectContext ctx : contexts) {
            ApplyResult rowResult = new ApplyResult(ctx == null ? null : ctx.assignmentId);
            results.add(rowResult);
            if (ctx == null || ctx.assignmentId == null || ctx.caseId == null) {
                rowResult.errorMessage = 'Thiếu Case Id hoặc Assignment Id.';
                continue;
            }
            ctxByAssignmentId.put(ctx.assignmentId, ctx);
            caseIdsToSync.add(ctx.caseId);
        }

        if (ctxByAssignmentId.isEmpty()) {
            return results;
        }

        List<FEC_Assignment__c> assignmentUpdates = new List<FEC_Assignment__c>();
        Map<Id, ApplyResult> resultByAssignmentId = new Map<Id, ApplyResult>();
        for (ApplyResult r : results) {
            if (r.assignmentId != null) {
                resultByAssignmentId.put(r.assignmentId, r);
            }
        }

        for (Id assignmentId : ctxByAssignmentId.keySet()) {
            ResolveRejectContext ctx = ctxByAssignmentId.get(assignmentId);
            ApplyResult rowResult = resultByAssignmentId.get(assignmentId);
            if (ctx == null || rowResult == null) {
                continue;
            }
            Datetime submitTs = ctx.submittedOn == null ? System.now() : ctx.submittedOn;
            assignmentUpdates.add(new FEC_Assignment__c(
                Id = assignmentId,
                FEC_Assignment_Owner__c = currentUserId,
                FEC_Submitted_On__c = submitTs,
                FEC_Team__c = null,
                FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_COMPLETED
            ));
        }

        if (assignmentUpdates.isEmpty()) {
            return results;
        }

        Database.SaveResult[] saveResults = Database.update(assignmentUpdates, false);
        for (Integer i = 0; i < saveResults.size(); i++) {
            FEC_Assignment__c row = assignmentUpdates[i];
            ApplyResult rowResult = resultByAssignmentId.get(row.Id);
            if (rowResult == null) {
                continue;
            }
            if (saveResults[i].isSuccess()) {
                rowResult.success = true;
                rowResult.errorMessage = null;
            } else {
                rowResult.errorMessage = saveResults[i].getErrors().isEmpty()
                    ? 'Cập nhật Assignment Resolve/Reject thất bại.'
                    : saveResults[i].getErrors()[0].getMessage();
            }
        }

        syncAssignmentUsersForCases(caseIdsToSync);
        return results;
    }

    private static void syncAssignmentUsersForCases(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return;
        }
        List<FEC_Assignment__c> activeAssignments = [
            SELECT Id, FEC_Case__c, FEC_Assignment_Owner__c, FEC_OwnerID__c
            FROM FEC_Assignment__c
            WHERE FEC_Case__c IN :caseIds
            AND FEC_Assignment_Status__c NOT IN :FEC_ConstantCommon.CLOSED_ASSIGNMENT_STATUSES
        ];
        Map<Id, List<String>> userValuesByCaseId = new Map<Id, List<String>>();
        Set<Id> queueIdsToResolve = new Set<Id>();
        for (FEC_Assignment__c a : activeAssignments) {
            if (a == null || a.FEC_Case__c == null) {
                continue;
            }
            if (!userValuesByCaseId.containsKey(a.FEC_Case__c)) {
                userValuesByCaseId.put(a.FEC_Case__c, new List<String>());
            }
            if (a.FEC_Assignment_Owner__c != null) {
                userValuesByCaseId.get(a.FEC_Case__c).add(String.valueOf(a.FEC_Assignment_Owner__c));
                continue;
            }
            if (String.isBlank(a.FEC_OwnerID__c)) {
                continue;
            }
            String ownerIdStr = a.FEC_OwnerID__c.trim();
            Boolean looksLikeId = ownerIdStr.length() >= 15 &&
                ownerIdStr.startsWith(FEC_ConstantCommon.QUEUE_ID_START);
            if (looksLikeId) {
                try {
                    queueIdsToResolve.add((Id) ownerIdStr);
                } catch (Exception ex) {
                    userValuesByCaseId.get(a.FEC_Case__c).add(ownerIdStr);
                }
            } else {
                userValuesByCaseId.get(a.FEC_Case__c).add(ownerIdStr);
            }
        }
        Map<Id, String> queueNameById = new Map<Id, String>();
        if (!queueIdsToResolve.isEmpty()) {
            for (Group q : [
                SELECT Id, Name
                FROM Group
                WHERE Id IN :queueIdsToResolve
                AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            ]) {
                if (q != null) {
                    queueNameById.put(q.Id, q.Name);
                }
            }
        }
        for (FEC_Assignment__c a : activeAssignments) {
            if (a == null || a.FEC_Case__c == null || a.FEC_Assignment_Owner__c != null || String.isBlank(a.FEC_OwnerID__c)) {
                continue;
            }
            String ownerIdStr = a.FEC_OwnerID__c.trim();
            try {
                Id queueId = (Id) ownerIdStr;
                if (queueNameById.containsKey(queueId)) {
                    userValuesByCaseId.get(a.FEC_Case__c).add(queueNameById.get(queueId));
                }
            } catch (Exception ex) {
                // already added as plain string
            }
        }
        List<Case> casesToUpdate = new List<Case>();
        for (Id caseId : caseIds) {
            List<String> values = userValuesByCaseId.get(caseId);
            String joined = values == null || values.isEmpty() ? null : String.join(values, ',');
            casesToUpdate.add(new Case(Id = caseId, FEC_Assignment_Users__c = joined));
        }
        if (!casesToUpdate.isEmpty()) {
            Database.update(casesToUpdate, false);
        }
    }

    private static String appendImportError(String existing, String message) {
        if (String.isBlank(message)) {
            return existing;
        }
        return String.isBlank(existing) ? message : existing + '; ' + message;
    }
}
