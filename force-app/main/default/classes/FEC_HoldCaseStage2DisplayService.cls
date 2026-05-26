/**
 * Hold Case tự động — quy tắc hiển thị khi Case đã Submit (Stage 2+, CS Support / CS Customer Care)
 * và user đổi bộ Nature of Case trên UI.
 */
public with sharing class FEC_HoldCaseStage2DisplayService {
    public static final String MODE_DEFAULT = 'DEFAULT';
    public static final String MODE_ERROR_RETRY = 'ERROR_RETRY';
    public static final String MODE_ERROR_RETRY_INFO_NO_AUTO = 'ERROR_RETRY_INFO_NO_AUTO';
    public static final String MODE_INFO_NO_AUTO_ONLY = 'INFO_NO_AUTO_ONLY';
    /** Stage 1 SUCCESS + Stage 2+ đổi NOC không Auto: giữ UI success, thêm info xanh. */
    public static final String MODE_SUCCESS_WITH_INFO_NO_AUTO = 'SUCCESS_WITH_INFO_NO_AUTO';
    public static final String MODE_INFO_HAS_AUTO_BUTTON = 'INFO_HAS_AUTO_BUTTON';

    private static final String HOLD_TYPE_AUTO = 'Auto';
    private static final String HOLD_TYPE_MANUAL = 'Manual';
    private static final String RESULT_ERROR = 'ERROR';
    private static final String RESULT_SUCCESS = 'SUCCESS';
    private static final String RESULT_ALREADY_MARKED = 'ALREADY_MARKED';

    private static final Set<String> ELIGIBLE_TEAMS = new Set<String>{
        FEC_ConstantCommon.TEAM_CS_SUPPORT,
        FEC_ConstantCommon.TEAM_VALUE_CSSUPPORT,
        FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE
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
        Id subCodeId,
        Id baselineProductTypeId,
        Id baselineCategoryId,
        Id baselineSubCategoryId,
        Id baselineSubCodeId
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
                Status,
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

        // Baseline = bộ NOC trên Case lúc mở màn hình (trước khi fec_CaseEditNOC persist saveCaseNOC).
        // UI publish CASE_NOC sau persist nên so với Case hiện tại sẽ luôn trùng → không phát hiện đổi NOC.
        Id comparePt = baselineProductTypeId != null ? baselineProductTypeId : savedPt;
        Id compareCat = baselineCategoryId != null ? baselineCategoryId : savedCat;
        Id compareSub = baselineSubCategoryId != null
            ? baselineSubCategoryId
            : savedSub;
        Id compareCode = baselineSubCodeId != null ? baselineSubCodeId : savedCode;

        Id currentStageId = c.FEC_Current_Case_Stage__c;
        Id newNocId = resolveNatureOfCaseId(newPt, newCat, newSub, newCode, currentStageId);
        Id baselineNocId = resolveNatureOfCaseId(
            comparePt,
            compareCat,
            compareSub,
            compareCode,
            currentStageId
        );

        Boolean newHasAuto = hasHoldConfig(HOLD_TYPE_AUTO, newNocId);
        Boolean newHasAutoAtCurrentStage = hasHoldConfigForStage(
            HOLD_TYPE_AUTO,
            newNocId,
            currentStageId
        );
        Boolean savedHadAutoAtStage1 = baselineNocId != null &&
            hasHoldConfigAtStage1(HOLD_TYPE_AUTO, baselineNocId, currentStageId);
        Boolean nocChanged = isNatureOfCaseChanged(
            newPt,
            newCat,
            newSub,
            newCode,
            comparePt,
            compareCat,
            compareSub,
            compareCode
        );

        String stage1Result = String.isBlank(c.FEC_NFU_Description_Result__c)
            ? null
            : c.FEC_NFU_Description_Result__c.trim();

        // TH1: Stage 1 Auto Hold thất bại — không đổi NOC: đỏ + nút retry; đã đổi NOC: chỉ đỏ
        if (stage1Result == RESULT_ERROR) {
            Integer userRetryCount = FEC_AutoHoldCaseService.getHoldCaseUserRetryCount(
                caseId
            );
            Boolean maxRetryReached = userRetryCount >= 3;
            out.showHoldCaseSection = true;
            out.displayMode = MODE_ERROR_RETRY;
            out.errorMessage = System.Label.FEC_MSG_HOLD_CASE_AUTO_FAIL_RETRY;
            out.showManualHoldCaseButton =
                !nocChanged && !c.IsClosed && !maxRetryReached;
            debugStage2Evaluate(caseId, 'TH1', nocChanged, newHasAuto, out);
            return out;
        }

        // TH2: Stage 1 Hold Case thành công — luôn hiện UI success; đổi NOC không Auto → thêm info xanh (không thay thế success)
        if (stage1Result == RESULT_SUCCESS || stage1Result == RESULT_ALREADY_MARKED) {
            out.showHoldCaseSection = true;
            if (nocChanged && !newHasAuto) {
                out.displayMode = MODE_SUCCESS_WITH_INFO_NO_AUTO;
                out.infoMessage = System.Label.FEC_MSG_HOLD_CASE_NOC_NO_AUTO;
            }
            return out;
        }

        // TH3: Stage 1 không Auto; Stage 2+ đổi NOC có Auto tại stage hiện tại → info xanh + nút Hold Case.
        if (
            stage1Result == null &&
            nocChanged &&
            newHasAutoAtCurrentStage &&
            !savedHadAutoAtStage1
        ) {
            out.showHoldCaseSection = true;
            out.displayMode = MODE_INFO_HAS_AUTO_BUTTON;
            out.infoMessage = System.Label.FEC_MSG_HOLD_CASE_NOC_HAS_AUTO;
            out.showManualHoldCaseButton = !c.IsClosed;
            debugStage2Evaluate(caseId, 'TH3', nocChanged, newHasAuto, out);
        }

        return out;
    }

    @TestVisible
    private static void debugStage2Evaluate(
        Id caseId,
        String scenario,
        Boolean nocChanged,
        Boolean newHasAuto,
        HoldCaseStage2Display out
    ) {
        System.debug(
            LoggingLevel.WARN,
            '[FEC_HoldCaseStage2Display] evaluate ' +
                scenario +
                ' caseId=' +
                caseId +
                ' nocChanged=' +
                nocChanged +
                ' newHasAuto=' +
                newHasAuto +
                ' displayMode=' +
                out.displayMode +
                ' showHoldCaseSection=' +
                out.showHoldCaseSection +
                ' showManualHoldCaseButton=' +
                out.showManualHoldCaseButton
        );
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
        return isEligibleHoldCaseTeam(c.FEC_Team__c, c.Status);
    }

    /** FEC_Team__c có thể là một team hoặc chuỗi ghép (vd. CSSupport_Other). */
    @TestVisible
    private static Boolean isEligibleHoldCaseTeam(String team, String caseStatus) {
        if (String.isNotBlank(team)) {
            if (ELIGIBLE_TEAMS.contains(team.trim())) {
                return true;
            }
            for (String part : team.split('_')) {
                if (ELIGIBLE_TEAMS.contains(part.trim())) {
                    return true;
                }
            }
        }
        if (String.isNotBlank(caseStatus)) {
            String status = caseStatus.trim();
            return status.containsIgnoreCase(FEC_ConstantCommon.TEAM_VALUE_CSSUPPORT) ||
                status.containsIgnoreCase(FEC_ConstantCommon.TEAM_CS_SUPPORT) ||
                status.containsIgnoreCase(FEC_ConstantCommon.TEAM_CS_CUSTOMER_CARE);
        }
        return false;
    }

    /** Có config Hold (Auto/Manual) cho NOC — không lọc stage (TH1/TH2). */
    @TestVisible
    private static Boolean hasHoldConfig(String holdType, Id nocId) {
        if (nocId == null) {
            return false;
        }
        List<FEC_Hold_Case_Config__c> rows = [
            SELECT Id
            FROM FEC_Hold_Case_Config__c
            WHERE Hold_Case_Type__c = :holdType
              AND FEC_Active__c = TRUE
              AND (FEC_Nature_of_Cases__c = :nocId OR FEC_Nature_of_Cases__c = NULL)
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return !rows.isEmpty();
    }

    /** Có config Hold tại đúng FEC_Case_Stage__c (TH3 — stage Case hiện tại). */
    @TestVisible
    private static Boolean hasHoldConfigForStage(
        String holdType,
        Id nocId,
        Id stageId
    ) {
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
        return hasHoldConfigForStage(holdType, nocId, stage1Id);
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
