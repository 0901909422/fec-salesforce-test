/**
 * Class Description: Controller class xử lý Interaction SLA và Outcome cho LWC
 * @created  : 2026/01/03 Toannd61
 * @modified :    
 */
public with sharing class FEC_InteractionSLAController {

  // Outcome codes theo điều kiện: Inbound + Inbound Call
  private static final Set<String> OUTCOME_CODES_INBOUND_CALL = new Set<String>{
    'Hoàn tất/ Đã phản hồi', 'Liên hệ lại sau', 'Rớt cuộc/ Cúp máy ngang', 'Không có/ Mất tín hiệu',
    'Nhầm line', 'Chuyển line', 'Gặp người thân', 'Lỗi hệ thống', 'Test'
  };
  // Outbound + Outbound Call
  private static final Set<String> OUTCOME_CODES_OUTBOUND_CALL = new Set<String>{
    'Hoàn tất/ Đã phản hồi', 'Liên hệ lại sau', 'Rớt cuộc/ Cúp máy ngang', 'Không có/ Mất tín hiệu',
    'Hộp thư thoại', 'Nhầm số', 'Gặp người thân', 'Lỗi hệ thống', 'Test'
  };
  // Email + Incoming Email
  private static final Set<String> OUTCOME_CODES_EMAIL_INCOMING = new Set<String>{
    'Hoàn tất/ Đã phản hồi', 'Thư rác', 'Lỗi hệ thống', 'Test'
  };
  // Email + Outgoing Email
  private static final Set<String> OUTCOME_CODES_EMAIL_OUTGOING = new Set<String>{
    'Hoàn tất/ Đã phản hồi', 'Lỗi hệ thống', 'Test'
  };
  // Chat + (Facebook / Zalo / Website / Mobile App)
  private static final Set<String> OUTCOME_CODES_CHAT = new Set<String>{
    'Hoàn tất/ Đã phản hồi', 'Liên hệ lại sau', 'Mất kết nối', 'Lỗi hệ thống', 'Test'
  };
  private static final Set<String> CHAT_SUBCHANNELS = new Set<String>{
    'Facebook', 'Zalo', 'Website', 'Mobile App', 'Mobile App Chat'
  };
  // F2F + F2F | Letter + Letter | Internal (Email/Task/Other) | External
  private static final Set<String> OUTCOME_CODES_F2F = new Set<String>{ 'Hoàn tất/ Đã phản hồi', 'Lỗi hệ thống', 'Test' };
  private static final Set<String> OUTCOME_CODES_LETTER = new Set<String>{ 'Hoàn tất/ Đã phản hồi', 'Lỗi hệ thống', 'Test' };
  private static final Set<String> OUTCOME_CODES_INTERNAL_EMAIL = new Set<String>{ 'Hoàn tất/ Đã phản hồi', 'Thư rác', 'Lỗi hệ thống', 'Test' };
  private static final Set<String> OUTCOME_CODES_INTERNAL_TASK = new Set<String>{ 'Hoàn tất/ Đã phản hồi', 'Lỗi hệ thống', 'Test' };
  private static final Set<String> OUTCOME_CODES_INTERNAL_OTHER = new Set<String>{ 'Hoàn tất/ Đã phản hồi', 'Lỗi hệ thống', 'Test' };
  private static final Set<String> INTERNAL_OTHER_SUBCHANNELS = new Set<String>{ 'iCollect', 'iSale', 'Vtiger' };
  private static final Set<String> OUTCOME_CODES_EXTERNAL = new Set<String>{ 'Hoàn tất/ Đã phản hồi', 'Lỗi hệ thống', 'Test' };
  private static final Set<String> EXTERNAL_SUBCHANNELS = new Set<String>{ 'SBV', 'EA', 'VPBank' };
  // Customer Type áp dụng cho Inbound/Outbound Call: Existing, Non-existing
  private static final Set<String> CUSTOMER_TYPES_FOR_CALL = new Set<String>{ 'Existing', 'Non-existing' };

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

  /**
   * Lấy danh sách Outcome Code được phép chọn theo Channel + Sub Channel + Customer Type của Case (Interaction).
   * Điều kiện Inbound/Outbound Call: FEC_Customer_Type__c = Existing hoặc Non-existing.
   * @param recordId Id Case (Interaction hoặc Case con)
   * @return Danh sách option {label, value} đã lọc
   */
  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getOutcomeCodeOptionsByContext(String recordId) {
    try {
      Id targetId = recordId;
      List<Case> cases = [SELECT Id, FEC_Interaction__c, FEC_Channel__c, FEC_Interaction_Subchannel__c, FEC_Customer_Type__c FROM Case WHERE Id = :recordId LIMIT 1];
      if (!cases.isEmpty() && cases[0].FEC_Interaction__c != null) {
        targetId = cases[0].FEC_Interaction__c;
      }
      String channel = null;
      String subChannel = null;
      String customerType = null;
      if (targetId != null) {
        List<Case> interactionCases = [SELECT FEC_Channel__c, FEC_Interaction_Subchannel__c, FEC_Customer_Type__c FROM Case WHERE Id = :targetId LIMIT 1];
        if (!interactionCases.isEmpty()) {
          channel = interactionCases[0].FEC_Channel__c;
          subChannel = interactionCases[0].FEC_Interaction_Subchannel__c;
          customerType = interactionCases[0].FEC_Customer_Type__c;
        }
      }
      Set<String> allowedValues = null;
      Boolean isCallCustomerTypeAllowed = (customerType != null && CUSTOMER_TYPES_FOR_CALL.contains(customerType));
      if (channel == 'Inbound' && subChannel == 'Inbound Call' && isCallCustomerTypeAllowed) {
        allowedValues = OUTCOME_CODES_INBOUND_CALL;
      } else if (channel == 'Outbound' && subChannel == 'Outbound Call' && isCallCustomerTypeAllowed) {
        allowedValues = OUTCOME_CODES_OUTBOUND_CALL;
      } else if (channel == 'Email' && subChannel == 'Incoming Email' && isCallCustomerTypeAllowed) {
        allowedValues = OUTCOME_CODES_EMAIL_INCOMING;
      } else if (channel == 'Email' && subChannel == 'Outgoing Email' && isCallCustomerTypeAllowed) {
        allowedValues = OUTCOME_CODES_EMAIL_OUTGOING;
      } else if (channel == 'Chat' && subChannel != null && CHAT_SUBCHANNELS.contains(subChannel) && isCallCustomerTypeAllowed) {
        allowedValues = OUTCOME_CODES_CHAT;
      } else if (channel == 'F2F' && subChannel == 'F2F' && isCallCustomerTypeAllowed) {
        allowedValues = OUTCOME_CODES_F2F;
      } else if (channel == 'Letter' && subChannel == 'Letter' && isCallCustomerTypeAllowed) {
        allowedValues = OUTCOME_CODES_LETTER;
      } else if (channel == 'Internal' && subChannel == 'Internal Email') {
        allowedValues = OUTCOME_CODES_INTERNAL_EMAIL;
      } else if (channel == 'Internal' && subChannel == 'Internal Task') {
        allowedValues = OUTCOME_CODES_INTERNAL_TASK;
      } else if (channel == 'Internal' && subChannel != null && INTERNAL_OTHER_SUBCHANNELS.contains(subChannel)) {
        allowedValues = OUTCOME_CODES_INTERNAL_OTHER;
      } else if (channel == 'External' && subChannel != null && EXTERNAL_SUBCHANNELS.contains(subChannel)) {
        allowedValues = OUTCOME_CODES_EXTERNAL;
      }
      List<Map<String, String>> options = new List<Map<String, String>>();
      Schema.DescribeFieldResult fieldResult = Case.FEC_Outcome_Code__c.getDescribe();
      List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
      for (Schema.PicklistEntry entry : picklistValues) {
        if (entry.isActive() && (allowedValues == null || allowedValues.contains(entry.getValue()))) {
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