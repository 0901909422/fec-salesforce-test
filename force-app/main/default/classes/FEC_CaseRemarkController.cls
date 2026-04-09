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
      String traceId = String.valueOf(Crypto.getRandomLong());

      try {
          System.debug('===== START clearDraftRemarks | TRACE: ' + traceId + ' =====');

          // ===== CONTEXT =====
          System.debug('UserId: ' + UserInfo.getUserId());
          System.debug('ProfileId: ' + UserInfo.getProfileId());
          System.debug('UserRoleId: ' + UserInfo.getUserRoleId());
          System.debug('OrgId: ' + UserInfo.getOrganizationId());
          System.debug('Input caseId: ' + caseId);

          if (String.isBlank(caseId)) {
              System.debug('caseId is blank → EXIT');
              return;
          }

          // ===== PERMISSION CHECK =====
          Boolean canUpdateCase = Schema.sObjectType.Case.isUpdateable();
          Boolean canReadCase = Schema.sObjectType.Case.isAccessible();
          Boolean canUpdateField = Schema.sObjectType.Case.fields.FEC_Draft_Remarks__c.isUpdateable();

          System.debug('Case Accessible: ' + canReadCase);
          System.debug('Case Updateable: ' + canUpdateCase);
          System.debug('Field Updateable: ' + canUpdateField);

          // ===== QUERY =====
          List<Case> caselst = [
              SELECT Id, OwnerId, CreatedById, LastModifiedById,
                    FEC_Draft_Remarks__c
              FROM Case
              WHERE Id = :caseId
              LIMIT 1
          ];

          System.debug('Query size: ' + caselst.size());

          if (caselst.isEmpty()) {
              System.debug('No Case found → EXIT');
              return;
          }

          Case c = caselst[0];

          // ===== RECORD CONTEXT =====
          System.debug('CaseId: ' + c.Id);
          System.debug('OwnerId: ' + c.OwnerId);
          System.debug('CreatedById: ' + c.CreatedById);
          System.debug('LastModifiedById: ' + c.LastModifiedById);
          System.debug('Draft Length: ' + (c.FEC_Draft_Remarks__c != null ? c.FEC_Draft_Remarks__c.length() : 0));

          // ===== LOCK CHECK =====
          Boolean isLocked = Approval.isLocked(c.Id);
          System.debug('IsLocked: ' + isLocked);

          if (isLocked) {
              System.debug('Attempting unlock...');
              try {
                  Approval.unlock(c.Id);
                  System.debug('Unlock SUCCESS');
              } catch (Exception unlockEx) {
                  System.debug('Unlock FAILED: ' + unlockEx.getMessage());
                  System.debug('Unlock Stack: ' + unlockEx.getStackTraceString());
                  throw new AuraHandledException('Case is locked and cannot be updated');
              }
          }

          // ===== SHARING DEBUG =====
          System.debug('Running as without sharing → bypass sharing, but still checking context');
          System.debug('Current User == Owner? ' + (UserInfo.getUserId() == c.OwnerId));

          // ===== DML PREP =====
          c.FEC_Draft_Remarks__c = null;

          System.debug('Prepared record for update');

          // ===== TRY UPDATE =====
          try {
              System.debug('Executing update...');
              update c;
              System.debug('Update SUCCESS');
          } catch (DmlException dmlEx) {
              System.debug('❌ DML ERROR: ' + dmlEx.getMessage());
              System.debug('DML StatusCode: ' + dmlEx.getDmlType(0));
              System.debug('DML Fields: ' + dmlEx.getDmlFields(0));
              System.debug('DML Stack: ' + dmlEx.getStackTraceString());

              // Deep hint
              if (dmlEx.getMessage().contains('INSUFFICIENT_ACCESS')) {
                  System.debug('👉 ROOT CAUSE HINT: Permission / Sharing / Lock issue');
              }

              throw new AuraHandledException(dmlEx.getMessage());
          }

          System.debug('===== END clearDraftRemarks | TRACE: ' + traceId + ' =====');

      } catch (Exception e) {
          System.debug('❌ FATAL ERROR | TRACE: ' + traceId);
          System.debug('Message: ' + e.getMessage());
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