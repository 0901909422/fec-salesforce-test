trigger FEC_CaseRemarksTrigger on FEC_Case_Remarks__c(
  after insert,
  after update,
  after delete,
  after undelete
) {
  FEC_CaseRemarksTriggerHandler.run();
}