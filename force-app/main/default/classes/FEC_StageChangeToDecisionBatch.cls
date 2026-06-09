/**
 * @description One-time migration batch: dump FEC_Stage_Change__c data into the
 *              Decision Engine objects (BOTH MDM staging + Live runtime layers).
 *
 *              Source of truth = FEC_Stage_Change__c (NOT modified).
 *              Each active Stage Change row → 1 Decision Rule + N Decision Condition rows,
 *              created identically in MDM and Live so the Decision Engine UI (MDM) and
 *              runtime resolver (Live) both see the same data.
 *
 *              Rule code = 'STG_' + Stage_Change.Id (stable, idempotent via upsert).
 *
 *              NOTE: This is a faithful 1:1 data dump. Multi-destination combos
 *              (same Previous Stage + Action Button → many Next Stages) become
 *              multiple rules — none are lost. Runtime selection logic (Phase 2)
 *              is handled separately when wiring the engine into route().
 *
 *              JUSTIFIED: scope=1 batchable migration utility, no business runtime path.
 */
public with sharing class FEC_StageChangeToDecisionBatch implements Database.Batchable<SObject>, Database.Stateful {

    private static final String TABLE_KEY = 'STAGE_TRANSITION';
    private static final String CODE_PREFIX = 'STG_';
    private static final String STATUS_SYNCED = 'Synced';

    private Integer rulesCreated = 0;
    private Integer condsCreated = 0;
    private Integer skipped = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id,
                   FEC_Active__c,
                   FEC_Previous_Stage__c, FEC_Previous_Stage__r.Name, FEC_Previous_Stage__r.FEC_Code__c,
                   FEC_Previous_Stage__r.FEC_Nature_of_Cases__r.FEC_Business_Process__c,
                   FEC_Action_Button__c, FEC_Action_Button__r.Name,
                   FEC_Next_Stage__c, FEC_Next_Stage__r.Name, FEC_Next_Stage__r.FEC_Code__c,
                   FEC_Next_Queue__c,
                   FEC_Team_User_Group__c
            FROM FEC_Stage_Change__c
            WHERE FEC_Active__c = TRUE
              AND FEC_Previous_Stage__c != NULL
              AND FEC_Action_Button__c   != NULL
              AND FEC_Next_Stage__c      != NULL
        ]);
    }

    public void execute(Database.BatchableContext bc, List<FEC_Stage_Change__c> scope) {
        Map<String, FEC_MDM_Decision_Rule__c> mdmRules = new Map<String, FEC_MDM_Decision_Rule__c>();
        Map<String, FEC_Decision_Rule__c>     liveRules = new Map<String, FEC_Decision_Rule__c>();

        for (FEC_Stage_Change__c sc : scope) {
            String code = CODE_PREFIX + sc.Id;
            String keyId = sc.FEC_Previous_Stage__r?.FEC_Nature_of_Cases__r?.FEC_Business_Process__c != null
                ? String.valueOf(sc.FEC_Previous_Stage__r.FEC_Nature_of_Cases__r.FEC_Business_Process__c)
                : null;

            // Name là Auto-Number trên cả 2 Decision Rule object → KHÔNG set.
            mdmRules.put(code, new FEC_MDM_Decision_Rule__c(
                FEC_Code__c = code,
                FEC_Table_Key__c = TABLE_KEY,
                FEC_Key_ID__c = keyId,
                FEC_Priority__c = 1,
                FEC_Active__c = true,
                Process_Change_Status__c = STATUS_SYNCED
            ));
            liveRules.put(code, new FEC_Decision_Rule__c(
                FEC_Code__c = code,
                FEC_Table_Key__c = TABLE_KEY,
                FEC_Key_ID__c = keyId,
                FEC_Priority__c = 1,
                FEC_Active__c = true
            ));
        }

        upsert mdmRules.values() FEC_Code__c;
        upsert liveRules.values() FEC_Code__c;
        rulesCreated += mdmRules.size();

        List<FEC_MDM_Decision_Condition__c> mdmConds = new List<FEC_MDM_Decision_Condition__c>();
        List<FEC_Decision_Condition__c>     liveConds = new List<FEC_Decision_Condition__c>();

        for (FEC_Stage_Change__c sc : scope) {
            String code = CODE_PREFIX + sc.Id;
            Id mdmRuleId  = mdmRules.get(code).Id;
            Id liveRuleId = liveRules.get(code).Id;

            for (RowSpec spec : buildRowSpecs(sc)) {
                String condCode = code + spec.suffix;
                mdmConds.add(new FEC_MDM_Decision_Condition__c(
                    FEC_Code__c = condCode,
                    FEC_Decision_Rule__c = mdmRuleId,
                    FEC_Type__c = spec.rowType,
                    FEC_Label__c = spec.label,
                    FEC_Value__c = spec.value,
                    FEC_Operator__c = spec.operatorVal,
                    FEC_Order__c = spec.orderVal,
                    Process_Change_Status__c = STATUS_SYNCED
                ));
                liveConds.add(new FEC_Decision_Condition__c(
                    FEC_Code__c = condCode,
                    FEC_Decision_Rule__c = liveRuleId,
                    FEC_Type__c = spec.rowType,
                    FEC_Label__c = spec.label,
                    FEC_Value__c = spec.value,
                    FEC_Operator__c = spec.operatorVal,
                    FEC_Order__c = spec.orderVal
                ));
            }
        }

        upsert mdmConds FEC_Code__c;
        upsert liveConds FEC_Code__c;
        condsCreated += mdmConds.size();
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('=== FEC_StageChangeToDecisionBatch DONE ===');
        System.debug('Rules created (per layer): ' + rulesCreated);
        System.debug('Conditions created (per layer): ' + condsCreated);
        System.debug('Skipped: ' + skipped);
    }

    // ── Helpers ──

    private List<RowSpec> buildRowSpecs(FEC_Stage_Change__c sc) {
        List<RowSpec> specs = new List<RowSpec>();
        // Condition: Current Stage (UI label dùng "Current Stage")
        specs.add(new RowSpec('_R01', 'Condition', 'Current Stage', sc.FEC_Previous_Stage__r?.Name, '=', 1));
        // Action: Available Decisions = tên action button (Route to / Revert / ...).
        // ĐÂY là cột chốt cho getDecisionTableResults group/filter. KHÔNG cần thêm row
        // "Action Button" riêng vì 2 cột trùng value & chức năng.
        specs.add(new RowSpec('_R03', 'Action', 'Available Decisions', sc.FEC_Action_Button__r?.Name, null, 3));
        // Action: Next Stage
        specs.add(new RowSpec('_R04', 'Action', 'Next Stage', sc.FEC_Next_Stage__r?.Name, null, 4));
        // Action: Next Queue (nếu có)
        if (String.isNotBlank(sc.FEC_Next_Queue__c)) {
            specs.add(new RowSpec('_R05', 'Action', 'Next Queue', sc.FEC_Next_Queue__c, null, 5));
        }
        // Action: Team User Group (nếu có)
        if (String.isNotBlank(sc.FEC_Team_User_Group__c)) {
            specs.add(new RowSpec('_R06', 'Action', 'Team User Group', sc.FEC_Team_User_Group__c, null, 6));
        }
        // Action: Routing Mode (cột FIS team thêm vào Decision Engine để phân biệt routing tự động vs thủ công).
        // Stage_Change không phân biệt → default 'Auto' cho mọi rule migrate; admin chỉnh 'Manual' tay sau nếu cần.
        specs.add(new RowSpec('_R07', 'Action', 'Routing Mode', 'Auto', null, 7));
        return specs;
    }

    private class RowSpec {
        String suffix;
        String rowType;
        String label;
        String value;
        String operatorVal;
        Integer orderVal;
        RowSpec(String suffix, String rowType, String label, String value, String operatorVal, Integer orderVal) {
            this.suffix = suffix;
            this.rowType = rowType;
            this.label = label;
            this.value = value;
            this.operatorVal = operatorVal;
            this.orderVal = orderVal;
        }
    }
}