trigger FEC_EmailMessageTrigger on EmailMessage (after insert) {
    FEC_EmailMessageTriggerHandler.run(Trigger.new);
}
