public with sharing class FEC_CaseRemarkController {
  @AuraEnabled
  public static List<FEC_Case_Remarks__c> getRemarklst(String caseId) {
    try {
      if (String.isNotBlank(caseId)) {
        return [
          SELECT
            Id,
            FEC_Case_Remarks__c,
            FEC_Stage_Name__c,
            FEC_User__c,
            FEC_User_Role__c,
            CreatedDate
          FROM FEC_Case_Remarks__c
          WHERE FEC_Case__c = :caseId
          ORDER BY CreatedDate DESC
        ];
      }

      return new List<FEC_Case_Remarks__c>();
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static void createRemark(String remark, String caseId) {
    try {
      List<User> userlst = [
        SELECT Id, Email, UserRole.Name
        FROM User
        WHERE Id = :UserInfo.getUserId()
      ];

      if (userlst.isEmpty())
        return;

      List<Case> caselst = [
        SELECT Id, FEC_Stage_Name__c, FEC_Draft_Remarks__c
        FROM Case
        WHERE Id = :caseId
      ];

      if (caselst.isEmpty())
        return;

      String emailId;
      if (String.isNotBlank((userlst.get(0).Email))) {
        emailId = userlst[0].Email.substringBefore('@');
      }

      String roleName = userlst.get(0).UserRole?.Name;

      FEC_Case_Remarks__c caseRemark = new FEC_Case_Remarks__c();
      caseRemark.FEC_Case_Remarks__c = remark;
      caseRemark.FEC_User__c = emailId;
      caseRemark.FEC_User_Role__c = roleName;
      caseRemark.FEC_Stage_Name__c = caselst[0].FEC_Stage_Name__c;
      caseRemark.FEC_Case__c = caseId;

      List<FEC_Case_Remarks__c> existingRemarks = jsonToRemarks(
        caselst[0].FEC_Draft_Remarks__c
      );

      existingRemarks.add(caseRemark);
      caselst[0].FEC_Draft_Remarks__c = remarksToJson(existingRemarks);

      update caselst;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static void submitRemark(String caseId) {
    try {
      List<Case> caselst = [
        SELECT Id, FEC_Stage_Name__c, FEC_Draft_Remarks__c
        FROM Case
        WHERE Id = :caseId
      ];

      if (caselst.isEmpty())
        return;

      List<FEC_Case_Remarks__c> existingRemarks = jsonToRemarks(
        caselst[0].FEC_Draft_Remarks__c
      );

      if (!existingRemarks.isEmpty())
        insert existingRemarks;

      caselst[0].FEC_Draft_Remarks__c = null;
      update caselst;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  private static String remarksToJson(List<FEC_Case_Remarks__c> remarks) {
    if (remarks == null || remarks.isEmpty()) {
      return null;
    }
    return JSON.serialize(remarks);
  }

  private static List<FEC_Case_Remarks__c> jsonToRemarks(String jsonStr) {
    if (String.isBlank(jsonStr)) {
      return new List<FEC_Case_Remarks__c>();
    }

    return (List<FEC_Case_Remarks__c>) JSON.deserialize(
      jsonStr,
      List<FEC_Case_Remarks__c>.class
    );
  }
}