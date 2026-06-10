//08/06/2026: Tạo FEC_Routing_Action_History__c khi Batch Case Creation import Case Status bắt đầu Resolved-.
public with sharing class FEC_BCC_CreationResolveHistService {

    private static final String ERR_CASE_NOT_LOADED = 'Không tải được Case sau khi tạo import.';
    private static final String ERR_ROUTING_ACTION_HISTORY_INSERT_FAILED = 'Tạo Routing Action History thất bại.';
    private static final String ERR_IMPORTER_NOT_FOUND = 'Không tìm thấy user thực hiện import.';

    public class CreationResolveHistoryItem {
        public FEC_BatchCaseCreationController.CaseRowResult rowResult;
        public Id caseId;
    }

    public static void collectItemIfResolvedStatus(
        List<CreationResolveHistoryItem> target,
        FEC_BatchCaseCreationController.CaseRowResult rowResult,
        Id caseId,
        String statusApi
    ) {
        if (!FEC_CommonUltils.isCaseStatusResolved(statusApi)) {
            return;
        }
        collectItem(target, rowResult, caseId);
    }

    public static void collectItem(
        List<CreationResolveHistoryItem> target,
        FEC_BatchCaseCreationController.CaseRowResult rowResult,
        Id caseId
    ) {
        if (target == null || rowResult == null || caseId == null) {
            return;
        }
        if (!'Succeeded'.equals(rowResult.status)) {
            return;
        }
        CreationResolveHistoryItem item = new CreationResolveHistoryItem();
        item.rowResult = rowResult;
        item.caseId = caseId;
        target.add(item);
    }

    public static void applyAfterCreationBulk(List<CreationResolveHistoryItem> items) {
        if (items == null || items.isEmpty()) {
            return;
        }
        Set<Id> caseIds = new Set<Id>();
        for (CreationResolveHistoryItem item : items) {
            if (item != null && item.caseId != null) {
                caseIds.add(item.caseId);
            }
        }
        if (caseIds.isEmpty()) {
            return;
        }
        Map<Id, Case> caseAfterById = new Map<Id, Case>([
            SELECT Id, OwnerId, Owner.Name, Owner.Type, Status, FEC_Final_Status__c,
                FEC_Team__c, FEC_Current_Case_Stage__c,
                FEC_Current_Case_Stage__r.FEC_Code__c, FEC_Stage_Name__c
            FROM Case
            WHERE Id IN :caseIds
        ]);
        applyCreationBulk(items, caseAfterById);
    }

    private static void applyCreationBulk(
        List<CreationResolveHistoryItem> items,
        Map<Id, Case> caseAfterById
    ) {
        if (items == null || items.isEmpty()) {
            return;
        }
        User importer = loadImporter();
        if (importer == null) {
            markAllFailed(items, ERR_IMPORTER_NOT_FOUND);
            return;
        }

        Set<Id> stageIds = new Set<Id>();
        List<CreationResolveHistoryItem> validItems = new List<CreationResolveHistoryItem>();
        for (CreationResolveHistoryItem item : items) {
            if (item == null || item.rowResult == null || item.caseId == null) {
                continue;
            }
            if (!'Succeeded'.equals(item.rowResult.status)) {
                continue;
            }
            validItems.add(item);
            Case caseAfter = caseAfterById == null ? null : caseAfterById.get(item.caseId);
            if (caseAfter != null && caseAfter.FEC_Current_Case_Stage__c != null) {
                stageIds.add(caseAfter.FEC_Current_Case_Stage__c);
            }
        }
        if (validItems.isEmpty()) {
            return;
        }

        Map<String, String> customLabelByStage = loadResolveCustomLabels(stageIds);
        String importerEmailId = FEC_CaseBusinessService.emailLocalPart(importer.Email);
        Datetime submittedOn = System.now();

        List<FEC_Routing_Action_History__c> toInsert = new List<FEC_Routing_Action_History__c>();
        Map<Integer, CreationResolveHistoryItem> itemByInsertIndex = new Map<Integer, CreationResolveHistoryItem>();
        Integer insertIndex = 0;

        for (CreationResolveHistoryItem item : validItems) {
            Case caseAfter = caseAfterById == null ? null : caseAfterById.get(item.caseId);
            if (caseAfter == null) {
                markRowFailed(item, ERR_CASE_NOT_LOADED);
                continue;
            }
            String stageName = resolveStageName(caseAfter);
            String customLabel = resolveCustomLabel(caseAfter, customLabelByStage);
            FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
                FEC_Routing_Action__c = FEC_CaseBusinessService.RESOLVE,
                FEC_Decision__c = null,
                FEC_Case__c = item.caseId,
                FEC_Original_User_Queue__c = importerEmailId,
                FEC_Original_User_Queue_ID__c = String.valueOf(importer.Id),
                FEC_Updated_User_Queue__c = FEC_CaseBusinessService.resolveRoutingHistoryOwnerLabel(
                    caseAfter.OwnerId,
                    caseAfter.Owner?.Name
                ),
                FEC_Updated_User_Queue_ID__c = caseAfter.OwnerId != null
                    ? String.valueOf(caseAfter.OwnerId)
                    : null,
                FEC_Stage_Name__c = stageName,
                FEC_User__c = importerEmailId,
                FEC_User_Role__c = importer.UserRole?.Name,
                FEC_Perform_User__c = importer.Id,
                FEC_Current_Status__c = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_Changed_Status__c = caseAfter.FEC_Final_Status__c,
                FEC_Custom_Action_Button_Label__c = customLabel,
                FEC_Routing_Action_Type__c = 'Case',
                FEC_Submitted_On__c = submittedOn,
                FEC_IsReverted__c = false
            );
            toInsert.add(history);
            itemByInsertIndex.put(insertIndex, item);
            insertIndex++;
        }

        if (toInsert.isEmpty()) {
            return;
        }

        Database.SaveResult[] saveResults = Database.insert(toInsert, false);
        for (Integer i = 0; i < saveResults.size(); i++) {
            CreationResolveHistoryItem item = itemByInsertIndex.get(i);
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
                    ? ERR_ROUTING_ACTION_HISTORY_INSERT_FAILED
                    : saveResults[i].getErrors()[0].getMessage();
                markRowFailed(item, message);
            }
        }
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

    private static Map<String, String> loadResolveCustomLabels(Set<Id> stageIds) {
        Map<String, String> out = new Map<String, String>();
        if (stageIds == null || stageIds.isEmpty()) {
            return out;
        }
        for (FEC_Stage_Screen__c screen : [
            SELECT FEC_Case_Stage__c, FEC_Custom_Action_Button_Label__c,
                FEC_Action_Button__r.Name, FEC_Action_Button__r.FEC_Code__c
            FROM FEC_Stage_Screen__c
            WHERE FEC_Case_Stage__c IN :stageIds
            AND FEC_Action_Button__r.FEC_Code__c = :FEC_CaseBusinessService.RESOLVE
            AND FEC_Active__c = TRUE
        ]) {
            if (screen == null || screen.FEC_Case_Stage__c == null) {
                continue;
            }
            String label = String.isNotBlank(screen.FEC_Custom_Action_Button_Label__c)
                ? screen.FEC_Custom_Action_Button_Label__c
                : screen.FEC_Action_Button__r?.Name;
            out.put(String.valueOf(screen.FEC_Case_Stage__c), label);
        }
        return out;
    }

    private static String resolveStageName(Case caseAfter) {
        if (caseAfter == null) {
            return null;
        }
        if (caseAfter.FEC_Current_Case_Stage__r != null &&
            String.isNotBlank(caseAfter.FEC_Current_Case_Stage__r.FEC_Code__c)) {
            return caseAfter.FEC_Current_Case_Stage__r.FEC_Code__c;
        }
        return caseAfter.FEC_Stage_Name__c;
    }

    private static String resolveCustomLabel(Case caseAfter, Map<String, String> customLabelByStage) {
        if (caseAfter != null &&
            caseAfter.FEC_Current_Case_Stage__c != null &&
            customLabelByStage.containsKey(String.valueOf(caseAfter.FEC_Current_Case_Stage__c))) {
            return customLabelByStage.get(String.valueOf(caseAfter.FEC_Current_Case_Stage__c));
        }
        return FEC_CaseBusinessService.RESOLVE;
    }

    private static void markAllFailed(List<CreationResolveHistoryItem> items, String message) {
        if (items == null) {
            return;
        }
        for (CreationResolveHistoryItem item : items) {
            markRowFailed(item, message);
        }
    }

    private static void markRowFailed(CreationResolveHistoryItem item, String message) {
        if (item == null || item.rowResult == null || String.isBlank(message)) {
            return;
        }
        item.rowResult.status = 'Failed';
        item.rowResult.recordId = '';
        item.rowResult.errors = appendError(item.rowResult.errors, message);
    }

    private static String appendError(String existing, String message) {
        if (String.isBlank(message)) {
            return existing;
        }
        return String.isBlank(existing) ? message : existing + '; ' + message;
    }
}
