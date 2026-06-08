//08/06/2026 dungLTdev: Tạo FEC_Routing_Action_History__c khi Import Batch Case Creation với Case Status = Resolve.
public with sharing class FEC_BCC_ImportResolveHistService {

    private static final String ROW_STATUS_SUCCEEDED = 'Succeeded';
    private static final String ROW_STATUS_FAILED = 'Failed';
    private static final String ERR_ROUTING_ACTION_UNDETERMINED = 'Không xác định được Routing Action.';
    private static final String ERR_CASE_AFTER_CREATE_NOT_LOADED = 'Không tải được Case sau khi import tạo Resolve.';
    private static final String ERR_STAGE_NOT_FOUND = 'Không xác định được Stage của Case để tạo Routing Action History.';
    private static final String ERR_HISTORY_INSERT_FAILED = 'Tạo Routing Action History thất bại.';

    public class ImportResolveHistoryItem {
        public FEC_BatchCaseCreationController.CaseRowResult row;
        public Id caseId;
        public Id actionButtonId;
        public Id currentStageId;
        public String stageNameBefore;
        public String finalStatusBefore;
    }

    public static void collectItem(
        List<ImportResolveHistoryItem> target,
        FEC_BatchCaseCreationController.CaseRowResult rr,
        Id caseId
    ) {
        if (target == null || rr == null || caseId == null) {
            return;
        }
        ImportResolveHistoryItem item = new ImportResolveHistoryItem();
        item.row = rr;
        item.caseId = caseId;
        item.finalStatusBefore = FEC_ConstantCommon.CASE_STATUS_OPEN;
        target.add(item);
    }

    public static void applyAfterCaseCreateBulk(List<ImportResolveHistoryItem> items) {
        if (items == null || items.isEmpty()) {
            return;
        }
        Set<Id> caseIds = new Set<Id>();
        for (ImportResolveHistoryItem item : items) {
            if (item != null && item.caseId != null) {
                caseIds.add(item.caseId);
            }
        }
        if (caseIds.isEmpty()) {
            return;
        }
        Map<Id, Case> caseAfterById = new Map<Id, Case>([
            SELECT Id, OwnerId, Owner.Name, Owner.Type, FEC_Final_Status__c, Status, FEC_Team__c,
                FEC_Current_Case_Stage__c, FEC_Current_Case_Stage__r.FEC_Code__c
            FROM Case
            WHERE Id IN :caseIds
        ]);
        for (ImportResolveHistoryItem item : items) {
            if (item == null || item.caseId == null) {
                continue;
            }
            Case caseAfter = caseAfterById.get(item.caseId);
            if (caseAfter == null) {
                continue;
            }
            item.currentStageId = caseAfter.FEC_Current_Case_Stage__c;
            item.stageNameBefore = caseAfter.FEC_Current_Case_Stage__r?.FEC_Code__c;
        }
        applyImportBulk(items, caseAfterById);
    }

    public static void applyImportBulk(
        List<ImportResolveHistoryItem> items,
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

        Set<Id> stageIds = new Set<Id>();
        List<ImportResolveHistoryItem> validItems = new List<ImportResolveHistoryItem>();
        for (ImportResolveHistoryItem item : items) {
            if (item == null || item.row == null || item.caseId == null) {
                continue;
            }
            if (item.row.status == ROW_STATUS_FAILED) {
                continue;
            }
            validItems.add(item);
            if (item.currentStageId != null) {
                stageIds.add(item.currentStageId);
            }
        }
        if (validItems.isEmpty()) {
            return;
        }

        Map<Id, ResolveStageMeta> resolveMetaByStageId = loadResolveStageMeta(stageIds);
        List<FEC_Routing_Action_History__c> toInsert = new List<FEC_Routing_Action_History__c>();
        Map<Integer, ImportResolveHistoryItem> itemByInsertIndex = new Map<Integer, ImportResolveHistoryItem>();
        Integer insertIndex = 0;
        String importerEmailId = FEC_CaseBusinessService.emailLocalPart(importer.Email);
        Datetime submittedOn = System.now();

        for (ImportResolveHistoryItem item : validItems) {
            Case caseAfter = caseAfterById == null ? null : caseAfterById.get(item.caseId);
            if (caseAfter == null) {
                markRowFailed(item, ERR_CASE_AFTER_CREATE_NOT_LOADED);
                continue;
            }
            if (item.currentStageId == null) {
                markRowFailed(item, ERR_STAGE_NOT_FOUND);
                continue;
            }
            ResolveStageMeta stageMeta = resolveMetaByStageId.get(item.currentStageId);
            if (stageMeta == null || stageMeta.actionButtonId == null) {
                markRowFailed(item, ERR_ROUTING_ACTION_UNDETERMINED);
                continue;
            }
            item.actionButtonId = stageMeta.actionButtonId;
            String routingActionCode = String.isNotBlank(stageMeta.actionCode)
                ? stageMeta.actionCode
                : FEC_CaseBusinessService.RESOLVE;
            String updatedLabel = FEC_CaseBusinessService.resolveRoutingHistoryOwnerLabel(
                caseAfter.OwnerId,
                caseAfter.Owner?.Name
            );
            String updatedId = caseAfter.OwnerId != null ? String.valueOf(caseAfter.OwnerId) : null;
            String customLabel = String.isNotBlank(stageMeta.customLabel)
                ? stageMeta.customLabel
                : FEC_CaseBusinessService.RESOLVE;
            FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
                FEC_Routing_Action__c = routingActionCode,
                FEC_Decision__c = null,
                FEC_Case__c = item.caseId,
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
            ImportResolveHistoryItem item = itemByInsertIndex.get(i);
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
                    ? ERR_HISTORY_INSERT_FAILED
                    : saveResults[i].getErrors()[0].getMessage();
                markRowFailed(item, message);
            }
        }
    }

    private class ResolveStageMeta {
        public Id actionButtonId;
        public String actionCode;
        public String customLabel;
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

    private static Map<Id, ResolveStageMeta> loadResolveStageMeta(Set<Id> stageIds) {
        Map<Id, ResolveStageMeta> out = new Map<Id, ResolveStageMeta>();
        if (stageIds == null || stageIds.isEmpty()) {
            return out;
        }
        for (FEC_Stage_Screen__c screen : [
            SELECT FEC_Case_Stage__c, FEC_Action_Button__c, FEC_Custom_Action_Button_Label__c,
                FEC_Action_Button__r.FEC_Code__c, FEC_Action_Button__r.Name
            FROM FEC_Stage_Screen__c
            WHERE FEC_Case_Stage__c IN :stageIds
            AND FEC_Action_Button__r.FEC_Code__c = :FEC_CaseBusinessService.RESOLVE
            AND FEC_Active__c = TRUE
        ]) {
            if (screen == null || screen.FEC_Case_Stage__c == null || screen.FEC_Action_Button__c == null) {
                continue;
            }
            if (out.containsKey(screen.FEC_Case_Stage__c)) {
                continue;
            }
            ResolveStageMeta meta = new ResolveStageMeta();
            meta.actionButtonId = screen.FEC_Action_Button__c;
            meta.actionCode = screen.FEC_Action_Button__r?.FEC_Code__c;
            meta.customLabel = String.isNotBlank(screen.FEC_Custom_Action_Button_Label__c)
                ? screen.FEC_Custom_Action_Button_Label__c
                : screen.FEC_Action_Button__r?.Name;
            out.put(screen.FEC_Case_Stage__c, meta);
        }
        return out;
    }

    private static void markAllFailed(List<ImportResolveHistoryItem> items, String message) {
        if (items == null) {
            return;
        }
        for (ImportResolveHistoryItem item : items) {
            markRowFailed(item, message);
        }
    }

    private static void markRowFailed(ImportResolveHistoryItem item, String message) {
        if (item == null || item.row == null || String.isBlank(message)) {
            return;
        }
        item.row.status = ROW_STATUS_FAILED;
        item.row.errors = appendError(item.row.errors, message);
    }

    private static String appendError(String existing, String message) {
        if (String.isBlank(message)) {
            return existing;
        }
        return String.isBlank(existing) ? message : existing + '; ' + message;
    }
}
