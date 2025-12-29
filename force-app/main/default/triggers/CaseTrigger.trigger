/** * CaseTrigger
* Single Apex Trigger on the Case object to manage all automation for Case events.
* It delegates logic execution to the CaseTriggerHandler class.
* @created    : 2025/12/03 long.nguyen.50
* @modified   : 
*/ 
trigger CaseTrigger on Case (before insert, before update) {
    // Luôn sử dụng Handler để chứa logic
    CaseTriggerHandler handler = new CaseTriggerHandler();

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            handler.onBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.onBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
    // Logic after event (if any)
}