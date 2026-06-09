/**
 * Trigger Description: FEC_Template__c trigger – delegates to Handler class.
 * @created  : 2026/03/12
 */
trigger FEC_TemplateTrigger on FEC_Template__c (before insert, before update) {
    FEC_TemplateTriggerHandler.run();
}