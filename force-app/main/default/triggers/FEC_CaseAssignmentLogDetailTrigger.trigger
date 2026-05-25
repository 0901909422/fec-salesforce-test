trigger FEC_CaseAssignmentLogDetailTrigger on FEC_Case_Assignment_Log_Detail__c (
    before insert,
    before update,
    before delete
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            FEC_CaseAssignmentLogDetailGuard.blockManualMutation(Trigger.new);
        } else if (Trigger.isDelete) {
            FEC_CaseAssignmentLogDetailGuard.blockManualMutation(Trigger.old);
        }
    }
}
