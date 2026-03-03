trigger FEC_ContentDocumentTrigger on ContentDocument(before delete) {
  FEC_ContentDocumentTriggerHandler handler = new FEC_ContentDocumentTriggerHandler();
  handler.run();
}