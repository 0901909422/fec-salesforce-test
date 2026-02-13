public with sharing class FEC_CreateCaseInteractionController {
  @AuraEnabled
  public static Id createCustomerCaseFromCase(Id caseId) {
    Case interation = [
      SELECT Id, FEC_Account_or_Contract__c, FEC_Account_or_Contract__r.FEC_Customer_Name__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];

    Id customerCaseRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get('Customer_Case')
      .getRecordTypeId();

    Case newCase = new Case();
    newCase.RecordTypeId = customerCaseRtId;
    newCase.FEC_Account_or_Contract__c = interation.FEC_Account_or_Contract__c;
    newCase.Status = 'Open';
    newCase.Origin = 'Web';
    newCase.FEC_Customer_Type__c = 'Existing';
    newCase.FEC_Interaction__c = caseId;
    newCase.FEC_Interaction_View_Mode__c = 'handling';
    newCase.FEC_Customer_Name__c = interation.FEC_Account_or_Contract__r?.FEC_Customer_Name__c;

    insert newCase;

    FEC_Additional_Info__c newInfo = new FEC_Additional_Info__c(
      FEC_Case__c = newCase.Id
    );
    insert newInfo;

    return newCase.Id;
  }

  @AuraEnabled
  public static Id createCustomerCaseFromCaseNonExistingCustomer(
    Id caseId,
    String customerName,
    String nationalPassportId
  ) {
    try {
      // 1. Validate input
      if (caseId == null) {
        throw new AuraHandledException('caseId is required');
      }

      // 2. Get interaction case
      Case interaction = [
        SELECT Id, FEC_Account_or_Contract__r.FEC_Customer_Name__c
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
      ];

      // Id customerCaseRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
      //   .get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)
      //   .getRecordTypeId();
      // 3. Get RecordType safely
      Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();

      if (
        !rtMap.containsKey(
          FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME
        )
      ) {
        throw new AuraHandledException(
          'RecordType not found: ' +
          FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME
        );
      }

      Id customerCaseRtId = rtMap.get(
          FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME
        )
        .getRecordTypeId();

      Case newCase = new Case();
      newCase.RecordTypeId = customerCaseRtId;
      newCase.FEC_Customer_Name__c = customerName;
      newCase.FEC_National_ID_Passport_ID__c = nationalPassportId;
      newCase.Status = FEC_ConstantCommon.CASE_STATUS_NEW;
      newCase.Origin = FEC_ConstantCommon.CASE_WEB_ORIGIN;
      newCase.FEC_Customer_Type__c = FEC_ConstantCommon.CASE_NON_EXISTING_CUSTOMER;
      newCase.FEC_Interaction__c = interaction.Id;
      newCase.FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE;
      newCase.FEC_Customer_Name__c = interaction.FEC_Account_or_Contract__r?.FEC_Customer_Name__c;
      insert newCase;

      FEC_Additional_Info__c newInfo = new FEC_Additional_Info__c(
        FEC_Case__c = newCase.Id
      );
      insert newInfo;

      // 5. Update Customer History (safe)
      // List<FEC_Customer_History__c> histories = [
      //   SELECT Id, FEC_Customer_Type__c, FEC_Customer_Name__c
      //   FROM FEC_Customer_History__c
      //   WHERE FEC_Case__c = :caseId
      //   LIMIT 1
      // ];

      // if (!histories.isEmpty()) {
      //   histories[0].Name =
      //     'Non-Existing Customer - ' +
      //     customerName +
      //     ' - ' +
      //     Datetime.now().format('yyyy-MM-dd HH:mm:ss');
      //   histories[0]
      //     .FEC_Customer_Type__c = FEC_ConstantCommon.CUSTOMER_HISTORY_NON_EXISTING_CUSTOMER;
      //   histories[0].FEC_Customer_Name__c = customerName;
      //   update histories[0];
      // }

      return newCase.Id;
    } catch (Exception e) {
      throw new AuraHandledException(
        'createCustomerCaseFromCaseNonExistingCustomer failed: ' +
        e.getMessage()
      );
    }
  }
}