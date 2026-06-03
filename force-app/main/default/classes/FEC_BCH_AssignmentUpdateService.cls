//PhongBT 29/05/26: Service bulk — cập nhật FEC_Assignment__c khi Assignment Routing Action "Update to …" (Import COF/GSR).
//PhongBT 29/05/26: Logic đồng bộ FEC_AssignmentRoutingActionHandler.handleUpdate (decision từ label Update to).
public with sharing class FEC_BCH_AssignmentUpdateService {

    public class UpdateContext {
        public Id caseId;
        public Id assignmentId;
        public String decision;
    }

    //PhongBT 29/05/26: Payload 1 dòng import — Assignment Update to (vd Update to Pending Product).
    public class ImportUpdateItem {
        public FEC_BatchCaseHandlingImportRow row;
        public Id caseId;
        public Id assignmentId;
        public String decision;
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

    private static final Set<String> QUEUE_DECISIONS = new Set<String>{
        FEC_ConstantCommon.DECISION_OUT_OF_PROCESS,
        FEC_ConstantCommon.DECISION_CIC_RELATED,
        FEC_ConstantCommon.DECISION_DOCUMENT_PREP,
        FEC_ConstantCommon.DECISION_TASK_UNDER_REVIEW
    };

    //PhongBT 29/05/26: Chuẩn hóa label Excel / Stage Screen → decision key (vd Pending Product, Pending Contract Processing).
    public static String resolveDecisionLabel(String rawDecision) {
        if (String.isBlank(rawDecision)) {
            return null;
        }
        String trimmed = rawDecision.trim();
        if (FEC_ConstantCommon.decisionToTeamMap.containsKey(trimmed)) {
            return trimmed;
        }
        for (String key : FEC_ConstantCommon.decisionToTeamMap.keySet()) {
            if (key != null && key.equalsIgnoreCase(trimmed)) {
                return key;
            }
        }
        if (trimmed.equalsIgnoreCase(FEC_ConstantCommon.DECISION_CANNOT_CONTACT)) {
            return FEC_ConstantCommon.DECISION_CANNOT_CONTACT;
        }
        for (String queueDecision : QUEUE_DECISIONS) {
            if (queueDecision.equalsIgnoreCase(trimmed)) {
                return queueDecision;
            }
        }
        Map<String, String> aliases = new Map<String, String>{
            'contractprocessing' => 'Pending Contract Processing',
            'pendingcontractprocessing' => 'Pending Contract Processing',
            'product' => 'Pending Product',
            'pendingproduct' => 'Pending Product'
        };
        String aliasKey = normalizeToken(trimmed);
        if (aliases.containsKey(aliasKey)) {
            return aliases.get(aliasKey);
        }
        return trimmed;
    }

    //PhongBT 29/05/26: Gom 1 dòng import COF/GSR có assignmentRoutingAction = Update to …
    public static void collectFromImportRow(
        FEC_BatchCaseHandlingImportRow rr,
        Boolean cofOrGsr,
        Id caseId,
        Id stageId,
        Id assignmentRecordId,
        List<ImportUpdateItem> assignmentUpdateItems
    ) {
        if (rr == null ||
            cofOrGsr != true ||
            assignmentRecordId == null ||
            caseId == null ||
            assignmentUpdateItems == null) {
            return;
        }
        //PhongBT 02/06/26: Sửa routing action cho cof/gsr — Update từ Routing Action hoặc Assignment Routing Action.
        String routingLabel = String.isNotBlank(rr.assignmentRoutingAction)
            ? rr.assignmentRoutingAction.trim()
            : (String.isNotBlank(rr.routingAction) ? rr.routingAction.trim() : null);
        if (String.isBlank(routingLabel)) {
            return;
        }
        FEC_BCH_ImportRoutingResolver.ResolvedRouting resolvedRouting =
            FEC_BCH_ImportRoutingResolver.resolve(stageId, routingLabel, true);
        String methodKey = resolvedRouting != null && String.isNotBlank(resolvedRouting.methodKey)
            ? resolvedRouting.methodKey
            : resolveUpdateMethodKeyFromLabel(routingLabel);
        if (methodKey != FEC_CaseBusinessService.UPDATEACTION) {
            return;
        }
        String decision = resolvedRouting == null ? null : resolvedRouting.decision;
        if (String.isBlank(decision)) {
            decision = extractDecisionFromUpdateLabel(routingLabel);
        }
        decision = resolveDecisionLabel(decision);
        if (String.isBlank(decision)) {
            return;
        }
        ImportUpdateItem item = new ImportUpdateItem();
        item.row = rr;
        item.caseId = caseId;
        item.assignmentId = assignmentRecordId;
        item.decision = decision;
        assignmentUpdateItems.add(item);
    }

    //PhongBT 29/05/26: Apply bulk từ import và gán lỗi lên dòng result.
    public static void applyImportBulk(List<ImportUpdateItem> updateItems) {
        if (updateItems == null || updateItems.isEmpty()) {
            return;
        }
        List<UpdateContext> contexts = new List<UpdateContext>();
        Map<Id, List<ImportUpdateItem>> rowsByAssignmentId = new Map<Id, List<ImportUpdateItem>>();
        for (ImportUpdateItem item : updateItems) {
            if (item == null || item.assignmentId == null || item.caseId == null || item.row == null) {
                continue;
            }
            UpdateContext ctx = new UpdateContext();
            ctx.caseId = item.caseId;
            ctx.assignmentId = item.assignmentId;
            ctx.decision = item.decision;
            contexts.add(ctx);
            if (!rowsByAssignmentId.containsKey(item.assignmentId)) {
                rowsByAssignmentId.put(item.assignmentId, new List<ImportUpdateItem>());
            }
            rowsByAssignmentId.get(item.assignmentId).add(item);
        }
        if (contexts.isEmpty()) {
            return;
        }
        List<ApplyResult> results = applyUpdateAssignmentsBulk(contexts);
        for (ApplyResult result : results) {
            if (result == null || result.success == true || result.assignmentId == null) {
                continue;
            }
            if (!rowsByAssignmentId.containsKey(result.assignmentId)) {
                continue;
            }
            for (ImportUpdateItem item : rowsByAssignmentId.get(result.assignmentId)) {
                if (item == null || item.row == null) {
                    continue;
                }
                item.row.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                item.row.errors = appendImportError(item.row.errors, result.errorMessage);
            }
        }
    }

    public static ApplyResult applyUpdateAssignment(Id caseId, Id assignmentId, String decision) {
        UpdateContext ctx = new UpdateContext();
        ctx.caseId = caseId;
        ctx.assignmentId = assignmentId;
        ctx.decision = decision;
        List<ApplyResult> results = applyUpdateAssignmentsBulk(new List<UpdateContext>{ ctx });
        if (results.isEmpty()) {
            ApplyResult empty = new ApplyResult(assignmentId);
            empty.errorMessage = 'Không có dữ liệu cập nhật Assignment Update.';
            return empty;
        }
        return results[0];
    }

    public static List<ApplyResult> applyUpdateAssignmentsBulk(List<UpdateContext> contexts) {
        List<ApplyResult> results = new List<ApplyResult>();
        if (contexts == null || contexts.isEmpty()) {
            return results;
        }

        Id currentUserId = UserInfo.getUserId();
        Map<Id, UpdateContext> ctxByAssignmentId = new Map<Id, UpdateContext>();
        Set<String> queueNames = new Set<String>();
        Set<Id> caseIdsToSync = new Set<Id>();

        for (UpdateContext ctx : contexts) {
            ApplyResult rowResult = new ApplyResult(ctx == null ? null : ctx.assignmentId);
            results.add(rowResult);
            if (ctx == null || ctx.assignmentId == null || ctx.caseId == null) {
                rowResult.errorMessage = 'Thiếu Case Id hoặc Assignment Id.';
                continue;
            }
            String decision = resolveDecisionLabel(ctx.decision);
            if (String.isBlank(decision)) {
                rowResult.errorMessage = 'Thiếu giá trị Update to (decision).';
                continue;
            }
            ctx.decision = decision;
            ctxByAssignmentId.put(ctx.assignmentId, ctx);
            caseIdsToSync.add(ctx.caseId);
            if (QUEUE_DECISIONS.contains(decision)) {
                String queueName = FEC_ConstantCommon.DECISION_QUEUE_MAP.get(decision);
                if (String.isNotBlank(queueName)) {
                    queueNames.add(queueName);
                }
            }
        }

        if (ctxByAssignmentId.isEmpty()) {
            return results;
        }

        Map<String, Id> queueIdByName = loadQueueIdsByName(queueNames);
        List<FEC_Assignment__c> assignmentUpdates = new List<FEC_Assignment__c>();
        Map<Id, Case> caseUpdatesById = new Map<Id, Case>();
        Map<Id, ApplyResult> resultByAssignmentId = new Map<Id, ApplyResult>();
        for (ApplyResult r : results) {
            if (r.assignmentId != null) {
                resultByAssignmentId.put(r.assignmentId, r);
            }
        }

        for (Id assignmentId : ctxByAssignmentId.keySet()) {
            UpdateContext ctx = ctxByAssignmentId.get(assignmentId);
            ApplyResult rowResult = resultByAssignmentId.get(assignmentId);
            if (ctx == null || rowResult == null) {
                continue;
            }
            String decision = ctx.decision;
            FEC_Assignment__c assignmentRow = new FEC_Assignment__c(Id = assignmentId);

            if (QUEUE_DECISIONS.contains(decision)) {
                String queueName = FEC_ConstantCommon.DECISION_QUEUE_MAP.get(decision);
                Id queueId = String.isBlank(queueName) ? null : queueIdByName.get(queueName);
                if (queueId == null) {
                    rowResult.errorMessage = System.Label.FEC_ERR_QUEUE_NOT_FOUND;
                    continue;
                }
                assignmentRow.FEC_Assignment_Owner__c = null;
                assignmentRow.FEC_OwnerID__c = queueId;
            } else {
                assignmentRow.FEC_Assignment_Owner__c = currentUserId;
                assignmentRow.FEC_OwnerID__c = currentUserId;
            }

            //PhongBT 29/05/26: Update to … → FEC_Assignment_Status__c (vd Pending Product → Pending-PBDOutOfSystem).
            String assignmentStatus = resolveAssignmentStatusForUpdateDecision(decision);
            if (String.isNotBlank(assignmentStatus)) {
                assignmentRow.FEC_Assignment_Status__c = assignmentStatus;
            }
            String teamCode = FEC_ConstantCommon.decisionToTeamMap.get(decision);
            if (String.isNotBlank(teamCode)) {
                assignmentRow.FEC_Team__c = teamCode;
            }

            assignmentUpdates.add(assignmentRow);

            String caseStatus = resolveAssignmentStatusForUpdateDecision(decision);
            if (String.isNotBlank(caseStatus)) {
                caseUpdatesById.put(
                    ctx.caseId,
                    new Case(Id = ctx.caseId, Status = caseStatus)
                );
            }
        }

        if (assignmentUpdates.isEmpty()) {
            return results;
        }

        Database.SaveResult[] assignmentSaveResults = Database.update(assignmentUpdates, false);
        for (Integer i = 0; i < assignmentSaveResults.size(); i++) {
            FEC_Assignment__c row = assignmentUpdates[i];
            ApplyResult rowResult = resultByAssignmentId.get(row.Id);
            if (rowResult == null) {
                continue;
            }
            if (assignmentSaveResults[i].isSuccess()) {
                rowResult.success = true;
                rowResult.errorMessage = null;
            } else {
                rowResult.errorMessage = assignmentSaveResults[i].getErrors().isEmpty()
                    ? 'Cập nhật Assignment Update thất bại.'
                    : assignmentSaveResults[i].getErrors()[0].getMessage();
            }
        }

        if (!caseUpdatesById.isEmpty()) {
            Database.update(caseUpdatesById.values(), false);
        }

        syncAssignmentUsersForCases(caseIdsToSync);
        return results;
    }

    //PhongBT 29/05/26: Map label Update to (Pending Product, Pending Contract Processing, …) → status picklist.
    private static String resolveAssignmentStatusForUpdateDecision(String decision) {
        if (String.isBlank(decision)) {
            return null;
        }
        if (decision == FEC_ConstantCommon.DECISION_CANNOT_CONTACT) {
            return FEC_ConstantCommon.ASSIGNMENT_STATUS_COMPLETED;
        }
        String fromLegacyMap = FEC_ConstantCommon.CASE_STATUS_MAP.get(decision);
        if (String.isNotBlank(fromLegacyMap)) {
            return fromLegacyMap;
        }
        String team = FEC_ConstantCommon.decisionToTeamMap.get(decision);
        if (String.isNotBlank(team)) {
            return FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX + team;
        }
        return null;
    }

    private static Map<String, Id> loadQueueIdsByName(Set<String> queueNames) {
        Map<String, Id> out = new Map<String, Id>();
        if (queueNames == null || queueNames.isEmpty()) {
            return out;
        }
        for (Group q : [
            SELECT Id, Name
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            AND Name IN :queueNames
        ]) {
            if (q != null && String.isNotBlank(q.Name)) {
                out.put(q.Name, q.Id);
            }
        }
        return out;
    }

    //PhongBT 29/05/26: Rebuild Case.FEC_Assignment_Users__c sau bulk update (theo rule syncAssignmentUsersToCase).
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

    private static String resolveUpdateMethodKeyFromLabel(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        return raw.trim().toLowerCase().startsWith('update')
            ? FEC_CaseBusinessService.UPDATEACTION
            : null;
    }

    private static String extractDecisionFromUpdateLabel(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String normalized = raw.trim().toLowerCase();
        if (!normalized.startsWith('update')) {
            return null;
        }
        Integer pos = normalized.indexOf('to ');
        if (pos >= 0 && pos + 3 < raw.length()) {
            return raw.substring(pos + 3).trim();
        }
        return null;
    }

    private static String appendImportError(String existing, String message) {
        if (String.isBlank(message)) {
            return existing;
        }
        return String.isBlank(existing) ? message : existing + '; ' + message;
    }

    private static String normalizeToken(String value) {
        if (String.isBlank(value)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return value.trim().toLowerCase().replaceAll('\\s+', FEC_ConstantCommon.STR_EMPTY).replaceAll('[^a-z0-9]', '');
    }
}
