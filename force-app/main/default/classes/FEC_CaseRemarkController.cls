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

      result.addAll([
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
      ]);

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

      update caselst;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /** Xóa draft Case Remarks trên Case (trước khi Submit để chỉ lưu 1 bản ghi = nội dung hiện tại). */
  @AuraEnabled
  public static void clearDraftRemarks(String caseId) {
      try {
          System.debug('===== START clearDraftRemarks =====');
          System.debug('Input caseId: ' + caseId);
          System.debug('Running UserId: ' + UserInfo.getUserId());

          if (String.isBlank(caseId)) {
              System.debug('caseId is blank → EXIT');
              return;
          }

          // Check permission
          Boolean canUpdateCase = Schema.sObjectType.Case.isUpdateable();
          Boolean canUpdateField = Schema.sObjectType.Case.fields.FEC_Draft_Remarks__c.isUpdateable();

          System.debug('Can update Case: ' + canUpdateCase);
          System.debug('Can update FEC_Draft_Remarks__c: ' + canUpdateField);

          if (!canUpdateCase || !canUpdateField) {
              throw new AuraHandledException('No permission to update Case or field');
          }

          List<Case> caselst = [
              SELECT Id, OwnerId, FEC_Draft_Remarks__c
              FROM Case
              WHERE Id = :caseId
              LIMIT 1
          ];

          System.debug('Query result size: ' + caselst.size());

          if (caselst.isEmpty()) {
              System.debug('No Case found → EXIT');
              return;
          }

          Case c = caselst[0];

          System.debug('Case Id: ' + c.Id);
          System.debug('Case OwnerId: ' + c.OwnerId);
          System.debug('Draft before clear: ' + c.FEC_Draft_Remarks__c);

          // Check lock
          Boolean isLocked = Approval.isLocked(c.Id);
          System.debug('Is Case Locked: ' + isLocked);

          if (isLocked) {
              System.debug('Trying to unlock Case...');
              try {
                  Approval.unlock(c.Id);
                  System.debug('Unlock SUCCESS');
              } catch (Exception unlockEx) {
                  System.debug('Unlock FAILED: ' + unlockEx.getMessage());
                  throw new AuraHandledException('Case is locked, cannot update');
              }
          }

          // Clear field
          c.FEC_Draft_Remarks__c = null;

          System.debug('Updating Case...');

          update c;

          System.debug('Update SUCCESS');
          System.debug('===== END clearDraftRemarks =====');

      } catch (Exception e) {
          System.debug('❌ ERROR clearDraftRemarks: ' + e.getMessage());
          System.debug('StackTrace: ' + e.getStackTraceString());
          throw new AuraHandledException(e.getMessage());
      }
  }

  /** Submit chỉ tạo 1 bản ghi: lấy bản nháp mới nhất (phần tử cuối trong draft). */
  @AuraEnabled
  public static void submitRemark(String caseId, String stageNameFromClient) {
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