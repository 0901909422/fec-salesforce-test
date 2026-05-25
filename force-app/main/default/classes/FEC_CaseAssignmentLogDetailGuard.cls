/**
 * FEC_Case_Assignment_Log_Detail__c — system-generated rows from auto-distribute.
 * Block manual create/update/delete from UI.
 */
public with sharing class FEC_CaseAssignmentLogDetailGuard {
    public static final String MSG_SYSTEM_READONLY =
        'Case Assignment Log Detail is system-generated and cannot be edited manually.';

    @TestVisible
    private static Boolean bypassGuard = false;

    /** Auto-distribute Apex inserts log details with this flag. */
    public static Boolean allowSystemInsert = false;

    @TestVisible
    public static void setBypassForTests(Boolean value) {
        bypassGuard = value == true;
    }

    public static void blockManualMutation(List<FEC_Case_Assignment_Log_Detail__c> rows) {
        if (bypassGuard || allowSystemInsert || rows == null || rows.isEmpty()) {
            return;
        }
        for (FEC_Case_Assignment_Log_Detail__c row : rows) {
            row.addError(MSG_SYSTEM_READONLY);
        }
    }
}
