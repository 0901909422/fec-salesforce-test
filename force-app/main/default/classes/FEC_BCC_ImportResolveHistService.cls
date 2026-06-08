//08/06/2026 dungLTdev: Tạo FEC_Routing_Action_History__c khi Import Batch Case Creation / Case Routing Action = Resolve.

public with sharing class FEC_BCC_ImportResolveHistService {

    //08/06/2026 dungLTdev: Lỗi import khi không resolve được Routing Action code từ metadata.
    private static final String ERR_ROUTING_ACTION_UNDETERMINED = 'Không xác định được Routing Action.';

    public class ImportResolveHistoryItem {

        public FEC_BatchCaseHandlingImportRow row;

        public Id caseId;

        public Id actionButtonId;

        public Id currentStageId;

        public String stageNameBefore;

        public String finalStatusBefore;

        public String excelRoutingLabel;

    }



    //08/06/2026 dungLTdev: Gom payload history Resolve từ 1 dòng import Case-level.

    public static void collectItem(

        List<ImportResolveHistoryItem> target,

        FEC_BatchCaseHandlingImportRow rr,

        Id caseId,

        Id stageIdForRow,

        String stageNameBefore,

        String finalStatusBefore

    ) {

        if (target == null || rr == null || caseId == null) {

            return;

        }

        ImportResolveHistoryItem item = new ImportResolveHistoryItem();

        item.row = rr;

        item.caseId = caseId;

        item.currentStageId = stageIdForRow;

        item.stageNameBefore = stageNameBefore;

        item.finalStatusBefore = finalStatusBefore;

        item.excelRoutingLabel = rr.routingAction;

        if (String.isNotBlank(rr.actionButtonId)) {

            try {

                item.actionButtonId = Id.valueOf(rr.actionButtonId);

            } catch (Exception ex) {

                item.actionButtonId = null;

            }

        }

        target.add(item);

    }



    //08/06/2026 dungLTdev: Reload Case sau run Resolve rồi insert Routing Action History bulk.

    public static void applyAfterCaseRunBulk(List<ImportResolveHistoryItem> items) {

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

            SELECT Id, OwnerId, Owner.Name, Owner.Type, FEC_Final_Status__c, Status, FEC_Team__c

            FROM Case

            WHERE Id IN :caseIds

        ]);

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



        Set<Id> actionButtonIds = new Set<Id>();

        Set<Id> stageIds = new Set<Id>();

        List<ImportResolveHistoryItem> validItems = new List<ImportResolveHistoryItem>();

        for (ImportResolveHistoryItem item : items) {

            if (item == null || item.row == null || item.caseId == null) {

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

                stageIds.add(item.currentStageId);

            }

        }

        if (validItems.isEmpty()) {

            return;

        }



        Map<Id, ActionButtonMeta> actionMetaById = loadActionButtonMeta(actionButtonIds);

        Map<String, String> customLabelByStageAndButton = loadCustomLabels(stageIds, actionButtonIds);



        List<FEC_Routing_Action_History__c> toInsert = new List<FEC_Routing_Action_History__c>();

        Map<Integer, ImportResolveHistoryItem> itemByInsertIndex = new Map<Integer, ImportResolveHistoryItem>();

        Integer insertIndex = 0;

        String importerEmailId = FEC_CaseBusinessService.emailLocalPart(importer.Email);

        Datetime submittedOn = System.now();



        for (ImportResolveHistoryItem item : validItems) {

            Case caseAfter = caseAfterById == null ? null : caseAfterById.get(item.caseId);

            if (caseAfter == null) {

                markRowFailed(item, 'Không tải được Case sau khi thực hiện Resolve.');

                continue;

            }

            ActionButtonMeta actionMeta = item.actionButtonId == null

                ? null

                : actionMetaById.get(item.actionButtonId);

            String routingActionCode = resolveRoutingActionCode(actionMeta);

            if (String.isBlank(routingActionCode)) {

                markRowFailed(item, ERR_ROUTING_ACTION_UNDETERMINED);

                continue;

            }

            String updatedLabel = FEC_CaseBusinessService.resolveRoutingHistoryOwnerLabel(

                caseAfter.OwnerId,

                caseAfter.Owner?.Name

            );

            String updatedId = caseAfter.OwnerId != null ? String.valueOf(caseAfter.OwnerId) : null;

            String customLabel = resolveCustomLabel(item, actionMeta, customLabelByStageAndButton);

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

                    ? 'Tạo Routing Action History thất bại.'

                    : saveResults[i].getErrors()[0].getMessage();

                markRowFailed(item, message);

            }

        }

    }



    private class ActionButtonMeta {

        public String actionCode;

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

            out.put(stageButtonKey(screen.FEC_Case_Stage__c, screen.FEC_Action_Button__c), label);

        }

        return out;

    }



    private static String stageButtonKey(Id stageId, Id actionButtonId) {

        return String.valueOf(stageId) + '|' + String.valueOf(actionButtonId);

    }



    private static String resolveRoutingActionCode(ActionButtonMeta actionMeta) {

        if (actionMeta != null && String.isNotBlank(actionMeta.actionCode)) {

            return actionMeta.actionCode;

        }

        return FEC_CaseBusinessService.RESOLVE;

    }



    private static String resolveCustomLabel(

        ImportResolveHistoryItem item,

        ActionButtonMeta actionMeta,

        Map<String, String> customLabelByStageAndButton

    ) {

        if (item != null &&

            item.actionButtonId != null &&

            item.currentStageId != null &&

            customLabelByStageAndButton.containsKey(stageButtonKey(item.currentStageId, item.actionButtonId))) {

            return customLabelByStageAndButton.get(stageButtonKey(item.currentStageId, item.actionButtonId));

        }

        if (item != null && String.isNotBlank(item.excelRoutingLabel)) {

            return item.excelRoutingLabel;

        }

        return actionMeta == null ? FEC_CaseBusinessService.RESOLVE : actionMeta.actionCode;

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

