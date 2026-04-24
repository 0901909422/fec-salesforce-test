/**
 * Ghi đè hiển thị / Route to Team & Queue theo nghiệp vụ:
 * 1) Case có Interaction + Category Request + RC09 (điện thoại/địa chỉ) → Team SP, queue FEC_DQ_CS_Support.
 * 2) Customer History Block Code → Team OM, queue FEC_Day_2_Check.
 * Tách khỏi FEC_CaseBusinessService để dễ bảo trì.
 * @author Toannd61
 */
public without sharing class FEC_BlockCodeRoutingService {
  // --- Block Code → OM / Day 2 ---
  private static final Set<String> BLOCK_CODE_VALUES_OM_DAY2 = new Set<String>{
    'F',
    'S',
    'G',
    'N'
  };
  private static final Set<String> BLOCK_CODE1_VALUES_OM_DAY2 = new Set<String>{
    'F',
    'G',
    'N'
  };
  private static final String TEAM_DISPLAY_OM = 'OM';

  // --- Interaction + RC09 sibling + current RC27 → SP / DQ CS Support ---
  private static final String TEAM_DISPLAY_SP = 'SP';
  private static final String REQUEST_CATEGORY_NAME = 'Request';
  private static final String INTERACTION_RC09_SUBCATEGORY_NAME = 'RC09-Cập nhật thông tin';
  private static final Set<String> INTERACTION_RC09_SUBCODE_NAMES = new Set<String>{
    'RC09.01-Cập nhật số điện thoại',
    'RC09.02-Cập nhật địa chỉ'
  };
  private static final String CURRENT_RC27_SUBCATEGORY_NAME = 'RC27-Thay thế thẻ';
  private static final Set<String> CURRENT_RC27_SUBCODE_NAMES = new Set<String>{
    'RC27.01-Có phí',
    'RC27.02-Miễn phí'
  };

  /** @author Toannd61 */
  public static Boolean isBlockCodePairForcedOmDay2(
    String blockCode,
    String blockCode1
  ) {
    String bc = blockCode != null ? blockCode.trim() : null;
    String bc1 = blockCode1 != null ? blockCode1.trim() : null;
    return (String.isNotBlank(bc) && BLOCK_CODE_VALUES_OM_DAY2.contains(bc)) ||
      (String.isNotBlank(bc1) && BLOCK_CODE1_VALUES_OM_DAY2.contains(bc1));
  }

  /** @author Toannd61 */
  public static Boolean isCustomerHistoryForcedOmDay2(Id customerHistoryId) {
    if (customerHistoryId == null) {
      return false;
    }
    List<FEC_Customer_History__c> rows = [
      SELECT FEC_Block_Code__c, FEC_Block_Code_1__c
      FROM FEC_Customer_History__c
      WHERE Id = :customerHistoryId
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      return false;
    }
    FEC_Customer_History__c h = rows[0];
    return isBlockCodePairForcedOmDay2(h.FEC_Block_Code__c, h.FEC_Block_Code_1__c);
  }

  /** @author Toannd61 */
  public static Id resolveDay2CheckQueueId() {
    List<Group> g = [
      SELECT Id
      FROM Group
      WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
        AND DeveloperName = :FEC_ConstantCommon.QUEUE_DAY_2_CHECK_NAME
      LIMIT 1
    ];
    return g.isEmpty() ? null : g[0].Id;
  }

  /**
   * Case hiện tại đang là RC27 (theo NOC chọn trên màn, chưa cần save vào Case).
   * @author Toannd61
   */
  public static Boolean isCurrentCaseRc27ByCurrentNoc(
    Case c,
    String categoryId,
    String subCategoryId,
    String subCodeId
  ) {
    if (c == null || c.FEC_Interaction__c == null) {
      return false;
    }

    Id catId = parseIdSafely(categoryId);
    Id subCatId = parseIdSafely(subCategoryId);
    Id subCodeRecId = parseIdSafely(subCodeId);
    if (catId == null || subCatId == null || subCodeRecId == null) {
      return false;
    }

    String categoryName;
    List<FEC_Category__c> categoryRows = [
      SELECT Name
      FROM FEC_Category__c
      WHERE Id = :catId
      LIMIT 1
    ];
    if (categoryRows.isEmpty()) {
      return false;
    }
    categoryName = trimSafe(categoryRows[0].Name);
    if (
      String.isBlank(categoryName) ||
      categoryName.toLowerCase() != REQUEST_CATEGORY_NAME.toLowerCase()
    ) {
      return false;
    }

    List<FEC_Sub_Category__c> subCategoryRows = [
      SELECT Name
      FROM FEC_Sub_Category__c
      WHERE Id = :subCatId
      LIMIT 1
    ];
    if (
      subCategoryRows.isEmpty() ||
      CURRENT_RC27_SUBCATEGORY_NAME != trimSafe(subCategoryRows[0].Name)
    ) {
      return false;
    }

    List<FEC_Sub_Code__c> subCodeRows = [
      SELECT Name
      FROM FEC_Sub_Code__c
      WHERE Id = :subCodeRecId
      LIMIT 1
    ];
    if (subCodeRows.isEmpty()) {
      return false;
    }
    String subCodeName = trimSafe(subCodeRows[0].Name);
    return String.isNotBlank(subCodeName) &&
      CURRENT_RC27_SUBCODE_NAMES.contains(subCodeName);
  }

  /**
   * Case hiện tại đang là RC27 (dựa trên field đã có sẵn trên Case).
   * @author Toannd61
   */
  public static Boolean isCurrentCaseRc27ByCaseFields(Case c) {
    if (c == null || c.FEC_Interaction__c == null) {
      return false;
    }
    String categoryName = c.FEC_Category__r != null ? trimSafe(c.FEC_Category__r.Name) : null;
    String subCategoryName = c.FEC_SubCategory__r != null ? trimSafe(c.FEC_SubCategory__r.Name) : null;
    String subCodeName = c.FEC_SubCode__r != null ? trimSafe(c.FEC_SubCode__r.Name) : null;
    return String.isNotBlank(categoryName) &&
      categoryName.toLowerCase() == REQUEST_CATEGORY_NAME.toLowerCase() &&
      CURRENT_RC27_SUBCATEGORY_NAME == subCategoryName &&
      String.isNotBlank(subCodeName) &&
      CURRENT_RC27_SUBCODE_NAMES.contains(subCodeName);
  }

  /**
   * Interaction cha có ít nhất 1 case con khác thuộc Request + RC09.01/RC09.02.
   * @author Toannd61
   */
  public static Boolean hasSiblingRc09CasesOnInteraction(
    Id parentInteractionId,
    Id currentCaseId
  ) {
    if (parentInteractionId == null) {
      return false;
    }
    List<Case> rows;
    if (currentCaseId == null) {
      rows = [
        SELECT Id
        FROM Case
        WHERE FEC_Interaction__c = :parentInteractionId
          AND FEC_Category__r.Name = :REQUEST_CATEGORY_NAME
          AND FEC_SubCategory__r.Name = :INTERACTION_RC09_SUBCATEGORY_NAME
          AND FEC_SubCode__r.Name IN :INTERACTION_RC09_SUBCODE_NAMES
        LIMIT 1
      ];
    } else {
      rows = [
        SELECT Id
        FROM Case
        WHERE FEC_Interaction__c = :parentInteractionId
          AND Id != :currentCaseId
          AND FEC_Category__r.Name = :REQUEST_CATEGORY_NAME
          AND FEC_SubCategory__r.Name = :INTERACTION_RC09_SUBCATEGORY_NAME
          AND FEC_SubCode__r.Name IN :INTERACTION_RC09_SUBCODE_NAMES
        LIMIT 1
      ];
    }
    return !rows.isEmpty();
  }

  private static String trimSafe(String s) {
    return s == null ? null : s.trim();
  }

  private static Id parseIdSafely(String rawId) {
    if (String.isBlank(rawId)) {
      return null;
    }
    try {
      return Id.valueOf(rawId.trim());
    } catch (Exception e) {
      return null;
    }
  }

  /** @author Toannd61 */
  public static Id resolveDqCsSupportQueueId() {
    List<Group> g = [
      SELECT Id
      FROM Group
      WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
        AND DeveloperName = :FEC_ConstantCommon.QUEUE_DQ_CS_SUPPORT_NAME
      LIMIT 1
    ];
    return g.isEmpty() ? null : g[0].Id;
  }

  /**
   * Sau khi getByCase đã tính nextTeam/nextQueue — ưu tiên Block Code (CS D2C), rồi Interaction RC09.
   * @author Toannd61
   */
  public static void applyToBusinessIfApplicable(
    Case theCase,
    FEC_CaseBusinessService.Business businessResult
  ) {
    applyToBusinessIfApplicable(
      theCase,
      businessResult,
      theCase != null ? (String) theCase.FEC_Category__c : null,
      theCase != null ? (String) theCase.FEC_SubCategory__c : null,
      theCase != null ? (String) theCase.FEC_SubCode__c : null
    );
  }

  /**
   * Sau khi getByCase đã tính nextTeam/nextQueue — ưu tiên Block Code (CS D2C), rồi rule RC27 + sibling RC09.
   * Dùng NOC hiện tại trên màn (category/subcategory/subcode Id), không phụ thuộc Case đã save.
   * @author Toannd61
   */
  public static void applyToBusinessIfApplicable(
    Case theCase,
    FEC_CaseBusinessService.Business businessResult,
    String currentCategoryId,
    String currentSubCategoryId,
    String currentSubCodeId
  ) {
    if (businessResult == null || theCase == null) {
      return;
    }
    if (isCustomerHistoryForcedOmDay2(theCase.FEC_Account_or_Contract__c)) {
      List<Group> ql = [
        SELECT Id, Name
        FROM Group
        WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
          AND DeveloperName = :FEC_ConstantCommon.QUEUE_DAY_2_CHECK_NAME
        LIMIT 1
      ];
      if (!ql.isEmpty()) {
        businessResult.nextTeam = TEAM_DISPLAY_OM;
        businessResult.nextQueue = new FEC_CommonUltils.PicklistOption(
          ql[0].Name,
          (String) ql[0].Id,
          null
        );
      }
      return;
    }
    if (
      isCurrentCaseRc27ByCurrentNoc(
        theCase,
        currentCategoryId,
        currentSubCategoryId,
        currentSubCodeId
      ) &&
      hasSiblingRc09CasesOnInteraction(theCase.FEC_Interaction__c, theCase.Id)
    ) {
      List<Group> ql = [
        SELECT Id, Name
        FROM Group
        WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
          AND DeveloperName = :FEC_ConstantCommon.QUEUE_DQ_CS_SUPPORT_NAME
        LIMIT 1
      ];
      if (!ql.isEmpty()) {
        businessResult.nextTeam = TEAM_DISPLAY_SP;
        businessResult.nextQueue = new FEC_CommonUltils.PicklistOption(
          ql[0].Name,
          (String) ql[0].Id,
          null
        );
      }
      return;
    }
  }

  /**
   * Sau các bước map queue trong route() — ưu tiên queue Day 2 Check (CS D2C), rồi rule RC27 + sibling RC09.
   * @author Toannd61
   */
  public static String applyRouteQueueOverrideIfApplicable(
    Case routeCase,
    String queueId
  ) {
    if (routeCase == null) {
      return queueId;
    }
    if (isCustomerHistoryForcedOmDay2(routeCase.FEC_Account_or_Contract__c)) {
      Id forcedId = resolveDay2CheckQueueId();
      return forcedId != null ? String.valueOf(forcedId) : queueId;
    }
    if (
      isCurrentCaseRc27ByCaseFields(routeCase) &&
      hasSiblingRc09CasesOnInteraction(routeCase.FEC_Interaction__c, routeCase.Id)
    ) {
      Id forcedId = resolveDqCsSupportQueueId();
      return forcedId != null ? String.valueOf(forcedId) : queueId;
    }
    return queueId;
  }
}
