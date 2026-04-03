/**
 * Trigger Description: EmailMessage trigger delegate to Handler class
 * @created  : 2026/04/03
 */
trigger FEC_EmailMessageTrigger on EmailMessage (after insert) {
    FEC_EmailMessageTriggerHandler.run(Trigger.new);
}
