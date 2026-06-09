trigger FEC_ContentDocumentLinkTrigger on ContentDocumentLink(before insert, after insert, before delete) {
  FEC_ContentDocumentLinkTriggerHandler handler = new FEC_ContentDocumentLinkTriggerHandler();

  handler.run();
}