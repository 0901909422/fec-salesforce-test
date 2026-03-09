/**
 * Class Description: Controller class xử lý Interaction SLA và Outcome cho LWC
 * @created  : 2026/01/03 Toannd61
 * @modified :    
 */
public with sharing class FEC_InteractionSLAController {

  /**
   * Method Description: Lấy thông tin Case theo ID
   * @param recordId ID của Case
   * @return Case Thông tin Case
   * @created: 2026/01/03 Toannd61
   * @modified:  
   */
  @AuraEnabled
  public static Case getCase(String recordId) {
    try {
      // Thêm các field cần thiết cho LWC kiểm tra wrap-up
      Set<String> fields = new Set<String>{
        'Id',
        'FEC_KYC_Method__c',
        'FEC_Product_Type__c',
        'FEC_Channel__c',
        'FEC_Interaction_Subchannel__c',
        'CreatedDate',
        'FEC_Is_Submited__c',
        'RecordType.DeveloperName',
        'IsClosed'
      };
      
      List<Case> caselst = FEC_CaseService.getById(new Set<Id>{ recordId }, fields);

      if (caselst.isEmpty())
        return null;

      return caselst.get(0);
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getOutcomeCodePicklistValues() {
    try {
      List<Map<String, String>> options = new List<Map<String, String>>();
      Schema.DescribeFieldResult fieldResult = Case.FEC_Interaction_Outcome_Status__c.getDescribe();
      List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
      for (Schema.PicklistEntry entry : picklistValues) {
        if (entry.isActive()) {
          Map<String, String> option = new Map<String, String>();
          option.put('label', entry.getLabel());
          option.put('value', entry.getValue());
          options.add(option);
        }
      }
      return options;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getQuickOutcomeCodePicklistValues() {
    try {
      List<Map<String, String>> options = new List<Map<String, String>>();
      Schema.DescribeFieldResult fieldResult = Case.FEC_Outcome_Code__c.getDescribe();
      List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
      for (Schema.PicklistEntry entry : picklistValues) {
        if (entry.isActive()) {
          Map<String, String> option = new Map<String, String>();
          option.put('label', entry.getLabel());
          option.put('value', entry.getValue());
          options.add(option);
        }
      }
      return options;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static void updateInteractionOutcome(String recordId, String outcomeCode, String interactionRemarks) {
    try {
      // Nếu record có FEC_Interaction__c = case con (link tới Interaction cha) → chỉ đóng Interaction cha, không đóng case con
      Id targetId = recordId;
      List<Case> cases = [SELECT Id, FEC_Interaction__c FROM Case WHERE Id = :recordId LIMIT 1];
      if (!cases.isEmpty() && cases[0].FEC_Interaction__c != null) {
        targetId = cases[0].FEC_Interaction__c;
      }
      
      Case interaction = new Case(
        Id = targetId,
        FEC_Outcome_Code__c = outcomeCode,
        Status = FEC_ConstantCommon.INTERACTION_STATUS_CLOSED,
        FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_REVIEW_MODE
      );
      
      // Update FEC_Interaction_Remarks__c field with Interaction Remarks if provided
      if (String.isNotBlank(interactionRemarks)) {
        interaction.FEC_Interaction_Remarks__c = interactionRemarks;
      }
      
      update interaction;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static void updateInteractionQuickWrapUp(String recordId, String outcomeCode) {
    try {
      // Nếu record có FEC_Interaction__c = case con → chỉ đóng Interaction cha, không đóng case con
      Id targetId = recordId;
      List<Case> cases = [SELECT Id, FEC_Interaction__c FROM Case WHERE Id = :recordId LIMIT 1];
      if (!cases.isEmpty() && cases[0].FEC_Interaction__c != null) {
        targetId = cases[0].FEC_Interaction__c;
      }

      Case interaction = new Case(
        Id = targetId,
        FEC_Outcome_Code__c = outcomeCode,
        Status = FEC_ConstantCommon.INTERACTION_STATUS_CLOSED,
        FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_REVIEW_MODE
      );
      
      update interaction;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * Method Description: Đếm số lượng Case liên quan đến Interaction
   * @param recordId ID của Interaction
   * @return Integer Số lượng Case liên quan
   * @created: 2026/02/03
   * @modified:  
   */
  @AuraEnabled
  public static Integer getRelatedCasesCount(String recordId) {
    try {
      return [SELECT COUNT() FROM Case WHERE FEC_Interaction__c = :recordId];
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * Method Description: Kiểm tra xem có Case nào chưa submit không
   * @param recordId ID của Interaction
   * @return Boolean True nếu có Case chưa submit, False nếu tất cả đã submit
   * @created: 2026/02/04
   * @modified:  
   */
  @AuraEnabled
  public static Boolean hasUnsubmittedCases(String recordId) {
    try {
      Integer count = [SELECT COUNT() FROM Case WHERE FEC_Interaction__c = :recordId AND FEC_Is_Submited__c = FALSE];
      return count > 0;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * Method Description: Kiểm tra các Case đã được submit
   * @param recordId ID của Interaction
   * @return Boolean True nếu tất cả đã submit
   * @created: 2026/02/04
   * @modified:  
   */
  @AuraEnabled
  public static Boolean hasSubmittedCases(String recordId){
    try {
      Integer total = [SELECT COUNT() FROM Case WHERE FEC_Interaction__c = :recordId];
      Integer submitted = [SELECT COUNT() FROM Case WHERE FEC_Interaction__c = :recordId AND FEC_Is_Submited__c = TRUE];
      return total > 0 && total == submitted;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }
}