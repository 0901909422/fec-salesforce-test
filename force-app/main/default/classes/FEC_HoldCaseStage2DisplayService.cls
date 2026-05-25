/**
 * Hold Case tự động — quy tắc hiển thị khi Case đã Submit (Stage 2+, CS Support / CS Customer Care)
 * và user đổi bộ Nature of Case trên UI.
 */
public with sharing class FEC_HoldCaseStage2DisplayService {
    public static final String MODE_DEFAULT = 'DEFAULT';
    public static final String MODE_ERROR_RETRY = 'ERROR_RETRY';
    public static final String MODE_ERROR_RETRY_INFO_NO_AUTO = 'ERROR_RETRY_INFO_NO_AUTO';
    public static final String MODE_INFO_NO_AUTO_ONLY = 'INFO_NO_AUTO_ONLY';
    public static final String MODE_INFO_HAS_AUTO_BUTTON = 'INFO_HAS_AUTO_BUTTON';

    private static final String HOLD_TYPE_AUTO = 'Auto';
    private static final String HOLD_TYPE_MANUAL = 'Manual';
    private static final String RESULT_ERROR = 'ERROR';
    private static final String RESULT_SUCCESS = 'SUCCESS';
    private static final String RESULT_ALREADY_MARKED = 'ALREADY_MARKED';

    private static final Set<String> ELIGIBLE_TEAMS = new Set<String>{
        'CS Support',
        'CS Customer Care'
    };

    public class HoldCaseStage2Display {
        @AuraEnabled
        public String displayMode { get; set; }
        @AuraEnabled
        public Boolean showHoldCaseSection { get; set; }
        @AuraEnabled
        public String infoMessage { get; set; }
        @AuraEnabled
        public String errorMessage { get; set; }
        @AuraEnabled
        public Boolean showManualHoldCaseButton { get; set; }
    }

    @AuraEnabled(cacheable=false)
    public static HoldCaseStage2Display evaluate(
        Id caseId,
        Id productTypeId,
        Id categoryId,
        Id subCategoryId,
        Id subCodeId
    ) {
        HoldCaseStage2Display out = new HoldCaseStage2Display();
        out.displayMode = MODE_DEFAULT;
        out.showHoldCaseSection = false;
        out.infoMessage = null;
        out.errorMessage = null;
        out.showManualHoldCaseButton = false;

        if (caseId == null) {
            return out;
        }

        List<Case> cases = [
            SELECT
                Id,
                IsClosed,
                FEC_Is_Submited__c,
                FEC_Stage_Name__c,
                FEC_Team__c,
                FEC_NFU_Description_Result__c,
                FEC_Product_Type__c,
                FEC_Category__c,
                FEC_SubCategory__c,
                FEC_SubCode__c,
                FEC_Current_Case_Stage__c,
                FEC_Current_Case_Stage__r.FEC_Default_Stage__c,
                FEC_Current_Case_Stage__r.Name
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            return out;
        }

        Case c = cases[0];
        if (!isStage2HoldCaseContext(c)) {
            return out;
        }

        Id newPt = productTypeId != null ? productTypeId : c.FEC_Product_Type__c;
        Id newCat = categoryId != null ? categoryId : c.FEC_Category__c;
        Id newSub = subCategoryId != null ? subCategoryId : c.FEC_SubCategory__c;
        Id newCode = subCodeId != null ? subCodeId : c.FEC_SubCode__c;

        Id savedPt = c.FEC_Product_Type__c;
        Id savedCat = c.FEC_Category__c;
        Id savedSub = c.FEC_SubCategory__c;
        Id savedCode = c.FEC_SubCode__c;

        Id currentStageId = c.FEC_Current_Case_Stage__c;
        Id newNocId = resolveNatureOfCaseId(newPt, newCat, newSub, newCode, currentStageId);
        Id savedNocId = resolveNatureOfCaseId(savedPt, savedCat, savedSub, savedCode, currentStageId);

        Boolean newHasAuto = hasHoldConfig(
            HOLD_TYPE_AUTO,
            newNocId,
            currentStageId
        );
        Boolean savedHadAutoAtStage1 = savedNocId != null &&
            hasHoldConfigAtStage1(HOLD_TYPE_AUTO, savedNocId, currentStageId);
        Boolean nocChanged = isNatureOfCaseChanged(
            newPt,
            newCat,
            newSub,
            newCode,
            savedPt,
            savedCat,
            savedSub,
            savedCode
        );

        String stage1Result = String.isBlank(c.FEC_NFU_Description_Result__c)
            ? null
            : c.FEC_NFU_Description_Result__c.trim();

        // TH1: Stage 1 Auto Hold thất bại — 1.1/1.2 giữ nút khi có Auto; 1.3 chỉ khi đổi NOC sang bộ không Auto
        if (stage1Result == RESULT_ERROR) {
            out.showHoldCaseSection = true;
            out.errorMessage = System.Label.FEC_MSG_HOLD_CASE_AUTO_FAIL_RETRY;
            if (newHasAuto) {
                out.displayMode = MODE_ERROR_RETRY;
                out.showManualHoldCaseButton = !c.IsClosed;
            } else if (nocChanged) {
                out.displayMode = MODE_ERROR_RETRY_INFO_NO_AUTO;
                out.infoMessage = System.Label.FEC_MSG_HOLD_CASE_NOC_NO_AUTO;
                out.showManualHoldCaseButton = false;
            }
            return out;
        }

        // TH2: Stage 1 thành công — chỉ thông báo xanh khi user đổi NOC sang bộ không Auto tại stage hiện tại
        if (stage1Result == RESULT_SUCCESS || stage1Result == RESULT_ALREADY_MARKED) {
            if (nocChanged && !newHasAuto) {
                out.showHoldCaseSection = true;
                out.displayMode = MODE_INFO_NO_AUTO_ONLY;
                out.infoMessage = System.Label.FEC_MSG_HOLD_CASE_NOC_NO_AUTO;
            }
            return out;
        }

        // TH3: Stage 1 không Auto — chỉ khi user chọn NOC mới có Auto tại stage hiện tại
        if (nocChanged && newHasAuto && !savedHadAutoAtStage1) {
            out.showHoldCaseSection = true;
            out.displayMode = MODE_INFO_HAS_AUTO_BUTTON;
            out.infoMessage = System.Label.FEC_MSG_HOLD_CASE_NOC_HAS_AUTO;
            out.showManualHoldCaseButton = !c.IsClosed;
        }

        return out;
    }

    /** So sánh bộ NOC trên UI (hoặc fallback Case) với bộ đã lưu trên Case. */
    @TestVisible
    private static Boolean isNatureOfCaseChanged(
        Id newPt,
        Id newCat,
        Id newSub,
        Id newCode,
        Id savedPt,
        Id savedCat,
        Id savedSub,
        Id savedCode
    ) {
        return newPt != savedPt ||
            newCat != savedCat ||
            newSub != savedSub ||
            newCode != savedCode;
    }

    @TestVisible
    private static Boolean isStage2HoldCaseContext(Case c) {
        if (c == null || c.FEC_Is_Submited__c != true) {
            return false;
        }
        if (c.FEC_Current_Case_Stage__r?.FEC_Default_Stage__c == true) {
            return false;
        }
        String stageName = c.FEC_Stage_Name__c != null
            ? c.FEC_Stage_Name__c
            : c.FEC_Current_Case_Stage__r?.Name;
        if (String.isNotBlank(stageName) && stageName.containsIgnoreCase('Stage 1')) {
            return false;
        }
        return ELIGIBLE_TEAMS.contains(c.FEC_Team__c);
    }

    @TestVisible
    private static Boolean hasHoldConfig(String holdType, Id nocId, Id stageId) {
        if (nocId == null || stageId == null) {
            return false;
        }
        List<FEC_Hold_Case_Config__c> rows = [
            SELECT Id
            FROM FEC_Hold_Case_Config__c
            WHERE Hold_Case_Type__c = :holdType
              AND FEC_Active__c = TRUE
              AND FEC_Case_Stage__c = :stageId
              AND (FEC_Nature_of_Cases__c = :nocId OR FEC_Nature_of_Cases__c = NULL)
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return !rows.isEmpty();
    }

    @TestVisible
    private static Boolean hasHoldConfigAtStage1(
        String holdType,
        Id nocId,
        Id currentStageId
    ) {
        Id stage1Id = resolveStage1IdForNature(nocId, currentStageId);
        return hasHoldConfig(holdType, nocId, stage1Id);
    }

    @TestVisible
    private static Id resolveStage1IdForNature(Id nocId, Id currentStageId) {
        if (nocId == null) {
            return null;
        }
        List<FEC_Case_Stage__c> byDefault = [
            SELECT Id
            FROM FEC_Case_Stage__c
            WHERE FEC_Nature_of_Cases__c = :nocId
              AND FEC_Default_Stage__c = TRUE
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (!byDefault.isEmpty()) {
            return byDefault[0].Id;
        }
        List<FEC_Case_Stage__c> byName = [
            SELECT Id
            FROM FEC_Case_Stage__c
            WHERE FEC_Nature_of_Cases__c = :nocId
              AND Name LIKE '%Stage 1%'
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return byName.isEmpty() ? null : byName[0].Id;
    }

    @TestVisible
    private static Id resolveNatureOfCaseId(
        Id productTypeId,
        Id categoryId,
        Id subCategoryId,
        Id subCodeId,
        Id stageId
    ) {
        if (productTypeId == null || categoryId == null || subCategoryId == null) {
            return null;
        }

        List<FEC_Nature_of_Case__c> nocList;
        if (subCodeId != null) {
            nocList = [
                SELECT Id
                FROM FEC_Nature_of_Case__c
                WHERE FEC_Product_Type__c = :productTypeId
                  AND FEC_Category__c = :categoryId
                  AND FEC_Sub_Category__c = :subCategoryId
                  AND FEC_Sub_Code__c = :subCodeId
                WITH SECURITY_ENFORCED
            ];
        } else {
            nocList = [
                SELECT Id
                FROM FEC_Nature_of_Case__c
                WHERE FEC_Product_Type__c = :productTypeId
                  AND FEC_Category__c = :categoryId
                  AND FEC_Sub_Category__c = :subCategoryId
                  AND FEC_Sub_Code__c = NULL
                WITH SECURITY_ENFORCED
            ];
        }
        if (nocList.isEmpty()) {
            return null;
        }
        if (nocList.size() == 1 || stageId == null) {
            return nocList[0].Id;
        }

        Set<Id> nocIds = new Map<Id, FEC_Nature_of_Case__c>(nocList).keySet();
        List<FEC_Hold_Case_Config__c> configs = [
            SELECT FEC_Nature_of_Cases__c
            FROM FEC_Hold_Case_Config__c
            WHERE FEC_Nature_of_Cases__c IN :nocIds
              AND Hold_Case_Type__c = :HOLD_TYPE_AUTO
              AND FEC_Active__c = TRUE
              AND FEC_Case_Stage__c = :stageId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (!configs.isEmpty() && configs[0].FEC_Nature_of_Cases__c != null) {
            return configs[0].FEC_Nature_of_Cases__c;
        }
        return nocList[0].Id;
    }
}
