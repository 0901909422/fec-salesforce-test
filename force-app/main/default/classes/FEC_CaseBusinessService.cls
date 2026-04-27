public without sharing class FEC_CaseBusinessService {
  public static final String TYPE_LWC = 'LWC';

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
    ROUTE_TO_COF_GSR
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
    'Route to COF/GSR' => Method.ROUTE_TO_COF_GSR
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
          FEC_SubCode__r.Name
        FROM Case
        WHERE Id = :caseId
      ];

      if (caselst.isEmpty())
        return result;

      Case selectedCase = caselst.get(0);

      if(!selectedCase.FEC_Is_Submited__c) {
        selectedCase.FEC_Current_Case_Stage__c = null;
      }

      result.sectionlst.add(buildAccountInfor(selectedCase));
      // 03/02/2026 adhoc for product type, category, sub category, sub code
      if (String.isBlank(productTypeId))
        productTypeId = selectedCase.FEC_Product_Type__c;
      if (String.isBlank(categoryId))
        categoryId = selectedCase.FEC_Category__c;
      if (String.isBlank(subCategoryId))
        subCategoryId = selectedCase.FEC_SubCategory__c;
      if (String.isBlank(subCodeId))
        subCodeId = selectedCase.FEC_SubCode__c;
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
      FEC_Routing_Action_History__c selectedHistory;
      // Lưu riêng REVERT record trước khi selectedHistory bị override bởi routeToHistorylst.
      // routeToHistorylst không SELECT FEC_Perform_User__r.Name nên không thể dùng selectedHistory
      // sau khi bị override để lấy Name → SObjectException → nextQueue.value = null → lỗi UI.
      FEC_Routing_Action_History__c revertHistory;

      if (!historylst.isEmpty()) {
        selectedHistory = historylst.get(0);
        isRevert = REVERT.equals(selectedHistory.FEC_Routing_Action__c);
        if (isRevert) {
          revertHistory = historylst.get(0);
        }
      }

      List<FEC_Routing_Action_History__c> routeToHistorylst = [
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
          AND FEC_Case__c = :selectedCase.Id
        ORDER BY CreatedDate DESC, Id DESC
        LIMIT 1
      ];

      if (!routeToHistorylst.isEmpty()) {
        selectedHistory = routeToHistorylst.get(0);

        if (String.isNotBlank(selectedHistory.FEC_Perform_User__c)) {
          result.lastUser = FRONT_LINE.equals(
              selectedHistory.FEC_Perform_User__r.FEC_User_Division_Group__c
            ) && selectedHistory.FEC_Previous_Stage__r.FEC_Default_Stage__c
            ? 'User\'s Team Queue'
            : 'User';

          // if (
          //   String.isNotBlank(
          //     selectedHistory.FEC_Perform_User__r.FEC_Main_Queue__c
          //   )
          // ) {
          // queuelst = [
          //   SELECT Id, Name, DeveloperName, Type
          //   FROM Group
          //   WHERE
          //     Type = 'Queue'
          //     AND DeveloperName = :selectedHistory.FEC_Perform_User__r.FEC_Main_Queue__c
          // ];

          // if (!queuelst.isEmpty())
          //   result.lastQueue = new FEC_CommonUltils.PicklistOption(
          //     queuelst.get(0).Name,
          //     (String) queuelst.get(0).Id,
          //     null
          //   );
          // }
        }
      } else {
        // ======================= UPDATE DATA FROM API =============================

        // if (
        //   String.isBlank(selectedCase.FEC_Current_Case_Stage__c) ||
        //   selectedCase.FEC_Current_Case_Stage__r?.FEC_Default_Stage__c
        // ) {
        // FEC_MainInfoAccountController.refreshAccountInfo(selectedCase.Id);
        // }
      }

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

      String natureOfCaseObj = String.isNotBlank(selectedNatureOfCaseId)
        ? 'FEC_Actual_Nature_of_Case__c'
        : 'FEC_Nature_of_Case__c';

      String masterDataSettingObj = String.isNotBlank(selectedNatureOfCaseId)
        ? 'FEC_Actual_Master_Data_Setting__c'
        : 'FEC_Master_Data_Setting__c';

      // =================================== NATURE OF CASE ==================================
      if (String.isBlank(selectedNatureOfCaseId)) {
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
        selectedCase.FEC_Current_Case_Stage__c = null;
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
          when else {
          }
        }
      } catch (DmlException e) {
      }

      // ================================= GET CASE STAGE ===========================
      selectedNatureOfCaseId = (String) selectedNatureOfCase.get('Id');

      String selectedCaseStageId = selectedCase.FEC_Current_Case_Stage__c;

      String caseStageQuery;

      Map<String, Object> bindVars;

      if (String.isNotBlank(selectedCaseStageId)) {
        caseStageQuery =
          'SELECT Id, Name ' +
          'FROM FEC_Case_Stage__c ' +
          'WHERE Id = :id ' +
          'AND FEC_Active__c = TRUE '; 
          // +
          // 'AND FEC_User_Group__c INCLUDES (\'' +
          // String.join(new List<String>(rolelst), '\',\'') +
          // '\')';

        bindVars = new Map<String, Object>{ 'id' => selectedCaseStageId };
      } else {
        caseStageQuery =
          'SELECT Id, Name ' +
          'FROM FEC_Case_Stage__c ' +
          'WHERE FEC_Nature_of_Cases__c = :selectedNatureOfCaseId ' +
          'AND FEC_Active__c = TRUE ' +
          'AND FEC_Default_Stage__c = TRUE ';
          // + 
          // 'AND FEC_User_Group__c INCLUDES (\'' +
          // String.join(new List<String>(rolelst), '\',\'') +
          // '\')';

        bindVars = new Map<String, Object>{
          'selectedNatureOfCaseId' => selectedNatureOfCaseId
        };
      }

      List<FEC_Case_Stage__c> stagelst = (List<FEC_Case_Stage__c>) Database.queryWithBinds(
        caseStageQuery,
        bindVars,
        AccessLevel.USER_MODE
      );

      if (stagelst.isEmpty()) {
        selectedCase.FEC_Current_Case_Stage__c = null;
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

          if (TYPE_LWC.equals(itemType)) {
            String lwcName = (String) item.get('FEC_LWC_Name__c');
            if (String.isNotBlank(lwcName)) {
              DynamicLwcComponent lwcSlot = new DynamicLwcComponent();
              lwcSlot.componentName = lwcName;
              lwcSlot.order = subSectionOrderTemp;
              lwcSlot.fieldLayout = (Decimal) item.get(
                'FEC_Sub_Section_Field_Layout__c'
              );
              lwcSlot.subSectionName = subSectionNameTemp;
              lwcSlot.fecMasterDataSettingIsEdit = isLwcDynamicMasterInEditMode(
                item,
                currentUser.FEC_User_Group__c,
                selectedStage.Name
              );
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

      // get next queue for Route to action
      // isRevert=true (last history = REVERT):
      //   Step 1: Query Stage Change với action button = Route to + FEC_IsReverted__c=true → nextTeam
      //   Step 2: Owner = revertHistory.FEC_Perform_User__c (queue/user được gán khi Revert)
      // isRevert=false: dùng Stage Change với routeToId + FEC_IsReverted__c = false
      if (isRevert) {
        // Step 1: query Stage Change với Route to + isReverted=true để lấy nextTeam.
        // Nếu không có record isReverted=true → fallback sang isReverted=false.
        if (routeToId != null) {
          List<FEC_Stage_Change__c> revertRouteToChangelst = [
        SELECT FEC_Next_Stage__c, FEC_Next_Queue__c, Id, FEC_Team_User_Group__c
        FROM FEC_Stage_Change__c
        WHERE
          FEC_Previous_Stage__c = :selectedStage.Id
          AND FEC_Active__c = TRUE
          AND FEC_Action_Button__c = :routeToId
              AND FEC_IsReverted__c = true
          ];
          if (!revertRouteToChangelst.isEmpty()) {
            result.nextTeam = revertRouteToChangelst.get(0).FEC_Team_User_Group__c;
          } else {
            List<FEC_Stage_Change__c> fallbackChangelst = [
              SELECT FEC_Next_Stage__c, FEC_Next_Queue__c, Id, FEC_Team_User_Group__c
              FROM FEC_Stage_Change__c
              WHERE
                FEC_Previous_Stage__c = :selectedStage.Id
                AND FEC_Active__c = TRUE
                AND FEC_Action_Button__c = :routeToId
                AND FEC_IsReverted__c = false
            ];
            if (!fallbackChangelst.isEmpty()) {
              result.nextTeam = fallbackChangelst.get(0).FEC_Team_User_Group__c;
            }
          }
        }
        // Step 2: owner = FEC_Updated_User_Queue_ID__c từ Revert history (queue/user được gán khi Revert)
        // Dùng revertHistory (đã lưu trước khi selectedHistory bị override bởi routeToHistorylst)
        if (revertHistory != null && String.isNotBlank(revertHistory.FEC_Perform_User__c)) {
          result.nextQueue = new FEC_CommonUltils.PicklistOption(
            revertHistory.FEC_Updated_User_Queue__c,
            revertHistory.FEC_Perform_User__c,
            null
          );
        }
      } else if (!isRevert && routeToId != null) {
        //thangtv: Route to — history mới nhất IsReverted=true ưu tiên Stage Change Route to + FEC_IsReverted__c=true, không có thì false
        List<FEC_Stage_Change__c> routeToChangelst = new List<FEC_Stage_Change__c>();
        if (latestRoutingHistoryIsReverted) {
          routeToChangelst = [
            SELECT FEC_Next_Stage__c, FEC_Next_Queue__c, Id, FEC_Team_User_Group__c
            FROM FEC_Stage_Change__c
            WHERE
              FEC_Previous_Stage__c = :selectedStage.Id
              AND FEC_Active__c = TRUE
              AND FEC_Action_Button__c = :routeToId
              AND FEC_IsReverted__c = true
          ];
        }
        if (routeToChangelst.isEmpty()) {
          routeToChangelst = [
            SELECT FEC_Next_Stage__c, FEC_Next_Queue__c, Id, FEC_Team_User_Group__c
            FROM FEC_Stage_Change__c
            WHERE
              FEC_Previous_Stage__c = :selectedStage.Id
              AND FEC_Active__c = TRUE
              AND FEC_Action_Button__c = :routeToId
              AND FEC_IsReverted__c = false
          ];
        }
        if (!routeToChangelst.isEmpty()) {
          result.nextTeam = routeToChangelst.get(0).FEC_Team_User_Group__c;
          queuelst = [
            SELECT Id, Name, DeveloperName, Type
            FROM Group
            WHERE
              Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
              AND DeveloperName = :routeToChangelst.get(0).FEC_Next_Queue__c
          ];
          if (!queuelst.isEmpty())
            result.nextQueue = new FEC_CommonUltils.PicklistOption(
              queuelst.get(0).Name,
              (String) queuelst.get(0).Id,
              null
            );
        }
      }

      //thangtv: Revert button + custom label "Route to" — fallback nextQueue theo revertId + Stage Change IsReverted=true khi routeToId không ra queue
      // Revert button + FEC_Custom_Action_Button_Label__c = "Route to": Action.value/label = "Route to"
      // nhưng Stage Change cấu hình theo FEC_Action_Button__c = Revert + FEC_Previous_Stage__c = stage hiện tại.
      // Khi query theo routeToId không ra queue (hoặc không có routeToId), lấy next team/queue theo revertId.
      if (
        !isRevert &&
        revertId != null &&
        (result.nextQueue == null || String.isBlank(result.nextQueue.value))
      ) {
        List<FEC_Stage_Change__c> stageChangeByRevertBtn = [
          SELECT FEC_Next_Stage__c, FEC_Next_Queue__c, Id, FEC_Team_User_Group__c
          FROM FEC_Stage_Change__c
          WHERE
            FEC_Previous_Stage__c = :selectedStage.Id
            AND FEC_Active__c = TRUE
            AND FEC_Action_Button__c = :revertId
            AND FEC_IsReverted__c = true
        ];
        if (!stageChangeByRevertBtn.isEmpty()) {
          result.nextTeam = stageChangeByRevertBtn.get(0).FEC_Team_User_Group__c;
        queuelst = [
          SELECT Id, Name, DeveloperName, Type
          FROM Group
          WHERE
            Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
              AND DeveloperName = :stageChangeByRevertBtn.get(0).FEC_Next_Queue__c
        ];
        if (!queuelst.isEmpty())
          result.nextQueue = new FEC_CommonUltils.PicklistOption(
            queuelst.get(0).Name,
            (String) queuelst.get(0).Id,
            null
          );
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

      // Case đã Submit thì không trả draft → màn Execute hiển thị mới, không autofill dữ liệu cũ
      result.draftRoutingActionCode = selectedCase.FEC_Is_Submited__c == true
        ? null
        : selectedCase.FEC_Draft_Routing_Action_Code__c;
      // tungnm37 thêm: trả isSubmited để LWC kiểm tra Stage 2 (showManualAddItem)
      result.isSubmited = selectedCase.FEC_Is_Submited__c == true;
      // tungnm37 thêm: trả customerType để LWC fec_RoutingAssignment query đúng
      result.customerType = selectedCase.FEC_Customer_Type__c;

      if (Schema.sObjectType.Case.isUpdateable()) {
        try {
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
  private static String emailLocalPart(String email) {
    if (String.isBlank(email)) {
      return null;
    }
    List<String> parts = email.split('@');
    return parts.isEmpty() ? email.trim() : parts[0].trim();
  }

  private static String resolveRoutingHistoryOwnerLabel(Id ownerId, String fallbackName) {
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


  private static void markCaseSubmittedAndClearDrafts(String caseId) {
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
  private static void createCaseFlowHistory(String caseId, String natureOfCaseId, String fieldListJson) {
    if (String.isBlank(caseId)) return;
    try {
      FEC_Case_Flow_History__c history = new FEC_Case_Flow_History__c(
        FEC_Case__c = caseId,
        FEC_Field_List__c = fieldListJson
      );
      if (String.isNotBlank(natureOfCaseId)) {
        history.FEC_Nature_of_Cases__c = natureOfCaseId;
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
      String finalStatusBeforeSubmit = null;
      
      if (params != null) {
        caseId = (String) params.get('caseId');
        Case c = [
          SELECT
            Id,
            OwnerId,
            Owner.Name,
            FEC_Stage_Name__c,
            FEC_Final_Status__c,
            FEC_Customer_Type__c,
            FEC_Account_Contract_Number_PL__c
          FROM Case
          WHERE Id = :caseId
          LIMIT 1
        ];
        // tungnm37: không check FEC_Account_Contract_Number_PL__c ở đây
        oldOwnerId = c.OwnerId;
        oldOwnerName = resolveRoutingHistoryOwnerLabel(c.OwnerId, c.Owner?.Name);
        stageName = c.FEC_Stage_Name__c;
        finalStatusBeforeSubmit = c.FEC_Final_Status__c;
      }

      String blockCode = (String)params.get('blockCode');
      String replacementFee = (String)params.get('replacementFee');
      String last4Digit = (String)params.get('last4Digit');

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
          String natureOfCaseId = (String) params.get('natureOfCaseId');
          String manualItemsJson = (String) params.get('manualItemsJson');
          // tungnm37 thêm: nhận remarkContent từ LWC để gắn vào Assignment Remark
          String remarkContent = (String) params.get('remarkContent');
          try { markCaseSubmittedAndClearDrafts(caseId); } catch (Exception e1) { System.debug('markCaseSubmitted error: ' + e1.getMessage()); }
          if (String.isNotBlank(natureOfCaseId)) {
            try { saveCaseNOC(caseId, natureOfCaseId); } catch (Exception e2) { System.debug('saveCaseNOC error: ' + e2.getMessage()); }
          }
          User currentUser = [SELECT Email, UserRole.Name, Id, FEC_User_Group__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

          // tungnm37 thêm: nếu có manual items (Stage 2) → tạo Assignment từ manual items
          if (String.isNotBlank(manualItemsJson)) {
            createAssignmentsFromManualItems(caseId, manualItemsJson, currentUser, stageName);
            return null;
          }

          // tungnm37 sửa: resolve về tất cả FEC_Nature_of_Case__c IDs có RA
          Set<Id> nocIds = resolveToNocIds(natureOfCaseId);
          // tungnm37 thêm: check team CC/SP → chuyển Owner sang Queue tương ứng, không tạo Assignment
          String firstTeam = null;
          if (!nocIds.isEmpty()) {
            List<FEC_Routing_Assignment__c> teamCheck = [
              SELECT FEC_Team__c FROM FEC_Routing_Assignment__c
              WHERE FEC_Nature_of_Cases__c IN :nocIds AND FEC_Team__c != null LIMIT 1
            ];
            if (!teamCheck.isEmpty()) firstTeam = teamCheck[0].FEC_Team__c;
          }
          Boolean isCcSpTeam = 'CC'.equals(firstTeam) || 'SP'.equals(firstTeam);
          if (isCcSpTeam) {
            // tungnm37: CC → DQ - CS Customer Care, SP → DQ - CS Support
            String targetQueueName = 'CC'.equals(firstTeam)
              ? System.Label.FEC_CC_Queue_Name
              : System.Label.FEC_CS_Support_Queue_Name;
            List<Group> targetQueues = [SELECT Id FROM Group WHERE Name = :targetQueueName AND Type = 'Queue' LIMIT 1];
            if (!targetQueues.isEmpty()) {
              registerSkipOwnerChangeRoutingHistory(caseId);
              Database.update(new Case(Id = caseId, OwnerId = targetQueues[0].Id), AccessLevel.SYSTEM_MODE);
            }
            // tungnm37 thêm: chuyển Case sang Stage 2 sau khi submit Stage 1 (CC/SP)
            if (!nocIds.isEmpty()) {
              List<FEC_Case_Stage__c> nextStages = [
                SELECT Id FROM FEC_Case_Stage__c
                WHERE FEC_Nature_of_Cases__c IN :nocIds
                  AND FEC_Default_Stage__c = false
                  AND FEC_Active__c = true
                ORDER BY Name ASC LIMIT 1
              ];
              if (!nextStages.isEmpty()) {
                Database.update(new Case(Id = caseId, FEC_Current_Case_Stage__c = nextStages[0].Id), AccessLevel.SYSTEM_MODE);
              }
            }
          } else {
            createAssignmentsOnRoute(caseId, nocIds, currentUser, null, stageName, remarkContent);
          }
          return null;
        }
        when REVERT {
          String revertActionId = (String) params.get('actionId');
          //thangtv: action.value (LWC) → phân nhánh Stage Change FEC_IsReverted__c + custom label history
          String routingActionValue = params != null
            ? (String) params.get('routingActionValue')
            : null;
          markCaseSubmittedAndClearDrafts(caseId);
          revert(caseId, revertActionId, finalStatusBeforeSubmit, routingActionValue);
          return null;
        }
        when RECALL {
          markCaseSubmittedAndClearDrafts(caseId);
          recall(caseId);
          createRoutingActionHis('Recall', '', oldOwnerName, oldOwnerId, caseId, stageName, finalStatusBeforeSubmit);
          return null;
        }
        when CANCEL {
          markCaseSubmittedAndClearDrafts(caseId);
          cancel(caseId);
          createRoutingActionHis('Cancel', '', oldOwnerName, oldOwnerId, caseId, stageName, finalStatusBeforeSubmit);
          return null;
        }
        when REOPEN {
          markCaseSubmittedAndClearDrafts(caseId);
          reopen(caseId);
          createRoutingActionHis('Reopen', '', oldOwnerName, oldOwnerId, caseId, stageName, finalStatusBeforeSubmit);
          return null;
        }
        when ESCALATE {
          markCaseSubmittedAndClearDrafts(caseId);
          escalate(caseId);
          createRoutingActionHis('Escalate', '', oldOwnerName, oldOwnerId, caseId, stageName, finalStatusBeforeSubmit);
          return null;
        }
        when REJECT {
          markCaseSubmittedAndClearDrafts(caseId);
          reject(caseId);
          createRoutingActionHis('Reject', '', oldOwnerName, oldOwnerId, caseId, stageName, finalStatusBeforeSubmit);
          return null;
        }
        when RESOLVE {
          markCaseSubmittedAndClearDrafts(caseId);
          resolve(caseId);
          createRoutingActionHis('Resolve', '', oldOwnerName, oldOwnerId, caseId, stageName, finalStatusBeforeSubmit);
          return null;
        }
        when TRANSFER {
          markCaseSubmittedAndClearDrafts(caseId);
          String userOrQueueId = (String) params.get('userOrQueueId');
          // Đổi owner trước (transfer đã registerSkip), rồi ghi history — tránh 2 bản; Updated = owner sau transfer
          transfer(caseId, userOrQueueId);
          createRoutingActionHis('Transfer', '', oldOwnerName, oldOwnerId, caseId, stageName, finalStatusBeforeSubmit);
          return null;
        }
        when UPDATEACTION {
          String decision = (String) params.get('decision');
          updateCaseTeamAndOwner(caseId, decision);
          markCaseSubmittedAndClearDrafts(caseId);
          createRoutingActionHis('Update', decision, oldOwnerName, oldOwnerId, caseId, stageName, finalStatusBeforeSubmit);
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
          FEC_Category__r.Name,
          FEC_SubCategory__r.Name,
          FEC_SubCode__r.Name
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
          FEC_IsReverted__c,
          FEC_Perform_User__c
        FROM FEC_Routing_Action_History__c
        WHERE
          FEC_Case__c = :caseId
          AND FEC_Routing_Action__c IN :new List<String>{ ROUTE_TO, REVERT }
        ORDER BY CreatedDate DESC, Id DESC
        LIMIT 1
      ];
      //thangtv: cờ history mới nhất IsReverted — quyết định query Stage Change Route to (true trước, fallback false)
      Boolean latestRoutingHistoryIsReverted =
        !latestHistForRoute.isEmpty() &&
        latestHistForRoute.get(0).FEC_IsReverted__c == true;
      //thangtv: có 2 history stage liên tiếp (newest=true, previous=false) thì action tiếp theo (không phải Revert) đi theo Stage Change IsReverted=false
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
      Boolean shouldRouteByNonRevertedStageChange =
        latestStageHistoryForRoute.size() == 2 &&
        latestStageHistoryForRoute.get(0).FEC_IsReverted__c == true &&
        latestStageHistoryForRoute.get(1).FEC_IsReverted__c == false &&
        latestStageHistoryForRoute.get(0).FEC_Previous_Stage__c != null &&
        latestStageHistoryForRoute.get(0).FEC_Next_Stage__c != null &&
        latestStageHistoryForRoute.get(1).FEC_Previous_Stage__c ==
        latestStageHistoryForRoute.get(0).FEC_Next_Stage__c &&
        latestStageHistoryForRoute.get(1).FEC_Next_Stage__c ==
        latestStageHistoryForRoute.get(0).FEC_Previous_Stage__c;

      //thangtv: Route to — history IsReverted=true → Stage Change + FEC_IsReverted__c=true; rỗng thì query false. Owner = Perform user history khi có (block dưới)
      List<FEC_Stage_Change__c> changelst = new List<FEC_Stage_Change__c>();
      if (shouldRouteByNonRevertedStageChange) {
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
      } else if (latestRoutingHistoryIsReverted) {
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
            AND FEC_IsReverted__c = true
        ];
      }
      if (changelst.isEmpty()) {
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

      //thangtv: History mới nhất IsReverted — Route to gán queueId/Owner từ FEC_Perform_User__c bản ghi đó (trước applyFrontline)
      if (
        !shouldRouteByNonRevertedStageChange &&
        latestRoutingHistoryIsReverted &&
        !latestHistForRoute.isEmpty() &&
        String.isNotBlank(latestHistForRoute.get(0).FEC_Perform_User__c)
      ) {
        queueId = String.valueOf(latestHistForRoute.get(0).FEC_Perform_User__c);
      }
      if (shouldRouteByNonRevertedStageChange && selectedChange.FEC_Next_Queue__c != null) {
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

      // tungnm37 thêm: tạo Assignment + Case Remarks khi Route to
      // Bỏ qua khi nextTeam = CC hoặc SP (luồng Manual, user tự thêm qua nút Add Item)
      String nextTeamForAssignment = selectedChange != null
        ? [SELECT FEC_Team_User_Group__c FROM FEC_Stage_Change__c WHERE Id = :selectedChange.Id LIMIT 1]?.FEC_Team_User_Group__c
        : null;
      Boolean isManualTeam = ('CC'.equals(nextTeamForAssignment) || 'SP'.equals(nextTeamForAssignment));
      if (!isManualTeam) {
        Set<Id> nocIds = resolveToNocIds(natureOfCaseId);
        createAssignmentsOnRoute(caseId, nocIds, currentUser, history.Id, history.FEC_Stage_Name__c, null);
      }
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
    String finalStatusBeforeSubmit
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

  private static FEC_Actual_Nature_of_Case__c cloneActualNatureOfCase(
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

  private static void cloneMasterDataSetting(
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
            options.add(new PicklistOptionDto(entry.getValue(), entry.getLabel()));
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
    public String draftRoutingActionCode;

    // tungnm37 thêm: isSubmited - để LWC biết Case đã Submit chưa (dùng cho showManualAddItem Stage 2)
    @AuraEnabled
    public Boolean isSubmited;

    @AuraEnabled
    public String code;

    // tungnm37 thêm: customerType - để LWC fec_RoutingAssignment query đúng theo Customer Type
    @AuraEnabled
    public String customerType;

    @AuraEnabled
    public Map<String, Map<String, List<PicklistOptionDto>>> picklistOptionsMap;

    // @AuraEnabled
    // public FEC_CommonUltils.PicklistOption lastQueue;

    public Business() {
      this.routingActionlst = new List<Action>();
      this.processActionlst = new List<Action>();
      this.sectionlst = new List<Section>();

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
  }

  public class Section implements Comparable {
    @AuraEnabled
    public String name;

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

    public PicklistOptionDto() {
    }

    public PicklistOptionDto(String value, String label) {
      this.value = value;
      this.label = label;
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

  // tungnm37 thêm: getTeamQueueOptions - lấy danh sách Team/Queue từ FEC_Team_Queue__c cho Manual Assignment
  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getTeamQueueOptions() {
    List<FEC_Team_Queue__c> records = [
      SELECT FEC_Name__c, FEC_Queue_Name__c
      FROM FEC_Team_Queue__c
      ORDER BY FEC_Name__c, FEC_Queue_Name__c
    ];
    List<Map<String, String>> result = new List<Map<String, String>>();
    for (FEC_Team_Queue__c r : records) {
      result.add(new Map<String, String>{
        'teamName' => r.FEC_Name__c,
        'queueName' => r.FEC_Queue_Name__c
      });
    }
    return result;
  }

  // tungnm37 thêm: getRoutingAssignments - query FEC_Routing_Assignment__c theo NOC + CustomerType
  // natureOfCaseId có thể là ID của FEC_Nature_of_Case__c hoặc FEC_Actual_Nature_of_Case__c
  @AuraEnabled
  public static List<Map<String, String>> getRoutingAssignments(String natureOfCaseId, String customerType) {
    if (String.isBlank(natureOfCaseId)) return new List<Map<String, String>>();

    // tungnm37: thử query trực tiếp theo FEC_Nature_of_Case__c trước
    List<FEC_Routing_Assignment__c> records = [
      SELECT FEC_Team__c, FEC_Queue__c, FEC_Customer_Type__c
      FROM FEC_Routing_Assignment__c
      WHERE FEC_Nature_of_Cases__c = :natureOfCaseId
        AND FEC_Team__c != null
        AND FEC_Queue__c != null
        
      ORDER BY FEC_Team__c ASC
    ];

    // tungnm37: nếu không có kết quả, tìm NOC cùng Category/SubCode (kể cả inactive)
    // để match với Routing Assignment (data có thể gắn với NOC inactive)
    if (records.isEmpty()) {
      List<FEC_Nature_of_Case__c> srcNoc = [
        SELECT FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c
        FROM FEC_Nature_of_Case__c
        WHERE Id = :natureOfCaseId
        LIMIT 1
      ];
      if (!srcNoc.isEmpty()) {
        FEC_Nature_of_Case__c src = srcNoc[0];
        List<FEC_Nature_of_Case__c> siblingNocs = [
          SELECT Id
          FROM FEC_Nature_of_Case__c
          WHERE FEC_Business_Process__c = :src.FEC_Business_Process__c
            AND FEC_Category__c = :src.FEC_Category__c
            AND FEC_Sub_Category__c = :src.FEC_Sub_Category__c
            AND FEC_Sub_Code__c = :src.FEC_Sub_Code__c
            AND Id != :natureOfCaseId
          LIMIT 20
        ];
        if (!siblingNocs.isEmpty()) {
          Set<Id> siblingIds = new Set<Id>();
          for (FEC_Nature_of_Case__c n : siblingNocs) siblingIds.add(n.Id);
          records = [
            SELECT FEC_Team__c, FEC_Queue__c, FEC_Customer_Type__c
            FROM FEC_Routing_Assignment__c
            WHERE FEC_Nature_of_Cases__c IN :siblingIds
              AND FEC_Team__c != null
              AND FEC_Queue__c != null
              
            ORDER BY FEC_Team__c ASC
          ];
        }
      }
    }

    // tungnm37: nếu không có kết quả, thử lookup qua FEC_Actual_Nature_of_Case__c
    // (natureOfCaseId có thể là ID của FEC_Actual_Nature_of_Case__c)
    if (records.isEmpty()) {
      List<FEC_Actual_Nature_of_Case__c> actualNocs = [
        SELECT FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c,
               FEC_Sub_Code__c, FEC_Customer_Type__c, FEC_Product_Type__c
        FROM FEC_Actual_Nature_of_Case__c
        WHERE Id = :natureOfCaseId
        LIMIT 1
      ];
      if (!actualNocs.isEmpty()) {
        FEC_Actual_Nature_of_Case__c an = actualNocs[0];
        // Tìm FEC_Nature_of_Case__c tương ứng
        List<FEC_Nature_of_Case__c> matchNocs = [
          SELECT Id
          FROM FEC_Nature_of_Case__c
          WHERE FEC_Business_Process__c = :an.FEC_Business_Process__c
            AND FEC_Category__c = :an.FEC_Category__c
            AND FEC_Sub_Category__c = :an.FEC_Sub_Category__c
            AND FEC_Sub_Code__c = :an.FEC_Sub_Code__c
            AND FEC_Active__c = true
          LIMIT 10
        ];
        if (!matchNocs.isEmpty()) {
          Set<Id> nocIds = new Set<Id>();
          for (FEC_Nature_of_Case__c n : matchNocs) nocIds.add(n.Id);
          records = [
            SELECT FEC_Team__c, FEC_Queue__c, FEC_Customer_Type__c
            FROM FEC_Routing_Assignment__c
            WHERE FEC_Nature_of_Cases__c IN :nocIds
              AND FEC_Active__c = true
              AND FEC_Team__c != null
              AND FEC_Queue__c != null
              
            ORDER BY FEC_Team__c ASC
          ];
        }
      }
    }

    List<Map<String, String>> result = new List<Map<String, String>>();
    for (FEC_Routing_Assignment__c r : records) {
      result.add(new Map<String, String>{
        'team' => r.FEC_Team__c,
        'queue' => r.FEC_Queue__c
      });
    }
    return result;
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
    Set<Id> allAssociatedIds = new Set<Id>{ userId };

    // BƯỚC 1: Thu thập tất cả ID đại diện cho User (User ID, Role, Public Groups, v.v.)
    if (roleId != null) {
        Set<Id> roleIds = new Set<Id>{ roleId };
        Map<Id, Id> roleToParentMap = new Map<Id, Id>();
        
        // Lấy toàn bộ cấu trúc Role để tìm Parent Roles
        for (UserRole ur : [SELECT Id, ParentRoleId FROM UserRole]) {
            roleToParentMap.put(ur.Id, ur.ParentRoleId);
        }
        
        // Duyệt ngược lên để lấy toàn bộ Parent Roles
        Id currentRoleId = roleId;
        while (roleToParentMap.get(currentRoleId) != null) {
            currentRoleId = roleToParentMap.get(currentRoleId);
            roleIds.add(currentRoleId);
        }

        // Gộp query lấy Group của Role và RoleAndSubordinates làm 1
        for (Group g : [
            SELECT Id, Type, RelatedId 
            FROM Group 
            WHERE RelatedId IN :roleIds AND Type IN ('Role', 'RoleAndSubordinates')
        ]) {
            if (g.Type == 'RoleAndSubordinates' || (g.Type == 'Role' && g.RelatedId == roleId)) {
                allAssociatedIds.add(g.Id);
            }
        }
    }

    // Quét các Public Groups lồng nhau (Nested Public Groups)
    Integer previousSize;
    do {
        previousSize = allAssociatedIds.size();
        for (GroupMember gm : [
            SELECT GroupId 
            FROM GroupMember 
            WHERE UserOrGroupId IN :allAssociatedIds AND Group.Type = 'Regular'
        ]) {
            allAssociatedIds.add(gm.GroupId);
        }
    } while (allAssociatedIds.size() > previousSize);

    // BƯỚC 2: Lấy Tên (Name) của các Queue này để map sang Custom Object
    List<Group> userQueues = [
        SELECT Name, DeveloperName  
        FROM Group 
        WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE 
        AND Id IN (
            SELECT GroupId 
            FROM GroupMember 
            WHERE UserOrGroupId IN :allAssociatedIds
        )
    ];

    Set<String> currentQueueNames = new Set<String>();
    for (Group g : userQueues) {
        currentQueueNames.add(g.DeveloperName);
    }

    if (currentQueueNames.isEmpty()) {
        return new List<Group>();
    }

    // BƯỚC 3: Tìm Team Name chung dựa trên Queue Name
    List<FEC_Team_Queue__c> matchedTeamQueues = [
        SELECT FEC_Name__c 
        FROM FEC_Team_Queue__c
        WHERE FEC_Queue_Name__c IN :currentQueueNames
    ];

    Set<String> teamNames = new Set<String>();
    for (FEC_Team_Queue__c tq : matchedTeamQueues) {
        teamNames.add(tq.FEC_Name__c);
    }

    if (teamNames.isEmpty()) {
        return new List<Group>();
    }

    // BƯỚC 4: Lấy danh sách Tên Queue (FEC_Queue_Name__c) thuộc các Team Name tìm được
    List<FEC_Team_Queue__c> allQueuesInTeam = [
        SELECT FEC_Queue_Name__c
        FROM FEC_Team_Queue__c
        WHERE FEC_Name__c IN :teamNames
    ];

    Set<String> targetQueueNames = new Set<String>();
    for (FEC_Team_Queue__c tq : allQueuesInTeam) {
        targetQueueNames.add(tq.FEC_Queue_Name__c);
    }

    if (targetQueueNames.isEmpty()) {
        return new List<Group>();
    }

    // BƯỚC 5: Query bảng Group để trả về Id và Name thật của Queue
    return [
        SELECT Id, Name, DeveloperName
        FROM Group
        WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE AND DeveloperName IN :targetQueueNames
        ORDER BY Name ASC
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

  public class CaseBusinessServiceException extends Exception {
  }

  // tungnm37 thêm: tạo FEC_Assignment__c + FEC_Case_Remarks__c + FEC_Routing_Action_History__c khi Route to COF/GSR
  private static void createAssignmentsOnRoute(
    String caseId, Set<Id> nocIds, User currentUser, Id historyId, String stageName, String remarkContentParam
  ) {
    try {
      System.debug('FEC_DEBUG createAssignmentsOnRoute caseId=' + caseId + ' nocIds=' + nocIds);
      if (nocIds == null || nocIds.isEmpty() || String.isBlank(caseId)) return;

      // tungnm37: query tất cả FEC_Routing_Assignment__c của tất cả NOC IDs
      List<FEC_Routing_Assignment__c> routingAssignments = [
        SELECT FEC_Team__c, FEC_Queue__c
        FROM FEC_Routing_Assignment__c
        WHERE FEC_Nature_of_Cases__c IN :nocIds
          AND FEC_Team__c != null AND FEC_Queue__c != null
        ORDER BY FEC_Team__c ASC
      ];

      System.debug('FEC_DEBUG createAssignmentsOnRoute routingAssignments.size=' + routingAssignments.size());
      if (routingAssignments.isEmpty()) return;

      // tungnm37: build map Queue Name → Queue Id để tránh query trong loop
      Set<String> queueNames = new Set<String>();
      for (FEC_Routing_Assignment__c ra : routingAssignments) {
        if (String.isNotBlank(ra.FEC_Queue__c)) queueNames.add(ra.FEC_Queue__c);
      }
      Map<String, Id> queueNameToId = new Map<String, Id>();
      Map<String, String> queueNameToName = new Map<String, String>();
      for (Group g : [SELECT Id, Name FROM Group WHERE Name IN :queueNames AND Type = 'Queue']) {
        queueNameToId.put(g.Name, g.Id);
        queueNameToName.put(g.Name, g.Name);
      }

      // tungnm37 sửa: dùng remarkContent từ param (truyền từ LWC), fallback query nếu null
      String remarkContent = remarkContentParam;
      String remarkUserEmail = currentUser.Email;
      if (String.isBlank(remarkContent)) {
        List<FEC_Case_Remarks__c> latestRemarks = [
          SELECT Id, FEC_Case_Remarks__c, FEC_User__c
          FROM FEC_Case_Remarks__c
          WHERE FEC_Case__c = :caseId AND Remark_Type__c != 'Assignment'
          ORDER BY CreatedDate DESC LIMIT 1
        ];
        remarkContent = latestRemarks.isEmpty() ? '' : latestRemarks[0].FEC_Case_Remarks__c;
        remarkUserEmail = latestRemarks.isEmpty() ? currentUser.Email : latestRemarks[0].FEC_User__c;
      }

      // tungnm37: lấy Case owner hiện tại để ghi vào Routing Action History
      Case currentCase = [
        SELECT Id, OwnerId, Owner.Name, Owner.Type, FEC_Final_Status__c
        FROM Case WHERE Id = :caseId LIMIT 1
      ];
      String originalOwnerLabel = resolveRoutingHistoryOwnerLabel(currentCase.OwnerId, currentCase.Owner?.Name);

       // tungnm37 sửa: lấy UserRole.Name trực tiếp, không fallback
      String userRoleName = currentUser.UserRole?.Name;

      // tungnm37: tạo Assignment cho mỗi dòng Routing Assignment
      List<FEC_Assignment__c> assignments = new List<FEC_Assignment__c>();
      for (FEC_Routing_Assignment__c ra : routingAssignments) {
        String queueId = queueNameToId.containsKey(ra.FEC_Queue__c) ? String.valueOf(queueNameToId.get(ra.FEC_Queue__c)) : null;
        assignments.add(new FEC_Assignment__c(
          FEC_Case__c = caseId,
          FEC_Assignment_Name__c = 'Call',
          FEC_Assignment_Type__c = 'Routing',
          FEC_Assignment_Status__c = 'Open',
          FEC_OwnerID__c = queueId,
          // tungnm37 thêm: set Assignment Owner = current user (người thực hiện route)
          FEC_Assignment_Owner__c = currentUser.Id,
          FEC_Team__c = ra.FEC_Team__c,
          FEC_Assignment_Remark__c = remarkContent,
          FEC_User_Role__c = userRoleName,
          FEC_Assignment_Routing_Action__c = stageName
        ));
      }
      System.debug('FEC_DEBUG createAssignmentsOnRoute inserting ' + assignments.size() + ' assignments');
      insert assignments;

      // tungnm37: tạo n remark type Assignment ứng với n Assignment (theo tài liệu)
      // Remark type Assignment được ẩn khỏi Case Remark History (filter trong getRemarklst)
      List<FEC_Case_Remarks__c> remarksToInsert = new List<FEC_Case_Remarks__c>();
      for (FEC_Assignment__c a : assignments) {
        remarksToInsert.add(new FEC_Case_Remarks__c(
          FEC_Case__c = caseId,
          Remark_Type__c = 'Assignment',
          FEC_Case_Remarks__c = remarkContent,
          FEC_User__c = remarkUserEmail,
          FEC_Assignment__c = a.Id,
          FEC_Stage_Name__c = stageName
        ));
      }
      if (!remarksToInsert.isEmpty()) insert remarksToInsert;

      // tungnm37: tạo Routing Action History per Assignment (theo tài liệu)
      List<FEC_Routing_Action_History__c> histories = new List<FEC_Routing_Action_History__c>();
      for (FEC_Assignment__c a : assignments) {
        String queueId = a.FEC_OwnerID__c;
        String queueName = null;
        for (String qn : queueNameToId.keySet()) {
          if (queueNameToId.get(qn) != null && String.valueOf(queueNameToId.get(qn)) == queueId) {
            queueName = qn;
            break;
          }
        }
        histories.add(new FEC_Routing_Action_History__c(
          FEC_Routing_Action__c = ROUTE_TO,
          FEC_Case__c = caseId,
          FEC_Assignment__c = a.Id,
          FEC_Perform_User__c = currentUser.Id,
          FEC_User__c = emailLocalPart(currentUser.Email),
          FEC_User_Role__c = userRoleName,
          FEC_Stage_Name__c = stageName,
          FEC_Original_User_Queue__c = originalOwnerLabel,
          FEC_Original_User_Queue_ID__c = currentCase.OwnerId != null ? String.valueOf(currentCase.OwnerId) : null,
          FEC_Updated_User_Queue__c = queueName,
          FEC_Updated_User_Queue_ID__c = queueId,
          FEC_Current_Status__c = currentCase.FEC_Final_Status__c
        ));
      }
      if (!histories.isEmpty()) {
        new FEC_CaseBusinessWithoutSharing().doInsert(histories);
      }

    } catch (Exception e) {
      System.debug('FEC_DEBUG createAssignmentsOnRoute error: ' + e.getMessage() + ' | ' + e.getStackTraceString());
      try {
        insert new FEC_Log__c(
          FEC_Function_Name__c = 'createAssignmentsOnRoute',
          FEC_Error_Message__c = e.getMessage(),
          FEC_Stack_Trace_String__c = e.getStackTraceString()
        );
      } catch (Exception logEx) {}
  }
  }

  // tungnm37 thêm: tạo Assignment từ manual items (Stage 2 - Add Item)
  // manualItemsJson: JSON array [{teamName, queueName, remark}]
  private static void createAssignmentsFromManualItems(
    String caseId, String manualItemsJson, User currentUser, String stageName
  ) {
    try {
      List<Object> rawItems = (List<Object>) JSON.deserializeUntyped(manualItemsJson);
      if (rawItems == null || rawItems.isEmpty()) return;

      // tungnm37: build queue name list để query IDs
      Set<String> queueNames = new Set<String>();
      for (Object raw : rawItems) {
        Map<String, Object> item = (Map<String, Object>) raw;
        String qn = (String) item.get('queueName');
        if (String.isNotBlank(qn)) queueNames.add(qn);
      }
      Map<String, Id> queueNameToId = new Map<String, Id>();
      for (Group g : [SELECT Id, Name FROM Group WHERE Name IN :queueNames AND Type = 'Queue']) {
        queueNameToId.put(g.Name, g.Id);
      }

      // tungnm37: resolve User Role
      String userRoleName = currentUser.UserRole?.Name;
      if (String.isBlank(userRoleName)) userRoleName = currentUser.FEC_User_Group__c;

      // tungnm37: lấy Case owner hiện tại
      Case currentCase = [SELECT Id, OwnerId, Owner.Name, FEC_Final_Status__c FROM Case WHERE Id = :caseId LIMIT 1];
      String originalOwnerLabel = resolveRoutingHistoryOwnerLabel(currentCase.OwnerId, currentCase.Owner?.Name);

      List<FEC_Assignment__c> assignments = new List<FEC_Assignment__c>();
      List<String> remarkList = new List<String>();
      for (Object raw : rawItems) {
        Map<String, Object> item = (Map<String, Object>) raw;
        String teamName = (String) item.get('teamName');
        String queueName = (String) item.get('queueName');
        String remark = (String) item.get('remark');
        String queueId = queueNameToId.containsKey(queueName) ? String.valueOf(queueNameToId.get(queueName)) : null;
        assignments.add(new FEC_Assignment__c(
          FEC_Case__c = caseId,
          FEC_Assignment_Name__c = 'Call',
          FEC_Assignment_Type__c = 'Routing',
          FEC_Assignment_Status__c = 'Open',
          FEC_OwnerID__c = queueId,
          FEC_Team__c = teamName,
          FEC_Assignment_Remark__c = remark,
          FEC_User_Role__c = userRoleName,
          FEC_Assignment_Routing_Action__c = stageName
        ));
        remarkList.add(remark);
      }
      insert assignments;

      // tungnm37: tạo Case Remark type Assignment per Assignment
      List<FEC_Case_Remarks__c> remarks = new List<FEC_Case_Remarks__c>();
      for (Integer i = 0; i < assignments.size(); i++) {
        remarks.add(new FEC_Case_Remarks__c(
          FEC_Case__c = caseId,
          Remark_Type__c = 'Assignment',
          FEC_Case_Remarks__c = remarkList[i],
          FEC_User__c = currentUser.Email,
          FEC_Assignment__c = assignments[i].Id,
          FEC_Stage_Name__c = stageName
        ));
      }
      if (!remarks.isEmpty()) insert remarks;

      // tungnm37: tạo Routing Action History per Assignment
      List<FEC_Routing_Action_History__c> histories = new List<FEC_Routing_Action_History__c>();
      for (Integer i = 0; i < assignments.size(); i++) {
        FEC_Assignment__c a = assignments[i];
        // tungnm37: lấy queue name từ queueId
        String queueName = null;
        for (String qn : queueNameToId.keySet()) {
          if (queueNameToId.get(qn) != null && String.valueOf(queueNameToId.get(qn)) == a.FEC_OwnerID__c) {
            queueName = qn;
            break;
          }
        }
        histories.add(new FEC_Routing_Action_History__c(
          FEC_Routing_Action__c = ROUTE_TO,
          FEC_Case__c = caseId,
          FEC_Assignment__c = a.Id,
          FEC_Perform_User__c = currentUser.Id,
          FEC_User__c = emailLocalPart(currentUser.Email),
          FEC_User_Role__c = userRoleName,
          FEC_Stage_Name__c = stageName,
          FEC_Original_User_Queue__c = originalOwnerLabel,
          FEC_Original_User_Queue_ID__c = currentCase.OwnerId != null ? String.valueOf(currentCase.OwnerId) : null,
          FEC_Updated_User_Queue__c = queueName,
          FEC_Updated_User_Queue_ID__c = a.FEC_OwnerID__c,
          FEC_Current_Status__c = currentCase.FEC_Final_Status__c
        ));
      }
      if (!histories.isEmpty()) {
        new FEC_CaseBusinessWithoutSharing().doInsert(histories);
      }
    } catch (Exception e) {
      System.debug('createAssignmentsFromManualItems error: ' + e.getMessage() + ' | ' + e.getStackTraceString());
      try {
        insert new FEC_Log__c(
          FEC_Function_Name__c = 'createAssignmentsFromManualItems',
          FEC_Error_Message__c = e.getMessage(),
          FEC_Stack_Trace_String__c = e.getStackTraceString()
        );
      } catch (Exception logEx) {}
    }
  }

  // tungnm37 thêm: resolve natureOfCaseId (FEC_Actual_Nature_of_Case__c hoặc FEC_Nature_of_Case__c)
  // → trả về Set<Id> tất cả FEC_Nature_of_Case__c IDs có Routing Assignment cùng Sub_Code
  private static Set<Id> resolveToNocIds(String inputId) {
    Set<Id> result = new Set<Id>();
    if (String.isBlank(inputId)) return result;
    try {
      Id recordId = inputId;
      String objName = recordId.getSObjectType().getDescribe().getName();
      System.debug('FEC_DEBUG resolveToNocIds inputId=' + inputId + ' objName=' + objName);

      Id bpId; Id catId; Id subCatId; Id subCodeId;

      if (objName == 'FEC_Nature_of_Case__c') {
        // tungnm37: đã là NOC → lấy Sub_Code để tìm tất cả NOC cùng bộ
        List<FEC_Nature_of_Case__c> nocs = [
          SELECT FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c
          FROM FEC_Nature_of_Case__c WHERE Id = :inputId LIMIT 1
        ];
        if (nocs.isEmpty()) { result.add(recordId); return result; }
        bpId = nocs[0].FEC_Business_Process__c;
        catId = nocs[0].FEC_Category__c;
        subCatId = nocs[0].FEC_Sub_Category__c;
        subCodeId = nocs[0].FEC_Sub_Code__c;
      } else if (objName == 'FEC_Actual_Nature_of_Case__c') {
        List<FEC_Actual_Nature_of_Case__c> actualNocs = [
          SELECT FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c
          FROM FEC_Actual_Nature_of_Case__c WHERE Id = :inputId LIMIT 1
        ];
        if (actualNocs.isEmpty()) return result;
        bpId = actualNocs[0].FEC_Business_Process__c;
        catId = actualNocs[0].FEC_Category__c;
        subCatId = actualNocs[0].FEC_Sub_Category__c;
        subCodeId = actualNocs[0].FEC_Sub_Code__c;
      } else {
        return result;
      }

      // tungnm37: lấy tất cả FEC_Nature_of_Case__c cùng bộ (BP+Cat+SubCat+SubCode)
      List<FEC_Nature_of_Case__c> matchNocs = [
        SELECT Id FROM FEC_Nature_of_Case__c
        WHERE FEC_Business_Process__c = :bpId
          AND FEC_Category__c = :catId
          AND FEC_Sub_Category__c = :subCatId
          AND FEC_Sub_Code__c = :subCodeId
      ];
      if (matchNocs.isEmpty()) return result;

      Set<Id> allNocIds = new Set<Id>();
      for (FEC_Nature_of_Case__c n : matchNocs) allNocIds.add(n.Id);

      // tungnm37: chỉ giữ lại NOC có Routing Assignment
      for (AggregateResult ar : [
        SELECT FEC_Nature_of_Cases__c nocId
        FROM FEC_Routing_Assignment__c
        WHERE FEC_Nature_of_Cases__c IN :allNocIds
          AND FEC_Team__c != null AND FEC_Queue__c != null
        GROUP BY FEC_Nature_of_Cases__c
      ]) {
        result.add((Id) ar.get('nocId'));
      }

      System.debug('FEC_DEBUG resolveToNocIds result=' + result);
      // tungnm37: nếu không có NOC nào có RA, trả về tất cả để debug
      if (result.isEmpty()) result = allNocIds;
    } catch (Exception e) {
      System.debug('FEC_DEBUG resolveToNocIds error: ' + e.getMessage());
    }
    return result;
  }

}