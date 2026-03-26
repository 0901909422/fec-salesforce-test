public with sharing class FEC_CreateCaseInteractionController {
  @AuraEnabled
  public static Id createCustomerCaseFromCase(Id caseId) {
    Case interation = [
      SELECT Id, FEC_Account_or_Contract__c, FEC_Account_or_Contract__r.FEC_Customer_Name__c,
             FEC_Product_Type__c, FEC_Phone_Number__c,
             FEC_Account_Number__c, FEC_Contract_Number__c, FEC_CIF_Number__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    
    Id customerCaseRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)
      .getRecordTypeId();
    
    Case newCase = new Case();
    newCase.RecordTypeId = customerCaseRtId;
    newCase.OwnerId = UserInfo.getUserId(); 
    newCase.FEC_Account_or_Contract__c = interation.FEC_Account_or_Contract__c;
    newCase.Status = FEC_ConstantCommon.CASE_STATUS_OPEN;
    newCase.Origin = FEC_ConstantCommon.CASE_WEB_ORIGIN;
    newCase.FEC_Customer_Type__c = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER;
    newCase.FEC_Interaction__c = caseId;
    newCase.FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE;
    newCase.FEC_Customer_Name__c = interation.FEC_Account_or_Contract__r?.FEC_Customer_Name__c;
    newCase.FEC_Product_Type__c = interation.FEC_Product_Type__c;
    newCase.FEC_Phone_Number__c = interation.FEC_Phone_Number__c;
    newCase.FEC_Account_Number__c = interation.FEC_Account_Number__c;
    newCase.FEC_Contract_Number__c = interation.FEC_Contract_Number__c;
    newCase.FEC_CIF_Number__c = interation.FEC_CIF_Number__c;
    
    insert newCase;
    
    FEC_Additional_Info__c newInfo = new FEC_Additional_Info__c(
      FEC_Case__c = newCase.Id
      );
    insert newInfo;
    
    List<FEC_KYC_Result__c> kycResults = [SELECT Id, FEC_Editable__c FROM FEC_KYC_Result__c WHERE FEC_Case_Interaction__c = :interation.Id];
    for (FEC_KYC_Result__c kycResult : kycResults) {
      kycResult.FEC_Editable__c = false;
    }
    if (!kycResults.isEmpty()) {
      update kycResults;
    }
    
    return newCase.Id;
  }
  
  @AuraEnabled
  public static Id createCustomerCaseFromCaseNonExistingCustomer(
    Id caseId,
  String customerName,
  String nationalPassportId,
  String isCreatedFromSearch
  ) {
    try {
      // 1. Validate input
      if (caseId == null) {
        throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'}));
      }
      
      // 2. Get interaction case
      Case interaction = [
        SELECT Id, FEC_Account_or_Contract__r.FEC_Customer_Name__c, FEC_Product_Type__c, FEC_Phone_Number__c,
               FEC_Customer_Type__c, FEC_Account_or_Contract__c,
               FEC_Account_Number__c, FEC_Contract_Number__c, FEC_CIF_Number__c
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
      ];
      
      // 3. Get RecordType safely
      Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
      
      if (
        !rtMap.containsKey(
        FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME
        )
      ) {
        throw new AuraHandledException(
        String.format(System.Label.FEC_MSG_Not_Found, new List<String>{FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME})
        );
      }
      
      Id customerCaseRtId = rtMap.get(
        FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME
        )
        .getRecordTypeId();
      
      Case newCase = new Case();
      newCase.RecordTypeId = customerCaseRtId;
      newCase.OwnerId = UserInfo.getUserId();
      newCase.FEC_Customer_Name__c = customerName;
      newCase.FEC_National_ID_Passport_ID__c = nationalPassportId;
      newCase.Status = FEC_ConstantCommon.CASE_STATUS_NEW;
      newCase.Origin = FEC_ConstantCommon.CASE_WEB_ORIGIN;
      newCase.FEC_Customer_Type__c = FEC_ConstantCommon.CUSTOMER_HISTORY_NON_EXISTING_CUSTOMER;
      newCase.FEC_Interaction__c = interaction.Id;
      newCase.FEC_Account_Contract_Number_PL__c = FEC_ConstantCommon.PRODUCT_NON_EXISTING_CUSTOMER;
      newCase.FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE;
      newCase.FEC_Product_Type__c = interaction.FEC_Product_Type__c;
      newCase.FEC_Phone_Number__c = interaction.FEC_Phone_Number__c;
      newCase.FEC_Account_Number__c = interaction.FEC_Account_Number__c;
      newCase.FEC_Contract_Number__c = interaction.FEC_Contract_Number__c;
      newCase.FEC_CIF_Number__c = interaction.FEC_CIF_Number__c;

      if (isCreatedFromSearch == 'true') {
        newCase.FEC_Is_Created_From_Search__c = true;
      }
      
      insert newCase;
      
      FEC_Additional_Info__c newInfo = new FEC_Additional_Info__c(
        FEC_Case__c = newCase.Id
        );
      insert newInfo;
      
      FEC_Customer_History__c newHistory = createHistoryNonExistingCustomer(interaction.Id, customerName);

      interaction.FEC_Customer_Type__c = FEC_ConstantCommon.CUSTOMER_HISTORY_NON_EXISTING_CUSTOMER;
      interaction.FEC_Account_or_Contract__c = newHistory.Id;
      update interaction;

      newCase.FEC_Account_or_Contract__c = newHistory.Id;
      update newCase;
      
      return newCase.Id;
    } catch (Exception e) {
      throw new AuraHandledException(
        e.getMessage()
        );
    }
  }
  
  @AuraEnabled
  public static FEC_Customer_History__c  createHistoryNonExistingCustomer(Id caseId, String customerName) {
    
    FEC_Customer_History__c rec = new FEC_Customer_History__c();
    rec.Name = FEC_ConstantCommon.PRODUCT_NON_EXISTING_CUSTOMER;
    rec.FEC_Customer_Type__c = FEC_ConstantCommon.CUSTOMER_HISTORY_NON_EXISTING_CUSTOMER;
    rec.FEC_Customer_Name__c = customerName;
    rec.FEC_Account_Number__c = FEC_ConstantCommon.PRODUCT_NON_EXISTING_CUSTOMER;
    rec.FEC_Case__c = caseId;
    rec.FEC_Product_Code__c = FEC_ConstantCommon.PRODUCT_NON_EXISTING_CUSTOMER;
    try {
      insert rec;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
    return rec;
  }
}