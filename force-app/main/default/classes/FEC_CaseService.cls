public with sharing class FEC_CaseService {
  public static List<Case> getById(Set<Id> caseIds) {
    return [
      SELECT
        Id,
        FEC_KYC_Method__c,
        FEC_Product_Type__c,
        FEC_Channel__c,
        FEC_Interaction_Subchannel__c,
        CreatedDate,
        FEC_Account_or_Contract__c,
        FEC_Account_or_Contract__r.FEC_Plastic_ID__c,
        FEC_Account_or_Contract__r.FEC_Block_Code_1__c,
        FEC_Account_or_Contract__r.FEC_Card_Number__c,
        FEC_Search_Products__c
      FROM Case
      WHERE Id IN :caseIds
    ];
  }

  public static List<Case> getById(Set<Id> caseIdlst, Set<String> fieldlst) {
    fieldlst.add('Id');

    String soql =
      'SELECT ' +
      String.join(new List<String>(fieldlst), ', ') +
      ' FROM Case WHERE Id IN :caseIdlst';

    return Database.query(soql);
  }
}