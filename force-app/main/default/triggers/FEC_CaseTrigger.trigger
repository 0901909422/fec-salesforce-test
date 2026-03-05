/**
 * Trigger Description: Case trigger delegate to Handler class
 * @created  : 2026/01/03 Toannd61
 * @modified : 2026/01/16
 */
trigger FEC_CaseTrigger on Case (before insert, after insert, after update) {
    FEC_CaseTriggerHandler.run();
}