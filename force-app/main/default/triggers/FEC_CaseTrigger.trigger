/**
 * Trigger Description: Case trigger delegate to Handler class
 * @created  : 2026/01/03 Toannd61
 * @modified : 2026/01/16
 */
trigger FEC_CaseTrigger on Case (before insert, before update, after insert, after update) {
    // Notification chạy độc lập, không bị ảnh hưởng bởi isExecuting guard
    if (Trigger.isAfter && Trigger.isUpdate) {
        FEC_NotificationService.sendEmailNotifications(Trigger.new, Trigger.oldMap);
        FEC_NotificationService.sendSFAppNotifications(Trigger.new, Trigger.oldMap);
    }
    FEC_CaseTriggerHandler.run();
}