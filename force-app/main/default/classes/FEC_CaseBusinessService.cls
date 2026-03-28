public with sharing class FEC_CaseBusinessService {
  public static final String ROUTE_TO = 'Route to';
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
  public static final String IDENTIFICATION_UPDATE = 'National ID Update';
  public static final String OC_001 = 'Outbound Campaign - OU01';

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
    IDENTIFICATION_UPDATE,
    OC_001
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
    IDENTIFICATION_UPDATE => Method.IDENTIFICATION_UPDATE,
    OC_001 => Method.OC_001
  };

  @AuraEnabled
  public static Business getByCase(
    String caseId,
    String productTypeId,
    String categoryId,
    String subCategoryId,
    String subCodeId
  ) {
    try {
      Business result = new Business();
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
          FEC_Account_or_Contract__r.FEC_Customer_Type__c
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
          FEC_Perform_User__r.FEC_User_Division_Group__c,
          FEC_Next_Stage__c,
          FEC_Next_Stage__r.FEC_Default_Stage__c,
          CreatedDate
        FROM FEC_Routing_Action_History__c
        WHERE
          FEC_Routing_Action__c IN :validActionlst
          AND FEC_Case__c = :selectedCase.Id
        ORDER BY CreatedDate DESC, Id DESC
        LIMIT 1
      ];

      List<Group> queuelst;
      FEC_Routing_Action_History__c selectedHistory;

      if (!historylst.isEmpty()) {
        selectedHistory = historylst.get(0);
        isRevert = REVERT.equals(selectedHistory.FEC_Routing_Action__c);
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
        update selectedCase;
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
        undeliveriedCardUpdate(selectedCase);
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
          'AND FEC_Active__c = TRUE ' +
          'AND FEC_User_Group__c INCLUDES (\'' +
          String.join(new List<String>(rolelst), '\',\'') +
          '\')';

        bindVars = new Map<String, Object>{ 'id' => selectedCaseStageId };
      } else {
        caseStageQuery =
          'SELECT Id, Name ' +
          'FROM FEC_Case_Stage__c ' +
          'WHERE FEC_Nature_of_Cases__c = :selectedNatureOfCaseId ' +
          'AND FEC_Active__c = TRUE ' +
          'AND FEC_Default_Stage__c = TRUE ' +
          'AND FEC_User_Group__c INCLUDES (\'' +
          String.join(new List<String>(rolelst), '\',\'') +
          '\')';

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
        update selectedCase;
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
          'FEC_Sub_Section__c, FEC_Sub_Section_Order__c, FEC_Sub_Section_Layout__c, FEC_Field_Reverted__c, FEC_Sub_Section_Field_Layout__c ' +
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
          'ORDER BY FEC_Section__c, FEC_Sub_Section__c, FEC_Field_Object_Name__c, FEC_Field_Order_Display__c';

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

          if (String.isNotBlank(subSectionNameTemp)) {
            subSectionTemp = sectionTemp.findSubSection(subSectionNameTemp);

            if (subSectionTemp == null) {
              subSectionTemp = new Section(
                subSectionNameTemp,
                subSectionOrderTemp,
                subSectionLayoutTemp
              );
              sectionTemp.subSectionlst.add(subSectionTemp);
            }

            cObjTemp = subSectionTemp.findObj(cObjNameTemp);

            if (cObjTemp == null) {
              cObjTemp = new CObject(cObjNameTemp);
              subSectionTemp.objlst.add(cObjTemp);
            }

            cObjTemp.masterDataSettinglst.add(item);
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
          'FEC_Action_Button__r.FEC_Code__c ' +
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

      // get actions
      for (FEC_Stage_Screen__c item : actionlst) {
        if ('Routing Action'.equals(item.FEC_Action_Button__r.FEC_Type__c)) {
          if (ROUTE_TO.equals(item.FEC_Action_Button__r.FEC_Code__c)) {
            routeToId = item.FEC_Action_Button__c;
          }
          result.routingActionlst.add(
            new Action(
              item.FEC_Action_Button__c,
              item.FEC_Action_Button__r.FEC_Code__c,
              item.FEC_Action_Button__r.Name
            )
          );
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

      // get next stage metadata
      List<FEC_Stage_Change__c> stageChangelst = [
        SELECT FEC_Next_Stage__c, FEC_Next_Queue__c, Id, FEC_Team_User_Group__c
        FROM FEC_Stage_Change__c
        WHERE
          FEC_Previous_Stage__c = :selectedStage.Id
          AND FEC_Active__c = TRUE
          AND FEC_Action_Button__c = :routeToId
      ];

      // add queue and team
      if (!stageChangelst.isEmpty()) {
        result.nextTeam = stageChangelst.get(0).FEC_Team_User_Group__c;

        queuelst = [
          SELECT Id, Name, DeveloperName, Type
          FROM Group
          WHERE
            Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            AND DeveloperName = :stageChangelst.get(0).FEC_Next_Queue__c
        ];

        if (!queuelst.isEmpty())
          result.nextQueue = new FEC_CommonUltils.PicklistOption(
            queuelst.get(0).Name,
            (String) queuelst.get(0).Id,
            null
          );
      }

      // Case đã Submit thì không trả draft → màn Execute hiển thị mới, không autofill dữ liệu cũ
      result.draftRoutingActionCode = selectedCase.FEC_Is_Submited__c == true
        ? null
        : selectedCase.FEC_Draft_Routing_Action_Code__c;

      if (Schema.sObjectType.Case.isUpdateable()) {
        try {
          update selectedCase;
        } catch (DmlException e) {
          // User có thể không có quyền sửa Case (vd: Case đã assign Queue). Vẫn trả result để hiển thị section.
        }
      }

      return result;
    } catch (CaseBusinessServiceException e) {
      throw new AuraHandledException(e.getMessage());
    } catch (AuraHandledException e) {
      throw new AuraHandledException(e.getMessage());
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static void saveCaseNOC(String caseId, String natureOfCaseId) {
    if (String.isBlank(caseId) || String.isBlank(natureOfCaseId))
      return;
    List<Case> caselst = [
      SELECT
        Id,
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
    if (String.isNotBlank(natureOfCaseId))
      saveCaseNOC(caseId, natureOfCaseId);

    Case c = new Case(Id = caseId);
    c.FEC_Updated_Info_Phone_Number__c = trimToNull(updatedPhoneNumber);
    if (routingActionCode != null)
      c.FEC_Draft_Routing_Action_Code__c = trimToNull(routingActionCode);
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

  @AuraEnabled
  public static Object run(String method, Map<String, String> params) {
    try {
      Method selectedMethod = METHOD_MAP.get(method);
      String caseId;
      String oldOwnerName;
      String stageName;
      Id oldOwnerId;
      
      if (params != null) {
        caseId = (String) params.get('caseId');
        Case c = [
          SELECT
            Id,
            OwnerId,
            Owner.Name,
            FEC_Stage_Name__c,
            FEC_Customer_Type__c,
            FEC_Account_Contract_Number_PL__c
          FROM Case
          WHERE Id = :caseId
        ];
        // if (FEC_ConstantCommon.CASE_NON_EXISTING_CUSTOMER.equals(c.FEC_Customer_Type__c) && String.isBlank(c.FEC_Account_Contract_Number_PL__c)) {
        //   throw new AuraHandledException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Account/ Contract Number' }));
        // }
        oldOwnerId = c.OwnerId;
        oldOwnerName = resolveRoutingHistoryOwnerLabel(c.OwnerId, c.Owner?.Name);
        stageName = c.FEC_Stage_Name__c;
      }

      switch on selectedMethod {
        when ROUTE_TO {
          String queueId = (String) params.get('queueId');
          String natureOfCaseId = (String) params.get('natureOfCaseId');
          String actionId = (String) params.get('actionId');
          if (String.isBlank(queueId)) {
            throw new AuraHandledException(System.Label.FEC_MSG_Can_Not_Find_Next_Stage);
          }
          markCaseSubmittedAndClearDrafts(caseId);
          route(caseId, queueId, natureOfCaseId, actionId);
          return null;
        }
        when REVERT {
          markCaseSubmittedAndClearDrafts(caseId);
          revert(caseId);
          return null;
        }
        when RECALL {
          markCaseSubmittedAndClearDrafts(caseId);
          recall(caseId);
          createRoutingActionHis('Recall', '', oldOwnerName, oldOwnerId, caseId, stageName);
          return null;
        }
        when CANCEL {
          markCaseSubmittedAndClearDrafts(caseId);
          cancel(caseId);
          createRoutingActionHis('Cancel', '', oldOwnerName, oldOwnerId, caseId, stageName);
          return null;
        }
        when REOPEN {
          markCaseSubmittedAndClearDrafts(caseId);
          reopen(caseId);
          createRoutingActionHis('Reopen', '', oldOwnerName, oldOwnerId, caseId, stageName);
          return null;
        }
        when ESCALATE {
          markCaseSubmittedAndClearDrafts(caseId);
          escalate(caseId);
          createRoutingActionHis('Escalate', '', oldOwnerName, oldOwnerId, caseId, stageName);
          return null;
        }
        when REJECT {
          markCaseSubmittedAndClearDrafts(caseId);
          reject(caseId);
          createRoutingActionHis('Reject', '', oldOwnerName, oldOwnerId, caseId, stageName);
          return null;
        }
        when RESOLVE {
          markCaseSubmittedAndClearDrafts(caseId);
          resolve(caseId);
          createRoutingActionHis('Resolve', '', oldOwnerName, oldOwnerId, caseId, stageName);
          return null;
        }
        when TRANSFER {
          markCaseSubmittedAndClearDrafts(caseId);
          String userOrQueueId = (String) params.get('userOrQueueId');
          // Đổi owner trước (transfer đã registerSkip), rồi ghi history — tránh 2 bản; Updated = owner sau transfer
          transfer(caseId, userOrQueueId);
          createRoutingActionHis('Transfer', '', oldOwnerName, oldOwnerId, caseId, stageName);
          return null;
        }
        when UPDATEACTION {
          String decision = (String) params.get('decision');
          updateCaseTeamAndOwner(caseId, decision);
          createRoutingActionHis('Update', decision, oldOwnerName, oldOwnerId, caseId, stageName);
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
        when OC_001 {
          System.debug(OC_001);
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
    String actionId
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
          FEC_Actual_Nature_of_Case__c, FEC_Team__c
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

      List<String> validActionlst = new List<String>{ REVERT };

      List<FEC_Routing_Action_History__c> historylst = [
        SELECT
          Id,
          FEC_Previous_Stage__c,
          FEC_Routing_Action__c,
          FEC_Perform_User__c,
          FEC_Next_Stage__c,
          CreatedDate
        FROM FEC_Routing_Action_History__c
        WHERE
          FEC_Routing_Action__c IN :validActionlst
          AND FEC_Case__c = :caseId
        ORDER BY CreatedDate DESC, Id DESC
        LIMIT 1
      ];

      if (!historylst.isEmpty()) {
        if (REVERT.equals(historylst.get(0).FEC_Routing_Action__c)) {
          queueId = historylst.get(0).FEC_Perform_User__c;
        }
      }

      List<FEC_Stage_Change__c> changelst = [
        SELECT
          Id,
          FEC_Previous_Stage__c,
          FEC_Previous_Stage__r.FEC_Code__c,
          FEC_Next_Stage__c
        FROM FEC_Stage_Change__c
        WHERE
          FEC_Previous_Stage__c = :updatedCase.FEC_Current_Case_Stage__c
          AND FEC_Active__c = TRUE
          AND FEC_Action_Button__c = :actionId
      ];

      if (changelst.isEmpty()) {
        throw new CaseBusinessServiceException(
          String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Stage Change for action' })
        );
      }

      FEC_Stage_Change__c selectedChange = changelst.get(0);

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
        FEC_User__c = emailLocalPart(userlst.get(0).Email),
        FEC_User_Role__c = userlst.get(0).UserRole?.Name
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
    String stageName
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
      SELECT Id, OwnerId, Owner.Name, FEC_Stage_Name__c
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
        FEC_User__c = emailLocalPart(usr.Email),
        FEC_User_Role__c = usr.UserRole?.Name
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
   * Bản ghi Route to mới nhất → Status Pending-{Team} hoặc Pending-{Team1}_{Team2}
   * (map Team qua FEC_Original_User_Queue_ID__c / FEC_Updated_User_Queue_ID__c).
   */
  public static String getPendingStatusFromLatestRouteTo(Id caseId) {
    return FEC_CasePendingStatusService.computePendingStatusForCase(caseId);
  }

  // --- Routing Action History khi Change Owner ---

  /**
   * Tạo bản ghi Routing Action History khi Change Owner (OwnerId thay đổi).
   * Gán: Routing Action = Route to, Description = Change Owner; Stage Name = FEC_Code của stage trước khi đổi.
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

    // Đã có history + đổi owner từ route() / takeOwnership — không tạo thêm bản Route to (Change Owner) từ trigger
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
        insert histories;
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
      FEC_Routing_Action__c = ROUTE_TO,
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
      FEC_Description__c = FEC_ConstantCommon.FEC_RAH_DESCRIPTION_CHANGE_OWNER
    );
  }

  private static void cancel(String caseId) {
    try {
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
      updatedCase.Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED;

      update updatedCase;
    } catch (Exception e) {
      throw new CaseBusinessServiceException(e.getMessage());
    }
  }

  private static void reopen(String caseId) {
    try {
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
      updatedCase.Status = FEC_ConstantCommon.CASE_STATUS_PENDING;

      update updatedCase;
    } catch (Exception e) {
      throw new CaseBusinessServiceException(e.getMessage());
    }
  }

  private static void reject(String caseId) {
    try {
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
      updatedCase.Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_REJECTED;

      update updatedCase;
    } catch (Exception e) {
      throw new CaseBusinessServiceException(e.getMessage());
    }
  }

  private static void resolve(String caseId) {
    try {
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
      updatedCase.Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED;

      update updatedCase;
    } catch (Exception e) {
      throw new CaseBusinessServiceException(e.getMessage());
    }
  }
  private static void transfer(String caseId, String userOrQueueId) {
    List<Case> caselst = [
      SELECT Id, OwnerId, Status
      FROM Case
      WHERE Id = :caseId
    ];

    if (caselst.isEmpty())
      throw new CaseBusinessServiceException(
        String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Case Id' })
      );

    if (userOrQueueId == null) {
      throw new CaseBusinessServiceException(
        String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'User/Queue Id' })
      );
    }
    try {
      Case updatedCase = caselst.get(0);
      updatedCase.OwnerId = userOrQueueId;
      registerSkipOwnerChangeRoutingHistory(updatedCase.Id);
      update updatedCase;
    } catch (Exception e) {
      throw new CaseBusinessServiceException(e.getMessage());
    }
  }

  private static void escalate(String caseId) {
    try {
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

  private static void revert(String caseId) {
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

      if (caselst.isEmpty())
        throw new CaseBusinessServiceException(
          String.format(System.Label.FEC_MSG_Invalid, new List<String>{ 'Case Id' })
        );

      Case updatedCase = caselst.get(0);

      String currentOwnerName = resolveRoutingHistoryOwnerLabel(
        updatedCase.OwnerId,
        updatedCase.Owner?.Name
      );
      List<String> validActionlst = new List<String>{ ROUTE_TO };

      List<FEC_Routing_Action_History__c> historylst = [
        SELECT
          Id,
          FEC_Previous_Stage__c,
          FEC_Previous_Stage__r.FEC_Default_Stage__c,
          FEC_Routing_Action__c,
          FEC_Perform_User__c,
          FEC_Perform_User__r.Name,
          FEC_Perform_User__r.Email,
          FEC_Perform_User__r.FEC_Main_Queue__c,
          FEC_Perform_User__r.FEC_User_Division_Group__c,
          FEC_Next_Stage__c,
          CreatedDate
        FROM FEC_Routing_Action_History__c
        WHERE
          FEC_Routing_Action__c IN :validActionlst
          AND FEC_Case__c = :caseId
        ORDER BY CreatedDate DESC, Id DESC
        LIMIT 1
      ];

      String queueId;
      String nextUser;

      if (!historylst.isEmpty()) {
        FEC_Routing_Action_History__c history = historylst.get(0);

        if (ROUTE_TO.equals(history.FEC_Routing_Action__c)) {
          if (
            history.FEC_Previous_Stage__r?.FEC_Default_Stage__c &&
            FRONT_LINE.equals(
              history.FEC_Perform_User__r.FEC_User_Division_Group__c
            )
          ) {
            List<Group> queuelst = [
              SELECT Id, Name, DeveloperName, Type
              FROM Group
              WHERE
                Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
                AND DeveloperName = :history.FEC_Perform_User__r.FEC_Main_Queue__c
            ];

            if (!queuelst.isEmpty()) {
              queueId = queuelst.get(0).Id;
              nextUser = queuelst.get(0).Name;
            }
          } else {
            queueId = history.FEC_Perform_User__c;
            nextUser = userDisplayForRoutingHistory(
              history.FEC_Perform_User__r,
              history.FEC_Perform_User__r?.Name
            );
          }

          List<User> userlst = [
            SELECT Email, UserRole.Name, Id
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
          ];

          if (userlst.isEmpty())
            return;

          FEC_Routing_Action_History__c newHistory = new FEC_Routing_Action_History__c(
            FEC_Previous_Stage__c = updatedCase.FEC_Current_Case_Stage__c,
            FEC_Next_Stage__c = history.FEC_Previous_Stage__c,
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
            FEC_Stage_Name__c = updatedCase.FEC_Current_Case_Stage__r
              ?.FEC_Code__c,
            FEC_User__c = emailLocalPart(userlst.get(0).Email),
            FEC_User_Role__c = userlst.get(0).UserRole?.Name
          );

          updatedCase.FEC_Current_Case_Stage__c = history.FEC_Previous_Stage__c;
          updatedCase.OwnerId = queueId;
          registerSkipOwnerChangeRoutingHistory(updatedCase.Id);
          insert newHistory; 
          update updatedCase;
        }
      }
    } catch (Exception e) {
      throw new CaseBusinessServiceException(e.getMessage());
    }
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
        FEC_Sub_Section_Field_Layout__c
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
    public String stage;

    @AuraEnabled
    public String stageName;

    @AuraEnabled
    public FEC_CommonUltils.PicklistOption nextQueue;

    @AuraEnabled
    public String lastUser;

    @AuraEnabled
    public String draftRoutingActionCode;

    @AuraEnabled
    public String code;

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

    // Default constructor
    public Section() {
      this.objlst = new List<CObject>();
      this.subSectionlst = new List<Section>();
      this.error = new Error();
    }

    public Section(String name) {
      this.name = name;
      this.objlst = new List<CObject>();
      this.subSectionlst = new List<Section>();
      this.error = new Error();
    }

    public Section(String name, Decimal order, Decimal layout) {
      this.name = name;
      this.objlst = new List<CObject>();
      this.order = order;
      this.layout = layout;
      this.subSectionlst = new List<Section>();
      this.error = new Error();
    }

    // Parameterized constructor
    public Section(String name, List<CObject> objlst) {
      this.name = name;
      this.objlst = objlst != null ? objlst : new List<CObject>();
      this.error = new Error();
    }

    public Section(String name, Error err) {
      this.name = name;
      this.error = err;
      this.subSectionlst = new List<Section>();
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

      // 3. Keep if still has valid subsections
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

    public Action() {
    }

    // Parameterized constructor
    public Action(String value, String label) {
      this.value = value;
      this.label = label;
    }

    public Action(String id, String value, String label) {
      this.id = id;
      this.value = value;
      this.label = label;
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
      WHERE FEC_Case__c = :caseId AND FEC_Routing_Action__c = :ROUTE_TO
      ORDER BY CreatedDate DESC
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

    // 1. Tạo Map ánh xạ từ Decision (Input) sang FEC_Team__c (Output)
    Map<String, String> decisionToTeamMap = new Map<String, String>{
      // Nhóm thường (Pending-) -> Bỏ prefix
      'Pending CS' => 'CSInternal',
      'Pending Customer' => 'Customer',
      'Pending Card Ops' => 'CardOpsOutOfSystem',
      'Pending Collections' => 'CollectionsOutOfSystem',
      'Pending Contract Processing' => 'CPOutOfSystem',
      'Pending Credit Assessment' => 'CAOutOfSystem',
      'Pending Direct Sales' => 'DirectSalesOutOfSystem',
      'Pending Telesales' => 'TelesalesOutOfSystem',
      'Pending IT' => 'ITOutOfSystem',
      'Pending Payment' => 'PaymentOutOfSystem',
      'Pending Product' => 'PBDOutOfSystem',
      'Pending RCP&A' => 'RCPAOutOfSystem',
      'Pending Security' => 'SecurityOutOfSystem',
      'Pending Vendor' => 'VendorOutOfSystem',
      // Nhóm đặc biệt (cần map Team và đổi Owner sang Queue)
      'Out Of Process' => 'OutOfProcess',
      'CIC Related' => 'CICRelated',
      'Document Preparation' => 'DocumentPreparation',
      'Task Under Review' => 'TaskUnderReview'
    };

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
      FEC_Team__c = teamValue,
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

  private static Error phoneUpdateValidate(Id cHistoryId) {
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

  private static void phoneUpdate(Case selectedCase) {
    selectedCase.FEC_Original_Info_Phone_Number__c = selectedCase.FEC_Account_or_Contract__r.FEC_Primary_Phone__c;
    // Chỉ gán Updated = Original khi chưa có giá trị (giữ bản nháp sau Save & Close khi bấm Execute lại).
    if (String.isBlank(selectedCase.FEC_Updated_Info_Phone_Number__c)) {
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
    if (String.isBlank(selectedCase.FEC_Updated_Info_First_Name__c)) {
      selectedCase.FEC_Updated_Info_First_Name__c = selectedCase.FEC_Original_Info_First_Name__c;
    }
    if (String.isBlank(selectedCase.FEC_Updated_Info_Middle_Name__c)) {
      selectedCase.FEC_Updated_Info_Middle_Name__c = selectedCase.FEC_Original_Info_Middle_Name__c;
    }
    if (String.isBlank(selectedCase.FEC_Updated_Info_Last_Name__c)) {
      selectedCase.FEC_Updated_Info_Last_Name__c = selectedCase.FEC_Original_Info_Last_Name__c;
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
    if (String.isBlank(selectedCase.FEC_Updated_Info_Email__c)) {
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
    if (selectedCase.FEC_Updated_Info_Date_of_Birth__c == null) {
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
    if (String.isBlank(selectedCase.FEC_Updated_Info_Gender__c)) {
      selectedCase.FEC_Updated_Info_Gender__c = selectedCase.FEC_Original_Info_Gender__c;
    }
    update selectedCase;
  }

  /**
   * Lấy FEC_National_ID_Passport_ID__c, FEC_Date_of_Issue__c, FEC_Place_of_Issue__c
   * từ Customer History (FEC_Account_or_Contract__c) và cập nhật vào các trường
   * FEC_Original_Info_National_ID__c, FEC_Original_Info_Date_of_Issue__c, FEC_Original_Info_Place_of_Issue__c trên Case.
   * Chỉ gán Updated = Original khi chưa có giá trị (giữ bản nháp sau Save & Close khi bấm Execute lại).
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
    if (String.isBlank(selectedCase.FEC_Updated_Info_National_ID__c)) {
      selectedCase.FEC_Updated_Info_National_ID__c = selectedCase.FEC_Original_Info_National_ID__c;
    }
    if (selectedCase.FEC_Updated_Info_Date_of_Issue__c == null) {
      selectedCase.FEC_Updated_Info_Date_of_Issue__c = selectedCase.FEC_Original_Info_Date_of_Issue__c;
    }
    if (String.isBlank(selectedCase.FEC_Updated_Info_Place_of_Issue__c)) {
      selectedCase.FEC_Updated_Info_Place_of_Issue__c = selectedCase.FEC_Original_Info_Place_of_Issue__c;
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

  @AuraEnabled(cacheable=true)
  public static List<User> getTransferUsers() {
    // 1. Lấy thông tin Group của User hiện tại
    User currentUser = [
      SELECT FEC_User_Group__c
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];

    if (String.isBlank(currentUser.FEC_User_Group__c)) {
      return new List<User>();
    }

    // 2. Trả về danh sách User cùng Group (loại trừ chính mình)
    return [
      SELECT Id, Name
      FROM User
      WHERE
        IsActive = TRUE
        AND FEC_User_Group__c = :currentUser.FEC_User_Group__c
        AND Id != :UserInfo.getUserId()
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
}