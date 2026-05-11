public without sharing class FEC_CaseRemarkController {
  @AuraEnabled
  public static List<FEC_Case_Remarks__c> getRemarklst(String caseId) {
    try {
      if (String.isBlank(caseId)) {
        return new List<FEC_Case_Remarks__c>();
      }

      List<FEC_Case_Remarks__c> result = new List<FEC_Case_Remarks__c>();

      List<Case> caselst = [
        SELECT Id, FEC_Draft_Remarks__c, FEC_Is_Submited__c
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
      ];
      // Case đã Submit thì không trả về draft → màn Execute hiển thị mới, không autofill dữ liệu cũ
      if (
        !caselst.isEmpty() &&
        caselst[0].FEC_Is_Submited__c != true &&
        String.isNotBlank(caselst[0].FEC_Draft_Remarks__c)
      ) {
        result.addAll(jsonToRemarks(caselst[0].FEC_Draft_Remarks__c));
      }

      String soql = 'SELECT Id, FEC_Case_Remarks__c, FEC_Stage_Name__c, FEC_User__c, FEC_User_Role__c, FEC_Remark_Type__c, CreatedDate ' +
        'FROM FEC_Case_Remarks__c ' +
        'WHERE FEC_Case__c = :caseId ' +
        'ORDER BY CreatedDate DESC';

      result.addAll((List<FEC_Case_Remarks__c>) Database.query(soql));

      return result;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static void createRemark(String remark, String caseId, String stageNameFromClient) {
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

      String stageName = String.isNotBlank(stageNameFromClient) ? stageNameFromClient : caselst[0].FEC_Stage_Name__c;
      FEC_Case_Remarks__c caseRemark = new FEC_Case_Remarks__c();
      caseRemark.FEC_Case_Remarks__c = remark;
      caseRemark.FEC_User__c = emailId;
      caseRemark.FEC_User_Role__c = roleName;
      caseRemark.FEC_Stage_Name__c = stageName;
      caseRemark.FEC_Case__c = caseId;

      List<FEC_Case_Remarks__c> existingRemarks = jsonToRemarks(
        caselst[0].FEC_Draft_Remarks__c
      );

      existingRemarks.add(caseRemark);
      caselst[0].FEC_Draft_Remarks__c = remarksToJson(existingRemarks);

      Database.update(caselst, AccessLevel.SYSTEM_MODE);
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /** Xóa draft Case Remarks trên Case (trước khi Submit để chỉ lưu 1 bản ghi = nội dung hiện tại). */
  @AuraEnabled
  public static void clearDraftRemarks(String caseId) {
    try {
      if (String.isBlank(caseId))
        return;
      List<Case> caselst = [
        SELECT Id, OwnerId, FEC_Draft_Remarks__c
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
      ];
      if (caselst.isEmpty())
        return;
      Case c = caselst[0];
      System.debug(
        'FEC_DBG clearDraftRemarks caseId=' +
          caseId +
          ' runUserId=' +
          UserInfo.getUserId() +
          ' profileId=' +
          UserInfo.getProfileId() +
          ' caseOwnerId=' +
          c.OwnerId +
          ' userIsOwner=' +
          (UserInfo.getUserId() == c.OwnerId)
      );
      c.FEC_Draft_Remarks__c = null;
      Database.update(caselst, AccessLevel.SYSTEM_MODE);
    } catch (Exception e) {
      System.debug(
        'FEC_DBG clearDraftRemarks ERROR msg=' +
          e.getMessage() +
          ' stack=' +
          e.getStackTraceString()
      );
      throw new AuraHandledException(e.getMessage());
    }
  }

  /** Submit chỉ tạo 1 bản ghi: lấy bản nháp mới nhất (phần tử cuối trong draft). */
  @AuraEnabled
  public static void submitRemark(String caseId, String stageNameFromClient) {    try {
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

      // Chỉ tạo 1 bản ghi = bản nháp mới nhất. Tránh double-submit: chỉ skip khi nội dung draft trùng với remark mới nhất đã lưu (cùng Case, trong 30s).
      if (!existingRemarks.isEmpty()) {
        FEC_Case_Remarks__c latestRemark = existingRemarks.get(
          existingRemarks.size() - 1
        );
        Datetime cutoff = Datetime.now().addSeconds(-30);
        List<FEC_Case_Remarks__c> recentForCase = [
          SELECT Id, FEC_Case_Remarks__c
          FROM FEC_Case_Remarks__c
          WHERE FEC_Case__c = :caseId
            AND CreatedDate >= :cutoff
          ORDER BY CreatedDate DESC
          LIMIT 1
        ];
        Boolean isDuplicate =
          !recentForCase.isEmpty() &&
          String.isNotBlank(latestRemark.FEC_Case_Remarks__c) &&
          latestRemark.FEC_Case_Remarks__c.equals(
            recentForCase[0].FEC_Case_Remarks__c
          );
        if (!isDuplicate) {
          latestRemark.FEC_Case__c = caseId;
          latestRemark.FEC_Stage_Name__c = String.isNotBlank(stageNameFromClient) ? stageNameFromClient : caselst[0].FEC_Stage_Name__c;
          insert latestRemark;
        }
      }

      caselst[0].FEC_Draft_Remarks__c = null;
      Database.update(caselst, AccessLevel.SYSTEM_MODE);
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /** tungnm37: Submit remark trực tiếp với content - dùng cho COF/GSR tránh duplicate do draft bị clear trước */
  @AuraEnabled
  public static void submitRemarkDirect(String caseId, String stageNameFromClient, String remarkContent) {
    try {
      if (String.isBlank(caseId) || String.isBlank(remarkContent)) return;

      List<User> userlst = [SELECT Id, Email, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId()];
      if (userlst.isEmpty()) return;

      String emailId = String.isNotBlank(userlst[0].Email) ? userlst[0].Email.substringBefore('@') : null;
      String roleName = userlst[0].UserRole?.Name;

      List<Case> caselst = [SELECT Id, FEC_Stage_Name__c FROM Case WHERE Id = :caseId LIMIT 1];
      if (caselst.isEmpty()) return;

      String stageName = String.isNotBlank(stageNameFromClient) ? stageNameFromClient : caselst[0].FEC_Stage_Name__c;

      // Tránh duplicate: kiểm tra remark giống nhau trong 30s
      Datetime cutoff = Datetime.now().addSeconds(-30);
      List<FEC_Case_Remarks__c> recentForCase = [
        SELECT Id, FEC_Case_Remarks__c FROM FEC_Case_Remarks__c
        WHERE FEC_Case__c = :caseId AND CreatedDate >= :cutoff ORDER BY CreatedDate DESC LIMIT 1
      ];
      Boolean isDuplicate = !recentForCase.isEmpty() && remarkContent.equals(recentForCase[0].FEC_Case_Remarks__c);
      if (isDuplicate) return;

      insert new FEC_Case_Remarks__c(
        FEC_Case__c = caseId,
        FEC_Case_Remarks__c = remarkContent,
        FEC_User__c = emailId,
        FEC_User_Role__c = roleName,
        FEC_Stage_Name__c = stageName
      );

      // Clear draft
      List<Case> caseToUpdate = [SELECT Id, FEC_Draft_Remarks__c FROM Case WHERE Id = :caseId LIMIT 1];
      if (!caseToUpdate.isEmpty()) {
        caseToUpdate[0].FEC_Draft_Remarks__c = null;
        Database.update(caseToUpdate, AccessLevel.SYSTEM_MODE);
      }
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