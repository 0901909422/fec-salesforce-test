// Service bulk — cập nhật FEC_Assignment__c khi Assignment Routing Action = Revert to User / Revert to User's Team Queue (Import COF/GSR).
public with sharing class FEC_BCH_AssignmentRevertService {

    public class ImportRevertItem {
        public FEC_BatchCaseHandlingImportRow row;
        public Id caseId;
        public Id assignmentId;
        public String decision;
    }

    public class RevertContext {
        public Id caseId;
        public Id assignmentId;
        public String decision;
        public String remark;
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

    private class MainQueueInfo {
        public Id queueId;
        public String queueName;
    }

    public static Boolean isAssignmentRevertMethodKey(String methodKey) {
        return methodKey == FEC_CaseBusinessService.REVERT;
    }

    public static String resolveRevertDecisionFromLabel(String routingLabel) {
        if (String.isBlank(routingLabel)) {
            return null;
        }
        String normalized = routingLabel.trim().toLowerCase();
        if (!normalized.startsWith('revert')) {
            return null;
        }
        if (normalized.contains('team') && normalized.contains('queue')) {
            return FEC_ConstantCommon.DECISION_USER_TEAM_QUEUE;
        }
        if (normalized.contains('user')) {
            return FEC_ConstantCommon.DECISION_USER;
        }
        return null;
    }

    public static void collectFromImportRow(
        FEC_BatchCaseHandlingImportRow rr,
        Boolean cofOrGsr,
        Boolean assignmentOnly,
        Id caseId,
        Id assignmentRecordId,
        String methodKey,
        List<ImportRevertItem> revertItems
    ) {
        if (rr == null ||
            cofOrGsr != true ||
            assignmentOnly != true ||
            assignmentRecordId == null ||
            caseId == null ||
            revertItems == null ||
            !isAssignmentRevertMethodKey(methodKey)) {
            return;
        }
        String decision = resolveRevertDecisionFromLabel(rr.assignmentRoutingAction);
        if (String.isBlank(decision)) {
            return;
        }
        ImportRevertItem item = new ImportRevertItem();
        item.row = rr;
        item.caseId = caseId;
        item.assignmentId = assignmentRecordId;
        item.decision = decision;
        revertItems.add(item);
    }

    public static void applyImportBulk(List<ImportRevertItem> revertItems) {
        if (revertItems == null || revertItems.isEmpty()) {
            return;
        }
        List<RevertContext> contexts = new List<RevertContext>();
        Map<Id, List<ImportRevertItem>> rowsByAssignmentId = new Map<Id, List<ImportRevertItem>>();
        for (ImportRevertItem item : revertItems) {
            if (item == null || item.assignmentId == null || item.caseId == null || item.row == null) {
                continue;
            }
            RevertContext ctx = new RevertContext();
            ctx.caseId = item.caseId;
            ctx.assignmentId = item.assignmentId;
            ctx.decision = item.decision;
            ctx.remark = item.row.inputtedRemarks;
            contexts.add(ctx);
            if (!rowsByAssignmentId.containsKey(item.assignmentId)) {
                rowsByAssignmentId.put(item.assignmentId, new List<ImportRevertItem>());
            }
            rowsByAssignmentId.get(item.assignmentId).add(item);
        }
        if (contexts.isEmpty()) {
            return;
        }
        List<ApplyResult> results = applyRevertAssignmentsBulk(contexts);
        for (ApplyResult result : results) {
            if (result == null || result.success == true || result.assignmentId == null) {
                continue;
            }
            if (!rowsByAssignmentId.containsKey(result.assignmentId)) {
                continue;
            }
            for (ImportRevertItem item : rowsByAssignmentId.get(result.assignmentId)) {
                if (item == null || item.row == null) {
                    continue;
                }
                item.row.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                item.row.errors = appendImportError(item.row.errors, result.errorMessage);
            }
        }
    }

    public static List<ApplyResult> applyRevertAssignmentsBulk(List<RevertContext> contexts) {
        List<ApplyResult> results = new List<ApplyResult>();
        if (contexts == null || contexts.isEmpty()) {
            return results;
        }

        Map<Id, RevertContext> ctxByAssignmentId = new Map<Id, RevertContext>();
        Set<Id> caseIds = new Set<Id>();
        Set<Id> assignmentIds = new Set<Id>();
        for (RevertContext ctx : contexts) {
            ApplyResult rowResult = new ApplyResult(ctx == null ? null : ctx.assignmentId);
            results.add(rowResult);
            if (ctx == null || ctx.assignmentId == null || ctx.caseId == null || String.isBlank(ctx.decision)) {
                rowResult.errorMessage = 'Thiếu Case Id, Assignment Id hoặc giá trị Revert.';
                continue;
            }
            ctxByAssignmentId.put(ctx.assignmentId, ctx);
            caseIds.add(ctx.caseId);
            assignmentIds.add(ctx.assignmentId);
        }
        if (ctxByAssignmentId.isEmpty()) {
            return results;
        }

        Map<Id, Case> caseById = new Map<Id, Case>([
            SELECT Id, CreatedById, FEC_Current_Case_Stage__r.FEC_Code__c
            FROM Case
            WHERE Id IN :caseIds
        ]);
        Set<Id> createdByIds = new Set<Id>();
        for (Case c : caseById.values()) {
            if (c != null && c.CreatedById != null) {
                createdByIds.add(c.CreatedById);
            }
        }
        Map<Id, User> createdByUserById = new Map<Id, User>();
        if (!createdByIds.isEmpty()) {
            for (User u : [SELECT Id, FEC_Main_Queue__c FROM User WHERE Id IN :createdByIds]) {
                if (u != null) {
                    createdByUserById.put(u.Id, u);
                }
            }
        }
        Map<Id, MainQueueInfo> mainQueueByUserId = loadMainQueueInfoByUserId(createdByUserById);

        List<FEC_Assignment__c> assignmentUpdates = new List<FEC_Assignment__c>();
        Map<Id, ApplyResult> resultByAssignmentId = new Map<Id, ApplyResult>();
        for (ApplyResult r : results) {
            if (r.assignmentId != null) {
                resultByAssignmentId.put(r.assignmentId, r);
            }
        }

        for (Id assignmentId : ctxByAssignmentId.keySet()) {
            RevertContext ctx = ctxByAssignmentId.get(assignmentId);
            ApplyResult rowResult = resultByAssignmentId.get(assignmentId);
            if (ctx == null || rowResult == null) {
                continue;
            }
            Case parentCase = caseById.get(ctx.caseId);
            if (parentCase == null || parentCase.CreatedById == null) {
                rowResult.errorMessage = 'Không tìm thấy Case hoặc Created By.';
                continue;
            }
            FEC_Assignment__c assignmentRow = new FEC_Assignment__c(
                Id = assignmentId,
                FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_REVERTING_CREATOR
            );
            if (ctx.decision == FEC_ConstantCommon.DECISION_USER) {
                assignmentRow.FEC_Assignment_Owner__c = parentCase.CreatedById;
                assignmentRow.FEC_OwnerID__c = parentCase.CreatedById;
            } else if (ctx.decision == FEC_ConstantCommon.DECISION_USER_TEAM_QUEUE) {
                MainQueueInfo queueInfo = mainQueueByUserId.get(parentCase.CreatedById);
                if (queueInfo == null || String.isBlank(queueInfo.queueName)) {
                    rowResult.errorMessage = System.Label.FEC_ERR_QUEUE_NOT_FOUND;
                    continue;
                }
                assignmentRow.FEC_Assignment_Owner__c = null;
                assignmentRow.FEC_OwnerID__c = queueInfo.queueName;
            } else {
                rowResult.errorMessage = System.Label.FEC_ERR_INVALID_INPUT;
                continue;
            }
            assignmentUpdates.add(assignmentRow);
        }

        if (assignmentUpdates.isEmpty()) {
            return results;
        }

        Database.SaveResult[] saveResults = Database.update(assignmentUpdates, false);
        Set<Id> successfulAssignmentIds = new Set<Id>();
        for (Integer i = 0; i < saveResults.size(); i++) {
            FEC_Assignment__c row = assignmentUpdates[i];
            ApplyResult rowResult = resultByAssignmentId.get(row.Id);
            if (rowResult == null) {
                continue;
            }
            if (saveResults[i].isSuccess()) {
                rowResult.success = true;
                rowResult.errorMessage = null;
                successfulAssignmentIds.add(row.Id);
            } else {
                rowResult.errorMessage = saveResults[i].getErrors().isEmpty()
                    ? 'Cập nhật Assignment Revert thất bại.'
                    : saveResults[i].getErrors()[0].getMessage();
            }
        }

        if (!successfulAssignmentIds.isEmpty()) {
            syncAssignmentUsersForCases(caseIds);
            insertRevertHistoriesBulk(ctxByAssignmentId, successfulAssignmentIds, caseById);
        }
        return results;
    }

    private static Map<Id, MainQueueInfo> loadMainQueueInfoByUserId(Map<Id, User> createdByUserById) {
        Map<Id, MainQueueInfo> out = new Map<Id, MainQueueInfo>();
        if (createdByUserById == null || createdByUserById.isEmpty()) {
            return out;
        }
        Set<String> queueDevNames = new Set<String>();
        for (User u : createdByUserById.values()) {
            if (u != null && String.isNotBlank(u.FEC_Main_Queue__c)) {
                queueDevNames.add(u.FEC_Main_Queue__c.trim());
            }
        }
        Map<String, Group> queueByDevName = new Map<String, Group>();
        if (!queueDevNames.isEmpty()) {
            for (Group q : [
                SELECT Id, Name, DeveloperName
                FROM Group
                WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
                AND DeveloperName IN :queueDevNames
            ]) {
                if (q != null && String.isNotBlank(q.DeveloperName)) {
                    queueByDevName.put(q.DeveloperName, q);
                }
            }
        }
        for (Id userId : createdByUserById.keySet()) {
            User u = createdByUserById.get(userId);
            if (u == null || String.isBlank(u.FEC_Main_Queue__c)) {
                continue;
            }
            Group q = queueByDevName.get(u.FEC_Main_Queue__c.trim());
            if (q == null) {
                continue;
            }
            MainQueueInfo info = new MainQueueInfo();
            info.queueId = q.Id;
            info.queueName = q.Name;
            out.put(userId, info);
        }
        return out;
    }

    private static void insertRevertHistoriesBulk(
        Map<Id, RevertContext> ctxByAssignmentId,
        Set<Id> successfulAssignmentIds,
        Map<Id, Case> caseById
    ) {
        if (ctxByAssignmentId == null || successfulAssignmentIds == null || successfulAssignmentIds.isEmpty()) {
            return;
        }
        User importer = [
            SELECT Id, Email, UserRole.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        Map<Id, FEC_Assignment__c> assignmentById = new Map<Id, FEC_Assignment__c>([
            SELECT Id, FEC_Assignment_Owner__c, FEC_Assignment_Owner_Text__c, FEC_OwnerID__c, FEC_Case__c
            FROM FEC_Assignment__c
            WHERE Id IN :successfulAssignmentIds
        ]);
        List<SObject> records = new List<SObject>();
        for (Id assignmentId : successfulAssignmentIds) {
            RevertContext ctx = ctxByAssignmentId.get(assignmentId);
            FEC_Assignment__c asg = assignmentById.get(assignmentId);
            if (ctx == null || asg == null || asg.FEC_Case__c == null) {
                continue;
            }
            Case parentCase = caseById.get(asg.FEC_Case__c);
            if (parentCase == null) {
                continue;
            }
            String decisionDisplay = resolveDecisionDisplay(ctx.decision);
            String updatedUserQueueId = '';
            String updatedUserQueue = asg.FEC_Assignment_Owner_Text__c;
            if (ctx.decision == FEC_ConstantCommon.DECISION_USER) {
                updatedUserQueueId = asg.FEC_Assignment_Owner__c == null
                    ? ''
                    : String.valueOf(asg.FEC_Assignment_Owner__c);
            } else if (ctx.decision == FEC_ConstantCommon.DECISION_USER_TEAM_QUEUE) {
                updatedUserQueueId = resolveQueueIdByName(asg.FEC_OwnerID__c);
            }
            String importerEmailId = FEC_CaseBusinessService.emailLocalPart(importer.Email);
            records.add(new FEC_Routing_Action_History__c(
                FEC_Routing_Action_Type__c = FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
                FEC_Case__c = asg.FEC_Case__c,
                FEC_Assignment__c = assignmentId,
                FEC_Routing_Action__c = FEC_ConstantCommon.ACTION_REVERT,
                FEC_Original_User_Queue__c = importerEmailId,
                FEC_Original_User_Queue_ID__c = String.valueOf(importer.Id),
                FEC_Updated_User_Queue__c = updatedUserQueue,
                FEC_Updated_User_Queue_ID__c = updatedUserQueueId,
                FEC_Stage_Name__c = parentCase.FEC_Current_Case_Stage__r?.FEC_Code__c,
                FEC_User__c = importerEmailId,
                FEC_User_Role__c = importer.UserRole?.Name,
                FEC_Decision__c = decisionDisplay
            ));
            if (String.isNotBlank(ctx.remark)) {
                records.add(new FEC_Case_Remarks__c(
                    FEC_Remark_Type__c = FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
                    FEC_Case_Remarks__c = ctx.remark,
                    FEC_Case__c = asg.FEC_Case__c,
                    FEC_Assignment__c = assignmentId,
                    FEC_Stage_Name__c = parentCase.FEC_Current_Case_Stage__r?.FEC_Code__c,
                    FEC_User__c = importerEmailId,
                    FEC_User_Role__c = importer.UserRole?.Name
                ));
            }
        }
        if (!records.isEmpty()) {
            Database.insert(records, false);
        }
    }

    private static String resolveDecisionDisplay(String decision) {
        if (decision == FEC_ConstantCommon.DECISION_USER) {
            return 'User';
        }
        if (decision == FEC_ConstantCommon.DECISION_USER_TEAM_QUEUE) {
            return 'User\'s Team Queue';
        }
        return decision;
    }

    private static String resolveQueueIdByName(String queueName) {
        if (String.isBlank(queueName)) {
            return '';
        }
        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            AND Name = :queueName
            LIMIT 1
        ];
        return queues.isEmpty() ? '' : String.valueOf(queues[0].Id);
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
