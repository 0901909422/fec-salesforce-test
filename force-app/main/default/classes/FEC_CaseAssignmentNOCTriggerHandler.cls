public without sharing class FEC_CaseAssignmentNOCTriggerHandler {
    private static final String MSG_NOC_REQUIRES_DRAFT =
        'You can only add Case Assignment NOC when Case Assignment Status is Draft.';

    public static void handleBeforeInsert(List<FEC_Case_Assignment_NOC__c> newList) {
        validateParentDraftForInsert(newList);
        FEC_CaseAssignmentConflictService.validateNocConflicts(newList, null);
    }

    private static void validateParentDraftForInsert(
        List<FEC_Case_Assignment_NOC__c> newList
    ) {
        Set<Id> parentIds = new Set<Id>();
        for (FEC_Case_Assignment_NOC__c noc : newList) {
            if (noc.FEC_Case_Assignment_Name__c != null) {
                parentIds.add(noc.FEC_Case_Assignment_Name__c);
            }
        }
        if (parentIds.isEmpty()) {
            return;
        }

        Map<Id, FEC_Case_Assignment__c> parentById = new Map<Id, FEC_Case_Assignment__c>(
            [
                SELECT Id, FEC_Status__c
                FROM FEC_Case_Assignment__c
                WHERE Id IN :parentIds
            ]
        );

        for (FEC_Case_Assignment_NOC__c noc : newList) {
            Id pid = noc.FEC_Case_Assignment_Name__c;
            if (pid == null) {
                continue;
            }

            FEC_Case_Assignment__c parentRecord = parentById.get(pid);
            if (parentRecord == null) {
                noc.addError('Case Assignment lookup is required.');
                continue;
            }
            if (
                parentRecord.FEC_Status__c !=
                FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
            ) {
                noc.addError(MSG_NOC_REQUIRES_DRAFT);
            }
        }
    }

    public static void handleBeforeUpdate(
        List<FEC_Case_Assignment_NOC__c> newList,
        Map<Id, FEC_Case_Assignment_NOC__c> oldMap
    ) {
        FEC_CaseAssignmentConflictService.validateNocConflicts(newList, oldMap);
    }
}