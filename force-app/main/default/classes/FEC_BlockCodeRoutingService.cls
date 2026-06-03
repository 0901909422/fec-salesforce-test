/**
 * Ghi đè hiển thị / Route to Team & Queue theo nghiệp vụ:
 * 1) RC27 tại Stage 2 → Stage 3: Team/Queue theo FEC_Stage_Change__c (Action Route to), ưu tiên hơn Block Code.
 * 2) RC27 + blockCode/blockCode1 null + không sibling RC09 → Stage Change OM / FEC_Day_2_Check (bỏ qua Stage 1→3 SP).
 * 3) Customer History Block Code → Team OM, queue FEC_Day_2_Check.
 * 4) RC27 + không block ép OM + sibling RC09 → Stage Change SP / FEC_DQ_CS_Support (Stage 1→3).
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
  private static final String REQUEST_CATEGORY_CODE = 'Request';
  private static final String INTERACTION_RC09_SUBCATEGORY_CODE = 'RC09';
  private static final Set<String> INTERACTION_RC09_SUBCODE_CODES = new Set<String>{
    FEC_ConstantCommon.SUB_CODE_PROCESS_UPDATE_MOBILE,
    FEC_ConstantCommon.SUB_CODE_PROCESS_UPDATE_ADDRESS
  };
  private static final String CURRENT_RC27_SUBCATEGORY_CODE = 'RC27';
  private static final Set<String> CURRENT_RC27_SUBCODE_CODES = new Set<String>{
    'RC27.01',
    'RC27.02'
  };

  /** Block code live từ API (in-memory / session LWC) — không persist DB. */
  public class LiveBlockCodeContext {
    @AuraEnabled
    public String blockCode { get; set; }
    @AuraEnabled
    public String blockCode1 { get; set; }
    /** true = dùng blockCode/blockCode1 live; false = fallback Customer History. */
    @AuraEnabled
    public Boolean fromLiveApi { get; set; }
  }

  @TestVisible
  private static Map<String, LiveBlockCodeContext> liveBlockCodeCacheByCaseId = new Map<String, LiveBlockCodeContext>();

  @TestVisible
  public static void clearLiveBlockCodeCacheForTest() {
    liveBlockCodeCacheByCaseId.clear();
  }

  /** Gọi Card Inquiry + EMEA Account Inquiry; cache theo caseId trong cùng Apex transaction. */
  public static LiveBlockCodeContext resolveLiveBlockCodesForCase(Id caseId) {
    if (caseId == null) {
      return contextFromParams(null, null);
    }
    String cacheKey = String.valueOf(caseId);
    if (liveBlockCodeCacheByCaseId.containsKey(cacheKey)) {
      return liveBlockCodeCacheByCaseId.get(cacheKey);
    }
    LiveBlockCodeContext ctx = fetchLiveBlockCodesFromApis(caseId);
    liveBlockCodeCacheByCaseId.put(cacheKey, ctx);
    return ctx;
  }

  /** Block code live từ LWC (getByCase session) khi Route to — không ghi DB. */
  public static LiveBlockCodeContext contextFromParams(
    String blockCode,
    String blockCode1
  ) {
    LiveBlockCodeContext ctx = new LiveBlockCodeContext();
    ctx.blockCode = blockCode;
    ctx.blockCode1 = blockCode1;
    ctx.fromLiveApi = blockCode != null || blockCode1 != null;
    return ctx;
  }

  public static Boolean isForcedOmDay2ForRouting(
    Id customerHistoryId,
    LiveBlockCodeContext liveCtx
  ) {
    if (liveCtx != null && liveCtx.fromLiveApi == true) {
      return isBlockCodePairForcedOmDay2(liveCtx.blockCode, liveCtx.blockCode1);
    }
    return isCustomerHistoryForcedOmDay2(customerHistoryId);
  }

  private static LiveBlockCodeContext fetchLiveBlockCodesFromApis(Id caseId) {
    LiveBlockCodeContext ctx = new LiveBlockCodeContext();
    ctx.fromLiveApi = true;
    try {
      FEC_CardLockUnLockController.ResponseResult cardStatus = FEC_CardLockUnLockController.getCardStatus(
        String.valueOf(caseId)
      );
      ctx.blockCode = cardStatus?.currentBlockCode;

      List<Case> cases = [
        SELECT FEC_Account_Number__c
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
      ];
      if (!cases.isEmpty() && String.isNotBlank(cases[0].FEC_Account_Number__c)) {
        FEC_EmeaAccountInqService.EmeaInput input = new FEC_EmeaAccountInqService.EmeaInput();
        input.context = FEC_ConstantCommon.REQUESTOR_CONTEXT;
        input.name = UserInfo.getUserId();
        input.org = FEC_ConstantCommon.REQUESTOR_ORG;
        input.account = cases[0].FEC_Account_Number__c;
        input.dualInd = FEC_ConstantCommon.SUCCESS_STATUS_CODE;
        input.vmxVersion = FEC_ConstantCommon.REQUESTOR_VMXVERSION_EMEA;
        FEC_EmeaAccountInqService.EmeaResult emeaRes = FEC_EmeaAccountInqService.callAccountInquiry(
          input
        );
        ctx.blockCode1 = emeaRes?.blkCd1;
      }
    } catch (Exception e) {
      System.debug(
        LoggingLevel.WARN,
        'fetchLiveBlockCodesFromApis: ' + e.getMessage()
      );
      ctx.fromLiveApi = false;
    }
    return ctx;
  }

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

    String categoryCode;
    List<FEC_Category__c> categoryRows = [
      SELECT FEC_Code__c
      FROM FEC_Category__c
      WHERE Id = :catId
      LIMIT 1
    ];
    if (categoryRows.isEmpty()) {
      return false;
    }
    categoryCode = trimSafe(categoryRows[0].FEC_Code__c);
    if (
      String.isBlank(categoryCode) ||
      categoryCode.toLowerCase() != REQUEST_CATEGORY_CODE.toLowerCase()
    ) {
      return false;
    }

    List<FEC_Sub_Category__c> subCategoryRows = [
      SELECT FEC_Code__c
      FROM FEC_Sub_Category__c
      WHERE Id = :subCatId
      LIMIT 1
    ];
    if (
      subCategoryRows.isEmpty() ||
      CURRENT_RC27_SUBCATEGORY_CODE != trimSafe(subCategoryRows[0].FEC_Code__c)
    ) {
      return false;
    }

    List<FEC_Sub_Code__c> subCodeRows = [
      SELECT FEC_Code__c
      FROM FEC_Sub_Code__c
      WHERE Id = :subCodeRecId
      LIMIT 1
    ];
    if (subCodeRows.isEmpty()) {
      return false;
    }
    String subCodeCode = trimSafe(subCodeRows[0].FEC_Code__c);
    return String.isNotBlank(subCodeCode) &&
      CURRENT_RC27_SUBCODE_CODES.contains(subCodeCode);
  }

  /**
   * Case hiện tại đang là RC27 (dựa trên field đã có sẵn trên Case).
   * @author Toannd61
   */
  public static Boolean isCurrentCaseRc27ByCaseFields(Case c) {
    if (c == null || c.FEC_Interaction__c == null) {
      return false;
    }
    // Dùng NOC Id trên Case + query mã (tránh lỗi khi SOQL Case không SELECT FEC_*__r.FEC_Code__c).
    return isCurrentCaseRc27ByCurrentNoc(
      c,
      c.FEC_Category__c != null ? String.valueOf(c.FEC_Category__c) : null,
      c.FEC_SubCategory__c != null ? String.valueOf(c.FEC_SubCategory__c) : null,
      c.FEC_SubCode__c != null ? String.valueOf(c.FEC_SubCode__c) : null
    );
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
          AND FEC_Category__r.FEC_Code__c = :REQUEST_CATEGORY_CODE
          AND FEC_SubCategory__r.FEC_Code__c = :INTERACTION_RC09_SUBCATEGORY_CODE
          AND FEC_SubCode__r.FEC_Code__c IN :INTERACTION_RC09_SUBCODE_CODES
        LIMIT 1
      ];
    } else {
      rows = [
        SELECT Id
        FROM Case
        WHERE FEC_Interaction__c = :parentInteractionId
          AND Id != :currentCaseId
          AND FEC_Category__r.FEC_Code__c = :REQUEST_CATEGORY_CODE
          AND FEC_SubCategory__r.FEC_Code__c = :INTERACTION_RC09_SUBCATEGORY_CODE
          AND FEC_SubCode__r.FEC_Code__c IN :INTERACTION_RC09_SUBCODE_CODES
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

  /** Case đang ở Stage 2 (theo FEC_Code__c hoặc Name trên FEC_Case_Stage__c). */
  public static Boolean isCaseAtStageTwo(Case c) {
    if (c == null || c.FEC_Current_Case_Stage__r == null) {
      return false;
    }
    String stageCode = trimSafe(c.FEC_Current_Case_Stage__r.FEC_Code__c);
    if (FEC_ConstantCommon.STAGE_TWO.equals(stageCode)) {
      return true;
    }
    String stageName = c.FEC_Current_Case_Stage__r.Name;
    return String.isNotBlank(stageName) &&
      stageName.contains(FEC_ConstantCommon.STAGE_TWO);
  }

  /**
   * RC27 (RC27.01/RC27.02) đang Route to từ Stage 2 — dùng Team/Queue theo Stage Change, không ép OM/Day 2.
   * @author Toannd61
   */
  public static Boolean isRc27StageTwoToThreeRouting(
    Case c,
    String categoryId,
    String subCategoryId,
    String subCodeId
  ) {
    return isCaseAtStageTwo(c) &&
      isCurrentCaseRc27ByCurrentNoc(c, categoryId, subCategoryId, subCodeId);
  }

  /** @author Toannd61 */
  public static Boolean isRc27StageTwoToThreeRouting(Case c) {
    return isCaseAtStageTwo(c) && isCurrentCaseRc27ByCaseFields(c);
  }

  /**
   * RC27.01/02: blockCode/blockCode1 không ép OM trên Customer History và không sibling RC09.01/02.
   * Chỉ dùng Stage Change OM + Day 2 (tương đương bỏ qua dòng Stage 1→3 SP trên master data).
   */
  @TestVisible
  public static Boolean isRc27DefaultOmDay2Routing(
    Case c,
    String categoryId,
    String subCategoryId,
    String subCodeId
  ) {
    return isRc27DefaultOmDay2Routing(
      c,
      categoryId,
      subCategoryId,
      subCodeId,
      null
    );
  }

  @TestVisible
  public static Boolean isRc27DefaultOmDay2Routing(
    Case c,
    String categoryId,
    String subCategoryId,
    String subCodeId,
    LiveBlockCodeContext liveCtx
  ) {
    if (!isCurrentCaseRc27ByCurrentNoc(c, categoryId, subCategoryId, subCodeId)) {
      return false;
    }
    if (isForcedOmDay2ForRouting(c?.FEC_Account_or_Contract__c, liveCtx)) {
      return false;
    }
    return !hasSiblingRc09CasesOnInteraction(c.FEC_Interaction__c, c.Id);
  }

  @TestVisible
  public static Boolean isRc27DefaultOmDay2Routing(Case c) {
    if (c == null) {
      return false;
    }
    return isRc27DefaultOmDay2Routing(
      c,
      c.FEC_Category__c != null ? String.valueOf(c.FEC_Category__c) : null,
      c.FEC_SubCategory__c != null ? String.valueOf(c.FEC_SubCategory__c) : null,
      c.FEC_SubCode__c != null ? String.valueOf(c.FEC_SubCode__c) : null,
      null
    );
  }

  @TestVisible
  public static Boolean isRc27DefaultOmDay2Routing(
    Case c,
    LiveBlockCodeContext liveCtx
  ) {
    if (c == null) {
      return false;
    }
    return isRc27DefaultOmDay2Routing(
      c,
      c.FEC_Category__c != null ? String.valueOf(c.FEC_Category__c) : null,
      c.FEC_SubCategory__c != null ? String.valueOf(c.FEC_SubCategory__c) : null,
      c.FEC_SubCode__c != null ? String.valueOf(c.FEC_SubCode__c) : null,
      liveCtx
    );
  }

  @TestVisible
  private static Boolean isRc27DefaultOmDay2StageChangeRow(FEC_Stage_Change__c sc) {
    if (sc == null) {
      return false;
    }
    return TEAM_DISPLAY_OM.equals(trimSafe(sc.FEC_Team_User_Group__c)) &&
      FEC_ConstantCommon.QUEUE_DAY_2_CHECK_NAME.equals(trimSafe(sc.FEC_Next_Queue__c));
  }

  /** Chọn dòng OM/Day 2; bỏ qua dòng Stage 1→3 SP (FEC_DQ_CS_Support). */
  @TestVisible
  public static FEC_Stage_Change__c selectRc27DefaultOmDay2FromList(
    List<FEC_Stage_Change__c> candidates
  ) {
    if (candidates == null || candidates.isEmpty()) {
      return null;
    }
    for (FEC_Stage_Change__c sc : candidates) {
      if (isRc27DefaultOmDay2StageChangeRow(sc)) {
        return sc;
      }
    }
    return null;
  }

  @TestVisible
  public static FEC_Stage_Change__c queryRc27DefaultOmDay2StageChange(
    Id previousStageId,
    Id routeToActionId
  ) {
    if (previousStageId == null) {
      return null;
    }
    List<FEC_Stage_Change__c> rows;
    if (routeToActionId != null) {
      rows = [
        SELECT
          Id,
          FEC_Previous_Stage__c,
          FEC_Previous_Stage__r.FEC_Code__c,
          FEC_Next_Stage__c,
          FEC_Next_Queue__c,
          FEC_Team_User_Group__c
        FROM FEC_Stage_Change__c
        WHERE
          FEC_Previous_Stage__c = :previousStageId
          AND FEC_Active__c = TRUE
          AND FEC_IsReverted__c = FALSE
          AND FEC_Action_Button__c = :routeToActionId
          AND FEC_Team_User_Group__c = :TEAM_DISPLAY_OM
          AND FEC_Next_Queue__c = :FEC_ConstantCommon.QUEUE_DAY_2_CHECK_NAME
        LIMIT 1
      ];
    } else {
      rows = [
        SELECT
          Id,
          FEC_Previous_Stage__c,
          FEC_Previous_Stage__r.FEC_Code__c,
          FEC_Next_Stage__c,
          FEC_Next_Queue__c,
          FEC_Team_User_Group__c
        FROM FEC_Stage_Change__c
        WHERE
          FEC_Previous_Stage__c = :previousStageId
          AND FEC_Active__c = TRUE
          AND FEC_IsReverted__c = FALSE
          AND FEC_Team_User_Group__c = :TEAM_DISPLAY_OM
          AND FEC_Next_Queue__c = :FEC_ConstantCommon.QUEUE_DAY_2_CHECK_NAME
        LIMIT 1
      ];
    }
    return rows.isEmpty() ? null : rows[0];
  }

  /**
   * RC27 + không block ép OM (null/khác F/S/G/N) + có sibling RC09.01/02 → dòng Stage 1→3 SP/DQ.
   */
  @TestVisible
  public static Boolean isRc27SiblingSpDqStageThreeRouting(
    Case c,
    String categoryId,
    String subCategoryId,
    String subCodeId
  ) {
    return isRc27SiblingSpDqStageThreeRouting(
      c,
      categoryId,
      subCategoryId,
      subCodeId,
      null
    );
  }

  @TestVisible
  public static Boolean isRc27SiblingSpDqStageThreeRouting(
    Case c,
    String categoryId,
    String subCategoryId,
    String subCodeId,
    LiveBlockCodeContext liveCtx
  ) {
    if (!isCurrentCaseRc27ByCurrentNoc(c, categoryId, subCategoryId, subCodeId)) {
      return false;
    }
    if (isForcedOmDay2ForRouting(c?.FEC_Account_or_Contract__c, liveCtx)) {
      return false;
    }
    return hasSiblingRc09CasesOnInteraction(c.FEC_Interaction__c, c.Id);
  }

  @TestVisible
  public static Boolean isRc27SiblingSpDqStageThreeRouting(Case c) {
    if (c == null) {
      return false;
    }
    return isRc27SiblingSpDqStageThreeRouting(
      c,
      c.FEC_Category__c != null ? String.valueOf(c.FEC_Category__c) : null,
      c.FEC_SubCategory__c != null ? String.valueOf(c.FEC_SubCategory__c) : null,
      c.FEC_SubCode__c != null ? String.valueOf(c.FEC_SubCode__c) : null,
      null
    );
  }

  @TestVisible
  public static Boolean isRc27SiblingSpDqStageThreeRouting(
    Case c,
    LiveBlockCodeContext liveCtx
  ) {
    if (c == null) {
      return false;
    }
    return isRc27SiblingSpDqStageThreeRouting(
      c,
      c.FEC_Category__c != null ? String.valueOf(c.FEC_Category__c) : null,
      c.FEC_SubCategory__c != null ? String.valueOf(c.FEC_SubCategory__c) : null,
      c.FEC_SubCode__c != null ? String.valueOf(c.FEC_SubCode__c) : null,
      liveCtx
    );
  }

  @TestVisible
  private static Boolean isRc27SiblingSpDqStageChangeRow(FEC_Stage_Change__c sc) {
    if (sc == null) {
      return false;
    }
    return TEAM_DISPLAY_SP.equals(trimSafe(sc.FEC_Team_User_Group__c)) &&
      FEC_ConstantCommon.QUEUE_DQ_CS_SUPPORT_NAME.equals(trimSafe(sc.FEC_Next_Queue__c));
  }

  @TestVisible
  public static FEC_Stage_Change__c selectRc27SiblingSpDqStageThreeFromList(
    List<FEC_Stage_Change__c> candidates
  ) {
    if (candidates == null || candidates.isEmpty()) {
      return null;
    }
    for (FEC_Stage_Change__c sc : candidates) {
      if (isRc27SiblingSpDqStageChangeRow(sc)) {
        return sc;
      }
    }
    return null;
  }

  @TestVisible
  public static FEC_Stage_Change__c queryRc27SiblingSpDqStageThreeStageChange(
    Id previousStageId,
    Id routeToActionId
  ) {
    if (previousStageId == null) {
      return null;
    }
    List<FEC_Stage_Change__c> rows;
    if (routeToActionId != null) {
      rows = [
        SELECT
          Id,
          FEC_Previous_Stage__c,
          FEC_Previous_Stage__r.FEC_Code__c,
          FEC_Next_Stage__c,
          FEC_Next_Queue__c,
          FEC_Team_User_Group__c
        FROM FEC_Stage_Change__c
        WHERE
          FEC_Previous_Stage__c = :previousStageId
          AND FEC_Active__c = TRUE
          AND FEC_IsReverted__c = FALSE
          AND FEC_Action_Button__c = :routeToActionId
          AND FEC_Team_User_Group__c = :TEAM_DISPLAY_SP
          AND FEC_Next_Queue__c = :FEC_ConstantCommon.QUEUE_DQ_CS_SUPPORT_NAME
        LIMIT 1
      ];
    } else {
      rows = [
        SELECT
          Id,
          FEC_Previous_Stage__c,
          FEC_Previous_Stage__r.FEC_Code__c,
          FEC_Next_Stage__c,
          FEC_Next_Queue__c,
          FEC_Team_User_Group__c
        FROM FEC_Stage_Change__c
        WHERE
          FEC_Previous_Stage__c = :previousStageId
          AND FEC_Active__c = TRUE
          AND FEC_IsReverted__c = FALSE
          AND FEC_Team_User_Group__c = :TEAM_DISPLAY_SP
          AND FEC_Next_Queue__c = :FEC_ConstantCommon.QUEUE_DQ_CS_SUPPORT_NAME
        LIMIT 1
      ];
    }
    return rows.isEmpty() ? null : rows[0];
  }

  private static void applyRc27SiblingSpDqStageThreeFromStageChange(
    FEC_CaseBusinessService.Business businessResult,
    Id currentStageId,
    Id routeToActionId
  ) {
    applyStageChangeTeamQueueToBusiness(
      businessResult,
      queryRc27SiblingSpDqStageThreeStageChange(currentStageId, routeToActionId)
    );
  }

  private static void applyStageChangeTeamQueueToBusiness(
    FEC_CaseBusinessService.Business businessResult,
    FEC_Stage_Change__c stageChange
  ) {
    if (businessResult == null || stageChange == null) {
      return;
    }
    if (String.isNotBlank(stageChange.FEC_Team_User_Group__c)) {
      businessResult.nextTeam = stageChange.FEC_Team_User_Group__c;
    }
    if (String.isNotBlank(stageChange.FEC_Next_Queue__c)) {
      List<Group> ql = [
        SELECT Id, Name
        FROM Group
        WHERE
          Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
          AND DeveloperName = :stageChange.FEC_Next_Queue__c
        LIMIT 1
      ];
      if (!ql.isEmpty()) {
        businessResult.nextQueue = new FEC_CommonUltils.PicklistOption(
          ql[0].Name,
          (String) ql[0].Id,
          null
        );
      }
    }
  }

  private static void applyRc27DefaultOmDay2FromStageChange(
    FEC_CaseBusinessService.Business businessResult,
    Id currentStageId,
    Id routeToActionId
  ) {
    applyStageChangeTeamQueueToBusiness(
      businessResult,
      queryRc27DefaultOmDay2StageChange(currentStageId, routeToActionId)
    );
  }

  private static void applyRc27StageTwoToThreeFromStageChange(
    FEC_CaseBusinessService.Business businessResult,
    Id currentStageId,
    Id routeToActionId
  ) {
    if (businessResult == null || currentStageId == null) {
      return;
    }
    List<FEC_Stage_Change__c> stageChangelst = new List<FEC_Stage_Change__c>();
    if (routeToActionId != null) {
      stageChangelst = [
        SELECT FEC_Team_User_Group__c, FEC_Next_Queue__c
        FROM FEC_Stage_Change__c
        WHERE
          FEC_Previous_Stage__c = :currentStageId
          AND FEC_Active__c = TRUE
          AND FEC_Action_Button__c = :routeToActionId
          AND FEC_IsReverted__c = false
        LIMIT 1
      ];
    }
    if (stageChangelst.isEmpty()) {
      return;
    }
    applyStageChangeTeamQueueToBusiness(businessResult, stageChangelst[0]);
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
      theCase != null ? (String) theCase.FEC_SubCode__c : null,
      theCase != null ? theCase.FEC_Current_Case_Stage__c : null,
      null
    );
  }

  /**
   * Sau khi getByCase đã tính nextTeam/nextQueue — RC27 Stage2→3, RC27 default OM/Day2,
   * Block Code (OM/Day 2), RC27 + sibling RC09.
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
    applyToBusinessIfApplicable(
      theCase,
      businessResult,
      currentCategoryId,
      currentSubCategoryId,
      currentSubCodeId,
      theCase != null ? theCase.FEC_Current_Case_Stage__c : null,
      null
    );
  }

  /**
   * @param currentStageId Stage hiện tại trên màn (selectedStage.Id từ getByCase).
   * @param routeToActionId Action Route to (FEC_Action_Button__c) để lấy đúng FEC_Stage_Change__c Stage2→3.
   * @author Toannd61
   */
  public static void applyToBusinessIfApplicable(
    Case theCase,
    FEC_CaseBusinessService.Business businessResult,
    String currentCategoryId,
    String currentSubCategoryId,
    String currentSubCodeId,
    Id currentStageId,
    Id routeToActionId
  ) {
    applyToBusinessIfApplicable(
      theCase,
      businessResult,
      currentCategoryId,
      currentSubCategoryId,
      currentSubCodeId,
      currentStageId,
      routeToActionId,
      null
    );
  }

  /**
   * @param liveBlockCodes Block code live từ API (RC27); null = fallback Customer History.
   */
  public static void applyToBusinessIfApplicable(
    Case theCase,
    FEC_CaseBusinessService.Business businessResult,
    String currentCategoryId,
    String currentSubCategoryId,
    String currentSubCodeId,
    Id currentStageId,
    Id routeToActionId,
    LiveBlockCodeContext liveBlockCodes
  ) {
    if (businessResult == null || theCase == null) {
      return;
    }
    // Revert về Stage 1: giữ Team/Queue từ resolveRouteToDisplayInfo (đích = stage trước revert, vd Stage 3 SP).
    if (businessResult.routeByLatestRevertHistory == true) {
      return;
    }
    if (
      isRc27StageTwoToThreeRouting(
        theCase,
        currentCategoryId,
        currentSubCategoryId,
        currentSubCodeId
      )
    ) {
      applyRc27StageTwoToThreeFromStageChange(
        businessResult,
        currentStageId,
        routeToActionId
      );
      return;
    }
    if (
      isRc27DefaultOmDay2Routing(
        theCase,
        currentCategoryId,
        currentSubCategoryId,
        currentSubCodeId,
        liveBlockCodes
      )
    ) {
      applyRc27DefaultOmDay2FromStageChange(
        businessResult,
        currentStageId,
        routeToActionId
      );
      return;
    }
    if (
      isForcedOmDay2ForRouting(
        theCase.FEC_Account_or_Contract__c,
        liveBlockCodes
      )
    ) {
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
      isRc27SiblingSpDqStageThreeRouting(
        theCase,
        currentCategoryId,
        currentSubCategoryId,
        currentSubCodeId,
        liveBlockCodes
      )
    ) {
      applyRc27SiblingSpDqStageThreeFromStageChange(
        businessResult,
        currentStageId,
        routeToActionId
      );
      return;
    }
  }

  /**
   * Sau các bước map queue trong route() — RC27 Stage2→3 giữ queue Stage Change;
   * rồi Day 2 Check (Block Code); rồi RC27 + sibling RC09.
   * @author Toannd61
   */
  public static String applyRouteQueueOverrideIfApplicable(
    Case routeCase,
    String queueId
  ) {
    return applyRouteQueueOverrideIfApplicable(routeCase, queueId, false);
  }

  /**
   * @param skipRc27Override true khi Route to sau Revert — giữ queue Stage Change đích (vd Stage 3 SP).
   */
  public static String applyRouteQueueOverrideIfApplicable(
    Case routeCase,
    String queueId,
    Boolean skipRc27Override
  ) {
    return applyRouteQueueOverrideIfApplicable(
      routeCase,
      queueId,
      skipRc27Override,
      null
    );
  }

  public static String applyRouteQueueOverrideIfApplicable(
    Case routeCase,
    String queueId,
    Boolean skipRc27Override,
    LiveBlockCodeContext liveBlockCodes
  ) {
    if (routeCase == null) {
      return queueId;
    }
    if (skipRc27Override == true) {
      return queueId;
    }
    if (isRc27StageTwoToThreeRouting(routeCase)) {
      return queueId;
    }
    if (
      isForcedOmDay2ForRouting(
        routeCase.FEC_Account_or_Contract__c,
        liveBlockCodes
      )
    ) {
      Id forcedId = resolveDay2CheckQueueId();
      return forcedId != null ? String.valueOf(forcedId) : queueId;
    }
    if (
      isRc27SiblingSpDqStageThreeRouting(routeCase, liveBlockCodes)
    ) {
      Id forcedId = resolveDqCsSupportQueueId();
      return forcedId != null ? String.valueOf(forcedId) : queueId;
    }
    return queueId;
  }
}
