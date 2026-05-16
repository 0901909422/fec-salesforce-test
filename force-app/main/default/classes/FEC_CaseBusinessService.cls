public without sharing class FEC_CaseBusinessService {
  public static final String TYPE_LWC = 'LWC';
  public static final String LWC_INCORRECT_PAYMENT_FORM = 'fec_IncorrectPaymentForm';

  public static final String ROUTE_TO = 'Route to';
  /** Routing Action History khi đổi Owner (UI/API), không phải luồng Route to nghiệp vụ. */
  public static final String CHANGE_OWNER = 'Change Owner';
  public static final String REVERT = 'Revert';
  public static final String CANCEL = 'Cancel';
  public static final String ESCALATE = 'Escalate';
  public static final String TRANSFER = 'Transfer';
  public static final String REJECT = 'Reject';
  public static final String RECALL = 'Recall';
  public static final String REOPEN = 'Reopen';
  public static final String RESOLVE = 'Resolve';
  public static final String UPDATEACTION = 'Update';
  public static final String PHONE_UPDATE = 'Phone Update';
  public static final String EMAIL_UPDATE = 'Email Update';
  public static final String FULLNAME_UPDATE = 'Full Name Update';
  public static final String DOB_UPDATE = 'Date of Birth Update';
  public static final String GENDER_UPDATE = 'Gender Update';
  public static final String ADDRESS_UPDATE = 'Address Update';
  public static final String IDENTIFICATION_UPDATE = 'National ID Update';
  public static final String OC_001 = 'Outbound Campaign - OU01';
  public static final String BLOCK_CARD = 'Block Card';
  public static final String UNBLOCK_CARD = 'Unblock Card';
  public static final String PIN_REISSUE = 'Reissue PIN';
  public static final String REPLACE_CARD = 'Replace Card';
  //PhongBT 14/05/26: Document Request
  public static final String DOCUMENT_REQUEST = 'Document Request';
  //linhdev fix jira FECREDIT_CSM_2025_KH-1294 — FEC_Business_Process__r.FEC_Code__c (quy trình Fast Card / RC11…)
  public static final String FAST_CARD = 'Fast Cash';
  // tungnm37 thêm: COF/GSR route string constant
  public static final String ROUTE_TO_COF_GSR_ACTION = 'Route to COF/GSR';

  /**
   * Case sẽ có Routing Action History do logic nghiệp vụ (không dùng bản tự động từ trigger khi đổi Owner).
   * Đăng ký trước khi update OwnerId — createRoutingActionHistoryOnOwnerChange bỏ qua → 1 history / lần đổi owner.
   * Dùng tại: route(), takeOwnership, transfer, escalate, revert, recall, updateCaseTeamAndOwner (khi Owner thực sự đổi).
   */
  private static Set<Id> caseIdsSkipOwnerChangeRoutingHistory = new Set<Id>();

  public static void registerSkipOwnerChangeRoutingHistory(Id caseId) {
    if (caseId != null) {
      caseIdsSkipOwnerChangeRoutingHistory.add(caseId);
      System.debug(
        'FEC_DEBUG CaseBusinessService.registerSkipOwnerChangeRoutingHistory caseId=' +
        caseId +
        ' skipSetSize=' +
        caseIdsSkipOwnerChangeRoutingHistory.size()
      );
    }
  }

  public static final String CATEGORY_UNDELIVERED_CARD = 'Undelivered Card';

  public static final String FRONT_LINE = 'CS Frontline';

  public enum Method {
    ROUTE_TO,
    CANCEL,
    REVERT,
    REJECT,
    RECALL,
    REOPEN,
    RESOLVE,
    UPDATEACTION,
    ESCALATE,
    TRANSFER,
    PHONE_UPDATE,
    EMAIL_UPDATE,
    FULLNAME_UPDATE,
    DOB_UPDATE,
    GENDER_UPDATE,
    ADDRESS_UPDATE,
    IDENTIFICATION_UPDATE,
    OC_001,
    BLOCK_CARD,
    UNBLOCK_CARD,
    PIN_REISSUE,
    REPLACE_CARD,
    // tungnm37 thêm: COF/GSR - không đổi owner, chỉ tạo Assignment
    ROUTE_TO_COF_GSR,
    //PhongBT 14/05/26: Document Request
    DOCUMENT_REQUEST
  }

  public static final Map<String, Method> METHOD_MAP = new Map<String, Method>{
    ROUTE_TO => Method.ROUTE_TO,
    CANCEL => Method.CANCEL,
    REJECT => Method.REJECT,
    RESOLVE => Method.RESOLVE,
    REOPEN => Method.REOPEN,
    REVERT => Method.REVERT,
    UPDATEACTION => Method.UPDATEACTION,
    ESCALATE => Method.ESCALATE,
    TRANSFER => Method.TRANSFER,
    RECALL => Method.RECALL,
    PHONE_UPDATE => Method.PHONE_UPDATE,
    EMAIL_UPDATE => Method.EMAIL_UPDATE,
    FULLNAME_UPDATE => Method.FULLNAME_UPDATE,
    DOB_UPDATE => Method.DOB_UPDATE,
    GENDER_UPDATE => Method.GENDER_UPDATE,
    ADDRESS_UPDATE => Method.ADDRESS_UPDATE,
    IDENTIFICATION_UPDATE => Method.IDENTIFICATION_UPDATE,
    OC_001 => Method.OC_001,
    BLOCK_CARD => Method.BLOCK_CARD,
    UNBLOCK_CARD => Method.UNBLOCK_CARD,
    PIN_REISSUE => Method.PIN_REISSUE,
    REPLACE_CARD => Method.REPLACE_CARD,
    // tungnm37 thêm: COF/GSR route - không đổi owner
    ROUTE_TO_COF_GSR_ACTION => Method.ROUTE_TO_COF_GSR,
    //PhongBT 14/05/26: Document Request
    DOCUMENT_REQUEST => Method.DOCUMENT_REQUEST
  };

  @AuraEnabled
  public static Business getByCase(
    String caseId,
    String productTypeId,
    String categoryId,
    String subCategoryId,
    String subCodeId
  ) {
    Business result = new Business();
    try {
      List<Section> sectionlst = new List<Section>();

      Id currentUserId = UserInfo.getUserId();
      List<User> userlst = [
        SELECT Id, FEC_User_Group__c
        FROM User
        WHERE Id = :currentUserId
      ];

      if (userlst.isEmpty())
        return result;

      User currentUser = userlst.get(0);
      List<String> rolelst = new List<String>{ currentUser.FEC_User_Group__c };

      //  ===================================== GET CASE ===============================
            List<Case> caselst = [
        SELECT
          Id,
          FEC_Product_Type__c,
          FEC_Category__c,
          FEC_SubCategory__c,
          FEC_SubCode__c,
          FEC_Current_Case_Stage__c,
          FEC_Current_Case_Stage__r.FEC_Default_Stage__c,
          FEC_Customer_Type__c,
          FEC_Actual_Nature_of_Case__c,
          FEC_Account_or_Contract__c,
          FEC_Account_or_Contract__r.FEC_Primary_Phone__c,
          FEC_Account_or_Contract__r.FEC_Account_Number__c,
          FEC_Account_or_Contract__r.FEC_First_Name__c,
          FEC_Account_or_Contract__r.FEC_Middle_Name__c,
          FEC_Account_or_Contract__r.FEC_Last_Name__c,
          FEC_Account_or_Contract__r.FEC_Email__c,
          FEC_Account_or_Contract__r.FEC_Date_of_Birth__c,
          FEC_Account_or_Contract__r.FEC_Gender__c,
          FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c,
          FEC_Account_or_Contract__r.FEC_Date_of_Issue__c,
          FEC_Account_or_Contract__r.FEC_Place_of_Issue__c,
          FEC_Process_Action_Count__c,
          FEC_Original_Info_Phone_Number__c,
          FEC_Updated_Info_Phone_Number__c,
          FEC_Draft_Routing_Action_Code__c,
          FEC_Draft_Remarks__c,
          FEC_Original_Info_First_Name__c,
          FEC_Original_Info_Middle_Name__c,
          FEC_Original_Info_Last_Name__c,
          FEC_Updated_Info_First_Name__c,
          FEC_Updated_Info_Middle_Name__c,
          FEC_Updated_Info_Last_Name__c,
          FEC_Original_Info_Email__c,
          FEC_Updated_Info_Email__c,
          FEC_Original_Info_Date_of_Birth__c,
          FEC_Updated_Info_Date_of_Birth__c,
          FEC_Original_Info_Gender__c,
          FEC_Updated_Info_Gender__c,
          FEC_Original_Info_National_ID__c,
          FEC_Updated_Info_National_ID__c,
          FEC_Original_Info_Date_of_Issue__c,
          FEC_Updated_Info_Date_of_Issue__c,
          FEC_Original_Info_Place_of_Issue__c,
          FEC_Updated_Info_Place_of_Issue__c,
          FEC_Is_Submited__c,
          FEC_Business_Process__c,
          FEC_Account_Contract_Number_Text__c,
          FEC_Customer_Name__c,
          FEC_Account_Contract_Number_PL__c,
          FEC_National_ID_Passport_ID__c,
          FEC_Case_Phone_Number__c,
          FEC_Case_Email__c,
          FEC_Account_or_Contract__r.FEC_Customer_Type__c,
          FEC_Interaction__c,
          FEC_Category__r.Name,
          FEC_SubCategory__r.Name,
          FEC_SubCode__r.Name,
          FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c
        FROM Case
        WHERE Id = :caseId
      ];

      if (caselst.isEmpty())
        return result;

      Case selectedCase = caselst.get(0);
      // Giữ stage đọc từ DB trước khi draft null field — dùng map sang stage tương đương khi đổi bộ NOC.
      Id caseStageIdPreservedAtLoad = selectedCase.FEC_Current_Case_Stage__c;

      if(!selectedCase.FEC_Is_Submited__c) {
        selectedCase.FEC_Current_Case_Stage__c = null;
      }

      result.sectionlst.add(buildAccountInfor(selectedCase));
      // 03/02/2026 adhoc for product type, category, sub category, sub code
      Boolean hasIncomingNocSelection =
        String.isNotBlank(productTypeId) ||
        String.isNotBlank(categoryId) ||
        String.isNotBlank(subCategoryId) ||
        subCodeId != null;
      String incomingProductTypeId = productTypeId;
      String incomingCategoryId = categoryId;
      String incomingSubCategoryId = subCategoryId;
      String incomingSubCodeId = subCodeId;
      // Có payload NOC từ UI (CASE_NOC / getData): chỉ dùng đúng bộ đang chọn — không gán lại Product/Category/Sub-Category/Sub-Code từ Case.
      // Không payload (mở trang, getData không tham số): fallback từ Case như trước.
      if (!hasIncomingNocSelection) {
      if (String.isBlank(productTypeId))
        productTypeId = selectedCase.FEC_Product_Type__c;
      if (String.isBlank(categoryId))
        categoryId = selectedCase.FEC_Category__c;
      if (String.isBlank(subCategoryId))
        subCategoryId = selectedCase.FEC_SubCategory__c;
      if (String.isBlank(subCodeId))
        subCodeId = selectedCase.FEC_SubCode__c;
      }

      // GSR: so bộ NOC từ UI với bộ NOC trên FEC_Case_Flow_History__c (bản đầu có Nature of Case),
      // cùng hướng chọn bản ghi với FEC_CaseEditNOCController.getOriginalNOCFromFlowHistory (CreatedDate ASC, LIMIT 1).
      Id flowHistProductTypeId = selectedCase.FEC_Product_Type__c;
      Id flowHistCategoryId = selectedCase.FEC_Category__c;
      Id flowHistSubCategoryId = selectedCase.FEC_SubCategory__c;
      Id flowHistSubCodeId = selectedCase.FEC_SubCode__c;
      List<FEC_Case_Flow_History__c> flowNocBaselineLst = [
        SELECT
          FEC_Nature_of_Cases__c,
          FEC_Nature_of_Cases__r.FEC_Product_Type__c,
          FEC_Nature_of_Cases__r.FEC_Category__c,
          FEC_Nature_of_Cases__r.FEC_Sub_Category__c,
          FEC_Nature_of_Cases__r.FEC_Sub_Code__c,
          FEC_Nature_of_Cases__r.FEC_Business_Process__r.FEC_Code__c
        FROM FEC_Case_Flow_History__c
        WHERE
          FEC_Case__c = :selectedCase.Id
          AND FEC_Nature_of_Cases__c != NULL
        ORDER BY CreatedDate ASC
        LIMIT 1
      ];
      Boolean hideOriginalInfoSubsectionLabelFromFlowHistGsr = false;
      if (!flowNocBaselineLst.isEmpty() && flowNocBaselineLst[0].FEC_Nature_of_Cases__r != null) {
        FEC_Nature_of_Case__c baseNoc = flowNocBaselineLst[0].FEC_Nature_of_Cases__r;
        flowHistProductTypeId = baseNoc.FEC_Product_Type__c;
        flowHistCategoryId = baseNoc.FEC_Category__c;
        flowHistSubCategoryId = baseNoc.FEC_Sub_Category__c;
        flowHistSubCodeId = baseNoc.FEC_Sub_Code__c;
        String flowHistNocBpCode = baseNoc.FEC_Business_Process__r != null
          ? baseNoc.FEC_Business_Process__r.FEC_Code__c
          : null;
        hideOriginalInfoSubsectionLabelFromFlowHistGsr =
          String.isNotBlank(flowHistNocBpCode) &&
          flowHistNocBpCode.toUpperCase().contains('GSR');
      }

      // Có thay đổi bộ NOC so với baseline flow history: có payload UI thì so incoming; không có (lần tải đầu getData) thì so Case vs baseline.
      Boolean isUpdatedNocDifferentFromCurrent;
      if (hasIncomingNocSelection) {
        isUpdatedNocDifferentFromCurrent =
          nocLookupDimensionDiffers(incomingProductTypeId, flowHistProductTypeId) ||
          nocLookupDimensionDiffers(incomingCategoryId, flowHistCategoryId) ||
          nocLookupDimensionDiffers(incomingSubCategoryId, flowHistSubCategoryId) ||
          nocLookupDimensionDiffers(incomingSubCodeId, flowHistSubCodeId);
      } else {
        isUpdatedNocDifferentFromCurrent =
          nocLookupDimensionDiffersIds(
            selectedCase.FEC_Product_Type__c,
            flowHistProductTypeId
          ) ||
          nocLookupDimensionDiffersIds(
            selectedCase.FEC_Category__c,
            flowHistCategoryId
          ) ||
          nocLookupDimensionDiffersIds(
            selectedCase.FEC_SubCategory__c,
            flowHistSubCategoryId
          ) ||
          nocLookupDimensionDiffersIds(selectedCase.FEC_SubCode__c, flowHistSubCodeId);
      }
      String actualBusinessProcessCode = selectedCase.FEC_Actual_Nature_of_Case__r == null
        ? null
        : selectedCase.FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r?.FEC_Code__c;
      Boolean isActualNatureGsrCof =
        String.isNotBlank(actualBusinessProcessCode) &&
        (actualBusinessProcessCode.toUpperCase().contains('GSR') || actualBusinessProcessCode.toUpperCase().contains('COF')) ;
      Boolean isActualNatureGsrOnly =
        String.isNotBlank(actualBusinessProcessCode) &&
        (actualBusinessProcessCode.toUpperCase().contains('GSR')) ;
      // 06/04/2026 adhoc for sub code
      result.subCodeCode = FEC_ConstantCommon.STR_EMPTY;
      if (String.isNotBlank(subCodeId)) {
        try {
          Id subCodeRecordId = subCodeId;
          List<FEC_Sub_Code__c> subCoderlst = [
            SELECT FEC_Code__c
            FROM FEC_Sub_Code__c
            WHERE Id = :subCodeRecordId
            LIMIT 1
          ];
          if (!subCoderlst.isEmpty() && subCoderlst[0].FEC_Code__c != null) {
            result.subCodeCode = subCoderlst[0].FEC_Code__c;
          }
        } catch (Exception e) {
          System.debug('getByCase subCodeCode: ' + e.getMessage());
        }
      }

      result.subCategoryCode = FEC_ConstantCommon.STR_EMPTY;
      if (String.isNotBlank(subCategoryId)) {
        try {
          Id subCategoryRecordId = subCategoryId;
          List<FEC_Sub_Category__c> subCategorylst = [
            SELECT FEC_Code__c
            FROM FEC_Sub_Category__c
            WHERE Id = :subCategoryRecordId
            LIMIT 1
          ];
          if (!subCategorylst.isEmpty() && subCategorylst[0].FEC_Code__c != null) {
            result.subCategoryCode = subCategorylst[0].FEC_Code__c;
          }
        } catch (Exception e) {
          System.debug('getByCase subCategoryCode: ' + e.getMessage());
        }
      }

      // =============================== GET ROUTING ACTION ===========================

      Boolean isRevert = false;
      List<String> validActionlst = new List<String>{ ROUTE_TO, REVERT };

      List<FEC_Routing_Action_History__c> historylst = [
        SELECT
          Id,
          FEC_Previous_Stage__c,
          FEC_Next_Stage__r.Name,
          FEC_Previous_Stage__r.FEC_Default_Stage__c,
          FEC_Routing_Action__c,
          FEC_Perform_User__c,
          FEC_Perform_User__r.Name,
          FEC_Perform_User__r.FEC_User_Division_Group__c,
          FEC_Next_Stage__c,
          FEC_Next_Stage__r.FEC_Default_Stage__c,
          FEC_Updated_User_Queue__c,
          FEC_Updated_User_Queue_ID__c,
          //thangtv: đọc cờ Revert trên history mới nhất để getByCase chọn Stage Change Route to (IsReverted true/false)
          FEC_IsReverted__c,
          CreatedDate
        FROM FEC_Routing_Action_History__c
        WHERE
          FEC_Routing_Action__c IN :validActionlst
          AND FEC_Case__c = :selectedCase.Id
        ORDER BY CreatedDate DESC, Id DESC
        LIMIT 1
      ];

      //thangtv: history mới nhất có FEC_IsReverted__c = true → UI/query Route to dùng bản ghi Stage Change IsReverted = true
      Boolean latestRoutingHistoryIsReverted =
        !historylst.isEmpty() &&
        historylst.get(0).FEC_IsReverted__c == true;

      List<Group> queuelst;
      // Lưu riêng REVERT record trước khi selectedHistory bị override bởi routeToHistorylst.
      // routeToHistorylst không SELECT FEC_Perform_User__r.Name nên không thể dùng selectedHistory
      // sau khi bị override để lấy Name → SObjectException → nextQueue.value = null → lỗi UI.
      FEC_Routing_Action_History__c revertHistory;

      if (!historylst.isEmpty()) {
        isRevert = REVERT.equals(historylst.get(0).FEC_Routing_Action__c);
        if (isRevert) {
          revertHistory = historylst.get(0);
        }
      }

      //linhdev: Fix jira FECREDIT_CSM_2025_KH-1162
      result.lockApiLwcsAfterRevertToDefaultStage = false;
      if (!historylst.isEmpty() && REVERT.equals(historylst.get(0).FEC_Routing_Action__c)) {
        FEC_Routing_Action_History__c hRevert = historylst.get(0);
        result.lockApiLwcsAfterRevertToDefaultStage =
          hRevert.FEC_Next_Stage__c != null &&
          hRevert.FEC_Next_Stage__c == selectedCase.FEC_Current_Case_Stage__c &&
          hRevert.FEC_Next_Stage__r != null &&
          hRevert.FEC_Next_Stage__r.FEC_Default_Stage__c == true;
      }

      //thangtv
      result.lastUser = resolveLastUserForRevertDecisionDisplay(
        selectedCase.Id,
        selectedCase.FEC_Current_Case_Stage__c,
        false
      );
      //thangtv
      result.lastUserForRouteToLabel = resolveLastUserForRevertDecisionDisplay(
        selectedCase.Id,
        selectedCase.FEC_Current_Case_Stage__c,
        true
      );

      List<String> customerTypelst = new List<String>{
        'All',
        selectedCase.FEC_Customer_Type__c
      };

      Map<String, Object> caseBindMap = new Map<String, Object>{
        'productType' => productTypeId,
        'category' => categoryId,
        'subCategory' => subCategoryId,
        'subCode' => subCodeId,
        'customerType' => customerTypelst,
        'selectedNatureOfCaseId' => selectedCase.FEC_Actual_Nature_of_Case__c
      };

      String natureOfCaseQuery;
      String selectedNatureOfCaseId = selectedCase.FEC_Actual_Nature_of_Case__c;
      // GSR: luôn áp dụng rule subsection (ẩn Property Info khi NOC không đổi so với history) kể cả lần tải đầu không truyền NOC từ UI.
      Boolean isGsrCofNocDisplayMode = isActualNatureGsrCof;
      Boolean isGsrNocOnlyDisplayMode = isActualNatureGsrOnly;
      Boolean useActualNatureAndSettingObj = String.isNotBlank(selectedNatureOfCaseId);
      if (isGsrCofNocDisplayMode && isUpdatedNocDifferentFromCurrent) {
        // GSR + chọn bộ NOC mới khác bộ cũ: dùng NOC thường + Master Data Setting.
        useActualNatureAndSettingObj = false;
      }

      String natureOfCaseObj = useActualNatureAndSettingObj
        ? 'FEC_Actual_Nature_of_Case__c'
        : 'FEC_Nature_of_Case__c';

      String masterDataSettingObj = useActualNatureAndSettingObj
        ? 'FEC_Actual_Master_Data_Setting__c'
        : 'FEC_Master_Data_Setting__c';

      // =================================== NATURE OF CASE ==================================
      if (!useActualNatureAndSettingObj) {
        natureOfCaseQuery =
          'SELECT Id, FEC_Business_Process__c, FEC_Business_Process__r.FEC_Code__c, FEC_User_Group__c, FEC_Category__r.FEC_Code__c ' +
          'FROM FEC_Nature_of_Case__c ' +
          'WHERE FEC_Product_Type__c = :productType ' +
          'AND FEC_Category__c = :category ' +
          'AND FEC_Sub_Category__c = :subCategory ' +
          'AND FEC_Sub_Code__c = :subCode ' +
          'AND FEC_Customer_Type__c = :customerType ' +
          'AND FEC_Business_Process__r.FEC_Active__c = TRUE ' +
          'AND FEC_Active__c = TRUE ' +
          'AND FEC_User_Group__c INCLUDES (\'' +
          String.join(new List<String>(rolelst), '\',\'') +
          '\')';
      } else {
        natureOfCaseQuery = 'SELECT Id, FEC_Category__r.FEC_Code__c, FEC_Business_Process__c, FEC_Business_Process__r.FEC_Code__c, FEC_User_Group__c FROM FEC_Actual_Nature_of_Case__c WHERE Id = :selectedNatureOfCaseId ';
      }

      List<SObject> natureOfCaselst = Database.queryWithBinds(
        natureOfCaseQuery,
        caseBindMap,
        AccessLevel.USER_MODE
      );

      if (natureOfCaselst.isEmpty()) {
        //PhongBT 14/05/26: fix th mất case stage khi view bằng user k thuộc user group của noc -> không hiển thị master data
        if (caseStageIdPreservedAtLoad != null) {
          selectedCase.FEC_Current_Case_Stage__c = caseStageIdPreservedAtLoad;
        }
        try { update selectedCase; } catch (DmlException e) {
          System.debug('Update case failed (no NOC): ' + e.getMessage());
        }
        return result;
      }

      // ========================== VALIDATE =================================
      SObject selectedNatureOfCase = natureOfCaselst.get(0);

      result.natureOfCase = (String) selectedNatureOfCase.get('Id');

      String businessProcessId = (String) selectedNatureOfCase.get(
        'FEC_Business_Process__c'
      );

      SObject businessObj = selectedNatureOfCase.getSObject(
        'FEC_Business_Process__r'
      );
      String businessProcessCode;

      if (businessObj != null) {
        businessProcessCode = (String) businessObj.get('FEC_Code__c');
        result.code = businessProcessCode;
      }

      SObject categoryObj = selectedNatureOfCase.getSObject('FEC_Category__r');
      String catergoryCode;

      if (categoryObj != null) {
        catergoryCode = (String) categoryObj.get('FEC_Code__c');
      }

      //  adhoc for Category = “Undelivered Card”
      if (CATEGORY_UNDELIVERED_CARD.equals(catergoryCode)) {
        try {
          undeliveriedCardUpdate(selectedCase);
        } catch (Exception e) {
          System.debug('undeliveriedCardUpdate failed: ' + e.getMessage());
        }
      }

      Error err = new Error();

      //PhongBT 14/05/26: Document Request — gọi validate 1 lần, dùng cho cả error display và ẩn field
      String docReqValidationMessage = DOCUMENT_REQUEST.equals(businessProcessCode)
        ? FEC_PaymentHistoryValidationService.getValidationMessage(selectedCase.Id, subCodeId)
        : null;

      try {
        switch on METHOD_MAP.get(businessProcessCode) {
          when PHONE_UPDATE {
            err = phoneUpdateValidate(selectedCase.FEC_Account_or_Contract__c);
            if (err.errorlst.isEmpty()) {
              if (historylst.isEmpty())
                // &&
                // (String.isBlank(selectedCase.FEC_Current_Case_Stage__c) ||
                // selectedCase.FEC_Current_Case_Stage__r?.FEC_Default_Stage__c)
                phoneUpdate(selectedCase);
            } else {
              result.sectionlst.add(new Section('Case Information', err));
            }
          }
          when FULLNAME_UPDATE {
            if (selectedCase.FEC_Account_or_Contract__c != null) {
              fullNameUpdate(selectedCase);
            }
          }
          when EMAIL_UPDATE {
            if (selectedCase.FEC_Account_or_Contract__c != null) {
              emailUpdate(selectedCase);
            }
          }
          when DOB_UPDATE {
            if (selectedCase.FEC_Account_or_Contract__c != null) {
              dobUpdate(selectedCase);
            }
          }
          when GENDER_UPDATE {
            if (selectedCase.FEC_Account_or_Contract__c != null) {
              genderUpdate(selectedCase);
            }
          }
          when IDENTIFICATION_UPDATE {
            if (selectedCase.FEC_Account_or_Contract__c != null) {
              identificationUpdate(selectedCase);
            }
          }
          //PhongBT 14/05/26: Document Request hiển thị cảnh báo từ validation (chỉ label, không có reason)
          when DOCUMENT_REQUEST {
            if (String.isNotBlank(docReqValidationMessage)) {
              err = new Error(docReqValidationMessage, new List<String>());
              result.sectionlst.add(new Section('Case Information', err));
            }
          }
          when else {
          }
        }
      } catch (DmlException e) {
      }

      //PhongBT: Fix cập nhật sai case stage
      // FEC_Case_Stage__c.FEC_Nature_of_Cases__c lookup template FEC_Nature_of_Case__c.
      // Khi COF/GSR dùng Actual NOC (useActualNatureAndSettingObj), Id trên selectedNatureOfCase
      // là Actual — không dùng cho query stage; nếu không map sang template thì remap rỗng
      // và fallback theo Id stage cũ giữ stage của NOC trước (vd A→B→A vẫn stage B).
      Id templateNatureIdForCaseStages = resolveTemplateNatureOfCaseIdForCaseStages(
        useActualNatureAndSettingObj,
        selectedNatureOfCase,
        caseBindMap,
        rolelst
      );

      // ================================= GET CASE STAGE ===========================
      selectedNatureOfCaseId = (String) selectedNatureOfCase.get('Id');

      List<FEC_Case_Stage__c> stagelst = new List<FEC_Case_Stage__c>();
      //PhongBT: Fix cập nhật sai case stage
      // Remap stage theo NOC case hiện tại, giữ số stage (Stage 2 → Stage 2 NOC đúng):
      // - Có payload NOC từ UI (đổi bộ NOC trên màn), hoặc
      // - Mới vào màn (không payload) nhưng Case đã Submit: nếu FEC_Current_Case_Stage__c
      //   thuộc NOC khác với bộ NOC trên Case thì resolveCaseStageForNewNatureOfCase đồng bộ lại.
      Boolean shouldTryRemapStageToCaseNature =
        String.isNotBlank(caseStageIdPreservedAtLoad) &&
        //PhongBT: Fix cập nhật sai case stage
        templateNatureIdForCaseStages != null &&
        (hasIncomingNocSelection || selectedCase.FEC_Is_Submited__c == true);
      if (shouldTryRemapStageToCaseNature) {
        FEC_Case_Stage__c remappedStageForNewNoc = resolveCaseStageForNewNatureOfCase(
          caseStageIdPreservedAtLoad,
          //PhongBT: Fix cập nhật sai case stage
          templateNatureIdForCaseStages
        );
        if (remappedStageForNewNoc != null) {
          stagelst = [
            SELECT Id, Name, FEC_Business_Process__r.Name
            FROM FEC_Case_Stage__c
            WHERE Id = :remappedStageForNewNoc.Id AND FEC_Active__c = TRUE
            LIMIT 1
          ];
        }
      }
      if (stagelst.isEmpty()) {
        String selectedCaseStageId = selectedCase.FEC_Current_Case_Stage__c;
        //PhongBT: Fix cập nhật sai case stage
        // Tránh load stage theo Id khi Id trỏ NOC khác với bộ NOC đang chọn (UI) hoặc với NOC trên Case (đã submit, mở màn).
        if (
          hasIncomingNocSelection &&
          templateNatureIdForCaseStages != null &&
          String.isNotBlank(selectedCaseStageId) &&
          (hasIncomingNocSelection || selectedCase.FEC_Is_Submited__c == true)
        ) {
          List<FEC_Case_Stage__c> stageNocCheck = [
            SELECT FEC_Nature_of_Cases__c
            FROM FEC_Case_Stage__c
            WHERE Id = :selectedCaseStageId
            LIMIT 1
          ];
          if (
            !stageNocCheck.isEmpty() &&
            stageNocCheck[0].FEC_Nature_of_Cases__c != templateNatureIdForCaseStages
          ) {
            selectedCaseStageId = null;
          }
        }
        String caseStageQuery;
        Map<String, Object> bindVars;
        if (String.isNotBlank(selectedCaseStageId)) {
          caseStageQuery =
            'SELECT Id, Name, FEC_Business_Process__r.Name ' +
            'FROM FEC_Case_Stage__c ' +
            'WHERE Id = :id ' +
            'AND FEC_Active__c = TRUE ';
            // +
            // 'AND FEC_User_Group__c INCLUDES (\'' +
            // String.join(new List<String>(rolelst), '\',\'') +
            // '\')';
          bindVars = new Map<String, Object>{ 'id' => selectedCaseStageId };
        } else {
          //PhongBT: Fix cập nhật sai case stage
          Id nocIdForDefaultStageQuery = templateNatureIdForCaseStages != null
            ? templateNatureIdForCaseStages
            : (String.isNotBlank(selectedNatureOfCaseId)
              ? (Id) selectedNatureOfCaseId
              : null);
          caseStageQuery =
            'SELECT Id, Name, FEC_Business_Process__r.Name ' +
            'FROM FEC_Case_Stage__c ' +
            //PhongBT: Fix cập nhật sai case stage
            'WHERE FEC_Nature_of_Cases__c = :nocIdForDefaultStageQuery ' +
            'AND FEC_Active__c = TRUE ' +
            'AND FEC_Default_Stage__c = TRUE ';
            // +
            // 'AND FEC_User_Group__c INCLUDES (\'' +
            // String.join(new List<String>(rolelst), '\',\'') +
            // '\')';
          bindVars = new Map<String, Object>{
            //PhongBT: Fix cập nhật sai case stage
            'nocIdForDefaultStageQuery' => nocIdForDefaultStageQuery
          };
        }
          stagelst = (List<FEC_Case_Stage__c>) Database.queryWithBinds(
          caseStageQuery,
          bindVars,
          AccessLevel.USER_MODE
        );
      }

      if (stagelst.isEmpty()) {
        //PhongBT 14/05/26: fix th mất case stage khi view bằng user k thuộc user group của noc -> không hiển thị master data
        if (caseStageIdPreservedAtLoad != null) {
          selectedCase.FEC_Current_Case_Stage__c = caseStageIdPreservedAtLoad;
        }
        try { update selectedCase; } catch (DmlException e) {
          System.debug('Update case failed (no stage): ' + e.getMessage());
        }
        return result;
      }

      FEC_Case_Stage__c selectedStage = stagelst.get(0);
      selectedCase.FEC_Current_Case_Stage__c = selectedStage.Id;

      // if (String.isBlank(selectedCaseStageId)) {
      //   selectedCase.FEC_Current_Case_Stage__c = selectedStage.Id;
      // }

      result.stage = selectedStage.Id;
      result.stageName = selectedStage.Name;
      Boolean isLatestRevertToCurrentStage = isLatestRevertToCurrentStage(
        selectedCase.Id,
        selectedStage.Id
      );

      // ============================= GET MASTET DATA SETTING ===========================
      if (err.errorlst.isEmpty()) {
        String soql =
          'SELECT Id, FEC_Field_API_Name__c, FEC_Field_Editable__c, ' +
          'FEC_Field_Mandatory__c, FEC_Field_Object_Name__c, ' +
          'FEC_Field_ReadOnly__c, FEC_Section__c, FEC_Field_Order_Display__c,' +
          'FEC_Field_Label_Name__c, FEC_Editable_User_Group__c, FEC_Field_Masking__c, FEC_Masking_Type__c, ' +
          'FEC_Sub_Section__c, FEC_Sub_Section_Order__c, FEC_Sub_Section_Layout__c, FEC_Field_Reverted__c, FEC_Sub_Section_Field_Layout__c, ' +
          'FEC_LWC_Name__c, FEC_Type__c ' +
          'FROM ' +
          masterDataSettingObj +
          ' ' +
          'WHERE ' +
          natureOfCaseObj +
          ' = \'' +
          String.escapeSingleQuotes(selectedNatureOfCaseId) +
          '\' ' +
          'AND FEC_Stage_Name__c = \'' +
          String.escapeSingleQuotes(String.valueOf(selectedStage.Id)) +
          '\' ' +
          'AND FEC_Field_Status__c = TRUE ' +
          'ORDER BY FEC_Section__c, FEC_Sub_Section_Order__c NULLS LAST, FEC_Sub_Section__c, FEC_Field_Object_Name__c, FEC_Field_Order_Display__c';

        List<SObject> masterDatalst = Database.query(soql);

        // ====================================== CREATE BUSINESS ============================
        // Retrieve Data
        Map<String, Set<String>> objToFieldlstMap = new Map<String, Set<String>>();
        Map<List<String>, SObject> sectionKeyToFieldApiMap = new Map<List<String>, SObject>();
        List<String> keyTemp;

        Section sectionTemp;
        Section subSectionTemp;
        CObject cObjTemp;
        Field fieldTemp;

        String maskingTypeTemp;
        String sectionNameTemp;
        String subSectionNameTemp;
        String cObjNameTemp;
        String fieldApiNameTemp;
        Decimal subSectionOrderTemp;
        Decimal subSectionLayoutTemp;
        SObject objTemp;

        Boolean isCOF = selectedStage?.FEC_Business_Process__r?.Name == FEC_ConstantCommon.COF_GENERAL_FLOW;
        Boolean isCOFStage1Revert = isLatestRevertToCurrentStage && isCOF && checkStageName(selectedStage.Name,FEC_ConstantCommon.STAGE_ONE);
        result.contextFlags.put('isCOFStage1Revert', isCOFStage1Revert);

        for (SObject item : masterDatalst) {
          sectionNameTemp = (String) item.get('FEC_Section__c');
          subSectionNameTemp = (String) item.get('FEC_Sub_Section__c');
          cObjNameTemp = (String) item.get('FEC_Field_Object_Name__c');
          fieldApiNameTemp = (String) item.get('FEC_Field_API_Name__c');
          subSectionOrderTemp = (Decimal) item.get('FEC_Sub_Section_Order__c');
          subSectionLayoutTemp = (Decimal) item.get(
            'FEC_Sub_Section_Layout__c'
          );
          String itemType = (String) item.get('FEC_Type__c');
          //PhongBT 14/05/26: Document Request
          //Ẩn Case Info (trừ Property Info), chỉ khi sub-code RL04.02/RL04.03/RC04.04 trả về message
          if(
            DOCUMENT_REQUEST.equals(businessProcessCode)
            && String.isNotBlank(docReqValidationMessage)
            && 'Case Information'.equals(sectionNameTemp)
            && !'Property Info'.equals(subSectionNameTemp)
          ){
            continue;
          }

          //linhdev fix jira FECREDIT_CSM_2025_KH-1294 — FAST_CARD: chỉ ẩn subsection C360 Info; section Account Information và subsection khác vẫn render.
          if (
            FAST_CARD.equals(businessProcessCode) &&
            'C360 Info'.equals(subSectionNameTemp)
          ) {
            continue;
          }

          // GSR handling: điều chỉnh field hiển thị theo việc bộ NOC updated có đổi hay không.
          if (isGsrNocOnlyDisplayMode) {
            if (isUpdatedNocDifferentFromCurrent) {

              //Có khác:
              if ('Original Info'.equals(subSectionNameTemp) && TYPE_LWC.equals(itemType)) {
                continue;
              }
            } else {
              //Không khác: nếu property info thì không hiển thị
              if ('Property Info'.equals(subSectionNameTemp)) {
                continue;
              }
            }
          }

          if (String.isNotBlank(cObjNameTemp)) {
            if (!objToFieldlstMap.containsKey(cObjNameTemp))
              objToFieldlstMap.put(cObjNameTemp, new Set<String>{ 'Id' });

            if (String.isNotBlank(fieldApiNameTemp))
              objToFieldlstMap.get(cObjNameTemp).add(fieldApiNameTemp);
          }

          sectionTemp = result.findSection(sectionNameTemp);

          if (sectionTemp == null) {
            sectionTemp = new Section(sectionNameTemp);
            result.sectionlst.add(sectionTemp);
          }
          Boolean isCOFStage1NotRevert = !isLatestRevertToCurrentStage && isCOF && checkStageName(selectedStage.Name,FEC_ConstantCommon.STAGE_ONE);
          if (TYPE_LWC.equals(itemType)) {
            String lwcName = (String) item.get('FEC_LWC_Name__c');
            // COF General Flow Stage 1: chỉ ẩn / remap subsection cho LWC Original Info (ORIGINAL_LWC_COF); các LWC khác vẫn hiển thị bình thường.
            Boolean isOriginalLwcCof = String.isNotBlank(lwcName) && FEC_ConstantCommon.ORIGINAL_LWC_COF.equalsIgnoreCase(lwcName);
            if (String.isNotBlank(lwcName) && !isCOFStage1NotRevert) {
              DynamicLwcComponent lwcSlot = new DynamicLwcComponent();
              lwcSlot.componentName = lwcName;
              lwcSlot.order = subSectionOrderTemp;
              lwcSlot.fieldLayout = (Decimal) item.get(
                'FEC_Sub_Section_Field_Layout__c'
              );
              lwcSlot.subSectionName = (isCOFStage1Revert && isOriginalLwcCof) ? FEC_ConstantCommon.ORIGINAL_INFORMATION : subSectionNameTemp;
              lwcSlot.fecMasterDataSettingIsEdit = isLwcDynamicMasterInEditMode(
                item,
                currentUser.FEC_User_Group__c,
                selectedStage.Name
              );
              if (
                isLatestRevertToCurrentStage &&
                LWC_INCORRECT_PAYMENT_FORM.equalsIgnoreCase(lwcName)
              ) {
                lwcSlot.fecMasterDataSettingIsEdit = false;
              }
              if (
                hideOriginalInfoSubsectionLabelFromFlowHistGsr &&
                'Original Info'.equals(subSectionNameTemp)
              ) {
                lwcSlot.hideSubSectionHeading = true;
              }
              if (isCOF && (subSectionNameTemp == FEC_ConstantCommon.ORIGINAL_INFO || subSectionNameTemp == FEC_ConstantCommon.UPDATED_INFO)) {
                lwcSlot.isCollapsible = (checkStageName(selectedStage?.Name, FEC_ConstantCommon.STAGE_ONE) && isLatestRevertToCurrentStage) || checkStageName(selectedStage?.Name, FEC_ConstantCommon.STAGE_TWO) || checkStageName(selectedStage?.Name, FEC_ConstantCommon.STAGE_THREE);
              }
              sectionTemp.componentlst.add(lwcSlot);
            }
          } else {
            if (String.isNotBlank(subSectionNameTemp)) {
              subSectionTemp = sectionTemp.findSubSection(subSectionNameTemp);

              if (subSectionTemp == null) {
                subSectionTemp = new Section(
                  subSectionNameTemp,
                  subSectionOrderTemp,
                  subSectionLayoutTemp
                );
                sectionTemp.subSectionlst.add(subSectionTemp);
              } else if (subSectionOrderTemp != null) {
                // Nhiều dòng MDS cùng FEC_Sub_Section__c: giữ order nhỏ nhất (đúng FEC_Sub_Section_Order__c khi SOQL không theo order).
                if (
                  subSectionTemp.order == null ||
                  subSectionOrderTemp < subSectionTemp.order
                ) {
                  subSectionTemp.order = subSectionOrderTemp;
                }
              }
              if (
                hideOriginalInfoSubsectionLabelFromFlowHistGsr &&
                'Original Info'.equals(subSectionNameTemp) &&
                subSectionTemp != null
              ) {
                subSectionTemp.hideSubSectionHeading = true;
              }

              if (subSectionTemp != null && isCOF && (subSectionNameTemp == FEC_ConstantCommon.ORIGINAL_INFO || subSectionNameTemp == FEC_ConstantCommon.UPDATED_INFO)) {
                subSectionTemp.isCollapsible = (checkStageName(selectedStage?.Name, FEC_ConstantCommon.STAGE_ONE) && isLatestRevertToCurrentStage) || checkStageName(selectedStage?.Name, FEC_ConstantCommon.STAGE_TWO) || checkStageName(selectedStage?.Name, FEC_ConstantCommon.STAGE_THREE);
              }

              cObjTemp = subSectionTemp.findObj(cObjNameTemp);

              if (cObjTemp == null) {
                cObjTemp = new CObject(cObjNameTemp);
                subSectionTemp.objlst.add(cObjTemp);
              }

              cObjTemp.masterDataSettinglst.add(item);
            }
          }
        }

        // =============================== GET DATA FROM FIELD OF MASTER DATA SETTING ============================
        // get data
        Map<String, SObject> objToDataMap = getData(
          objToFieldlstMap,
          selectedCase.Id,
          selectedCase.FEC_Account_or_Contract__c
        );

        Map<String, Map<String, String>> objToFieldToHelpTextMap = getHelpTextMap(
          objToFieldlstMap
        );

        result.picklistOptionsMap = getPicklistOptionsMap(objToFieldlstMap);

        // ================================== CONVERT MASTER DATA SETTING FIELD TO FIELD ================================
        for (Section sectionItem : result.sectionlst) {
          for (Section subSectionItem : sectionItem.subSectionlst) {
            for (CObject cObjectItem : subSectionItem.objlst) {
              for (SObject masterDataItem : cObjectItem.masterDataSettinglst) {
                if (objToDataMap.containsKey(cObjectItem.name)) {
                  objTemp = objToDataMap.get(cObjectItem.name);
                  if (objTemp == null)
                    continue;

                  if (String.isBlank(cObjectItem.id))
                    cObjectItem.id = (String) objTemp.get('Id');

                  fieldTemp = transform(
                    masterDataItem,
                    objTemp,
                    currentUser.FEC_User_Group__c,
                    isRevert
                  );

                  if (fieldTemp == null)
                    continue;

                  // add help text
                  if (
                    objToFieldToHelpTextMap.containsKey(cObjectItem.name) &&
                    objToFieldToHelpTextMap.get(cObjectItem.name)
                      .containsKey(fieldTemp.apiName)
                  ) {
                    fieldTemp.helpText = objToFieldToHelpTextMap.get(
                        cObjectItem.name
                      )
                      .get(fieldTemp.apiName);
                  }

                  cObjectItem.fieldlst.add(fieldTemp);
                }
              }
            }
          }

          sectionItem.sort();
        }

        result.removeEmptySections();
      }

      // ============================== GET ROUNTING AND PROCESS ACTION ===============================
      Boolean containProcessAction =
        selectedCase.FEC_Process_Action_Count__c != -1 &&
        selectedCase.FEC_Process_Action_Count__c != 3;

      List<String> validButtonTypelst = new List<String>{ 'Routing Action' };

      if (containProcessAction) {
        validButtonTypelst.add('Process Action');
      } 

      List<FEC_Stage_Screen__c> actionlst = Database.query(
        'SELECT Id, FEC_Action_Button__c, ' +
          'FEC_Action_Button__r.Name, ' +
          'FEC_Action_Button__r.FEC_Type__c, ' +
          'FEC_Action_Button__r.FEC_Code__c, ' +
          'FEC_Custom_Action_Button_Label__c, ' +
          'FEC_Field_Type__c ' +
          'FROM FEC_Stage_Screen__c ' +
          'WHERE FEC_Action_Button__c != NULL AND FEC_Active__c = TRUE AND FEC_Action_Button__r.FEC_Type__c IN :validButtonTypelst ' +
          'AND FEC_Case_Stage__c = \'' +
          String.escapeSingleQuotes(String.valueOf(selectedStage.Id)) +
          '\' ' +
          'AND FEC_User_Group__c INCLUDES (\'' +
          String.join(rolelst, '\',\'') +
          '\')'
      );

      String routeToId;
      String revertId;

      // get actions
      for (FEC_Stage_Screen__c item : actionlst) {
        if ('Routing Action'.equals(item.FEC_Action_Button__r.FEC_Type__c)) {
          if (ROUTE_TO.equals(item.FEC_Action_Button__r.FEC_Code__c)) {
            routeToId = item.FEC_Action_Button__c;
          } else if (REVERT.equals(item.FEC_Action_Button__r.FEC_Code__c)) {
            revertId = item.FEC_Action_Button__c;
          }
          Action act = new Action(
            item.FEC_Action_Button__c,
            String.isNotBlank(item.FEC_Custom_Action_Button_Label__c)
              ? item.FEC_Custom_Action_Button_Label__c
              : item.FEC_Action_Button__r.FEC_Code__c,
            String.isNotBlank(item.FEC_Custom_Action_Button_Label__c)
              ? item.FEC_Custom_Action_Button_Label__c
              : item.FEC_Action_Button__r.Name,
            item.FEC_Action_Button__r.FEC_Code__c
          );
          if (item.FEC_Field_Type__c == 'All') {
            result.routingActionlst.add(
              act
            );
          } else if (item.FEC_Field_Type__c == 'New' && !isRevert) {
            result.routingActionlst.add(
              act
            );
          } else if (item.FEC_Field_Type__c == 'Revert' && isRevert) {
            result.routingActionlst.add(
              act
            );
          }
        } else if (
          'Process Action'.equals(item.FEC_Action_Button__r.FEC_Type__c)
        ) {
          result.processActionlst.add(
            new Action(
              item.FEC_Action_Button__r.FEC_Code__c,
              item.FEC_Action_Button__r.Name
            )
          );
        }
      }

      // Hiển thị Team/Queue Route to theo nhánh Stage Change (không ảnh hưởng logic submit route()).
      RouteToDisplayInfo routeToDisplayInfo = resolveRouteToDisplayInfo(
        selectedCase.Id,
        selectedStage != null ? selectedStage.Id : null,
        routeToId,
        revertId,
        latestRoutingHistoryIsReverted
      );
      if (routeToDisplayInfo != null) {
        result.nextTeam = routeToDisplayInfo.nextTeam;
        if (routeToDisplayInfo.nextQueue != null) {
          result.nextQueue = routeToDisplayInfo.nextQueue;
        }
      }

      // get next stage metadata for Revert action display
      if (revertId != null) {
        List<FEC_Stage_Change__c> revertChangelst = [
          SELECT FEC_Next_Stage__c, FEC_Next_Queue__c, Id, FEC_Team_User_Group__c
          FROM FEC_Stage_Change__c
          WHERE
            FEC_Previous_Stage__c = :selectedStage.Id
            AND FEC_Active__c = TRUE
            AND FEC_Action_Button__c = :revertId
            AND FEC_IsReverted__c = true
        ];
        if (!revertChangelst.isEmpty()) {
          result.revertNextTeam = revertChangelst.get(0).FEC_Team_User_Group__c;
          List<Group> revertQueuelst = [
            SELECT Id, Name, DeveloperName, Type
            FROM Group
            WHERE
              Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
              AND DeveloperName = :revertChangelst.get(0).FEC_Next_Queue__c
          ];
          if (!revertQueuelst.isEmpty())
            result.revertNextQueue = new FEC_CommonUltils.PicklistOption(
              revertQueuelst.get(0).Name,
              (String) revertQueuelst.get(0).Id,
              null
            );
        }
      }

      FEC_BlockCodeRoutingService.applyToBusinessIfApplicable(
        selectedCase,
        result,
        categoryId,
        subCategoryId,
        subCodeId
      );

      // [HARDCODE RC27.01/RC27.02 — Display Override]:
      // Khi Case ở Stage 1 (chưa submit) với sub-code RC27.01/RC27.02 và KHÔNG có Block Code,
      // hiển thị Team=SP, Queue=CS Support. Block Code được phép ghi đè RC27.
      // Toannd61
      if (
        !selectedCase.FEC_Is_Submited__c &&
        selectedStage != null &&
        String.isNotBlank(routeToId) &&
        !FEC_BlockCodeRoutingService.isCustomerHistoryForcedOmDay2(selectedCase.FEC_Account_or_Contract__c) &&
        (FEC_ConstantCommon.SUB_CODE_CARD_REPLACEMENT_FEE.equals(result.subCodeCode) ||
         FEC_ConstantCommon.SUB_CODE_CARD_REPLACEMENT_FREE.equals(result.subCodeCode))
      ) {
        List<FEC_Stage_Change__c> rc27DisplayLst = [
          SELECT FEC_Next_Queue__c, FEC_Team_User_Group__c
          FROM FEC_Stage_Change__c
          WHERE FEC_Previous_Stage__c = :selectedStage.Id
            AND FEC_Active__c = TRUE
            AND FEC_Team_User_Group__c = 'SP'
            AND FEC_IsReverted__c = false
          LIMIT 1
        ];
        if (!rc27DisplayLst.isEmpty()) {
          System.debug('FEC_DEBUG getByCase RC27 display override (final): Stage1→Stage3 (SP), subCode=' + result.subCodeCode);
          result.nextTeam = rc27DisplayLst[0].FEC_Team_User_Group__c;
          if (String.isNotBlank(rc27DisplayLst[0].FEC_Next_Queue__c)) {
            List<Group> spQueues = [
              SELECT Id, Name
              FROM Group
              WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
                AND DeveloperName = :rc27DisplayLst[0].FEC_Next_Queue__c
              LIMIT 1
            ];
            if (!spQueues.isEmpty()) {
              result.nextQueue = new FEC_CommonUltils.PicklistOption(
                spQueues[0].Name,
                (String) spQueues[0].Id,
                null
              );
            }
          }
        }
      }

      // Case đã Submit thì không trả draft → màn Execute hiển thị mới, không autofill dữ liệu cũ
      result.draftRoutingActionCode = selectedCase.FEC_Is_Submited__c == true
        ? null
        : selectedCase.FEC_Draft_Routing_Action_Code__c;
      // tungnm37 thêm: trả isSubmited để LWC kiểm tra Stage 2 (showManualAddItem)
      // tungnm37 fix: khi Revert về Stage 1 (Default Stage) → isSubmited = false để hiện read-only display
      result.isSubmited = selectedCase.FEC_Is_Submited__c == true
          && result.lockApiLwcsAfterRevertToDefaultStage != true;
      // tungnm37 thêm: trả customerType để LWC fec_RoutingAssignment query đúng
      result.customerType = selectedCase.FEC_Customer_Type__c;

      if (Schema.sObjectType.Case.isUpdateable()) {
        try {
          FEC_CaseTriggerHandler.isSystemUpdate = true;
          update selectedCase;
        } catch (DmlException e) {
          // User có thể không có quyền sửa Case (vd: Case đã assign Queue). Vẫn trả result để hiển thị section.
        }
      }

      return result;
    } catch (CaseBusinessServiceException e) {
      System.debug('getByCase CaseBusinessServiceException: ' + e.getMessage());
    } catch (AuraHandledException e) {
      System.debug('getByCase AuraHandledException: ' + e.getMessage());
    } catch (Exception e) {
      System.debug('getByCase Exception: ' + e.getMessage());
      System.debug(e.getStackTraceString());
    }
    return result;
  }

  private static Boolean checkStageName(String selectedStageName, String stageName){
    return selectedStageName?.contains(stageName);
  }
  @AuraEnabled
  public static void saveCaseNOC(String caseId, String natureOfCaseId) {
    if (String.isBlank(caseId) || String.isBlank(natureOfCaseId))
      return;
    
    Id currentUserId = UserInfo.getUserId();
    
    List<Case> caselst = [
      SELECT
        Id,
        OwnerId,
        FEC_Product_Type__c,
        FEC_Category__c,
        FEC_SubCategory__c,
        FEC_SubCode__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    if (caselst.isEmpty())
      return;

    Case c = caselst.get(0);
    
    if (c.OwnerId != currentUserId) {
      throw new AuraHandledException(System.Label.FEC_MSG_Edit_Owner_Only);
    }
    List<FEC_Actual_Nature_of_Case__c> actualst = [
      SELECT
        Id,
        FEC_Product_Type__c,
        FEC_Category__c,
        FEC_Sub_Category__c,
        FEC_Sub_Code__c
      FROM FEC_Actual_Nature_of_Case__c
      WHERE Id = :natureOfCaseId
      LIMIT 1
    ];
    if (!actualst.isEmpty()) {
      FEC_Actual_Nature_of_Case__c noc = actualst.get(0);
      c.FEC_Actual_Nature_of_Case__c = noc.Id;
      c.FEC_Product_Type__c = noc.FEC_Product_Type__c;
      c.FEC_Category__c = noc.FEC_Category__c;
      c.FEC_SubCategory__c = noc.FEC_Sub_Category__c;
      c.FEC_SubCode__c = noc.FEC_Sub_Code__c;
      update c;
      return;
    }

    List<FEC_Nature_of_Case__c> templatest = [
      SELECT
        Id,
        FEC_Product_Type__c,
        FEC_Category__c,
        FEC_Sub_Category__c,
        FEC_Sub_Code__c
      FROM FEC_Nature_of_Case__c
      WHERE Id = :natureOfCaseId
      LIMIT 1
    ];
    if (!templatest.isEmpty()) {
      FEC_Nature_of_Case__c noc = templatest.get(0);
      c.FEC_Product_Type__c = noc.FEC_Product_Type__c;
      c.FEC_Category__c = noc.FEC_Category__c;
      c.FEC_SubCategory__c = noc.FEC_Sub_Category__c;
      c.FEC_SubCode__c = noc.FEC_Sub_Code__c;
      update c;
    }
  }

  @AuraEnabled
  public static void saveCaseDrafts(
    String caseId,
    String natureOfCaseId,
    String updatedPhoneNumber,
    String routingActionCode
  ) {
    if (String.isBlank(caseId))
      return;
    
    Id currentUserId = UserInfo.getUserId();
    Case existingCase = [SELECT Id, OwnerId, FEC_Draft_Remarks__c, FEC_Draft_Routing_Action_Code__c FROM Case WHERE Id = :caseId LIMIT 1];
    
    if (existingCase.OwnerId != currentUserId) {
      throw new AuraHandledException(System.Label.FEC_MSG_Edit_Owner_Only);
    }
    
    if (String.isNotBlank(natureOfCaseId))
      saveCaseNOC(caseId, natureOfCaseId);

    Case c = new Case(Id = caseId);
    c.FEC_Updated_Info_Phone_Number__c = trimToNull(updatedPhoneNumber);
    if (routingActionCode != null)
      c.FEC_Draft_Routing_Action_Code__c = trimToNull(routingActionCode);
    Boolean hadDraft =
      String.isNotBlank(existingCase.FEC_Draft_Remarks__c) ||
      String.isNotBlank(existingCase.FEC_Draft_Routing_Action_Code__c);
    if (!hadDraft && routingActionCode == null) {
      c.FEC_Draft_Remarks__c = '[]';
    }
    update c;
  }

  private static String trimToNull(String s) {
    return String.isNotBlank(s) ? s.trim() : null;
  }

  /**
   * Nhãn cho FEC_Original_User_Queue__c / FEC_Updated_User_Queue__c:
   * Owner là User → phần email trước @; Owner là Queue → Name queue.
   */
  // tungnm37: đổi thành public để FEC_CofGsrAssignmentService gọi được
  public static String emailLocalPart(String email) {
    if (String.isBlank(email)) {
      return null;
    }
    List<String> parts = email.split('@');
    return parts.isEmpty() ? email.trim() : parts[0].trim();
  }

  // tungnm37: đổi thành public để FEC_CofGsrAssignmentService gọi được
  public static String resolveRoutingHistoryOwnerLabel(Id ownerId, String fallbackName) {
    if (ownerId == null) {
      return fallbackName;
    }
    if (ownerId.getSObjectType() == User.SObjectType) {
      List<User> users = [
        SELECT Email, Name
        FROM User
        WHERE Id = :ownerId
        LIMIT 1
      ];
      if (users.isEmpty()) {
        return fallbackName;
      }
      String local = emailLocalPart(users[0].Email);
      return String.isNotBlank(local)
        ? local
        : (String.isNotBlank(users[0].Name) ? users[0].Name : fallbackName);
    }
    if (ownerId.getSObjectType() == Group.SObjectType) {
      List<Group> groups = [
        SELECT Name
        FROM Group
        WHERE Id = :ownerId AND Type = 'Queue'
        LIMIT 1
      ];
      return !groups.isEmpty() ? groups[0].Name : fallbackName;
    }
    return fallbackName;
  }

  /** User đã load relationship (tránh SOQL lặp). */
  private static String userDisplayForRoutingHistory(User u, String fallbackName) {
    if (u == null) {
      return fallbackName;
    }
    String local = emailLocalPart(u.Email);
    return String.isNotBlank(local)
      ? local
      : (String.isNotBlank(u.Name) ? u.Name : fallbackName);
  }

  private class RouteToDisplayInfo {
    String nextTeam;
    FEC_CommonUltils.PicklistOption nextQueue;
  }

  // Chỉ dùng để hiển thị Team/Queue trên UI Route to theo nhánh Stage Change hiện hành.
  private static RouteToDisplayInfo resolveRouteToDisplayInfo(
    Id caseId,
    Id currentStageId,
    String routeToActionId,
    String revertActionId,
    Boolean latestRoutingHistoryIsReverted
  ) {
    if (currentStageId == null) {
      return null;
    }

    //thangtv: đồng bộ hiển thị với logic submit Route to mới.
    // Nếu history mới nhất là Revert + IsReverted=true thì nhánh đích = latestHist.PreviousStage.
    List<FEC_Routing_Action_History__c> latestHist = [
      SELECT Id, FEC_Routing_Action__c, FEC_IsReverted__c, FEC_Previous_Stage__c
      FROM FEC_Routing_Action_History__c
      WHERE
        FEC_Case__c = :caseId
        AND FEC_Routing_Action__c IN :new List<String>{ ROUTE_TO, REVERT }
      ORDER BY CreatedDate DESC, Id DESC
      LIMIT 1
    ];
    Boolean routeByLatestRevertHistory =
      !latestHist.isEmpty() &&
      REVERT.equals(latestHist[0].FEC_Routing_Action__c) &&
      latestHist[0].FEC_IsReverted__c == true &&
      latestHist[0].FEC_Previous_Stage__c != null;

    Boolean shouldRouteByNonRevertedStageChange = false;
    List<FEC_Routing_Action_History__c> latestStageHistoryForRoute = [
      SELECT
        Id,
        FEC_IsReverted__c,
        FEC_Previous_Stage__c,
        FEC_Next_Stage__c
      FROM FEC_Routing_Action_History__c
      WHERE
        FEC_Case__c = :caseId
        AND FEC_Routing_Action__c IN :new List<String>{ ROUTE_TO, REVERT }
        AND FEC_Previous_Stage__c != null
      ORDER BY CreatedDate DESC, Id DESC
      LIMIT 2
    ];
    shouldRouteByNonRevertedStageChange =
      latestStageHistoryForRoute.size() == 2 &&
      latestStageHistoryForRoute.get(0).FEC_IsReverted__c == true &&
      latestStageHistoryForRoute.get(1).FEC_IsReverted__c == false &&
      latestStageHistoryForRoute.get(0).FEC_Previous_Stage__c != null &&
      latestStageHistoryForRoute.get(0).FEC_Next_Stage__c != null &&
      latestStageHistoryForRoute.get(1).FEC_Previous_Stage__c ==
      latestStageHistoryForRoute.get(0).FEC_Next_Stage__c &&
      latestStageHistoryForRoute.get(1).FEC_Next_Stage__c ==
      latestStageHistoryForRoute.get(0).FEC_Previous_Stage__c;

    List<FEC_Stage_Change__c> routeToChangelst = new List<FEC_Stage_Change__c>();
    if (String.isNotBlank(routeToActionId)) {
      if (routeByLatestRevertHistory) {
        routeToChangelst = [
          SELECT FEC_Next_Queue__c, FEC_Team_User_Group__c
          FROM FEC_Stage_Change__c
          WHERE
            FEC_Previous_Stage__c = :currentStageId
            AND FEC_Active__c = TRUE
            AND FEC_Action_Button__c = :routeToActionId
            AND FEC_Next_Stage__c = :latestHist[0].FEC_Previous_Stage__c
          LIMIT 1
        ];
      } else if (shouldRouteByNonRevertedStageChange) {
        routeToChangelst = [
          SELECT FEC_Next_Queue__c, FEC_Team_User_Group__c
          FROM FEC_Stage_Change__c
          WHERE
            FEC_Previous_Stage__c = :currentStageId
            AND FEC_Active__c = TRUE
            AND FEC_Action_Button__c = :routeToActionId
            AND FEC_IsReverted__c = false
          LIMIT 1
        ];
      } else if (latestRoutingHistoryIsReverted) {
        routeToChangelst = [
          SELECT FEC_Next_Queue__c, FEC_Team_User_Group__c
          FROM FEC_Stage_Change__c
          WHERE
            FEC_Previous_Stage__c = :currentStageId
            AND FEC_Active__c = TRUE
            AND FEC_Action_Button__c = :routeToActionId
            AND FEC_IsReverted__c = true
          LIMIT 1
        ];
      }
      if (routeToChangelst.isEmpty()) {
        routeToChangelst = [
          SELECT FEC_Next_Queue__c, FEC_Team_User_Group__c
          FROM FEC_Stage_Change__c
          WHERE
            FEC_Previous_Stage__c = :currentStageId
            AND FEC_Active__c = TRUE
            AND FEC_Action_Button__c = :routeToActionId
            AND FEC_IsReverted__c = false
          LIMIT 1
        ];
      }
    }

    // Trường hợp custom label "Route to" nhưng action code thực là Revert.
    if (routeToChangelst.isEmpty() && String.isNotBlank(revertActionId)) {
      routeToChangelst = [
        SELECT FEC_Next_Queue__c, FEC_Team_User_Group__c
        FROM FEC_Stage_Change__c
        WHERE
          FEC_Previous_Stage__c = :currentStageId
          AND FEC_Active__c = TRUE
          AND FEC_Action_Button__c = :revertActionId
          AND FEC_IsReverted__c = true
        LIMIT 1
      ];
    }

    if (routeToChangelst.isEmpty()) {
      return null;
    }

    RouteToDisplayInfo info = new RouteToDisplayInfo();
    info.nextTeam = routeToChangelst.get(0).FEC_Team_User_Group__c;
    info.nextQueue = new FEC_CommonUltils.PicklistOption();

    if (String.isNotBlank(routeToChangelst.get(0).FEC_Next_Queue__c)) {
      List<Group> queues = [
        SELECT Id, Name
        FROM Group
        WHERE
          Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
          AND DeveloperName = :routeToChangelst.get(0).FEC_Next_Queue__c
        LIMIT 1
      ];
      if (!queues.isEmpty()) {
        info.nextQueue = new FEC_CommonUltils.PicklistOption(
          queues.get(0).Name,
          (String) queues.get(0).Id,
          null
        );
      }
    }
    return info;
  }

  //thangtv: hỗ trợ hiển thị Decision (business.lastUser) cho Revert theo Stage Change trước, fallback logic Route to cũ
  //thangtv
  private static String resolveLastUserForRevertDecisionDisplay(
    Id caseId,
    Id currentStageId,
    Boolean useNonRevertedFirst
  ) {
    FEC_Routing_Action_History__c matchedRouteToHistory;

    if (currentStageId != null && useNonRevertedFirst == true) {
      // Nhánh cho trường hợp value='Route to' nhưng code='Revert'
      List<FEC_Stage_Change__c> revertByNonReverted = [
        SELECT FEC_Next_Stage__c
        FROM FEC_Stage_Change__c
        WHERE
          FEC_Previous_Stage__c = :currentStageId
          AND FEC_Active__c = TRUE
          AND FEC_Action_Button__r.FEC_Code__c = :REVERT
          AND FEC_IsReverted__c = FALSE
        ORDER BY CreatedDate DESC, Id DESC
        LIMIT 1
      ];

      if (!revertByNonReverted.isEmpty() && revertByNonReverted[0].FEC_Next_Stage__c != null) {
        List<FEC_Routing_Action_History__c> routeToByStage2Histories = [
          SELECT
            Id,
            FEC_Previous_Stage__c,
            FEC_Previous_Stage__r.FEC_Default_Stage__c,
            FEC_Perform_User__c,
            FEC_Perform_User__r.FEC_User_Division_Group__c,
            CreatedDate
          FROM FEC_Routing_Action_History__c
          WHERE
            FEC_Case__c = :caseId
            AND FEC_Routing_Action__c = :ROUTE_TO
            AND FEC_Previous_Stage__c = :revertByNonReverted[0].FEC_Next_Stage__c
          ORDER BY CreatedDate DESC, Id DESC
          LIMIT 1
        ];
        if (!routeToByStage2Histories.isEmpty()) {
          matchedRouteToHistory = routeToByStage2Histories[0];
        }
      }
    }

    // Nhánh Revert chuẩn (value='Revert', code='Revert')
    if (matchedRouteToHistory == null && currentStageId != null) {
      List<FEC_Stage_Change__c> revertByReverted = [
        SELECT FEC_Next_Stage__c
        FROM FEC_Stage_Change__c
        WHERE
          FEC_Previous_Stage__c = :currentStageId
          AND FEC_Active__c = TRUE
          AND FEC_Action_Button__r.FEC_Code__c = :REVERT
          AND FEC_IsReverted__c = TRUE
        ORDER BY CreatedDate DESC, Id DESC
        LIMIT 1
      ];

      if (
        !revertByReverted.isEmpty() &&
        revertByReverted[0].FEC_Next_Stage__c != null
      ) {
        List<FEC_Routing_Action_History__c> routeToByStageHistories = [
          SELECT
            Id,
            FEC_Previous_Stage__c,
            FEC_Previous_Stage__r.FEC_Default_Stage__c,
            FEC_Perform_User__c,
            FEC_Perform_User__r.FEC_User_Division_Group__c,
            CreatedDate
          FROM FEC_Routing_Action_History__c
          WHERE
            FEC_Case__c = :caseId
            AND FEC_Routing_Action__c = :ROUTE_TO
            AND FEC_Previous_Stage__c = :revertByReverted[0].FEC_Next_Stage__c
          ORDER BY CreatedDate DESC, Id DESC
          LIMIT 1
        ];
        if (!routeToByStageHistories.isEmpty()) {
          matchedRouteToHistory = routeToByStageHistories[0];
        }
      }
    }

    // Nếu đang tính cho route-label mà chưa ra dữ liệu thì fallback về nhánh revert chuẩn.
    if (matchedRouteToHistory == null && currentStageId != null && useNonRevertedFirst == true) {
      List<FEC_Stage_Change__c> revertByReverted = [
        SELECT FEC_Next_Stage__c
        FROM FEC_Stage_Change__c
        WHERE
          FEC_Previous_Stage__c = :currentStageId
          AND FEC_Active__c = TRUE
          AND FEC_Action_Button__r.FEC_Code__c = :REVERT
          AND FEC_IsReverted__c = TRUE
        ORDER BY CreatedDate DESC, Id DESC
        LIMIT 1
      ];
      if (!revertByReverted.isEmpty() && revertByReverted[0].FEC_Next_Stage__c != null) {
        List<FEC_Routing_Action_History__c> routeToByStageHistories = [
          SELECT
            Id,
            FEC_Previous_Stage__c,
            FEC_Previous_Stage__r.FEC_Default_Stage__c,
            FEC_Perform_User__c,
            FEC_Perform_User__r.FEC_User_Division_Group__c,
            CreatedDate
          FROM FEC_Routing_Action_History__c
          WHERE
            FEC_Case__c = :caseId
            AND FEC_Routing_Action__c = :ROUTE_TO
            AND FEC_Previous_Stage__c = :revertByReverted[0].FEC_Next_Stage__c
          ORDER BY CreatedDate DESC, Id DESC
          LIMIT 1
        ];
        if (!routeToByStageHistories.isEmpty()) {
          matchedRouteToHistory = routeToByStageHistories[0];
        }
      }
    }

    // Fallback 2 giữ nguyên logic cũ: lấy Route to history mới nhất
    if (matchedRouteToHistory == null) {
      List<FEC_Routing_Action_History__c> latestRouteToHistories = [
        SELECT
          Id,
          FEC_Previous_Stage__c,
          FEC_Previous_Stage__r.FEC_Default_Stage__c,
          FEC_Perform_User__c,
          FEC_Perform_User__r.FEC_User_Division_Group__c,
          CreatedDate
        FROM FEC_Routing_Action_History__c
        WHERE
          FEC_Routing_Action__c = :ROUTE_TO
          AND FEC_Case__c = :caseId
        ORDER BY CreatedDate DESC, Id DESC
        LIMIT 1
      ];
      if (!latestRouteToHistories.isEmpty()) {
        matchedRouteToHistory = latestRouteToHistories[0];
      }
    }

    if (matchedRouteToHistory != null && String.isNotBlank(matchedRouteToHistory.FEC_Perform_User__c)) {
      return FRONT_LINE.equals(
          matchedRouteToHistory.FEC_Perform_User__r.FEC_User_Division_Group__c
        )
        ? 'User\'s Team Queue'
        : 'User';
    }
    return null;
  }

  //thangtv: Sau Route to / Revert - nếu Owner là User thuộc CS Frontline thì map sang Queue chính của user đó
  /**
   * Sau Route to / Revert: nếu Owner không phải Queue mà là User có
   * FEC_User_Division_Group__c = CS Frontline, gán Owner = Queue có
   * DeveloperName = User.FEC_Main_Queue__c.
   */
  private static Id applyFrontlineMainQueueIfUserOwner(Id ownerId) {
    if (ownerId == null) {
      return null;
    }
    if (ownerId.getSobjectType() == Group.SObjectType) {
      List<Group> grp = [
        SELECT Id, Type
        FROM Group
        WHERE Id = :ownerId
        LIMIT 1
      ];
      if (
        !grp.isEmpty() &&
        FEC_ConstantCommon.GROUP_TYPE_QUEUE.equals(grp[0].Type)
      ) {
        return ownerId;
      }
      return ownerId;
    }
    if (ownerId.getSobjectType() != User.SObjectType) {
      return ownerId;
    }
    User u = [
      SELECT FEC_User_Division_Group__c, FEC_Main_Queue__c
      FROM User
      WHERE Id = :ownerId
      LIMIT 1
    ];
    if (
      !FRONT_LINE.equals(u.FEC_User_Division_Group__c) ||
      String.isBlank(u.FEC_Main_Queue__c)
    ) {
      return ownerId;
    }
    List<Group> qs = [
      SELECT Id
      FROM Group
      WHERE
        Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
        AND DeveloperName = :u.FEC_Main_Queue__c
      LIMIT 1
    ];
    return qs.isEmpty() ? ownerId : qs[0].Id;
  }

  //thangtv: overload String cho applyFrontlineMainQueueIfUserOwner
  private static String applyFrontlineMainQueueIfUserOwner(String ownerIdStr) {
    if (String.isBlank(ownerIdStr)) {
      return ownerIdStr;
    }
    try {
      Id oid = Id.valueOf(ownerIdStr.trim());
      Id resolved = applyFrontlineMainQueueIfUserOwner(oid);
      return resolved != null ? String.valueOf(resolved) : ownerIdStr;
    } catch (Exception e) {
      return ownerIdStr;
    }
  }

  //thangtv: Stage Change.FEC_Next_Queue__c có thể là Queue Id hoặc DeveloperName, luôn quy đổi về Queue Id để set Owner
  private static String resolveQueueOwnerIdFromStageChangeValue(String nextQueueValue) {
    if (String.isBlank(nextQueueValue)) {
      return nextQueueValue;
    }
    String normalized = nextQueueValue.trim();
    try {
      Id qid = Id.valueOf(normalized);
      if (qid.getSobjectType() == Group.SObjectType) {
        List<Group> grp = [
          SELECT Id, Type
          FROM Group
          WHERE Id = :qid
          LIMIT 1
        ];
        if (
          !grp.isEmpty() &&
          FEC_ConstantCommon.GROUP_TYPE_QUEUE.equals(grp[0].Type)
        ) {
          return String.valueOf(grp[0].Id);
        }
      }
      return normalized;
    } catch (Exception e) {
      List<Group> q = [
        SELECT Id
        FROM Group
        WHERE
          Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
          AND DeveloperName = :normalized
        LIMIT 1
      ];
      return q.isEmpty() ? normalized : String.valueOf(q[0].Id);
    }
  }

  //thangtv: kiểm tra Owner có phải Queue hay không
  /** Owner là Queue (Group Type = Queue). */
  private static Boolean isQueueOwnerId(Id ownerId) {
    if (ownerId == null || ownerId.getSobjectType() != Group.SObjectType) {
      return false;
    }
    List<Group> grp = [
      SELECT Type
      FROM Group
      WHERE Id = :ownerId
      LIMIT 1
    ];
    return !grp.isEmpty() &&
      FEC_ConstantCommon.GROUP_TYPE_QUEUE.equals(grp[0].Type);
  }

  /** true nếu giá trị lookup NOC từ UI khác baseline Id (null/blank coi là cùng khi cả hai rỗng). */
  private static Boolean nocLookupDimensionDiffers(String incoming, Id baseline) {
    String inc = incoming == null ? '' : incoming.trim();
    String base = baseline == null ? '' : String.valueOf(baseline);
    if (String.isBlank(inc) && String.isBlank(base)) {
      return false;
    }
    return inc != base;
  }

  private static Boolean nocLookupDimensionDiffersIds(Id incoming, Id baseline) {
    return nocLookupDimensionDiffers(
      incoming == null ? null : String.valueOf(incoming),
      baseline
    );
  }

  //thangtv: khi Owner hiện tại là Queue, tra FEC_Routing_Action_History__c để tìm User thực sự
  /**
   * Sau Route to / Revert: nếu Owner hiện tại là Queue, tìm trên FEC_Routing_Action_History__c
   * bản mới nhất có FEC_Original_User_Queue__c = Name của queue đó và cùng Case;
   * nếu FEC_Updated_User_Queue_ID__c trỏ tới User (không phải Queue) thì gán Owner = User đó.
   */
  private static String applyUserOwnerFromHistoryWhenCurrentOwnerIsQueue(
    String caseId,
    String ownerIdStr
  ) {
    if (String.isBlank(caseId) || String.isBlank(ownerIdStr)) {
      return ownerIdStr;
    }
    Id ownerId;
    try {
      ownerId = Id.valueOf(ownerIdStr.trim());
    } catch (Exception e) {
      return ownerIdStr;
    }
    if (!isQueueOwnerId(ownerId)) {
      return ownerIdStr;
    }
    List<Group> q = [
      SELECT Name
      FROM Group
      WHERE Id = :ownerId AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
      LIMIT 1
    ];
    if (q.isEmpty() || String.isBlank(q[0].Name)) {
      return ownerIdStr;
    }
    String queueName = q[0].Name.trim();

    List<FEC_Routing_Action_History__c> hist = [
      SELECT FEC_Updated_User_Queue_ID__c
      FROM FEC_Routing_Action_History__c
      WHERE
        FEC_Case__c = :caseId
        AND FEC_Original_User_Queue__c = :queueName
      ORDER BY CreatedDate DESC, Id DESC
      LIMIT 1
    ];
    if (hist.isEmpty() || String.isBlank(hist[0].FEC_Updated_User_Queue_ID__c)) {
      return ownerIdStr;
    }
    Id updatedId;
    try {
      updatedId = Id.valueOf(hist[0].FEC_Updated_User_Queue_ID__c.trim());
    } catch (Exception e) {
      return ownerIdStr;
    }
    if (updatedId.getSobjectType() == User.SObjectType) {
      return String.valueOf(updatedId);
    }
    if (updatedId.getSobjectType() == Group.SObjectType) {
      List<Group> g2 = [
        SELECT Type
        FROM Group
        WHERE Id = :updatedId
        LIMIT 1
      ];
      if (
        !g2.isEmpty() &&
        FEC_ConstantCommon.GROUP_TYPE_QUEUE.equals(g2[0].Type)
      ) {
        return ownerIdStr;
      }
    }
    return ownerIdStr;
  }

  /**
   * Khớp công thức Case.FEC_Final_Status__c (Pending → "Pending - " + FEC_Team__c, không Pending → Status).
   * Dùng cho trigger Change Owner khi cần snapshot từ Status + FEC_Team__c.
   * Author: ToanND61 (10/04/2026)
   */
  private static String routingHistoryFinalStatusSnapshot(Case k) {
    if (k == null) {
      return null;
    }
    if (FEC_ConstantCommon.CASE_STATUS_PENDING.equals(k.Status)) {
      String team = k.FEC_Team__c != null ? k.FEC_Team__c : '';
      return 'Pending - ' + team;
    }
    return k.Status;
  }


  // tungnm37: đổi thành public để FEC_CofGsrAssignmentService gọi được
  public static void markCaseSubmittedAndClearDrafts(String caseId) {
    if (String.isBlank(caseId))
      return;
    List<Case> caselst = [
      SELECT Id, IsClosed
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    if (caselst.isEmpty())
      return;
    Case c = caselst.get(0);
    Case toUpdate = new Case(
      Id = caseId,
      FEC_Is_Submited__c = true,
      FEC_Draft_Routing_Action_Code__c = null,
      FEC_Draft_Remarks__c = null
    );
    if (c.IsClosed == false) {
      toUpdate.Status = FEC_ConstantCommon.CASE_STATUS_PENDING;
    }
    Database.update(toUpdate, AccessLevel.SYSTEM_MODE);
  }

  @AuraEnabled
  public static void markCaseSubmittedWithoutRouting(String caseId) {
    markCaseSubmittedAndClearDrafts(caseId);
  }
//PhongBT: tạo FEC_Case_Flow_History__c khi submit case lần đầu.
  @AuraEnabled
  public static void markCaseSubmittedWithoutRoutingWithHistory(String caseId, String natureOfCaseId, String fieldListJson) {
    markCaseSubmittedAndClearDrafts(caseId);
    createCaseFlowHistory(caseId, natureOfCaseId, fieldListJson);
  }
  //PhongBT: tạo FEC_Case_Flow_History__c khi submit case lần đầu.
  /**
   * Tạo bản ghi FEC_Case_Flow_History__c khi Case được submit lần đầu (creation stage).
   * Chỉ tạo khi Case chưa submit (FEC_Is_Submited__c = false trước khi gọi).
   */
  public static void createCaseFlowHistory(String caseId, String natureOfCaseId, String fieldListJson) {
    if (String.isBlank(caseId)) return;
    try {
      FEC_Case_Flow_History__c history = new FEC_Case_Flow_History__c(
        FEC_Case__c = caseId,
        FEC_Field_List__c = fieldListJson
      );
      //PhongBT: Chỉ gán NOC lên history khi BP code chứa COF hoặc GSR (lookup trỏ FEC_Nature_of_Case__c).
      if (String.isNotBlank(natureOfCaseId)) {
        List<FEC_Nature_of_Case__c> nocRows = [
          SELECT Id, FEC_Business_Process__r.FEC_Code__c
          FROM FEC_Nature_of_Case__c
          WHERE Id = :natureOfCaseId
          LIMIT 1
        ];
        if (!nocRows.isEmpty()) {
          String bpCode = nocRows[0].FEC_Business_Process__r == null
            ? null
            : nocRows[0].FEC_Business_Process__r.FEC_Code__c;
          if (String.isNotBlank(bpCode)) {
            String u = bpCode.toUpperCase();
            if (u.contains('GSR') || u.contains('COF')) {
        history.FEC_Nature_of_Cases__c = natureOfCaseId;
            }
          }
        }
      }
      insert history;
    } catch (Exception e) {
      System.debug('createCaseFlowHistory error: ' + e.getMessage());
    }
  }

  @AuraEnabled
  public static Object run(String method, Map<String, String> params) {
    try {
      Method selectedMethod = METHOD_MAP.get(method);
      String caseId;
      String oldOwnerName;
      String stageName;
      Id oldOwnerId;
      Id currentStageId;
      String finalStatusBeforeSubmit = null;
      
      if (params != null) {
        caseId = (String) params.get('caseId');
        Case c = [
          SELECT
            Id,
            OwnerId,
            Owner.Name,
            FEC_Current_Case_Stage__c,
            FEC_Stage_Name__c,
            FEC_Final_Status__c,
            FEC_Actual_Nature_of_Case__c,
            FEC_Customer_Type__c,
            FEC_Account_Contract_Number_PL__c
          FROM Case
          WHERE Id = :caseId
          LIMIT 1
        ];
        // if (FEC_ConstantCommon.CASE_NON_EXISTING_CUSTOMER.equals(c.FEC_Customer_Type__c) && String.isBlank(c.FEC_Account_Contract_Number_PL__c)) {
        //   throw new AuraHandledException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Account/ Contract Number' }));
        // }
        oldOwnerId = c.OwnerId;
        oldOwnerName = resolveRoutingHistoryOwnerLabel(c.OwnerId, c.Owner?.Name);
        stageName = c.FEC_Stage_Name__c;
        currentStageId = c.FEC_Current_Case_Stage__c;
        finalStatusBeforeSubmit = c.FEC_Final_Status__c;
      }

      String blockCode = (String)params.get('blockCode');
      String replacementFee = (String)params.get('replacementFee');
      String last4Digit = (String)params.get('last4Digit');
      //PhongBT: Clone Actual NOC + Actual MDS
      //PhongBT: Tạo case flow history
      FEC_CofGsrRoutePrepareService.prepareActualNatureCloneAndCreationHistory(
        caseId,
        params,
        method
      );
      switch on selectedMethod {
        when ROUTE_TO {
          String queueId = (String) params.get('queueId');
          String natureOfCaseId = (String) params.get('natureOfCaseId');
          String actionId = (String) params.get('actionId');
          //PhongBT: tạo FEC_Case_Flow_History__c khi submit case lần đầu.
          String fieldListJson = (String) params.get('fieldListJson');
          if (String.isBlank(queueId)) {
            throw new AuraHandledException(System.Label.FEC_MSG_Can_Not_Find_Next_Stage);
          }
          //PhongBT: tạo FEC_Case_Flow_History__c khi submit case lần đầu.
          // Kiểm tra creation stage trước khi mark submitted
          Boolean isCreationStage = !([SELECT FEC_Is_Submited__c FROM Case WHERE Id = :caseId LIMIT 1].FEC_Is_Submited__c == true);
          markCaseSubmittedAndClearDrafts(caseId);
          //PhongBT: tạo FEC_Case_Flow_History__c khi submit case lần đầu.
          if (isCreationStage) {
            createCaseFlowHistory(caseId, natureOfCaseId, fieldListJson);
          }
          route(caseId, queueId, natureOfCaseId, actionId, finalStatusBeforeSubmit);
          return null;
        }
        // tungnm37 thêm: COF/GSR - không đổi owner, chỉ tạo Assignment + Case Remarks + Routing Action History
        when ROUTE_TO_COF_GSR {
          // tungnm37: delegate toàn bộ xử lý sang FEC_CofGsrAssignmentService
          return FEC_CofGsrAssignmentService.handleRouteToCofGsr(caseId, params, stageName);
        }
        when REVERT {
          String revertActionId = (String) params.get('actionId');
          //thangtv: action.value (LWC) → phân nhánh Stage Change FEC_IsReverted__c + custom label history
          String routingActionValue = params != null
            ? (String) params.get('routingActionValue')
            : null;
          //PhongBT: update bộ noc chọn ở updated khi revert về
          String revertNocId = (String) params.get('natureOfCaseId');
          FEC_CofGsrRoutePrepareService.updateCaseNocFromSelection(caseId, revertNocId);
          markCaseSubmittedAndClearDrafts(caseId);
          revert(caseId, revertActionId, finalStatusBeforeSubmit, routingActionValue);
          return null;
        }
        when RECALL {
          markCaseSubmittedAndClearDrafts(caseId);
          recall(caseId);
          createRoutingActionHis('Recall', '', oldOwnerName, oldOwnerId, caseId, stageName, finalStatusBeforeSubmit, currentStageId);
          return null;
        }
        when CANCEL {
          markCaseSubmittedAndClearDrafts(caseId);
          cancel(caseId);
          createRoutingActionHis('Cancel', '', oldOwnerName, oldOwnerId, caseId, stageName, finalStatusBeforeSubmit, currentStageId);
          return null;
        }
        when REOPEN {
          markCaseSubmittedAndClearDrafts(caseId);
          reopen(caseId);
          createRoutingActionHis('Reopen', '', oldOwnerName, oldOwnerId, caseId, stageName, finalStatusBeforeSubmit, currentStageId);
          return null;
        }
        when ESCALATE {
          markCaseSubmittedAndClearDrafts(caseId);
          escalate(caseId);
          createRoutingActionHis('Escalate', '', oldOwnerName, oldOwnerId, caseId, stageName, finalStatusBeforeSubmit, currentStageId);
          return null;
        }
        when REJECT {
          markCaseSubmittedAndClearDrafts(caseId);
          reject(caseId);
          createRoutingActionHis('Reject', '', oldOwnerName, oldOwnerId, caseId, stageName, finalStatusBeforeSubmit, currentStageId);
          return null;
        }
        when RESOLVE {
          markCaseSubmittedAndClearDrafts(caseId);
          resolve(caseId);
          createRoutingActionHis('Resolve', '', oldOwnerName, oldOwnerId, caseId, stageName, finalStatusBeforeSubmit, currentStageId);
          return null;
        }
        when TRANSFER {
          markCaseSubmittedAndClearDrafts(caseId);
          String userOrQueueId = (String) params.get('userOrQueueId');
          // Đổi owner trước (transfer đã registerSkip), rồi ghi history — tránh 2 bản; Updated = owner sau transfer
          transfer(caseId, userOrQueueId);
          createRoutingActionHis('Transfer', '', oldOwnerName, oldOwnerId, caseId, stageName, finalStatusBeforeSubmit, currentStageId);
          return null;
        }
        when UPDATEACTION {
          String decision = (String) params.get('decision');
          updateCaseTeamAndOwner(caseId, decision);
          markCaseSubmittedAndClearDrafts(caseId);
          createRoutingActionHis('Update', decision, oldOwnerName, oldOwnerId, caseId, stageName, finalStatusBeforeSubmit, currentStageId);
          return null;
        }
        when PHONE_UPDATE {
          return FEC_UpdateCustomerContact.updateValue(caseId, PHONE_UPDATE);
        }
        when EMAIL_UPDATE {
          return FEC_UpdateCustomerContact.updateValue(caseId, EMAIL_UPDATE);
        }
        when FULLNAME_UPDATE {
          return FEC_UpdateCustomerBasicInfo.updateValue(
            caseId,
            FULLNAME_UPDATE
          );
        }
        when DOB_UPDATE {
          return FEC_UpdateCustomerBasicInfo.updateValue(caseId, DOB_UPDATE);
        }
        when GENDER_UPDATE {
          return FEC_UpdateCustomerBasicInfo.updateValue(caseId, GENDER_UPDATE);
        }
        when ADDRESS_UPDATE {
          return FEC_UpdateCustomerAddress.updateValue(
            caseId,
            params,
            ADDRESS_UPDATE
          );
        }
        when OC_001 {
          System.debug(OC_001);
        }
        when BLOCK_CARD {
          return FEC_CardLockUnLockController.lockUnblockCard(caseId, 'B', blockCode, BLOCK_CARD);
        }
        when UNBLOCK_CARD {
          return FEC_CardLockUnLockController.lockUnblockCard(caseId, 'U', blockCode, UNBLOCK_CARD);
        }
        when PIN_REISSUE {
          return FEC_PinReplacementController.pinReplacement(caseId, PIN_REISSUE);
        }
        when REPLACE_CARD {
          return FEC_CardReplacementAddressController.cardReplacement(caseId, REPLACE_CARD, blockCode, last4Digit, replacementFee);
        }
        when else {
          // throw new CaseBusinessServiceException('Method not found.');
        }
      }

      markCaseSubmittedAndClearDrafts(caseId);
      return null;
    } catch (CaseBusinessServiceException e) {
      throw new AuraHandledException(e.getMessage());
    } catch (FEC_APIServiceException e) {
      throw new AuraHandledException(e.getMessage());
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  private static void route(
    String caseId,
    String queueId,
    String natureOfCaseId,
    String actionId,
    String finalStatusBeforeSubmit
  ) {
    try {
      Long corrId = DateTime.now().getTime();
      System.debug(
        'FEC_DEBUG CaseBusinessService.route start corrId=' +
        corrId +
        ' caseId=' + caseId +
        ' queueId=' + queueId +
        ' natureOfCaseId=' + natureOfCaseId +
        ' actionId=' + actionId +
        ' currentUserId=' + UserInfo.getUserId()
      );

      List<User> userlst = [
        SELECT Email, UserRole.Name, Id, FEC_User_Group__c
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
      ];

      if (userlst.isEmpty())
        return;

      User currentUser = userlst.get(0);

      List<String> rolelst = new List<String>{ currentUser.FEC_User_Group__c };

      List<Case> caselst = [
        SELECT
          Id,
          OwnerId,
          Owner.Name,
          FEC_Current_Case_Stage__c,
          FEC_Current_Case_Stage__r.FEC_Default_Stage__c,
          FEC_Actual_Nature_of_Case__c,
          FEC_Team__c,
          FEC_Account_or_Contract__c,
          FEC_Interaction__c,
          FEC_Category__c,
          FEC_SubCategory__c,
          FEC_SubCode__c,
          FEC_Category__r.Name,
          FEC_Category__r.FEC_Code__c,
          FEC_SubCategory__r.Name,
          FEC_SubCategory__r.FEC_Code__c,
          FEC_SubCode__r.Name,
          FEC_SubCode__r.FEC_Code__c,
          FEC_RD_Payment_Contract_Assessment__c
        FROM Case
        WHERE Id = :caseId
      ];

      if (caselst.isEmpty())
        throw new CaseBusinessServiceException(
          String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Case Id' })
        );

      Case updatedCase = caselst.get(0);

      System.debug(
        'FEC_DEBUG CaseBusinessService.route currOwnerId=' +
        updatedCase.OwnerId +
        ' currOwnerName=' + updatedCase.Owner.Name +
        ' currStageId=' + updatedCase.FEC_Current_Case_Stage__c
      );

      List<FEC_Case_Stage__c> stagelst;

      // true nếu stage chưa set (blank) hoặc đang ở Stage 1 (default) — dùng cho hardcode RC27.
      // Toannd61
      Boolean isCreationStageRoute =
        String.isBlank(updatedCase.FEC_Current_Case_Stage__c) ||
        (updatedCase.FEC_Current_Case_Stage__r != null &&
         updatedCase.FEC_Current_Case_Stage__r.FEC_Default_Stage__c == true);

      if (String.isBlank(updatedCase.FEC_Current_Case_Stage__c)) {
        List<FEC_Nature_of_Case__c> natureOfCaselst = [
          SELECT Id, FEC_Business_Process__c, FEC_User_Group__c
          FROM FEC_Nature_of_Case__c
          WHERE Id = :natureOfCaseId
        ];

        if (!natureOfCaselst.isEmpty()) {
          String caseStageQuery =
            'SELECT Id ' +
            'FROM FEC_Case_Stage__c ' +
            'WHERE FEC_Nature_of_Cases__c = :natureOfCaseId ' +
            'AND FEC_Active__c = TRUE ' +
            'AND FEC_Default_Stage__c = TRUE ' +
            'AND FEC_User_Group__c INCLUDES (\'' +
            String.join(new List<String>(rolelst), '\',\'') +
            '\')';

          Map<String, Object> bindVars = new Map<String, Object>{
            'natureOfCaseId' => natureOfCaselst.get(0)
              .Id
          };

          stagelst = (List<FEC_Case_Stage__c>) Database.queryWithBinds(
            caseStageQuery,
            bindVars,
            AccessLevel.USER_MODE
          );

          if (!stagelst.isEmpty()) {
            updatedCase.FEC_Current_Case_Stage__c = stagelst.get(0).Id;
          }
        }
      }

      String nextOwnerName;
      String currentOwnerName = resolveRoutingHistoryOwnerLabel(
        updatedCase.OwnerId,
        updatedCase.Owner?.Name
      );
      Id currentOwnerId = updatedCase.OwnerId;

      //thangtv: Route to — đọc history mới nhất (IsReverted + Perform user) để chọn Stage Change và gán Owner khi cần
      List<FEC_Routing_Action_History__c> latestHistForRoute = [
        SELECT
          Id,
          FEC_Routing_Action__c,
          FEC_IsReverted__c,
          FEC_Previous_Stage__c,
          FEC_Perform_User__c
        FROM FEC_Routing_Action_History__c
        WHERE
          FEC_Case__c = :caseId
          AND FEC_Routing_Action__c IN :new List<String>{ ROUTE_TO, REVERT }
        ORDER BY CreatedDate DESC, Id DESC
        LIMIT 1
      ];
      Boolean routeByLatestRevertHistory =
        !latestHistForRoute.isEmpty() &&
        REVERT.equals(latestHistForRoute.get(0).FEC_Routing_Action__c) &&
        latestHistForRoute.get(0).FEC_IsReverted__c == true &&
        latestHistForRoute.get(0).FEC_Previous_Stage__c != null;
      Id targetNextStageIdFromHistory = routeByLatestRevertHistory
        ? latestHistForRoute.get(0).FEC_Previous_Stage__c
        : null;

      //thangtv
      List<FEC_Stage_Change__c> changelst = new List<FEC_Stage_Change__c>();
      if (routeByLatestRevertHistory) {
        changelst = [
          SELECT
            Id,
            FEC_Previous_Stage__c,
            FEC_Previous_Stage__r.FEC_Code__c,
            FEC_Next_Stage__c,
            FEC_Next_Queue__c
          FROM FEC_Stage_Change__c
          WHERE
            FEC_Previous_Stage__c = :updatedCase.FEC_Current_Case_Stage__c
            AND FEC_Active__c = TRUE
            AND FEC_Action_Button__c = :actionId
            AND FEC_Next_Stage__c = :targetNextStageIdFromHistory
          LIMIT 1
        ];
      } else {
        changelst = [
        SELECT
          Id,
          FEC_Previous_Stage__c,
          FEC_Previous_Stage__r.FEC_Code__c,
          FEC_Next_Stage__c,
          FEC_Next_Queue__c
        FROM FEC_Stage_Change__c
        WHERE
          FEC_Previous_Stage__c = :updatedCase.FEC_Current_Case_Stage__c
          AND FEC_Active__c = TRUE
          AND FEC_Action_Button__c = :actionId
            AND FEC_IsReverted__c = false
        ];
      }

      if (changelst.isEmpty()) {
        throw new CaseBusinessServiceException(
          String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Stage Change for action' })
        );
      }

      FEC_Stage_Change__c selectedChange = changelst.get(0);

      // [HARDCODE RC27.01/RC27.02]: Stage1 → Stage3 (SP), bỏ qua Stage2.
      // SubCode lấy từ NOC (natureOfCaseId) nếu chưa set trên Case (lần submit đầu).
      // Block Code được phép ghi đè RC27: bỏ qua hardcode nếu Block Code đang kích hoạt.
      // Toannd61
      if (isCreationStageRoute &&
          !FEC_BlockCodeRoutingService.isCustomerHistoryForcedOmDay2(updatedCase.FEC_Account_or_Contract__c)) {
        String rc27SubCode = updatedCase.FEC_SubCode__r?.FEC_Code__c;
        if (String.isBlank(rc27SubCode) && String.isNotBlank(natureOfCaseId)) {
          List<FEC_Nature_of_Case__c> nocRc27Lst = [
            SELECT FEC_Sub_Code__r.FEC_Code__c
            FROM FEC_Nature_of_Case__c
            WHERE Id = :natureOfCaseId
            LIMIT 1
          ];
          if (!nocRc27Lst.isEmpty()) {
            rc27SubCode = nocRc27Lst[0].FEC_Sub_Code__r?.FEC_Code__c;
          }
        }
        if (FEC_ConstantCommon.SUB_CODE_CARD_REPLACEMENT_FEE.equals(rc27SubCode)
            || FEC_ConstantCommon.SUB_CODE_CARD_REPLACEMENT_FREE.equals(rc27SubCode)) {
          List<FEC_Stage_Change__c> rc27FallbackLst = [
            SELECT FEC_Next_Stage__c, FEC_Next_Queue__c
            FROM FEC_Stage_Change__c
            WHERE FEC_Previous_Stage__c = :updatedCase.FEC_Current_Case_Stage__c
              AND FEC_Active__c = TRUE
              AND FEC_Team_User_Group__c = 'SP'
              AND FEC_IsReverted__c = false
            LIMIT 1
          ];
          if (!rc27FallbackLst.isEmpty()) {
            FEC_Stage_Change__c rc27SpChange = rc27FallbackLst.get(0);
            System.debug('FEC_DEBUG route RC27 hardcode: Stage1→Stage3 (SP), subCode=' + rc27SubCode);
            selectedChange.FEC_Next_Stage__c = rc27SpChange.FEC_Next_Stage__c;
            if (rc27SpChange.FEC_Next_Queue__c != null) {
              selectedChange.FEC_Next_Queue__c = rc27SpChange.FEC_Next_Queue__c;
            }
          }
        }
      }

      String customActionButtonLabel = getCustomActionButtonLabel(
        updatedCase.FEC_Current_Case_Stage__c,
        ROUTE_TO,
        actionId
      );

      if (
        String.isBlank(updatedCase.FEC_Actual_Nature_of_Case__c) &&
        ((stagelst != null && !stagelst.isEmpty()) ||
        updatedCase.FEC_Current_Case_Stage__r.FEC_Default_Stage__c)
      ) {
        FEC_Actual_Nature_of_Case__c tgt = cloneActualNatureOfCase(
          natureOfCaseId
        );

        updatedCase.FEC_Actual_Nature_of_Case__c = tgt.Id;
        updatedCase.FEC_Product_Type__c = tgt.FEC_Product_Type__c;
        updatedCase.FEC_Category__c = tgt.FEC_Category__c;
        updatedCase.FEC_SubCategory__c = tgt.FEC_Sub_Category__c;
        updatedCase.FEC_SubCode__c = tgt.FEC_Sub_Code__c;

        cloneMasterDataSetting(tgt.Id, natureOfCaseId);
      }

      // Toannd61 — RL16.02/RL16.03: nếu RD Payment Assessment đã được chọn,
      // dùng queueId từ LWC (đã resolve theo assessment) thay vì override từ Stage Change.
      Boolean isRdPaymentAssessmentDriven =
        String.isNotBlank(updatedCase.FEC_RD_Payment_Contract_Assessment__c) &&
        (
          FEC_ConstantCommon.SUB_CODE_RD_PAYMENT_ASSESSMENT_1.equals(updatedCase.FEC_SubCode__r?.FEC_Code__c) ||
          FEC_ConstantCommon.SUB_CODE_RD_PAYMENT_ASSESSMENT_2.equals(updatedCase.FEC_SubCode__r?.FEC_Code__c)
        );

      //thangtv
      if (routeByLatestRevertHistory && String.isNotBlank(latestHistForRoute.get(0).FEC_Perform_User__c)) {
        queueId = String.valueOf(latestHistForRoute.get(0).FEC_Perform_User__c);
      } else if (!isRdPaymentAssessmentDriven && selectedChange.FEC_Next_Queue__c != null) {
        queueId = resolveQueueOwnerIdFromStageChangeValue(
          String.valueOf(selectedChange.FEC_Next_Queue__c)
        );
      }

      //thangtv: nếu Owner là Frontline User thì map sang Queue chính
      queueId = applyFrontlineMainQueueIfUserOwner(queueId);
      //thangtv: fallback Queue->latest history updated user mapping
      queueId = applyUserOwnerFromHistoryWhenCurrentOwnerIsQueue(caseId, queueId);

      queueId = FEC_BlockCodeRoutingService.applyRouteQueueOverrideIfApplicable(
        updatedCase,
        queueId
      );

      updatedCase.OwnerId = queueId;
      updatedCase.FEC_Current_Case_Stage__c = selectedChange.FEC_Next_Stage__c;

      List<Group> queuelst = [
        SELECT Id, Name, DeveloperName, Type
        FROM Group
        WHERE Id = :queueId
      ];

      if (queuelst.isEmpty()) {
        // queueId có thể là User (assign sang analyst / agent) — không dùng currentOwnerName
        nextOwnerName = resolveRoutingHistoryOwnerLabel(queueId, null);
      } else {
        nextOwnerName = queuelst.get(0).Name;
      }

      FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
        FEC_Perform_User__c = userlst.get(0).Id,
        FEC_Previous_Stage__c = selectedChange.FEC_Previous_Stage__c,
        FEC_Next_Stage__c = selectedChange.FEC_Next_Stage__c,
        FEC_Routing_Action__c = ROUTE_TO,
        FEC_Case__c = caseId,
        // FEC_Decision__c = '',
        FEC_Original_User_Queue__c = currentOwnerName,
        FEC_Original_User_Queue_ID__c = currentOwnerId != null
          ? String.valueOf(currentOwnerId)
          : null,
        FEC_Updated_User_Queue__c = nextOwnerName,
        FEC_Updated_User_Queue_ID__c = queueId != null
          ? String.valueOf(queueId)
          : null,
        FEC_Stage_Name__c = selectedChange.FEC_Previous_Stage__r?.FEC_Code__c,
        FEC_Custom_Action_Button_Label__c = customActionButtonLabel,
        FEC_User__c = emailLocalPart(userlst.get(0).Email),
        FEC_User_Role__c = userlst.get(0).UserRole?.Name,
        FEC_Current_Status__c = finalStatusBeforeSubmit
      );

      //HieuTT74: [UPDATE 9/5/2026: FECREDIT_CSM_2025_KH-1143 - Cập nhật hiển thị button Execute cho Case]
      // FEC_CaseExecuteService.createRoutingActionHistory(caseId, currentOwnerName, nextOwnerName);
      //----------//


      List<FEC_Routing_Action_History__c> dupCandidates = [
        SELECT Id, FEC_Description__c, FEC_Original_User_Queue__c, FEC_Updated_User_Queue__c, CreatedDate
        FROM FEC_Routing_Action_History__c
        WHERE FEC_Case__c = :caseId
            AND FEC_Routing_Action__c = :ROUTE_TO
            AND FEC_Updated_User_Queue_ID__c = :queueId
            AND FEC_Previous_Stage__c = :selectedChange.FEC_Previous_Stage__c
            AND FEC_Next_Stage__c = :selectedChange.FEC_Next_Stage__c
        ORDER BY CreatedDate DESC
        LIMIT 5
      ];
      List<String> dupIds = new List<String>();
      for (FEC_Routing_Action_History__c h : dupCandidates) {
        dupIds.add(String.valueOf(h.Id));
      }
      System.debug(
        'FEC_DEBUG CaseBusinessService.route corrId=' + corrId +
        ' dupCandidatesCount=' + dupCandidates.size() +
        ' dupIds=' + String.join(dupIds, ',') +
        ' newHistory(originalQueue=' + history.FEC_Original_User_Queue__c +
        ', updatedQueue=' + history.FEC_Updated_User_Queue__c +
        ', stagePrevCode=' + history.FEC_Stage_Name__c +
        ', decision=' + history.FEC_Decision__c + ')'
      );

      Database.insert(history, AccessLevel.SYSTEM_MODE);

      System.debug(
        'FEC_DEBUG CaseBusinessService.route corrId=' + corrId +
        ' inserted historyId=' + history.Id +
        ' originalQueue=' + history.FEC_Original_User_Queue__c +
        ' updatedQueue=' + history.FEC_Updated_User_Queue__c +
        ' description=' + history.FEC_Description__c
      );

      // tungnm37 fix: chỉ skip khi TẤT CẢ teams đều là CC/SP (thủ công - user thêm qua Add Item)
      // Nếu có bất kỳ team nào khác CC/SP → tạo Assignment tự động cho tất cả team
      Set<Id> nocIds = FEC_CofGsrAssignmentService.resolveToNocIds(natureOfCaseId);
      Boolean hasNonCcSpTeam = FEC_CofGsrAssignmentService.hasNonCcSpTeam(nocIds);
      if (hasNonCcSpTeam) {
        FEC_CofGsrAssignmentService.createAssignmentsOnRoute(caseId, nocIds, currentUser, history.Id, history.FEC_Stage_Name__c, null);
      }

      registerSkipOwnerChangeRoutingHistory(updatedCase.Id);
      // Trigger sau insert history đã cập nhật FEC_Team__c / Status — merge để không ghi đè
      Case postHistory = [
        SELECT FEC_Team__c, Status
        FROM Case
        WHERE Id = :updatedCase.Id
        LIMIT 1
      ];
      updatedCase.FEC_Team__c = postHistory.FEC_Team__c;
      updatedCase.Status = postHistory.Status;
      Database.update(updatedCase, AccessLevel.SYSTEM_MODE);

      Case endCase = [
        SELECT FEC_Final_Status__c
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
      ];
      history.FEC_Changed_Status__c = endCase.FEC_Final_Status__c;
      Database.update(history, AccessLevel.SYSTEM_MODE);
    } catch (Exception e) {
      throw new CaseBusinessServiceException(e.getMessage());
    }
  }

  private static void createRoutingActionHis(
    String routingAction,
    String decision,
    String oldOwnerName,
    Id originalOwnerId,
    String caseId,
    String stageName,
    String finalStatusBeforeSubmit,
    Id currentStageId
  ) {
    Long corrId = DateTime.now().getTime();
    System.debug(
      'FEC_DEBUG CaseBusinessService.createRoutingActionHis corrId=' + corrId +
      ' routingAction=' + routingAction +
      ' caseId=' + caseId +
      ' oldOwnerName=' + oldOwnerName +
      ' stageName=' + stageName +
      ' decision=' + decision
    );

    Case c = [
      SELECT Id, OwnerId, Owner.Name, FEC_Stage_Name__c, FEC_Final_Status__c, FEC_Current_Case_Stage__c
      FROM Case
      WHERE Id = :caseId
    ];

    User usr = [
        SELECT Email, UserRole.Name, Id, FEC_User_Group__c
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
      ];
    FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
        FEC_Routing_Action__c = routingAction,
        FEC_Decision__c = decision,
        FEC_Case__c = caseId,
        FEC_Original_User_Queue__c = oldOwnerName,
        FEC_Original_User_Queue_ID__c = originalOwnerId != null
          ? String.valueOf(originalOwnerId)
          : null,
        FEC_Updated_User_Queue__c = resolveRoutingHistoryOwnerLabel(
          c.OwnerId,
          c.Owner?.Name
        ),
        FEC_Updated_User_Queue_ID__c = c.OwnerId != null
          ? String.valueOf(c.OwnerId)
          : null,
        FEC_Stage_Name__c = stageName,
        FEC_Custom_Action_Button_Label__c = getCustomActionButtonLabel(
          c.FEC_Current_Case_Stage__c,
          routingAction,
          null
        ),
        FEC_User__c = emailLocalPart(usr.Email),
        FEC_User_Role__c = usr.UserRole?.Name,
        FEC_Current_Status__c = finalStatusBeforeSubmit,
        FEC_Changed_Status__c = c.FEC_Final_Status__c
      );
    try {
      new FEC_CaseBusinessWithoutSharing().doInsert(new List<FEC_Routing_Action_History__c>{ history });
      System.debug(
        'FEC_DEBUG CaseBusinessService.createRoutingActionHis corrId=' + corrId +
        ' inserted historyId=' + history.Id +
        ' routingAction=' + history.FEC_Routing_Action__c +
        ' originalQueue=' + history.FEC_Original_User_Queue__c +
        ' updatedQueue=' + history.FEC_Updated_User_Queue__c +
        ' description=' + history.FEC_Description__c
      );
    } catch (Exception e) {
      throw new CaseBusinessServiceException(e.getMessage());
    }
  }

  private without sharing class FEC_CaseBusinessWithoutSharing {
    public void doInsert(FEC_Routing_Action_History__c[] histories) {
        insert histories;
    }
  }

  /**
   * Chuỗi Pending-{Team} theo FEC_CasePendingStatusService.computePendingStatusForCase
   * (ưu tiên bản ghi Routing Action History **Change Owner** mới nhất).
   */
  public static String getPendingStatusFromLatestRouteTo(Id caseId) {
    return FEC_CasePendingStatusService.computePendingStatusForCase(caseId);
  }

  // --- Routing Action History khi Change Owner ---

  /**
   * Tạo bản ghi Routing Action History khi Change Owner (OwnerId thay đổi).
   * Gán: Routing Action = Change Owner; Description = Change Owner (FEC_RAH_DESCRIPTION_CHANGE_OWNER); Stage Name = FEC_Code của stage trước khi đổi.
   * @param newCases Trigger.new (sau update)
   * @param oldMap Trigger.oldMap
   */
  public static void createRoutingActionHistoryOnOwnerChange(List<Case> newCases, Map<Id, Case> oldMap) {
    if (newCases == null || oldMap == null) {
      return;
    }
    List<Case> ownerChangedCases = getOwnerChangedCases(newCases, oldMap);
    if (ownerChangedCases.isEmpty()) {
      return;
    }

    System.debug(
      'FEC_DEBUG CaseBusinessService.createRoutingActionHistoryOnOwnerChange start ownerChangedCases=' +
      ownerChangedCases.size() +
      ' skipSetSize(before)=' + caseIdsSkipOwnerChangeRoutingHistory.size()
    );

    // Đã có history + đổi owner từ route() / takeOwnership — không tạo thêm bản Change Owner từ trigger
    if (!caseIdsSkipOwnerChangeRoutingHistory.isEmpty()) {
      List<Case> filtered = new List<Case>();
      for (Case c : ownerChangedCases) {
        if (caseIdsSkipOwnerChangeRoutingHistory.contains(c.Id)) {
          System.debug(
            'FEC_DEBUG CaseBusinessService.createRoutingActionHistoryOnOwnerChange SKIP caseId=' +
            c.Id +
            ' skipSetSize(beforeRemove)=' + caseIdsSkipOwnerChangeRoutingHistory.size()
          );
          caseIdsSkipOwnerChangeRoutingHistory.remove(c.Id);
          continue;
        }
        filtered.add(c);
      }
      ownerChangedCases = filtered;
    }
    if (ownerChangedCases.isEmpty()) {
      return;
    }

    System.debug(
      'FEC_DEBUG CaseBusinessService.createRoutingActionHistoryOnOwnerChange afterSkip ownerChangedCases=' +
      ownerChangedCases.size() +
      ' skipSetSize(after)=' + caseIdsSkipOwnerChangeRoutingHistory.size()
    );

    Map<Id, String> ownerIdToName = getOwnerIdToNameMap(ownerChangedCases, oldMap);
    User currentUser = getCurrentUserForRoutingHistory();
    Map<Id, String> stageIdToCode = getStageCodeMapByOldCases(ownerChangedCases, oldMap);

    List<FEC_Routing_Action_History__c> histories = new List<FEC_Routing_Action_History__c>();
    for (Case c : ownerChangedCases) {
      Case oldCase = oldMap.get(c.Id);
      System.debug(
        'FEC_DEBUG CaseBusinessService.createRoutingActionHistoryOnOwnerChange building caseId=' + c.Id +
        ' oldOwnerId=' + oldCase.OwnerId +
        ' newOwnerId=' + c.OwnerId +
        ' stageCode=' + (stageIdToCode.containsKey(oldCase.FEC_Current_Case_Stage__c) ? stageIdToCode.get(oldCase.FEC_Current_Case_Stage__c) : null)
      );
      histories.add(buildRoutingActionHistoryRecord(c, oldCase, ownerIdToName, stageIdToCode, currentUser));
    }

    if (!histories.isEmpty()) {
      try {
        // SYSTEM_MODE: ghi nhận lịch sử phân bổ dù user không có Create/FLS trên FEC_Routing_Action_History__c
        // (đồng bộ với route() Database.insert(history, AccessLevel.SYSTEM_MODE))
        Database.insert(histories, AccessLevel.SYSTEM_MODE);
        System.debug(
          'FEC_DEBUG CaseBusinessService.createRoutingActionHistoryOnOwnerChange inserted historiesCount=' +
          histories.size()
        );
      } catch (Exception e) {
        System.debug('FEC_CaseBusinessService.createRoutingActionHistoryOnOwnerChange failed: ' + e.getMessage());
      }
    }
  }

  private static List<Case> getOwnerChangedCases(List<Case> newCases, Map<Id, Case> oldMap) {
    List<Case> result = new List<Case>();
    for (Case c : newCases) {
      Case oldCase = oldMap.get(c.Id);
      if (oldCase != null && c.OwnerId != oldCase.OwnerId && c.OwnerId != null) {
        result.add(c);
      }
    }
    return result;
  }

  private static Map<Id, String> getOwnerIdToNameMap(List<Case> ownerChangedCases, Map<Id, Case> oldMap) {
    Set<Id> allOwnerIds = new Set<Id>();
    for (Case c : ownerChangedCases) {
      allOwnerIds.add(c.OwnerId);
      allOwnerIds.add(oldMap.get(c.Id).OwnerId);
    }
    List<Id> userIds = new List<Id>();
    List<Id> queueIds = new List<Id>();
    for (Id ownerId : allOwnerIds) {
      if (ownerId.getSObjectType() == User.SObjectType) {
        userIds.add(ownerId);
      } else if (ownerId.getSObjectType() == Group.SObjectType) {
        queueIds.add(ownerId);
      }
    }
    Map<Id, String> ownerIdToName = new Map<Id, String>();
    if (!userIds.isEmpty()) {
      for (User u : [SELECT Id, Email, Name FROM User WHERE Id IN :userIds]) {
        String local = emailLocalPart(u.Email);
        ownerIdToName.put(
          u.Id,
          String.isNotBlank(local)
            ? local
            : (String.isNotBlank(u.Name) ? u.Name : null)
        );
      }
    }
    if (!queueIds.isEmpty()) {
      for (Group g : [SELECT Id, Name FROM Group WHERE Id IN :queueIds AND Type = 'Queue']) {
        ownerIdToName.put(g.Id, g.Name);
      }
    }
    return ownerIdToName;
  }

  private static User getCurrentUserForRoutingHistory() {
    List<User> users = [SELECT Email, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
    return users.isEmpty() ? null : users.get(0);
  }

  private static Map<Id, String> getStageCodeMapByOldCases(List<Case> ownerChangedCases, Map<Id, Case> oldMap) {
    Set<Id> oldStageIds = new Set<Id>();
    for (Case c : ownerChangedCases) {
      Case oldCase = oldMap.get(c.Id);
      if (oldCase != null && oldCase.FEC_Current_Case_Stage__c != null) {
        oldStageIds.add(oldCase.FEC_Current_Case_Stage__c);
      }
    }
    Map<Id, String> stageIdToCode = new Map<Id, String>();
    if (!oldStageIds.isEmpty()) {
      for (FEC_Case_Stage__c st : [SELECT Id, FEC_Code__c FROM FEC_Case_Stage__c WHERE Id IN :oldStageIds]) {
        stageIdToCode.put(st.Id, st.FEC_Code__c);
      }
    }
    return stageIdToCode;
  }

  private static FEC_Routing_Action_History__c buildRoutingActionHistoryRecord(
    Case c,
    Case oldCase,
    Map<Id, String> ownerIdToName,
    Map<Id, String> stageIdToCode,
    User currentUser
  ) {
    String originalName = ownerIdToName.get(oldCase.OwnerId);
    String updatedName = ownerIdToName.get(c.OwnerId);
    String stageName = oldCase.FEC_Current_Case_Stage__c != null
      ? stageIdToCode.get(oldCase.FEC_Current_Case_Stage__c)
      : null;
    String currentUserEmailId = currentUser != null
      ? emailLocalPart(currentUser.Email)
      : null;
    String currentUserRole = currentUser?.UserRole?.Name;

    return new FEC_Routing_Action_History__c(
      FEC_Case__c = c.Id,
      FEC_Routing_Action__c = CHANGE_OWNER,
      FEC_Perform_User__c = UserInfo.getUserId(),
      FEC_Decision__c = '',
      FEC_Original_User_Queue__c = originalName,
      FEC_Original_User_Queue_ID__c = oldCase.OwnerId != null
        ? String.valueOf(oldCase.OwnerId)
        : null,
      FEC_Updated_User_Queue__c = updatedName,
      FEC_Updated_User_Queue_ID__c = c.OwnerId != null ? String.valueOf(c.OwnerId) : null,
      FEC_Stage_Name__c = stageName,
      FEC_User__c = currentUserEmailId,
      FEC_User_Role__c = currentUserRole,
      FEC_Description__c = FEC_ConstantCommon.FEC_RAH_DESCRIPTION_CHANGE_OWNER,
      FEC_Current_Status__c = null,
      FEC_Changed_Status__c = null
    );
  }

  private static void cancel(String caseId) {
    try {
      Id currentUserId = UserInfo.getUserId();
      
      List<Case> caselst = [
        SELECT Id, OwnerId, Status
        FROM Case
        WHERE Id = :caseId
      ];

      if (caselst.isEmpty())
        throw new CaseBusinessServiceException(
          String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Case Id' })
        );

      Case updatedCase = caselst.get(0);
      
      if (updatedCase.OwnerId != currentUserId) {
        throw new CaseBusinessServiceException(
          System.Label.FEC_MSG_Action_Owner_Only
        );
      }
      
      updatedCase.Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED;

      update updatedCase;
    } catch (Exception e) {
      throw new CaseBusinessServiceException(e.getMessage());
    }
  }

  private static void reopen(String caseId) {
    try {
      Id currentUserId = UserInfo.getUserId();
      
      List<Case> caselst = [
        SELECT Id, OwnerId, Status
        FROM Case
        WHERE Id = :caseId
      ];

      if (caselst.isEmpty())
        throw new CaseBusinessServiceException(
          String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Case Id' })
        );

      Case updatedCase = caselst.get(0);
      
      if (updatedCase.OwnerId != currentUserId) {
        throw new CaseBusinessServiceException(
          System.Label.FEC_MSG_Action_Owner_Only
        );
      }
      
      updatedCase.Status = FEC_ConstantCommon.CASE_STATUS_PENDING;

      update updatedCase;
    } catch (Exception e) {
      throw new CaseBusinessServiceException(e.getMessage());
    }
  }

  private static void reject(String caseId) {
    try {
      Id currentUserId = UserInfo.getUserId();
      
      List<Case> caselst = [
        SELECT Id, OwnerId, Status
        FROM Case
        WHERE Id = :caseId
      ];

      if (caselst.isEmpty())
        throw new CaseBusinessServiceException(
          String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Case Id' })
        );

      Case updatedCase = caselst.get(0);
      
      if (updatedCase.OwnerId != currentUserId) {
        throw new CaseBusinessServiceException(
          System.Label.FEC_MSG_Action_Owner_Only
        );
      }
      
      updatedCase.Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_REJECTED;

      update updatedCase;
    } catch (Exception e) {
      throw new CaseBusinessServiceException(e.getMessage());
    }
  }

  private static void resolve(String caseId) {
    try {
      Id currentUserId = UserInfo.getUserId();
      
      List<Case> caselst = [
        SELECT Id, OwnerId, Status
        FROM Case
        WHERE Id = :caseId
      ];

      if (caselst.isEmpty())
        throw new CaseBusinessServiceException(
          String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Case Id' })
        );

      Case updatedCase = caselst.get(0);
      
      if (updatedCase.OwnerId != currentUserId) {
        throw new CaseBusinessServiceException(
          System.Label.FEC_MSG_Action_Owner_Only
        );
      }
      
      updatedCase.Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED;

      update updatedCase;
    } catch (Exception e) {
      throw new CaseBusinessServiceException(e.getMessage());
    }
  }
  private static void transfer(String caseId, String userOrQueueId) {
    Id currentUserId = UserInfo.getUserId();
    
    List<Case> caselst = [
      SELECT Id, OwnerId, Status
      FROM Case
      WHERE Id = :caseId
    ];

    if (caselst.isEmpty())
      throw new CaseBusinessServiceException(
        String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Case Id' })
      );

    Case updatedCase = caselst.get(0);
    
    if (updatedCase.OwnerId != currentUserId) {
      throw new CaseBusinessServiceException(
        System.Label.FEC_MSG_Transfer_Owner_Only
      );
    }

    if (userOrQueueId == null) {
      throw new CaseBusinessServiceException(
        String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'User/Queue Id' })
      );
    }
    try {
      updatedCase.OwnerId = userOrQueueId;
      registerSkipOwnerChangeRoutingHistory(updatedCase.Id);
      update updatedCase;
    } catch (Exception e) {
      throw new CaseBusinessServiceException(e.getMessage());
    }
  }

  private static void escalate(String caseId) {
    try {
      Id currentUserId = UserInfo.getUserId();
      
      // 1. Use TYPEOF to safely access User-specific fields on the Owner polymorphic lookup
      List<Case> caselst = [
        SELECT
          Id,
          OwnerId,
          Status,
          TYPEOF Owner
            WHEN User THEN ManagerId
          END
        FROM Case
        WHERE Id = :caseId
      ];

      if (caselst.isEmpty()) {
        throw new CaseBusinessServiceException(
          String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Case Id' })
        );
      }

      Case updatedCase = caselst.get(0);
      
      // Kiểm tra xem user hiện tại có phải là Owner không
      if (updatedCase.OwnerId != currentUserId) {
        throw new CaseBusinessServiceException(
          System.Label.FEC_MSG_Escalate_Owner_Only
        );
      }

      // 2. Check if the Owner is actually a User (not a Queue)
      if (updatedCase.Owner instanceof User) {
        // Cast the Owner relationship to a User object to access ManagerId
        User ownerUser = (User) updatedCase.Owner;

        if (ownerUser.ManagerId != null) {
          updatedCase.OwnerId = ownerUser.ManagerId;
        } else {
          throw new CaseBusinessServiceException(
            System.Label.FEC_MSG_Manager_Not_Found
          );
        }
      } else {
        throw new CaseBusinessServiceException(
          System.Label.FEC_MSG_Owner_Is_Queue_Escalation
        );
      }

      registerSkipOwnerChangeRoutingHistory(updatedCase.Id);
      update updatedCase;
    } catch (Exception e) {
      // It's better practice to include the original exception as a cause if your custom exception supports it
      throw new CaseBusinessServiceException(
        System.Label.FEC_MSG_Escalation_Failed_Prefix + e.getMessage()
      );
    }
  }

  //thangtv: Revert — routingActionDisplayValue = action.value (LWC); Stage Change theo FEC_IsReverted__c; owner ưu tiên history có Previous = next stage
  private static void revert(
    String caseId,
    String actionId,
    String finalStatusBeforeSubmit,
    String routingActionDisplayValue
  ) {
    try {
      List<Case> caselst = [
        SELECT
          Id,
          OwnerId,
          Owner.Name,
          FEC_Current_Case_Stage__c,
          FEC_Current_Case_Stage__r.FEC_Default_Stage__c,
          FEC_Current_Case_Stage__r.FEC_Code__c
        FROM Case
        WHERE Id = :caseId
      ];

      if (caselst.isEmpty()) {
        throw new CaseBusinessServiceException(
          String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Case Id' })
        );
      }

      Case updatedCase = caselst.get(0);

      String currentOwnerName = resolveRoutingHistoryOwnerLabel(
        updatedCase.OwnerId,
        updatedCase.Owner?.Name
      );

      if (String.isBlank(actionId)) {
        throw new CaseBusinessServiceException(
          String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Action Id' })
        );
      }

      //thangtv: action.value = "Revert" → Stage Change + history IsReverted true; khác Revert (vd "Route to") → false
      String actionValTrim = String.isBlank(routingActionDisplayValue)
        ? REVERT
        : routingActionDisplayValue.trim();
      Boolean scIsRevertedFilter = REVERT.equals(actionValTrim);
      //thangtv: đồng bộ cờ history với nhánh Stage Change (theo action.value)
      Boolean historyIsRevertedFlag = scIsRevertedFilter;

      List<FEC_Stage_Change__c> scRowList = [
        SELECT
          FEC_Next_Stage__c,
          FEC_Next_Stage__r.FEC_Default_Stage__c,
          FEC_Next_Queue__c,
          FEC_Previous_Stage__c
        FROM FEC_Stage_Change__c
        WHERE
          FEC_Previous_Stage__c = :updatedCase.FEC_Current_Case_Stage__c
          AND FEC_Active__c = TRUE
          AND FEC_Action_Button__c = :actionId
          AND FEC_IsReverted__c = :scIsRevertedFilter
        LIMIT 1
      ];

      if (scRowList.isEmpty()) {
        throw new CaseBusinessServiceException(
          String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Stage Change' })
        );
      }

      FEC_Stage_Change__c stagingRow = scRowList.get(0);
      Id nextStageId = stagingRow.FEC_Next_Stage__c;

      //thangtv: Next stage đã từng là FEC_Previous_Stage__c trên history → ưu tiên Owner = FEC_Perform_User__c tại bản ghi đó (fallback history mới nhất)
      List<FEC_Routing_Action_History__c> histWhereNextWasPrevious = [
        SELECT FEC_Perform_User__c
        FROM FEC_Routing_Action_History__c
        WHERE
          FEC_Case__c = :caseId
          AND FEC_Previous_Stage__c = :nextStageId
        ORDER BY CreatedDate DESC, Id DESC
        LIMIT 1
      ];

      List<FEC_Routing_Action_History__c> latestHist = [
        SELECT FEC_Perform_User__c
        FROM FEC_Routing_Action_History__c
        WHERE
          FEC_Case__c = :caseId
          AND FEC_Routing_Action__c IN :new List<String>{ ROUTE_TO, REVERT }
        ORDER BY CreatedDate DESC, Id DESC
        LIMIT 1
      ];

      String queueId;
      //thangtv: chọn ownerId (queueId) — ưu tiên histWhereNextWasPrevious, không có thì latestHist Perform user
      if (
        !histWhereNextWasPrevious.isEmpty() &&
        String.isNotBlank(histWhereNextWasPrevious.get(0).FEC_Perform_User__c)
          ) {
        queueId = histWhereNextWasPrevious.get(0).FEC_Perform_User__c;
      } else if (
        !latestHist.isEmpty() &&
        String.isNotBlank(latestHist.get(0).FEC_Perform_User__c)
      ) {
        queueId = latestHist.get(0).FEC_Perform_User__c;
          } else {
        throw new CaseBusinessServiceException(
          String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Routing Action History' })
            );
          }

      //thangtv: giữ map Frontline → main queue như cũ
          queueId = applyFrontlineMainQueueIfUserOwner(queueId);

      String nextUser;
          if (String.isNotBlank(queueId)) {
            try {
              nextUser = resolveRoutingHistoryOwnerLabel(
                Id.valueOf(queueId.trim()),
                null
              );
            } catch (Exception ignore) {
          nextUser = null;
            }
      } else {
        nextUser = null;
      }
      if (String.isBlank(nextUser)) {
        nextUser = currentOwnerName;
          }

          List<User> userlst = [
            SELECT Email, UserRole.Name, Id
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
          ];

      if (userlst.isEmpty()) {
            return;
      }

      //thangtv: lưu label hiển thị user chọn (action.value); không gửi thì fallback getCustomActionButtonLabel
      String customActionButtonLabel = String.isNotBlank(routingActionDisplayValue)
        ? routingActionDisplayValue.trim()
        : getCustomActionButtonLabel(
            updatedCase.FEC_Current_Case_Stage__c,
            REVERT,
            actionId
          );

          FEC_Routing_Action_History__c newHistory = new FEC_Routing_Action_History__c(
            FEC_Previous_Stage__c = updatedCase.FEC_Current_Case_Stage__c,
        FEC_Next_Stage__c = nextStageId,
            FEC_Routing_Action__c = REVERT,
            FEC_Case__c = caseId,
            FEC_Perform_User__c = userlst.get(0).Id,
            // FEC_Previous_Stage__c = selectedChange.FEC_Previous_Stage__c,
            // FEC_Next_Stage__c = selectedChange.FEC_Next_Stage__c,
            // FEC_Routing_Action__c = ROUTE_TO,
            // FEC_Case__c = caseId,
            // FEC_Decision__c = '',
            FEC_Original_User_Queue__c = currentOwnerName,
            FEC_Original_User_Queue_ID__c = String.valueOf(updatedCase.OwnerId),
            FEC_Updated_User_Queue__c = nextUser,
            FEC_Updated_User_Queue_ID__c = queueId,
        FEC_Stage_Name__c = updatedCase.FEC_Current_Case_Stage__r?.FEC_Code__c,
        FEC_Custom_Action_Button_Label__c = customActionButtonLabel,
            FEC_User__c = emailLocalPart(userlst.get(0).Email),
            FEC_User_Role__c = userlst.get(0).UserRole?.Name,
        FEC_Current_Status__c = finalStatusBeforeSubmit,
        //thangtv: cờ IsReverted trên history theo action.value / nhánh Stage Change
        FEC_IsReverted__c = historyIsRevertedFlag
          );

      updatedCase.OwnerId = Id.valueOf(queueId.trim());
      updatedCase.FEC_Current_Case_Stage__c = nextStageId;
          registerSkipOwnerChangeRoutingHistory(updatedCase.Id);
          insert newHistory; 
          update updatedCase;

          Case endCase = [
            SELECT FEC_Final_Status__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
          ];
          newHistory.FEC_Changed_Status__c = endCase.FEC_Final_Status__c;
          update newHistory;
    } catch (Exception e) {
      throw new CaseBusinessServiceException(e.getMessage());
    }
  }
  
  //linhdev: getCustomActionButtonLabel - lấy custom label theo previous stage + action code để lưu vào Routing Action History
  private static String getCustomActionButtonLabel(
    Id currentStageId,
    String actionCode,
    String actionButtonId
  ) {
    if (currentStageId == null) {
      return null;
    }
    List<FEC_Stage_Screen__c> stageScreenlst;
    if (String.isNotBlank(actionButtonId)) {
      stageScreenlst = [
        SELECT
          FEC_Custom_Action_Button_Label__c,
          FEC_Action_Button__r.Name
        FROM FEC_Stage_Screen__c
        WHERE
          FEC_Case_Stage__c = :currentStageId
          AND FEC_Active__c = TRUE
          AND FEC_Action_Button__c = :actionButtonId
        LIMIT 1
      ];
    } else if (String.isNotBlank(actionCode)) {
      stageScreenlst = [
        SELECT
          FEC_Custom_Action_Button_Label__c,
          FEC_Action_Button__r.Name
        FROM FEC_Stage_Screen__c
        WHERE
          FEC_Case_Stage__c = :currentStageId
          AND FEC_Active__c = TRUE
          AND FEC_Action_Button__r.FEC_Code__c = :actionCode
        LIMIT 1
      ];
    } else {
      return null;
    }
    if (stageScreenlst.isEmpty()) {
      return null;
    }
    FEC_Stage_Screen__c selectedStageScreen = stageScreenlst.get(0);
    return String.isNotBlank(selectedStageScreen.FEC_Custom_Action_Button_Label__c)
      ? selectedStageScreen.FEC_Custom_Action_Button_Label__c
      : selectedStageScreen.FEC_Action_Button__r.Name;
  }

  public static FEC_Actual_Nature_of_Case__c cloneActualNatureOfCase(
    String natureOfCaseId
  ) {
    FEC_Actual_Nature_of_Case__c tgt = new FEC_Actual_Nature_of_Case__c();

    List<FEC_Nature_of_Case__c> sourcelst = [
      SELECT
        Id,
        FEC_Active__c,
        FEC_User_Group__c,
        FEC_Customer_Type__c,
        FEC_Product_Type__c,
        FEC_Category__c,
        FEC_Sub_Category__c,
        FEC_Sub_Code__c,
        FEC_Business_Process__c,
        OwnerId
      FROM FEC_Nature_of_Case__c
      WHERE Id = :natureOfCaseId
    ];

    if (sourcelst.isEmpty())
      throw new CaseBusinessServiceException(
        String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Nature of Case Id' })
      );

    FEC_Nature_of_Case__c src = sourcelst.get(0);

    tgt.FEC_Active__c = src.FEC_Active__c;
    tgt.FEC_User_Group__c = src.FEC_User_Group__c;
    tgt.FEC_Customer_Type__c = src.FEC_Customer_Type__c;
    tgt.FEC_Product_Type__c = src.FEC_Product_Type__c;
    tgt.FEC_Category__c = src.FEC_Category__c;
    tgt.FEC_Sub_Category__c = src.FEC_Sub_Category__c;
    tgt.FEC_Sub_Code__c = src.FEC_Sub_Code__c;
    tgt.FEC_Business_Process__c = src.FEC_Business_Process__c;
    tgt.OwnerId = src.OwnerId;

    insert tgt;

    return tgt;
  }

  public static void cloneMasterDataSetting(
    String actualNatureOfCaseId,
    String natureOfCaseId
  ) {
    // String stageNameId
    List<FEC_Master_Data_Setting__c> sourcelst = [
      SELECT
        Id,
        FEC_Channel__c,
        FEC_Editable_User_Group__c,
        FEC_Field_API_Name__c,
        FEC_Field_Editable__c,
        FEC_Field_Label_Name__c,
        FEC_Field_Mandatory__c,
        FEC_Field_Masking__c,
        FEC_Field_Object_Name__c,
        FEC_Field_Order_Display__c,
        FEC_Field_ReadOnly__c,
        FEC_Field_Status__c,
        FEC_Nature_Of_Case__c,
        FEC_Section__c,
        FEC_Stage_Name__c,
        FEC_Sub_Section__c,
        FEC_Sub_Section_Order__c,
        FEC_Sub_Section_Layout__c,
        OwnerId,
        FEC_Field_Reverted__c,
        FEC_Sub_Section_Field_Layout__c, 
        FEC_LWC_Name__c, 
        FEC_Type__c
      FROM FEC_Master_Data_Setting__c
      WHERE FEC_Nature_of_Case__c = :natureOfCaseId
      // AND FEC_Stage_Name__c = :stageNameId
    ];

    if (sourcelst.isEmpty())
      throw new CaseBusinessServiceException(
        String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Master Data Setting for Nature of Case' })
      );

    List<FEC_Actual_Master_Data_Setting__c> targetlst = new List<FEC_Actual_Master_Data_Setting__c>();

    for (FEC_Master_Data_Setting__c src : sourcelst) {
      FEC_Actual_Master_Data_Setting__c tgt = new FEC_Actual_Master_Data_Setting__c();

      tgt.FEC_Channel__c = src.FEC_Channel__c;
      tgt.FEC_Editable_User_Group__c = src.FEC_Editable_User_Group__c;
      tgt.FEC_Field_API_Name__c = src.FEC_Field_API_Name__c;
      tgt.FEC_Field_Editable__c = src.FEC_Field_Editable__c;
      tgt.FEC_Field_Label_Name__c = src.FEC_Field_Label_Name__c;
      tgt.FEC_Field_Mandatory__c = src.FEC_Field_Mandatory__c;
      tgt.FEC_Field_Masking__c = src.FEC_Field_Masking__c;
      tgt.FEC_Field_Object_Name__c = src.FEC_Field_Object_Name__c;
      tgt.FEC_Field_Order_Display__c = src.FEC_Field_Order_Display__c;
      tgt.FEC_Field_ReadOnly__c = src.FEC_Field_ReadOnly__c;
      tgt.FEC_Field_Status__c = src.FEC_Field_Status__c;
      tgt.FEC_Actual_Nature_of_Case__c = actualNatureOfCaseId;
      tgt.FEC_Section__c = src.FEC_Section__c;
      tgt.FEC_Stage_Name__c = src.FEC_Stage_Name__c;
      tgt.FEC_Sub_Section__c = src.FEC_Sub_Section__c;
      tgt.OwnerId = src.OwnerId;
      tgt.FEC_Stage_Name__c = src.FEC_Stage_Name__c;
      tgt.FEC_Sub_Section_Order__c = src.FEC_Sub_Section_Order__c;
      tgt.FEC_Sub_Section_Layout__c = src.FEC_Sub_Section_Layout__c;
      tgt.FEC_Field_Reverted__c = src.FEC_Field_Reverted__c;
      tgt.FEC_Sub_Section_Field_Layout__c = src.FEC_Sub_Section_Field_Layout__c;
      tgt.FEC_LWC_Name__c = src.FEC_LWC_Name__c;
      tgt.FEC_Type__c = src.FEC_Type__c;

      targetlst.add(tgt);
    }

    insert targetlst;
  }

  private static Map<String, SObject> getData(
    Map<String, Set<String>> objToFieldlstMap,
    String caseId,
    String customerHistoryId
  ) {
    Map<String, SObject> soqlMap = new Map<String, SObject>();

    List<SObject> sObjectlst;
    String soql;

    for (String objName : objToFieldlstMap.keySet()) {

    Set<String> fields = new Set<String>();

    // Get object describe
    Schema.SObjectType objType = Schema.getGlobalDescribe().get(objName);
    Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
    Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();

    for (String fieldName : objToFieldlstMap.get(objName)) {
      if (fieldsMap.containsKey(fieldName)) {
        Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName).getDescribe();

        if (fieldDescribe.getType() == Schema.DisplayType.Picklist ||
          fieldDescribe.getType() == Schema.DisplayType.MultiPicklist) {
          fields.add('toLabel(' + fieldName + ')');
        } else {
          fields.add(fieldName);
        }
      }
    }

    System.debug('objName: ' + objName);
    System.debug('fields: ' + fields);

      if (fields == null || fields.isEmpty()) {
        continue;
      }

      String parentAPIName;
      String selectedId = caseId;

      switch on objName {
        when 'Case' {
          parentAPIName = 'Id';
        }
        when 'FEC_Customer_History__c' {
          parentAPIName = 'Id';
          selectedId = customerHistoryId;
        }
        when else {
          parentAPIName = 'FEC_Case__c';
        }
      }

      soql =
        'SELECT ' +
        String.join(new List<String>(fields), ', ') +
        ' FROM ' +
        objName +
        ' WHERE ' +
        parentAPIName +
        ' = :selectedId';

      // need to query in loop of obj name
      sObjectlst = Database.query(soql);

      System.debug('sObjectlst:' + sObjectlst);

      soqlMap.put(objName, sObjectlst.isEmpty() ? null : sObjectlst.get(0));
    }

    return soqlMap;
  }

  /**
   * Build map of picklist options (value + label) per object/field for fields that use toLabel in getData.
   * LWC uses this to convert label back to API value before submit.
   */
  private static Map<String, Map<String, List<PicklistOptionDto>>> getPicklistOptionsMap(
    Map<String, Set<String>> objToFieldlstMap
  ) {
    Map<String, Map<String, List<PicklistOptionDto>>> result = new Map<String, Map<String, List<PicklistOptionDto>>>();

    for (String objName : objToFieldlstMap.keySet()) {
      Schema.SObjectType objType = Schema.getGlobalDescribe().get(objName);
      if (objType == null)
        continue;

      Map<String, Schema.SObjectField> fieldsMap = objType.getDescribe().fields.getMap();
      Map<String, List<PicklistOptionDto>> fieldToOptions = new Map<String, List<PicklistOptionDto>>();

      for (String fieldName : objToFieldlstMap.get(objName)) {
        if (!fieldsMap.containsKey(fieldName))
          continue;

        Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName).getDescribe();
        if (fieldDescribe.getType() != Schema.DisplayType.Picklist &&
          fieldDescribe.getType() != Schema.DisplayType.MultiPicklist) {
          continue;
        }

        List<PicklistOptionDto> options = new List<PicklistOptionDto>();
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
          if (entry.isActive()) {
            options.add(new PicklistOptionDto(entry.getValue(), entry.getLabel(), entry.isDefaultValue()));
          }
        }
        fieldToOptions.put(fieldName, options);
      }

      if (!fieldToOptions.isEmpty()) {
        result.put(objName, fieldToOptions);
      }
    }

    return result;
  }

  /**
   * fecMasterDataSettingIsEdit — (1) ReadOnly=true -> false. (2) Editable=true va khong ReadOnly -> true chi khi UserGroup khop FEC_Editable_User_Group__c. (3) Field_Status=false khong load (SOQL getData). (4) Ten stage co "Stage N" voi N!=1 -> false; Stage 1 hoac khong co cap trong ten -> khong ep.
   */
  private static Boolean isCaseStageNameForcingDynLwcReadonly(String stageName) {
    if (String.isBlank(stageName)) {
      return false;
    }
    Matcher m = FEC_ConstantCommon.PAT_STAGE_NAME_WITH_NUMBER.matcher(stageName.trim());
    if (!m.find()) {
      return false;
    }
    Integer stageNum = Integer.valueOf(m.group(1));
    return stageNum != 1;
  }

  private static Boolean isLwcDynamicMasterInEditMode(
    SObject masterDataItem,
    String userGroup,
    String caseStageName
  ) {
    String lwcNm = (String) masterDataItem.get('FEC_LWC_Name__c');

    // Tam thoi: khong ep dynLwcStgReadOnly theo ten stage (DB da cau hinh).
    // Boolean dynLwcStgReadOnly = isCaseStageNameForcingDynLwcReadonly(caseStageName);
    Boolean dynLwcStgReadOnly = false;

    Boolean isReadOnly = (Boolean) masterDataItem.get('FEC_Field_ReadOnly__c');
    Boolean isEditable = (Boolean) masterDataItem.get('FEC_Field_Editable__c');
    String editableGr = (String) masterDataItem.get('FEC_Editable_User_Group__c');
    Boolean out;
    if (dynLwcStgReadOnly) {
      out = false;
    } else if (isReadOnly == true) {
      out = false;
    } else if (isEditable != true) {
      out = false;
    } else if (String.isBlank(editableGr) || String.isBlank(userGroup)) {
      out = false;
    } else {
      out = editableGr.contains(userGroup);
    }
    System.debug(
      LoggingLevel.DEBUG,
      'FEC_DYN_LWC_EDIT lwc=' +
        lwcNm +
        ' stgReadOnly=' +
        dynLwcStgReadOnly +
        ' readOnly=' +
        isReadOnly +
        ' editable=' +
        isEditable +
        ' ->' +
        out
    );
    return out;
  }

  private static Boolean isLatestRevertToCurrentStage(Id caseId, Id currentStageId) {
    if (caseId == null || currentStageId == null) {
      return false;
    }
    List<FEC_Routing_Action_History__c> latestRevertHist = [
      SELECT Id
      FROM FEC_Routing_Action_History__c
      WHERE
        FEC_Case__c = :caseId
        AND FEC_Next_Stage__c = :currentStageId
        AND FEC_Next_Stage__c != NULL
        AND FEC_IsReverted__c = true
      ORDER BY LastModifiedDate DESC
      LIMIT 1
    ];
    return !latestRevertHist.isEmpty();
  }

  private static Field transform(
    Sobject masterDataItem,
    SObject objTemp,
    String userGr,
    Boolean isStageRevert
  ) {
    String maskingTypeTemp = (String) masterDataItem.get('FEC_Masking_Type__c');
    String editableGr = (String) masterDataItem.get(
      'FEC_Editable_User_Group__c'
    );
    System.debug('>>>masterDataItem Sobject: ' + masterDataItem);
    System.debug('>>>objTemp: ' + objTemp);
    Boolean isReverted = (Boolean) masterDataItem.get('FEC_Field_Reverted__c');
    Boolean isReadOnly = (Boolean) masterDataItem.get('FEC_Field_ReadOnly__c');
    Boolean isEditable = (Boolean) masterDataItem.get('FEC_Field_Editable__c');
    String value = getFormattedFieldValue(
      objTemp,
      (String) masterDataItem.get('FEC_Field_API_Name__c')
    );

    system.debug(
      (String) masterDataItem.get('FEC_Field_Label_Name__c') +
        ' => ' +
        isReverted
    );

    system.debug(masterDataItem);

    if (isReverted && isEditable && !isStageRevert)
      return null;

    if (isReverted && isReadOnly && String.isBlank(value))
      return null;

    String apiName = (String) masterDataItem.get('FEC_Field_API_Name__c');
    Boolean masked = (Boolean) masterDataItem.get('FEC_Field_Masking__c');
    // Middle Name, Last Name are not sensitive => no eye icon
    if (
      apiName == 'FEC_Original_Info_Middle_Name__c' ||
      apiName == 'FEC_Original_Info_Last_Name__c'
    ) {
      masked = false;
    }
    if (
      apiName == 'FEC_Original_Info_Date_of_Issue__c' ||
      apiName == 'FEC_Original_Info_Place_of_Issue__c' ||
      apiName == 'FEC_Updated_Info_Date_of_Issue__c' ||
      apiName == 'FEC_Updated_Info_Place_of_Issue__c'
    ) {
      masked = false;
    }
    if (apiName == 'FEC_Original_Info_National_ID__c') {
      masked = true;
      maskingTypeTemp = 'National ID/ Passport';
    }

    return new Field(
      apiName,
      (String) masterDataItem.get('FEC_Field_Label_Name__c'),
      value,
      (Boolean) masterDataItem.get('FEC_Field_ReadOnly__c'),
      isEditable ||
      String.isNotBlank(editableGr) && editableGr.contains(userGr),
      (Boolean) masterDataItem.get('FEC_Field_Mandatory__c'),
      (Decimal) masterDataItem.get('FEC_Field_Order_Display__c'),
      masked,
      null,
      (Decimal) masterDataItem.get('FEC_Sub_Section_Field_Layout__c'),
      maskingTypeTemp
    );
  }

  public static Map<String, Map<String, String>> getHelpTextMap(
    Map<String, Set<String>> objToFieldlstMap
  ) {
    Map<String, Map<String, String>> result = new Map<String, Map<String, String>>();

    Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

    for (String objApiName : objToFieldlstMap.keySet()) {
      Schema.SObjectType objType = globalDescribe.get(objApiName);
      if (objType == null)
        continue;

      Map<String, Schema.SObjectField> fieldMap = objType.getDescribe()
        .fields.getMap();

      Map<String, String> fieldToHelpText = new Map<String, String>();

      for (String fieldApiName : objToFieldlstMap.get(objApiName)) {
        Schema.SObjectField field = fieldMap.get(fieldApiName);
        if (field == null)
          continue;

        String helpText = field.getDescribe().getInlineHelpText();

        fieldToHelpText.put(fieldApiName, helpText);
      }

      result.put(objApiName, fieldToHelpText);
    }

    return result;
  }

  private static String getFormattedFieldValue(SObject sobj, String fieldName) {
    if (sobj == null || String.isBlank(fieldName)) {
      return '';
    }

    Schema.SObjectType sType = sobj.getSObjectType();
    Schema.DescribeSObjectResult sDesc = sType.getDescribe();
    Schema.DescribeFieldResult fDesc = sDesc.fields.getMap()
      .get(fieldName)
      .getDescribe();

    Object value = sobj.get(fieldName);

    if (value == null) {
      return '';
    }

    Schema.DisplayType dtype = fDesc.getType();

    // Date: lightning-input-field expects YYYY-MM-DD (ISO date)
    if (dtype == Schema.DisplayType.Date) {
      Date d = (Date) value;
      String y = String.valueOf(d.year());
      String m = d.month() < 10 ? '0' + d.month() : String.valueOf(d.month());
      String day = d.day() < 10 ? '0' + d.day() : String.valueOf(d.day());
      return y + '-' + m + '-' + day;
    }

    // DateTime: lightning-input-field expects ISO8601 with timezone offset
    if (dtype == Schema.DisplayType.DateTime) {
      return ((DateTime) value).formatGmt(FEC_ConstantCommon.STR_DATETIME_FORMAT_Z);
    }

    // Everything else
    return String.valueOf(value);
  }

  public class Business {
    @AuraEnabled
    public List<Section> sectionlst;

    @AuraEnabled
    public List<Action> routingActionlst;

    @AuraEnabled
    public List<Action> processActionlst;

    @AuraEnabled
    public String nextTeam;

    @AuraEnabled
    public String natureOfCase;

    @AuraEnabled
    public String subCodeCode;

    @AuraEnabled
    public String subCategoryCode;

    @AuraEnabled
    public String stage;

    @AuraEnabled
    public String stageName;

    @AuraEnabled
    public FEC_CommonUltils.PicklistOption nextQueue;

    @AuraEnabled
    public String revertNextTeam;

    @AuraEnabled
    public FEC_CommonUltils.PicklistOption revertNextQueue;

    @AuraEnabled
    public String lastUser;

    @AuraEnabled
    //thangtv
    public String lastUserForRouteToLabel;

    //linhdev: Fix jira FECREDIT_CSM_2025_KH-1162
    /** LWC fec_CaseBussiness: khóa fec_IPPConversionRetailForm / fec_CardClosureRefundForm sau Revert về default stage. */
    @AuraEnabled
    public Boolean lockApiLwcsAfterRevertToDefaultStage;

    @AuraEnabled
    public String draftRoutingActionCode;

    // tungnm37 thêm: isSubmited - để LWC biết Case đã Submit chưa (dùng cho showManualAddItem Stage 2)
    @AuraEnabled
    public Boolean isSubmited;

    // tungnm37 thêm: customerType - để LWC fec_RoutingAssignment query đúng theo Customer Type
    @AuraEnabled
    public String customerType;

    @AuraEnabled
    public String code;

    @AuraEnabled
    public Map<String, Map<String, List<PicklistOptionDto>>> picklistOptionsMap;

    @AuraEnabled
    public Map<String, Boolean> contextFlags;

    // @AuraEnabled
    // public FEC_CommonUltils.PicklistOption lastQueue;

    public Business() {
      this.routingActionlst = new List<Action>();
      this.processActionlst = new List<Action>();
      this.sectionlst = new List<Section>();
      this.contextFlags = new Map<String, Boolean>();

      // this.lastQueue = new FEC_CommonUltils.PicklistOption();

      this.nextQueue = new FEC_CommonUltils.PicklistOption();
      this.revertNextQueue = new FEC_CommonUltils.PicklistOption();
    }

    public Section findSection(String name) {
      if (String.isBlank(name))
        return null;

      for (Section item : sectionlst) {
        if (name.equals(item.name))
          return item;
      }

      return null;
    }

    public void removeEmptySections() {
      for (Integer i = sectionlst.size() - 1; i >= 0; i--) {
        Section s = sectionlst[i];
        if (!s.removeIfNoFieldDeep()) {
          sectionlst.remove(i);
        }
      }
    }
  }

  /** Metadata LWC slot (FEC_Type__c = LWC) — thứ tự theo FEC_Sub_Section_Order__c. */
  public class DynamicLwcComponent {
    @AuraEnabled
    public String componentName;
    @AuraEnabled
    public Decimal order;
    @AuraEnabled
    public Decimal fieldLayout;
    @AuraEnabled
    public String subSectionName;
    @AuraEnabled
    public Boolean fecMasterDataSettingIsEdit;
    /** true: không hiển thị dòng label subsection (vd Original Info + GSR trên NOC flow history). */
    @AuraEnabled
    public Boolean hideSubSectionHeading;
    @AuraEnabled
    public Boolean isCollapsible;
  }

  public class Section implements Comparable {
    @AuraEnabled
    public String name;

    /** true: ẩn label subsection trên UI (vd Original Info khi BP NOC trên flow history chứa GSR). */
    @AuraEnabled
    public Boolean hideSubSectionHeading;

    @AuraEnabled
    public Error error;

    @AuraEnabled
    public List<CObject> objlst;

    @AuraEnabled
    public List<Section> subSectionlst;

    @AuraEnabled
    public Decimal order;

    @AuraEnabled
    public Decimal layout;

    @AuraEnabled
    public List<DynamicLwcComponent> componentlst;

    @AuraEnabled
    public Boolean isCollapsible;

    // Default constructor
    public Section() {
      this.objlst = new List<CObject>();
      this.subSectionlst = new List<Section>();
      this.error = new Error();
      this.componentlst = new List<DynamicLwcComponent>();
    }

    public Section(String name) {
      this.name = name;
      this.objlst = new List<CObject>();
      this.subSectionlst = new List<Section>();
      this.error = new Error();
      this.componentlst = new List<DynamicLwcComponent>();
    }

    public Section(String name, Decimal order, Decimal layout) {
      this.name = name;
      this.objlst = new List<CObject>();
      this.order = order;
      this.layout = layout;
      this.subSectionlst = new List<Section>();
      this.error = new Error();
      this.componentlst = new List<DynamicLwcComponent>();
    }

    // Parameterized constructor
    public Section(String name, List<CObject> objlst) {
      this.name = name;
      this.objlst = objlst != null ? objlst : new List<CObject>();
      this.componentlst = new List<DynamicLwcComponent>();
      this.error = new Error();
    }

    public Section(String name, Error err) {
      this.name = name;
      this.error = err;
      this.subSectionlst = new List<Section>();
      this.componentlst = new List<DynamicLwcComponent>();
    }

    public CObject findObj(String name) {
      if (String.isBlank(name))
        return null;

      for (CObject item : objlst) {
        if (name.equals(item.name))
          return item;
      }

      return null;
    }

    public Section findSubSection(String name) {
      if (String.isBlank(name))
        return null;

      for (Section item : subSectionlst) {
        if (name.equals(item.name))
          return item;
      }

      return null;
    }

    public void sort() {
      subSectionlst.sort();
      objlst.sort();
    }

    public Integer compareTo(Object other) {
      Section o = (Section) other;

      // Handle nulls safely
      if (this.order == null && o.order == null)
        return 0;
      if (this.order == null)
        return 1;
      if (o.order == null)
        return -1;

      return Integer.valueOf(this.order - o.order); // ascending
    }

    public Boolean removeIfNoFieldDeep() {
      // 1. Prune children first (bottom-up)
      for (Integer i = subSectionlst.size() - 1; i >= 0; i--) {
        Section child = subSectionlst[i];
        if (!child.removeIfNoFieldDeep()) {
          subSectionlst.remove(i);
        }
      }

      // 2. Check if this section has any field in its objects
      for (CObject obj : objlst) {
        if (obj.fieldlst != null && !obj.fieldlst.isEmpty()) {
          return true; // keep this section
        }
      }

      // 3. Check if this section has any LWC
      if (!componentlst.isEmpty()) {
        return true; // keep this section
      }

      // 4. Keep if still has valid subsections
      return !subSectionlst.isEmpty();
    }
  }

  public class CObject {
    @AuraEnabled
    public String name;

    @AuraEnabled
    public String id;

    @AuraEnabled
    public List<Field> fieldlst;

    public List<SObject> masterDataSettinglst;

    public CObject() {
      this.fieldlst = new List<Field>();
      this.masterDataSettinglst = new List<SObject>();
    }

    public CObject(String name) {
      this.name = name;
      // this.order = order;
      this.fieldlst = new List<Field>();
      this.masterDataSettinglst = new List<SObject>();
    }

    public void sort() {
      fieldlst.sort();
    }

    public Field findField(String name) {
      if (String.isBlank(name))
        return null;

      for (Field item : fieldlst) {
        if (name.equals(item.apiName))
          return item;
      }

      return null;
    }
  }

  public class Field implements Comparable {
    @AuraEnabled
    public String apiName;

    @AuraEnabled
    public String label;

    @AuraEnabled
    public String value;

    @AuraEnabled
    public String helpText;

    @AuraEnabled
    public Boolean readonly;

    @AuraEnabled
    public Boolean editable;

    @AuraEnabled
    public Boolean mandatory;

    @AuraEnabled
    public Boolean masked;

    @AuraEnabled
    public Decimal order;

    @AuraEnabled
    public Decimal layout;

    @AuraEnabled
    public String maskingType;

    @AuraEnabled
    public Boolean hidden;

    public Field() {
    }

    // Parameterized constructor
    public Field(
      String apiName,
      String label,
      String value,
      Boolean readonly,
      Boolean editable,
      Boolean mandatory,
      Decimal order,
      Boolean masked,
      String helpText,
      Decimal layout, 
      String maskingType
    ) {
      this.apiName = apiName;
      this.label = label;
      this.value = value;
      this.readonly = readonly;
      this.editable = editable;
      this.mandatory = mandatory;
      this.order = order;

      this.masked = masked;
      this.helpText = helpText;
      this.layout = layout;
      this.maskingType = maskingType;
    }

    public Integer compareTo(Object other) {
      Field o = (Field) other;

      // Handle nulls safely
      if (this.order == null && o.order == null)
        return 0;
      if (this.order == null)
        return 1;
      if (o.order == null)
        return -1;

      return Integer.valueOf(this.order - o.order); // ascending
    }
  }

  public class PicklistOptionDto {
    @AuraEnabled
    public String value;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public Boolean isDefault;

    public PicklistOptionDto() {
    }

    public PicklistOptionDto(String value, String label) {
      this.value = value;
      this.label = label;
    }
    
    public PicklistOptionDto(String value, String label, Boolean isDefault) {
      this.value = value;
      this.label = label;
      this.isDefault = isDefault;
    }
  }

  public class Action {
    @AuraEnabled
    public String id;

    @AuraEnabled
    public String value;

    @AuraEnabled
    public String label;

    @AuraEnabled
    public String code;

    public Action() {
    }

    // Parameterized constructor
    public Action(String value, String label) {
      this.value = value;
      this.label = label;
      this.code = value;
    }

    public Action(String id, String value, String label) {
      this.id = id;
      this.value = value;
      this.label = label;
      this.code = value;
    }

    public Action(String id, String value, String label, String code) {
      this.id = id;
      this.value = value;
      this.label = label;
      this.code = code;
    }
  }

  public class Error {
    @AuraEnabled
    public String label;

    @AuraEnabled
    public List<String> errorlst;

    public Error() {
      this.errorlst = new List<String>();
    }

    public Error(String label, List<String> errlst) {
      this.label = label;
      this.errorlst = errlst;
    }
  }

  public static void debugBusiness(Business b) {
    if (b == null) {
      System.debug('Business is NULL');
      return;
    }

    System.debug('========== Business ==========');
    System.debug('nextTeam = ' + b.nextTeam);
    System.debug('natureOfCase = ' + b.natureOfCase);
    System.debug('stage = ' + b.stage);
    System.debug('nextQueue = ' + JSON.serialize(b.nextQueue));

    // ===== ROUTING ACTIONS =====
    System.debug(
      '---- Routing Actions (' + b.routingActionlst.size() + ') ----'
    );
    for (Action a : b.routingActionlst) {
      System.debug('Action | id=' + a.value + ', name=' + a.label);
    }

    // ===== PROCESS ACTIONS =====
    System.debug(
      '---- Process Actions (' + b.processActionlst.size() + ') ----'
    );
    for (Action a : b.processActionlst) {
      System.debug('Action | id=' + a.value + ', name=' + a.label);
    }

    // ===== SECTIONS =====
    System.debug('---- Sections (' + b.sectionlst.size() + ') ----');
    for (Section s : b.sectionlst) {
      debugSection(s, 0);
    }

    System.debug('========== END Business ==========');
  }

  private static void debugSection(Section s, Integer level) {
    if (s == null)
      return;

    String indent = '';
    for (Integer i = 0; i < level * 4; i++) {
      indent += '  ';
    }

    System.debug(indent + 'SECTION: ' + s.name);

    // Objects
    for (CObject o : s.objlst) {
      System.debug(
        indent +
          '  OBJECT: ' +
          o.name +
          ' | id=' +
          o.id +
          ' | size:' +
          o.masterDataSettinglst.size()
      );

      for (Field f : o.fieldlst) {
        System.debug(
          indent +
            '    FIELD: ' +
            'api=' +
            f.apiName +
            ', label=' +
            f.label +
            ', value=' +
            f.value +
            ', readonly=' +
            f.readonly +
            ', editable=' +
            f.editable +
            ', mandatory=' +
            f.mandatory +
            ', masked=' +
            f.masked +
            ', order=' +
            f.order
        );
      }
    }

    // Sub sections (recursive)
    for (Section sub : s.subSectionlst) {
      debugSection(sub, level + 1);
    }
  }

  private static void recall(Id caseId) {
    Id currentUserId = UserInfo.getUserId();

    // 1. Query Case & Owner Info (Lấy thêm Owner.Type để đỡ phải check prefix ID)
    Case c = [
      SELECT Id, Status, OwnerId, Owner.Type
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];

    // 2. Query History gần nhất (Query vào List để tránh lỗi No Rows)
    List<FEC_Routing_Action_History__c> historyList = [
      SELECT
        Id,
        FEC_Perform_User__c,
        FEC_Updated_User_Queue__c,
        FEC_Updated_User_Queue_ID__c
      FROM FEC_Routing_Action_History__c
      WHERE
        FEC_Case__c = :caseId
        AND FEC_Routing_Action__c IN (:ROUTE_TO, :CHANGE_OWNER)
      ORDER BY CreatedDate DESC, Id DESC
      LIMIT 1
    ];
    System.debug('historyList: ' + historyList);
    if (historyList.isEmpty()) {
      throw new CaseBusinessServiceException(
        System.Label.FEC_MSG_Recall_Action_Not_Allowed
      );
    }

    FEC_Routing_Action_History__c lastAction = historyList[0];
    System.debug('lastAction: ' + lastAction);
    if (lastAction.FEC_Perform_User__c != currentUserId) {
      throw new CaseBusinessServiceException(
        System.Label.FEC_MSG_Recall_Action_Not_Allowed
      );
    }
    if (c.Owner.Type == 'User' && c.OwnerId != currentUserId) {
      throw new CaseBusinessServiceException(
        System.Label.FEC_MSG_Recall_Action_Not_Allowed
      );
    }
    try {
      if (
        c.Owner.Type == FEC_ConstantCommon.GROUP_TYPE_QUEUE &&
        currentUserId == lastAction.FEC_Perform_User__c &&
        lastAction.FEC_Updated_User_Queue_ID__c == c.OwnerId
      ) {
        c.OwnerId = currentUserId;
        c.Status = FEC_ConstantCommon.CASE_STATUS_PENDING;
        registerSkipOwnerChangeRoutingHistory(c.Id);
        update c;
      }
    } catch (Exception e) {
      // Log lỗi hệ thống
      System.debug('Error in recall: ' + e.getMessage());
      throw new CaseBusinessServiceException(e.getMessage());
    }
  }

  /**
   * Cập nhật Owner và FEC_Team__c dựa trên Decision
   * - Mặc định: Owner là User hiện tại.
   * - Out Of Process: Owner là Queue 'Handling'.
   * - CIC Related, Document Preparation, Task Under Review: Owner là Queue 'Care Internal Task'.
   */
  public static void updateCaseTeamAndOwner(Id caseId, String decision) {
    if (String.isBlank(caseId) || String.isBlank(decision))
      return;

    Id currentUserId = UserInfo.getUserId();
    
    // Kiểm tra xem user hiện tại có phải là Owner hoặc Case Participant không
    Case currentCase = [
      SELECT Id, OwnerId, FEC_Case_Participants__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    
    Boolean isOwner = currentCase.OwnerId == currentUserId;
    Boolean isParticipant = false;
    
    if (String.isNotBlank(currentCase.FEC_Case_Participants__c)) {
      List<String> participants = currentCase.FEC_Case_Participants__c.split(';');
      isParticipant = participants.contains(String.valueOf(currentUserId));
    }
    
    if (!isOwner && !isParticipant) {
      throw new AuraHandledException(
        System.Label.FEC_MSG_Update_Team_Permission_Denied
      );
    }

    // 1. Tạo Map ánh xạ từ Decision (Input) sang FEC_Team__c (Output)
    Map<String, String> decisionToTeamMap = FEC_ConstantCommon.decisionToTeamMap;

    // Nếu Decision không hợp lệ thì dừng
    if (!decisionToTeamMap.containsKey(decision))
      return;

    String teamValue = decisionToTeamMap.get(decision);
    Id newOwnerId = UserInfo.getUserId(); // Mặc định gán cho User đang thao tác

    // 2. Xử lý logic gán Owner là Queue cho các trường hợp đặc biệt
    String targetQueueName = null;

    if (decision == 'Out Of Process') {
      targetQueueName = 'Handling';
    } else if (
      decision == 'CIC Related' ||
      decision == 'Document Preparation' ||
      decision == 'Task Under Review'
    ) {
      targetQueueName = 'Care Internal Task';
    }

    // Nếu cần chuyển cho Queue, thực hiện query lấy Id
    if (targetQueueName != null) {
      List<Group> targetQueue = [
        SELECT Id
        FROM Group
        WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE AND Name = :targetQueueName
        LIMIT 1
      ];
      if (!targetQueue.isEmpty()) {
        newOwnerId = targetQueue[0].Id;
      } else {
        // Ném lỗi nếu không tìm thấy Queue cấu hình trong hệ thống
        throw new AuraHandledException(
          String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Queue' })
        );
      }
    }

    // Tránh trigger tạo thêm 1 bản Route to (Change Owner) — run(UPDATEACTION) sẽ gọi createRoutingActionHis('Update', ...) ngay sau
    Id priorOwnerId = [SELECT OwnerId FROM Case WHERE Id = :caseId LIMIT 1].OwnerId;
    if (priorOwnerId != newOwnerId) {
      registerSkipOwnerChangeRoutingHistory(caseId);
    }

    // 3. Thực hiện Update Case
    Case c = new Case(
      Id = caseId,
      OwnerId = newOwnerId,
      //FEC_Team__c = teamValue,
      Status = String.isNotBlank(teamValue)
        ? FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX + teamValue
        : FEC_ConstantCommon.CASE_STATUS_PENDING
    );

    try {
      update c;
    } catch (DmlException e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  public static Error phoneUpdateValidate(Id cHistoryId) {
    List<String> validStatuslst = new List<String>{ '8', '9', 'Z' };
    List<String> validBlockCodelst = new List<String>{ 'C' };
    List<String> validBlockCode1lst = new List<String>{
      'B',
      'F',
      'G',
      'N',
      'C',
      'U',
      'Z'
    };
    List<String> validBlockCode2lst = new List<String>{
      'D',
      'E',
      'H',
      'I',
      'J',
      'K',
      'M',
      'O'
    };

    List<FEC_Customer_History__c> cHistorylst = [
      SELECT
        Id,
        FEC_Account_Status__c,
        FEC_Block_Code__c,
        FEC_Block_Code_1__c,
        FEC_Block_Code_2__c
      FROM FEC_Customer_History__c
      WHERE Id = :cHistoryId
    ];

    List<String> errorlst = new List<String>();

    if (cHistorylst.isEmpty()) {
      errorlst.add(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'CUSTOMER_HISTORY' }));
    } else {
      FEC_Customer_History__c selectedHistory = cHistorylst.get(0);

      if (validStatuslst.contains(selectedHistory.FEC_Account_Status__c))
        errorlst.add(
          'Account Status = ' + selectedHistory.FEC_Account_Status__c
        );

      if (validBlockCode1lst.contains(selectedHistory.FEC_Block_Code_1__c))
        errorlst.add('Block Code 1 = ' + selectedHistory.FEC_Block_Code_1__c);

      if (validBlockCode2lst.contains(selectedHistory.FEC_Block_Code_2__c))
        errorlst.add('Block Code 2 = ' + selectedHistory.FEC_Block_Code_2__c);
      if (validBlockCodelst.contains(selectedHistory.FEC_Block_Code__c))
        errorlst.add('Block Code = ' + selectedHistory.FEC_Block_Code__c);
    }

    if (errorlst.isEmpty())
      return new Error();

    return new Error(Label.FEC_CaseBusinessService_Msg_006, errorlst);
  }

  /**
   * Lần khởi tạo màn Execute: Case chưa Submit và chưa có draft Routing/Remarks.
   */
  private static Boolean shouldFillBlankUpdatedInfoFromOriginal(Case selectedCase) {
    if (selectedCase.FEC_Is_Submited__c == true) {
      return false;
    }
    if (String.isNotBlank(selectedCase.FEC_Draft_Routing_Action_Code__c)) {
      return false;
    }
    if (String.isNotBlank(selectedCase.FEC_Draft_Remarks__c)) {
      return false;
    }
    return true;
  }

  private static void phoneUpdate(Case selectedCase) {
    selectedCase.FEC_Original_Info_Phone_Number__c = selectedCase.FEC_Account_or_Contract__r.FEC_Primary_Phone__c;
    if (
      shouldFillBlankUpdatedInfoFromOriginal(selectedCase) &&
      String.isBlank(selectedCase.FEC_Updated_Info_Phone_Number__c)
    ) {
      selectedCase.FEC_Updated_Info_Phone_Number__c = selectedCase.FEC_Original_Info_Phone_Number__c;
    }
    update selectedCase;
  }

  /**
   * Lấy First/Middle/Last Name từ Customer History (FEC_Account_or_Contract__c)
   * và cập nhật vào các trường FEC_Original_Info_* trên Case.
   * Chỉ gán Updated = Original khi chưa có giá trị (giữ bản nháp sau Save & Close khi bấm Execute lại).
   */
  private static void fullNameUpdate(Case selectedCase) {
    SObject accountOrContract = selectedCase.getSObject(
      'FEC_Account_or_Contract__r'
    );
    if (accountOrContract == null) {
      return;
    }
    selectedCase.FEC_Original_Info_Last_Name__c = (String) accountOrContract.get(
      'FEC_Last_Name__c'
    );
    selectedCase.FEC_Original_Info_Middle_Name__c = (String) accountOrContract.get(
      'FEC_Middle_Name__c'
    );
    selectedCase.FEC_Original_Info_First_Name__c = (String) accountOrContract.get(
      'FEC_First_Name__c'
    );
    if (shouldFillBlankUpdatedInfoFromOriginal(selectedCase)) {
      if (String.isBlank(selectedCase.FEC_Updated_Info_First_Name__c)) {
        selectedCase.FEC_Updated_Info_First_Name__c = selectedCase.FEC_Original_Info_First_Name__c;
      }
      if (String.isBlank(selectedCase.FEC_Updated_Info_Middle_Name__c)) {
        selectedCase.FEC_Updated_Info_Middle_Name__c = selectedCase.FEC_Original_Info_Middle_Name__c;
      }
      if (String.isBlank(selectedCase.FEC_Updated_Info_Last_Name__c)) {
        selectedCase.FEC_Updated_Info_Last_Name__c = selectedCase.FEC_Original_Info_Last_Name__c;
      }
    }
    update selectedCase;
  }

  /**
   * Lấy FEC_Email__c từ Customer History (FEC_Account_or_Contract__c)
   * và cập nhật vào trường FEC_Original_Info_Email__c trên Case.
   * Chỉ gán Updated = Original khi chưa có giá trị (giữ bản nháp sau Save & Close khi bấm Execute lại).
   */
  private static void emailUpdate(Case selectedCase) {
    SObject accountOrContract = selectedCase.getSObject(
      'FEC_Account_or_Contract__r'
    );
    if (accountOrContract == null) {
      return;
    }
    selectedCase.FEC_Original_Info_Email__c = (String) accountOrContract.get(
      'FEC_Email__c'
    );
    if (
      shouldFillBlankUpdatedInfoFromOriginal(selectedCase) &&
      String.isBlank(selectedCase.FEC_Updated_Info_Email__c)
    ) {
      selectedCase.FEC_Updated_Info_Email__c = selectedCase.FEC_Original_Info_Email__c;
    }
    update selectedCase;
  }

  /**
   * Lấy FEC_Date_of_Birth__c từ Customer History (FEC_Account_or_Contract__c)
   * và cập nhật vào trường FEC_Original_Info_Date_of_Birth__c trên Case.
   * Chỉ gán Updated = Original khi chưa có giá trị (giữ bản nháp sau Save & Close khi bấm Execute lại).
   */
  private static void dobUpdate(Case selectedCase) {
    SObject accountOrContract = selectedCase.getSObject(
      'FEC_Account_or_Contract__r'
    );
    if (accountOrContract == null) {
      return;
    }
    selectedCase.FEC_Original_Info_Date_of_Birth__c = (Date) accountOrContract.get(
      'FEC_Date_of_Birth__c'
    );
    if (
      shouldFillBlankUpdatedInfoFromOriginal(selectedCase) &&
      selectedCase.FEC_Updated_Info_Date_of_Birth__c == null
    ) {
      selectedCase.FEC_Updated_Info_Date_of_Birth__c = selectedCase.FEC_Original_Info_Date_of_Birth__c;
    }
    update selectedCase;
  }

  /**
   * Lấy FEC_Gender__c từ Customer History (FEC_Account_or_Contract__c)
   * và cập nhật vào trường FEC_Original_Info_Gender__c trên Case.
   * Chỉ gán Updated = Original khi chưa có giá trị (giữ bản nháp sau Save & Close khi bấm Execute lại).
   */
  private static void genderUpdate(Case selectedCase) {
    SObject accountOrContract = selectedCase.getSObject(
      'FEC_Account_or_Contract__r'
    );
    if (accountOrContract == null) {
      return;
    }
    selectedCase.FEC_Original_Info_Gender__c = (String) accountOrContract.get(
      'FEC_Gender__c'
    );
    if (
      shouldFillBlankUpdatedInfoFromOriginal(selectedCase) &&
      String.isBlank(selectedCase.FEC_Updated_Info_Gender__c)
    ) {
      selectedCase.FEC_Updated_Info_Gender__c = selectedCase.FEC_Original_Info_Gender__c;
    }
    update selectedCase;
  }

  /**
   * Lấy FEC_National_ID_Passport_ID__c, FEC_Date_of_Issue__c, FEC_Place_of_Issue__c
   * từ Customer History (FEC_Account_or_Contract__c) và cập nhật vào các trường
   * FEC_Original_Info_National_ID__c, FEC_Original_Info_Date_of_Issue__c, FEC_Original_Info_Place_of_Issue__c trên Case.
   */
  private static void identificationUpdate(Case selectedCase) {
    SObject accountOrContract = selectedCase.getSObject(
      'FEC_Account_or_Contract__r'
    );
    if (accountOrContract == null) {
      return;
    }
    selectedCase.FEC_Original_Info_National_ID__c = (String) accountOrContract.get(
      'FEC_National_ID_Passport_ID__c'
    );
    selectedCase.FEC_Original_Info_Date_of_Issue__c = (Date) accountOrContract.get(
      'FEC_Date_of_Issue__c'
    );
    selectedCase.FEC_Original_Info_Place_of_Issue__c = (String) accountOrContract.get(
      'FEC_Place_of_Issue__c'
    );
    if (shouldFillBlankUpdatedInfoFromOriginal(selectedCase)) {
      if (String.isBlank(selectedCase.FEC_Updated_Info_National_ID__c)) {
        selectedCase.FEC_Updated_Info_National_ID__c = selectedCase.FEC_Original_Info_National_ID__c;
      }
      if (selectedCase.FEC_Updated_Info_Date_of_Issue__c == null) {
        selectedCase.FEC_Updated_Info_Date_of_Issue__c = selectedCase.FEC_Original_Info_Date_of_Issue__c;
      }
      if (String.isBlank(selectedCase.FEC_Updated_Info_Place_of_Issue__c)) {
        selectedCase.FEC_Updated_Info_Place_of_Issue__c = selectedCase.FEC_Original_Info_Place_of_Issue__c;
      }
    }
    update selectedCase;
  }

  private static void undeliveriedCardUpdate(Case selectedCase) {
    FEC_GetStatus.CardDeliveryInfo cardDeliveryInfo = FEC_GetStatus.getDeliveryStatus(
      selectedCase.FEC_Account_or_Contract__r.FEC_Account_Number__c
    );

    if (cardDeliveryInfo != null) {
      selectedCase.FEC_Delivery_Status__c = cardDeliveryInfo.status;
      selectedCase.FEC_Delay_Note__c = cardDeliveryInfo.deliveryNotes;
      update selectedCase;
    }
  }

  // tungnm37: delegate sang FEC_CofGsrAssignmentService
  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getTeamQueueOptions() {
    return FEC_CofGsrAssignmentService.getTeamQueueOptions();
  }

  // tungnm37: delegate sang FEC_CofGsrAssignmentService
  @AuraEnabled
  public static List<Map<String, String>> getRoutingAssignments(String natureOfCaseId, String customerType) {
    return FEC_CofGsrAssignmentService.getRoutingAssignments(natureOfCaseId, customerType);
  }

  @AuraEnabled(cacheable=true)
  public static List<User> getTransferUsers(String caseId) {
    Id currentUserId = UserInfo.getUserId();
    
    // 1. Kiểm tra xem user hiện tại có phải là Owner của Case không
    if (String.isNotBlank(caseId)) {
      List<Case> caselst = [
        SELECT Id, OwnerId
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
      ];
      
      if (!caselst.isEmpty() && caselst[0].OwnerId != currentUserId) {
        return new List<User>();
      }
    }
    
    // 2. Lấy thông tin Group của User hiện tại
    User currentUser = [
      SELECT FEC_User_Group__c
      FROM User
      WHERE Id = :currentUserId
      LIMIT 1
    ];

    if (String.isBlank(currentUser.FEC_User_Group__c)) {
      return new List<User>();
    }

    // 3. Trả về danh sách User cùng Group (loại trừ chính mình)
    return [
      SELECT Id, Name
      FROM User
      WHERE
        IsActive = TRUE
        AND FEC_User_Group__c = :currentUser.FEC_User_Group__c
        AND Id != :currentUserId
      ORDER BY Name ASC
    ];
  }

  /**
   * Lấy danh sách Queue thuộc cùng Team Queue mà User là thành viên
   * @return List<FEC_Team_Queue__c>
   */
  // @AuraEnabled(cacheable=true)
  // public static List<Group> getTransferQueues() {
  //   // Thay đổi kiểu trả về
  //   Id userId = UserInfo.getUserId();

  //   // Bước 1: Tìm các GroupId (Type='Queue') mà User là thành viên
  //   Set<Id> groupIds = new Set<Id>();
  //   for (GroupMember gm : [
  //     SELECT GroupId
  //     FROM GroupMember
  //     WHERE UserOrGroupId = :userId AND Group.Type = 'Queue'
  //   ]) {
  //     groupIds.add(gm.GroupId);
  //   }

  //   if (groupIds.isEmpty())
  //     return new List<Group>();

  //   // Bước 2: Lấy Tên (Name) của các Queue này để map sang Custom Object
  //   List<Group> userQueues = [SELECT Name FROM Group WHERE Id IN :groupIds];

  //   Set<String> currentQueueNames = new Set<String>();
  //   for (Group g : userQueues) {
  //     currentQueueNames.add(g.Name);
  //   }

  //   if (currentQueueNames.isEmpty())
  //     return new List<Group>();

  //   // Bước 3: Tìm Team Name chung dựa trên Queue Name
  //   List<FEC_Team_Queue__c> matchedTeamQueues = [
  //     SELECT Name
  //     FROM FEC_Team_Queue__c
  //     WHERE FEC_Queue_Name__c IN :currentQueueNames
  //   ];

  //   Set<String> teamNames = new Set<String>();
  //   for (FEC_Team_Queue__c tq : matchedTeamQueues) {
  //     teamNames.add(tq.Name);
  //   }

  //   if (teamNames.isEmpty())
  //     return new List<Group>();

  //   // Bước 4: Lấy danh sách Tên Queue (FEC_Queue_Name__c) thuộc các Team Name tìm được
  //   List<FEC_Team_Queue__c> allQueuesInTeam = [
  //     SELECT FEC_Queue_Name__c
  //     FROM FEC_Team_Queue__c
  //     WHERE Name IN :teamNames
  //   ];

  //   Set<String> targetQueueNames = new Set<String>();
  //   for (FEC_Team_Queue__c tq : allQueuesInTeam) {
  //     targetQueueNames.add(tq.FEC_Queue_Name__c);
  //   }

  //   if (targetQueueNames.isEmpty())
  //     return new List<Group>();

  //   // Bước 5 (MỚI): Query bảng Group để trả về Id và Name thật của Queue
  //   return [
  //     SELECT Id, Name, DeveloperName
  //     FROM Group
  //     WHERE Type = 'Queue' AND Name IN :targetQueueNames
  //     ORDER BY Name ASC
  //   ];
  // }

  @AuraEnabled(cacheable=true)
  public static List<Group> getTransferQueues() {
    Id userId = UserInfo.getUserId();
    Id roleId = UserInfo.getUserRoleId(); 

    // Start with the user's direct ID
    Set<Id> allAssociatedIds = new Set<Id>{ userId };
    // 1. Add the Group IDs that correspond to the User's Role
    Group roleGroup = [SELECT Id FROM Group WHERE RelatedId = :roleId AND Type = 'Role' LIMIT 1];
    allAssociatedIds.add(roleGroup.Id);
    System.debug('getTransferQueues allAssociatedIds ' + allAssociatedIds);
    // 2. Query the Queues where the User, their Role Group, or their Public Groups are members
    return [
        SELECT Id, Name, DeveloperName  
        FROM Group 
        WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE 
        AND Id IN (
            SELECT GroupId 
            FROM GroupMember 
            WHERE UserOrGroupId IN :allAssociatedIds
        )
    ];
}

  private static Section buildAccountInfor(Case c) {
    // MAIN SECTION
    Section main = new Section('Account Information');

    // SUB SECTION (this is what you want)
    Section caseDetails = new Section('Account Infor', 1, 12);

    // CASE OBJECT
    CObject caseObj = new CObject('Case');
    caseObj.id = c.Id;

    Boolean isExisting = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER.equals(
      c.FEC_Account_or_Contract__r?.FEC_Customer_Type__c
    );

    if (isExisting)
      caseObj.fieldlst.add(
        new Field(
          'FEC_Account_Contract_Number_Text__c',
          'Account/ Contract Number',
          c.FEC_Account_Contract_Number_Text__c,
          true,
          false,
          false,
          1,
          false,
          null,
          3, 
          null
        )
      );

    caseObj.fieldlst.add(
      new Field(
        'FEC_Customer_Name__c',
        'Customer Name',
        c.FEC_Customer_Name__c,
        isExisting || String.isNotBlank(c.FEC_Customer_Name__c),
        !isExisting && String.isBlank(c.FEC_Customer_Name__c),
        !isExisting,
        1,
        false,
        null,
        3,
        null
      )
    );

    if (!isExisting) {
      caseObj.fieldlst.add(
        new Field(
          'FEC_Account_Contract_Number_PL__c',
          'Account/ Contract Number',
          c.FEC_Account_Contract_Number_PL__c,
          false,
          true,
          true,
          1,
          false,
          null,
          3,
          null
        )
      );

      caseObj.fieldlst.add(
        new Field(
          'FEC_National_ID_Passport_ID__c',
          'National ID/Passport ID',
          c.FEC_National_ID_Passport_ID__c,
          String.isNotBlank(c.FEC_National_ID_Passport_ID__c),
          String.isBlank(c.FEC_National_ID_Passport_ID__c),
          false,
          1,
          true,
          null,
          3,
          FEC_ConstantCommon.MASKING_TYPE_PASSPORT
        )
      );

      caseObj.fieldlst.add(
        new Field(
          'FEC_Case_Phone_Number__c',
          'Phone Number',
          c.FEC_Case_Phone_Number__c,
          false,
          true,
          false,
          1,
          true,
          null,
          3,
          FEC_ConstantCommon.MASKING_TYPE_PHONE
        )
      );

      caseObj.fieldlst.add(
        new Field(
          'FEC_Case_Email__c',
          'Email',
          c.FEC_Case_Email__c,
          false,
          true,
          false,
          1,
          false,
          null,
          3, 
          null
        )
      );

      Field customerTypeField = new Field(
        'FEC_Customer_Type__c',
        'Customer Type',
        c.FEC_Customer_Type__c,
        false,
        true,
        false,
        1,
        true,
        null,
        3,
        FEC_ConstantCommon.MASKING_TYPE_PASSPORT
      );

      customerTypeField.hidden  = true;

      caseObj.fieldlst.add(
        customerTypeField
      );
    }

    caseDetails.objlst.add(caseObj);

    main.subSectionlst.add(caseDetails);

    return main;
  }

  //PhongBT: Fix cập nhật sai case stage
  /**
   * Id FEC_Nature_of_Case__c (template) dùng cho FEC_Case_Stage__c.FEC_Nature_of_Cases__c.
   * Khi đang đọc từ FEC_Actual_Nature_of_Case__c, tra lại template theo dimension trong caseBindMap.
   */
  private static Id resolveTemplateNatureOfCaseIdForCaseStages(
    Boolean useActualNatureAndSettingObj,
    SObject selectedNatureOfCase,
    Map<String, Object> caseBindMap,
    List<String> rolelst
  ) {
    if (selectedNatureOfCase == null) {
      return null;
    }
    if (!useActualNatureAndSettingObj) {
      return (Id) selectedNatureOfCase.get('Id');
    }
    String templateNocQuery =
      'SELECT Id FROM FEC_Nature_of_Case__c ' +
      'WHERE FEC_Product_Type__c = :productType ' +
      'AND FEC_Category__c = :category ' +
      'AND FEC_Sub_Category__c = :subCategory ' +
      'AND FEC_Sub_Code__c = :subCode ' +
      'AND FEC_Customer_Type__c = :customerType ' +
      'AND FEC_Business_Process__r.FEC_Active__c = TRUE ' +
      'AND FEC_Active__c = TRUE ' +
      'AND FEC_User_Group__c INCLUDES (\'' +
      String.join(new List<String>(rolelst), '\',\'') +
      '\')';
    List<SObject> templateRows = Database.queryWithBinds(
      templateNocQuery,
      caseBindMap,
      AccessLevel.USER_MODE
    );
    return templateRows.isEmpty() ? null : (Id) templateRows[0].get('Id');
  }

  /**
   * Khi user đổi bộ NOC (FEC_Nature_of_Cases__c khác), map stage đang có trên case
   * sang bản ghi FEC_Case_Stage__c tương đương trên NOC mới để MDS và FEC_Current_Case_Stage__c
   * vẫn đúng "tầng" (vd Stage 2 → Stage 2 của NOC mới): khớp số stage trong Name (regex),
   * rồi cờ default; cuối cùng mới lấy bản ghi đầu theo Name.
   */
  private static FEC_Case_Stage__c resolveCaseStageForNewNatureOfCase(
    Id priorCaseStageId,
    Id newNatureOfCaseId
  ) {
    if (priorCaseStageId == null || newNatureOfCaseId == null) {
      return null;
    }
    List<FEC_Case_Stage__c> oldLst = [
      SELECT Id, Name, FEC_Default_Stage__c, FEC_Nature_of_Cases__c
      FROM FEC_Case_Stage__c
      WHERE Id = :priorCaseStageId AND FEC_Active__c = TRUE
      LIMIT 1
    ];
    if (oldLst.isEmpty()) {
      return null;
    }
    FEC_Case_Stage__c oldSt = oldLst[0];
    if (oldSt.FEC_Nature_of_Cases__c == newNatureOfCaseId) {
      return null;
    }
    List<FEC_Case_Stage__c> newLst = [
      SELECT Id, Name, FEC_Default_Stage__c
      FROM FEC_Case_Stage__c
      WHERE FEC_Nature_of_Cases__c = :newNatureOfCaseId AND FEC_Active__c = TRUE
      ORDER BY Name
    ];
    if (newLst.isEmpty()) {
      return null;
    }
    Integer oldStageNum = extractStageNumberFromStageName(oldSt.Name);
    if (oldStageNum != null) {
      for (FEC_Case_Stage__c n : newLst) {
        if (extractStageNumberFromStageName(n.Name) == oldStageNum) {
          return n;
        }
      }
    }
    for (FEC_Case_Stage__c n : newLst) {
      if (n.FEC_Default_Stage__c == oldSt.FEC_Default_Stage__c) {
        return n;
      }
    }
    return newLst[0];
  }

  private static Integer extractStageNumberFromStageName(String stageName) {
    if (String.isBlank(stageName)) {
      return null;
    }
    Matcher m = FEC_ConstantCommon.PAT_STAGE_NAME_WITH_NUMBER.matcher(stageName);
    if (m.find()) {
      return Integer.valueOf(m.group(1));
    }
    return null;
  }

  public class CaseBusinessServiceException extends Exception {
  }
}