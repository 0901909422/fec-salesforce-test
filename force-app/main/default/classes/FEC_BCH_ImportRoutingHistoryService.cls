//PhongBT 29/05/26: Tạo FEC_Routing_Action_History__c sau import COF/GSR Assignment Routing Action (assignmentOnly / skipCaseRun).
public with sharing class FEC_BCH_ImportRoutingHistoryService {

    public class ImportHistoryItem {
        public FEC_BatchCaseHandlingImportRow row;
        public Id caseId;
        public Id assignmentId;
        public String methodKey;
        public String decision;
        public Id actionButtonId;
        public Id currentStageId;
        public String stageNameBefore;
        public String finalStatusBefore;
        public String routeTeamHint;
        public String routeQueueHint;
        public String queueToken;
        public Boolean routeViaRevertButton;
        public String excelRoutingLabel;
    }

    public class ApplyResult {
        public Id caseId;
        public Boolean success;
        public String errorMessage;

        public ApplyResult(Id caseId) {
            this.caseId = caseId;
            this.success = false;
        }
    }

    public static void applyImportBulk(
        List<ImportHistoryItem> items,
        Map<Id, Case> caseAfterById
    ) {
        if (items == null || items.isEmpty()) {
            return;
        }
        User importer = loadImporter();
        if (importer == null) {
            markAllFailed(items, 'Không tìm thấy user thực hiện import.');
            return;
        }

        Set<Id> actionButtonIds = new Set<Id>();
        Set<Id> previousStageIds = new Set<Id>();
        List<ImportHistoryItem> validItems = new List<ImportHistoryItem>();
        for (ImportHistoryItem item : items) {
            if (item == null || item.row == null || item.caseId == null || item.assignmentId == null) {
                continue;
            }
            if (item.row.status == System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed) {
                continue;
            }
            validItems.add(item);
            if (item.actionButtonId != null) {
                actionButtonIds.add(item.actionButtonId);
            }
            if (item.currentStageId != null) {
                previousStageIds.add(item.currentStageId);
            }
        }
        if (validItems.isEmpty()) {
            return;
        }

        Map<Id, ActionButtonMeta> actionMetaById = loadActionButtonMeta(actionButtonIds);
        Map<String, StageChangeMeta> stageChangeByKey = loadStageChangeMeta(validItems, previousStageIds);
        Map<String, String> customLabelByStageAndButton = loadCustomLabels(previousStageIds, actionButtonIds);

        List<FEC_Routing_Action_History__c> toInsert = new List<FEC_Routing_Action_History__c>();
        Map<Integer, ImportHistoryItem> itemByInsertIndex = new Map<Integer, ImportHistoryItem>();
        Integer insertIndex = 0;
        for (ImportHistoryItem item : validItems) {
            Case caseAfter = caseAfterById == null ? null : caseAfterById.get(item.caseId);
            if (caseAfter == null) {
                markRowFailed(item, 'Không tải được Case sau khi cập nhật Assignment.');
                continue;
            }
            ActionButtonMeta actionMeta = item.actionButtonId == null
                ? null
                : actionMetaById.get(item.actionButtonId);
            String routingActionCode = resolveRoutingActionCode(item.methodKey, actionMeta);
            if (String.isBlank(routingActionCode)) {
                markRowFailed(item, 'Không xác định được Routing Action.');
                continue;
            }
            String importerEmailId = FEC_CaseBusinessService.emailLocalPart(importer.Email);
            String updatedLabel = FEC_CaseBusinessService.resolveRoutingHistoryOwnerLabel(
                caseAfter.OwnerId,
                caseAfter.Owner?.Name
            );
            String updatedId = caseAfter.OwnerId != null ? String.valueOf(caseAfter.OwnerId) : null;
            String customLabel = resolveCustomLabel(
                item,
                actionMeta,
                customLabelByStageAndButton
            );
            StageChangeMeta stageChange = resolveStageChangeMeta(item, stageChangeByKey);
            Datetime submittedOn = System.now();

            FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
                FEC_Routing_Action__c = routingActionCode,
                FEC_Decision__c = resolveDecision(item),
                FEC_Case__c = item.caseId,
                FEC_Assignment__c = item.assignmentId,
                FEC_Original_User_Queue__c = importerEmailId,
                FEC_Original_User_Queue_ID__c = String.valueOf(importer.Id),
                FEC_Updated_User_Queue__c = updatedLabel,
                FEC_Updated_User_Queue_ID__c = updatedId,
                FEC_Stage_Name__c = item.stageNameBefore,
                FEC_User__c = importerEmailId,
                FEC_User_Role__c = importer.UserRole?.Name,
                FEC_Perform_User__c = importer.Id,
                FEC_Current_Status__c = item.finalStatusBefore,
                FEC_Changed_Status__c = caseAfter.FEC_Final_Status__c,
                FEC_Custom_Action_Button_Label__c = customLabel,
                FEC_Routing_Action_Type__c = FEC_ConstantCommon.ROUTING_TYPE_ASSIGNMENT,
                FEC_Submitted_On__c = submittedOn
            );
            if (stageChange != null && isStageChangeHistoryAction(item.methodKey)) {
                history.FEC_Previous_Stage__c = stageChange.previousStageId;
                history.FEC_Next_Stage__c = stageChange.nextStageId;
                history.FEC_IsReverted__c = stageChange.isReverted;
            }
            toInsert.add(history);
            itemByInsertIndex.put(insertIndex, item);
            insertIndex++;
        }

        if (toInsert.isEmpty()) {
            return;
        }

        Database.SaveResult[] saveResults = Database.insert(toInsert, false);
        for (Integer i = 0; i < saveResults.size(); i++) {
            ImportHistoryItem item = itemByInsertIndex.get(i);
            if (item == null) {
                continue;
            }
            if (saveResults[i].isSuccess()) {
                Id historyId = saveResults[i].getId();
                Case caseAfter = caseAfterById.get(item.caseId);
                if (historyId != null && caseAfter != null) {
                    String changedSnapshot = FEC_CaseBusinessService.routingHistoryStatusSnapshot(caseAfter);
                    if (String.isNotBlank(changedSnapshot)) {
                        FEC_CaseBusinessService.patchRoutingHistoryChangedStatus(historyId, changedSnapshot);
                    }
                }
            } else {
                String message = saveResults[i].getErrors().isEmpty()
                    ? 'Tạo Routing Action History thất bại.'
                    : saveResults[i].getErrors()[0].getMessage();
                markRowFailed(item, message);
            }
        }
    }

    //PhongBT 29/05/26: Gom payload history từ 1 dòng import Assignment Routing Action.
    public static void collectItem(
        List<ImportHistoryItem> target,
        FEC_BatchCaseHandlingImportRow rr,
        Id caseId,
        Id assignmentId,
        String methodKey,
        String decision,
        Id stageIdForRow,
        String stageNameBefore,
        String finalStatusBefore,
        String routeTeamHint,
        String routeQueueHint,
        String queueToken,
        Boolean routeViaRevertButton
    ) {
        if (target == null || rr == null || caseId == null || assignmentId == null || String.isBlank(methodKey)) {
            return;
        }
        ImportHistoryItem item = new ImportHistoryItem();
        item.row = rr;
        item.caseId = caseId;
        item.assignmentId = assignmentId;
        item.methodKey = methodKey;
        item.decision = FEC_BCH_AssignmentUpdateService.resolveDecisionLabel(decision);
        item.currentStageId = stageIdForRow;
        item.stageNameBefore = stageNameBefore;
        item.finalStatusBefore = finalStatusBefore;
        item.excelRoutingLabel = rr.assignmentRoutingAction;
        item.routeViaRevertButton = routeViaRevertButton == true;
        item.queueToken = queueToken;
        item.routeTeamHint = routeTeamHint;
        item.routeQueueHint = routeQueueHint;
        if (String.isNotBlank(rr.actionButtonId)) {
            try {
                item.actionButtonId = Id.valueOf(rr.actionButtonId);
            } catch (Exception ex) {
                item.actionButtonId = null;
            }
        }
        target.add(item);
    }

    //PhongBT 29/05/26: Reload Case sau bulk Assignment rồi insert Routing Action History.
    public static void applyAfterAssignmentBulk(List<ImportHistoryItem> items) {
        if (items == null || items.isEmpty()) {
            return;
        }
        Set<Id> caseIds = new Set<Id>();
        for (ImportHistoryItem item : items) {
            if (item != null && item.caseId != null) {
                caseIds.add(item.caseId);
            }
        }
        if (caseIds.isEmpty()) {
            return;
        }
        Map<Id, Case> caseAfterById = new Map<Id, Case>([
            SELECT Id, OwnerId, Owner.Name, Owner.Type, FEC_Final_Status__c, Status, FEC_Team__c
            FROM Case
            WHERE Id IN :caseIds
        ]);
        applyImportBulk(items, caseAfterById);
    }

    private class ActionButtonMeta {
        public String actionCode;
    }

    private class StageChangeMeta {
        public Id previousStageId;
        public Id nextStageId;
        public Boolean isReverted;
    }

    private static User loadImporter() {
        List<User> users = [
            SELECT Id, Email, UserRole.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        return users.isEmpty() ? null : users[0];
    }

    private static Map<Id, ActionButtonMeta> loadActionButtonMeta(Set<Id> actionButtonIds) {
        Map<Id, ActionButtonMeta> out = new Map<Id, ActionButtonMeta>();
        if (actionButtonIds == null || actionButtonIds.isEmpty()) {
            return out;
        }
        for (FEC_Action_Button__c btn : [
            SELECT Id, FEC_Code__c
            FROM FEC_Action_Button__c
            WHERE Id IN :actionButtonIds
        ]) {
            if (btn == null) {
                continue;
            }
            ActionButtonMeta meta = new ActionButtonMeta();
            meta.actionCode = btn.FEC_Code__c;
            out.put(btn.Id, meta);
        }
        return out;
    }

    private static Map<String, String> loadCustomLabels(Set<Id> stageIds, Set<Id> actionButtonIds) {
        Map<String, String> out = new Map<String, String>();
        if (stageIds == null || stageIds.isEmpty() || actionButtonIds == null || actionButtonIds.isEmpty()) {
            return out;
        }
        for (FEC_Stage_Screen__c screen : [
            SELECT FEC_Case_Stage__c, FEC_Action_Button__c, FEC_Custom_Action_Button_Label__c,
                FEC_Action_Button__r.Name
            FROM FEC_Stage_Screen__c
            WHERE FEC_Case_Stage__c IN :stageIds
            AND FEC_Action_Button__c IN :actionButtonIds
            AND FEC_Active__c = TRUE
        ]) {
            if (screen == null || screen.FEC_Action_Button__c == null || screen.FEC_Case_Stage__c == null) {
                continue;
            }
            String label = String.isNotBlank(screen.FEC_Custom_Action_Button_Label__c)
                ? screen.FEC_Custom_Action_Button_Label__c
                : screen.FEC_Action_Button__r?.Name;
            out.put(stageChangeKey(screen.FEC_Case_Stage__c, screen.FEC_Action_Button__c), label);
        }
        return out;
    }

    private static Map<String, StageChangeMeta> loadStageChangeMeta(
        List<ImportHistoryItem> items,
        Set<Id> previousStageIds
    ) {
        Map<String, StageChangeMeta> out = new Map<String, StageChangeMeta>();
        if (items == null || items.isEmpty() || previousStageIds == null || previousStageIds.isEmpty()) {
            return out;
        }
        Set<Id> actionButtonIds = new Set<Id>();
        for (ImportHistoryItem item : items) {
            if (item != null && item.actionButtonId != null && isStageChangeHistoryAction(item.methodKey)) {
                actionButtonIds.add(item.actionButtonId);
            }
        }
        if (actionButtonIds.isEmpty()) {
            return out;
        }
        for (FEC_Stage_Change__c row : [
            SELECT FEC_Previous_Stage__c, FEC_Next_Stage__c, FEC_IsReverted__c, FEC_Action_Button__c
            FROM FEC_Stage_Change__c
            WHERE FEC_Previous_Stage__c IN :previousStageIds
            AND FEC_Action_Button__c IN :actionButtonIds
            AND FEC_Active__c = TRUE
        ]) {
            if (row == null || row.FEC_Action_Button__c == null || row.FEC_Previous_Stage__c == null) {
                continue;
            }
            String key = stageChangeKey(row.FEC_Previous_Stage__c, row.FEC_Action_Button__c);
            if (!out.containsKey(key)) {
                StageChangeMeta meta = new StageChangeMeta();
                meta.previousStageId = row.FEC_Previous_Stage__c;
                meta.nextStageId = row.FEC_Next_Stage__c;
                meta.isReverted = row.FEC_IsReverted__c;
                out.put(key, meta);
            }
        }
        return out;
    }

    private static StageChangeMeta resolveStageChangeMeta(
        ImportHistoryItem item,
        Map<String, StageChangeMeta> stageChangeByKey
    ) {
        if (item == null || item.currentStageId == null || item.actionButtonId == null) {
            return null;
        }
        return stageChangeByKey.get(stageChangeKey(item.currentStageId, item.actionButtonId));
    }

    private static String stageChangeKey(Id previousStageId, Id actionButtonId) {
        return String.valueOf(previousStageId) + '|' + String.valueOf(actionButtonId);
    }

    private static Boolean isStageChangeHistoryAction(String methodKey) {
        return methodKey == FEC_CaseBusinessService.ROUTE_TO
            || methodKey == FEC_CaseBusinessService.REVERT;
    }

    private static String resolveRoutingActionCode(String methodKey, ActionButtonMeta actionMeta) {
        if (actionMeta != null && String.isNotBlank(actionMeta.actionCode)) {
            return actionMeta.actionCode;
        }
        if (methodKey == FEC_CaseBusinessService.UPDATEACTION) {
            return FEC_CaseBusinessService.UPDATEACTION;
        }
        if (methodKey == FEC_CaseBusinessService.ROUTE_TO) {
            return FEC_CaseBusinessService.ROUTE_TO;
        }
        if (methodKey == FEC_CaseBusinessService.REVERT) {
            return FEC_CaseBusinessService.REVERT;
        }
        return methodKey;
    }

    private static String resolveDecision(ImportHistoryItem item) {
        if (item == null) {
            return null;
        }
        if (item.methodKey == FEC_CaseBusinessService.UPDATEACTION
            || item.methodKey == FEC_CaseBusinessService.REVERT
            || item.methodKey == FEC_CaseBusinessService.TRANSFER) {
            return item.decision;
        }
        return null;
    }

    private static String resolveCustomLabel(
        ImportHistoryItem item,
        ActionButtonMeta actionMeta,
        Map<String, String> customLabelByStageAndButton
    ) {
        if (item != null &&
            item.actionButtonId != null &&
            item.currentStageId != null &&
            customLabelByStageAndButton.containsKey(stageChangeKey(item.currentStageId, item.actionButtonId))) {
            return customLabelByStageAndButton.get(stageChangeKey(item.currentStageId, item.actionButtonId));
        }
        if (item != null && String.isNotBlank(item.excelRoutingLabel)) {
            return item.excelRoutingLabel;
        }
        return actionMeta == null ? null : actionMeta.actionCode;
    }

    private static void markAllFailed(List<ImportHistoryItem> items, String message) {
        if (items == null) {
            return;
        }
        for (ImportHistoryItem item : items) {
            markRowFailed(item, message);
        }
    }

    private static void markRowFailed(ImportHistoryItem item, String message) {
        if (item == null || item.row == null || String.isBlank(message)) {
            return;
        }
        item.row.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
        item.row.errors = appendError(item.row.errors, message);
    }

    private static String appendError(String existing, String message) {
        if (String.isBlank(message)) {
            return existing;
        }
        return String.isBlank(existing) ? message : existing + '; ' + message;
    }
}