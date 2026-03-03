public with sharing class FEC_KYCResultService {
  public static List<FEC_KYC_Result__c> getByCase(Set<Id> caseIdlst) {
    return [
      SELECT
        Id,
        FEC_Case_Interaction__c,
        FEC_KYC__c,
        FEC_Status__c,
        FEC_Editable__c
      FROM FEC_KYC_Result__c
      WHERE FEC_Case_Interaction__c IN :caseIdlst
      ORDER BY CreatedDate
    ];
  }
}