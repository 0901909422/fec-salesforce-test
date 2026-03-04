trigger FEC_ContentVersionTrigger on ContentVersion(before insert, before update) {
  FEC_ContentVersionTriggerHandler handler = new FEC_ContentVersionTriggerHandler();
  handler.run();
}