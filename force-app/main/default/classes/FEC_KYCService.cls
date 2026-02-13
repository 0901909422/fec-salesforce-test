public with sharing class FEC_KYCService {
  public static List<FEC_KYC__c> getByMethodAndProdType(
    Set<String> methodlst,
    Set<Id> prodTypelst
  ) {
    return [
      SELECT
        Id,
        FEC_KYC_Method__c,
        FEC_Product_Type__c,
        FEC_Product_Type__r.Name,
        FEC_KYC_Suggested_Answer__c,
        Name
      FROM FEC_KYC__c
      WHERE
        FEC_KYC_Method__c IN :methodlst
        AND FEC_Product_Type__c IN :prodTypelst
    ];
  }

  public static List<FEC_KYC__c> getByMethodAndProdTypeAndPlastic(
    Set<String> methodlst,
    Set<String> prodTypelst,
    Set<String> plasticIdlst
  ) {
    // Build INCLUDES ('A','B','C')
    List<String> plasticVals = new List<String>();
    for (String s : plasticIdlst) {
      if (String.isNotBlank(s))
        plasticVals.add('\'' + String.escapeSingleQuotes(s) + '\'');
    }

    String includesClause = String.join(plasticVals, ',');

    String soql =
      'SELECT ' +
      'Id, ' +
      'FEC_KYC_Method__c, ' +
      'FEC_Masking__c, ' +
      'FEC_Product_Type__c, ' +
      'FEC_Product_Type__r.Name, ' +
      'FEC_KYC_Suggested_Answer__c, ' +
      'Name ' +
      'FROM FEC_KYC__c ' +
      'WHERE FEC_KYC_Method__c IN :methodlst ' +
      'AND FEC_Product_Type__r.FEC_Code__c IN :prodTypelst ' +
      (String.isNotBlank(includesClause)
        ? ('AND FEC_Plastic_ID__c INCLUDES (' + includesClause + ')')
        : '');

    return Database.query(soql);
  }
}