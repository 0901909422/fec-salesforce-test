public with sharing class FEC_CaseBusinessService {
  public static final String CASE_ID = 'Case Id';
  public static final String CUSTOMER_HISTORY = 'Customer History';

  public static final String ROUTE_TO = 'Route to';
  public static final String REVERT = 'Revert';
  public static final String CANCEL = 'Cancel';
  public static final String ESCALATE = 'Escalate';
  public static final String REJECT = 'Reject';
  public static final String RESOLVE = 'Resolve';

  public static final String PHONE_UPDATE = 'Phone Update';
  public static final String EMAIL_UPDATE = 'Email Update';
  public static final String FULLNAME_UPDATE = 'Full Name Update';
  public static final String DOB_UPDATE = 'Date of Birth Update';
  public static final String GENDER_UPDATE = 'Gender Update';
  public static final String OC_001 = 'Outbound Campaign - OU01';

  public static final String CATEGORY_UNDELIVERED_CARD = 'Undelivered Card';

  public static final String FRONT_LINE = 'CS Frontline';

  public enum Method {
    ROUTE_TO,
    CANCEL,
    REVERT,
    REJECT,
    RESOLVE,
    ESCALATE,
    PHONE_UPDATE,
    EMAIL_UPDATE,
    FULLNAME_UPDATE,
    DOB_UPDATE,
    GENDER_UPDATE,
    OC_001
  }

  public static final Map<String, Method> METHOD_MAP = new Map<String, Method>{
    ROUTE_TO => Method.ROUTE_TO,
    CANCEL => Method.CANCEL,
    REJECT => Method.REJECT,
    RESOLVE => Method.RESOLVE,
    REVERT => Method.REVERT,
    ESCALATE => Method.ESCALATE,
    REVERT => Method.REVERT,
    PHONE_UPDATE => Method.PHONE_UPDATE,
    EMAIL_UPDATE => Method.EMAIL_UPDATE,
    FULLNAME_UPDATE => Method.FULLNAME_UPDATE,
    DOB_UPDATE => Method.DOB_UPDATE,
    GENDER_UPDATE => Method.GENDER_UPDATE,
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
          FEC_Process_Action_Count__c
        FROM Case
        WHERE Id = :caseId
      ];

      if (caselst.isEmpty())
        return result;

      Case selectedCase = caselst.get(0);

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
          FEC_Next_Stage__c = :selectedCase.FEC_Current_Case_Stage__c
          AND FEC_Routing_Action__c IN :validActionlst
          AND FEC_Case__c = :selectedCase.Id
        ORDER BY CreatedDate DESC
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
          FEC_Next_Stage__c = :selectedCase.FEC_Current_Case_Stage__c
          AND FEC_Routing_Action__c = :ROUTE_TO
          AND FEC_Case__c = :selectedCase.Id
        ORDER BY CreatedDate DESC
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
        FEC_MainInfoAccountController.refreshAccountInfo(selectedCase.Id);
        // }
      }

      Map<String, Object> caseBindMap = new Map<String, Object>{
        'productType' => productTypeId,
        'category' => categoryId,
        'subCategory' => subCategoryId,
        'subCode' => subCodeId,
        'customerType' => selectedCase.FEC_Customer_Type__c,
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

      if (natureOfCaselst.isEmpty())
        return result;

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
        when else {
        }
      }

      // ================================= GET CASE STAGE ===========================
      selectedNatureOfCaseId = (String) selectedNatureOfCase.get('Id');

      String selectedCaseStageId = selectedCase.FEC_Current_Case_Stage__c;

      String caseStageQuery;

      Map<String, Object> bindVars;

      if (String.isNotBlank(selectedCaseStageId)) {
        caseStageQuery =
          'SELECT Id ' +
          'FROM FEC_Case_Stage__c ' +
          'WHERE Id = :id ' +
          'AND FEC_Active__c = TRUE ' +
          'AND FEC_User_Group__c INCLUDES (\'' +
          String.join(new List<String>(rolelst), '\',\'') +
          '\')';

        bindVars = new Map<String, Object>{ 'id' => selectedCaseStageId };
      } else {
        caseStageQuery =
          'SELECT Id ' +
          'FROM FEC_Case_Stage__c ' +
          'WHERE FEC_Business_Process__c = :businessProcessId ' +
          'AND FEC_Active__c = TRUE ' +
          'AND FEC_Default_Stage__c = TRUE ' +
          'AND FEC_User_Group__c INCLUDES (\'' +
          String.join(new List<String>(rolelst), '\',\'') +
          '\')';

        bindVars = new Map<String, Object>{
          'businessProcessId' => businessProcessId
        };
      }

      List<FEC_Case_Stage__c> stagelst = (List<FEC_Case_Stage__c>) Database.queryWithBinds(
        caseStageQuery,
        bindVars,
        AccessLevel.USER_MODE
      );

      if (stagelst.isEmpty())
        return result;

      FEC_Case_Stage__c selectedStage = stagelst.get(0);

      if (String.isBlank(selectedCaseStageId)) {
        selectedCase.FEC_Current_Case_Stage__c = selectedStage.Id;
      }

      result.stage = selectedStage.Id;

      // ============================= GET MASTET DATA SETTING ===========================
      if (err.errorlst.isEmpty()) {
        String soql =
          'SELECT Id, FEC_Field_API_Name__c, FEC_Field_Editable__c, ' +
          'FEC_Field_Mandatory__c, FEC_Field_Object_Name__c, ' +
          'FEC_Field_ReadOnly__c, FEC_Section__c, FEC_Field_Order_Display__c,' +
          'FEC_Field_Label_Name__c, FEC_Editable_User_Group__c, FEC_Field_Masking__c, ' +
          'FEC_Sub_Section__c, FEC_Sub_Section_Order__c, FEC_Sub_Section_Layout__c, FEC_Field_Reverted__c ' +
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
            Type = 'Queue'
            AND DeveloperName = :stageChangelst.get(0).FEC_Next_Queue__c
        ];

        if (!queuelst.isEmpty())
          result.nextQueue = new FEC_CommonUltils.PicklistOption(
            queuelst.get(0).Name,
            (String) queuelst.get(0).Id,
            null
          );
      }

      update selectedCase;

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
  public static Object run(String method, Map<String, String> params) {
    try {
      Method selectedMethod = METHOD_MAP.get(method);
      String caseId;

      if(params != null) {
        caseId = (String) params.get('caseId');
      }

      switch on selectedMethod {
        when ROUTE_TO {
          caseId = (String) params.get('caseId');
          String queueId = (String) params.get('queueId');
          String natureOfCaseId = (String) params.get('natureOfCaseId');
          String actionId = (String) params.get('actionId');
          route(caseId, queueId, natureOfCaseId, actionId);
          return null;
        }
        when REVERT {
          revert(caseId);
          return null;
        }
        when CANCEL {
          cancel(caseId);
          return null;
        }
        when ESCALATE {
          escalate(caseId);
          return null;
        }
        when REJECT {
          reject(caseId);
          return null;
        }
        when RESOLVE {
          resolve(caseId);
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
        when OC_001 {
          return FEC_UpdateCustomerBasicInfo.updateValue(caseId, DOB_UPDATE);
        }
        when else {
          // throw new CaseBusinessServiceException('Method not found.');
        }
      }

      Case selectedCase = new Case(Id = caseId, FEC_Is_Submited__c = true);
      update selectedCase;
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
      List<Case> caselst = [
        SELECT
          Id,
          OwnerId,
          FEC_Current_Case_Stage__c,
          FEC_Current_Case_Stage__r.FEC_Default_Stage__c,
          FEC_Actual_Nature_of_Case__c
        FROM Case
        WHERE Id = :caseId
      ];

      if (caselst.isEmpty()) {
        throw new CaseBusinessServiceException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ CASE_ID }));
      }

      Case updatedCase = caselst.get(0);

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
          FEC_Next_Stage__c = :updatedCase.FEC_Current_Case_Stage__c
          AND FEC_Routing_Action__c IN :validActionlst
          AND FEC_Case__c = :caseId
        ORDER BY CreatedDate DESC
        LIMIT 1
      ];

      if (!historylst.isEmpty()) {
        if (REVERT.equals(historylst.get(0).FEC_Routing_Action__c)) {
          queueId = historylst.get(0).FEC_Perform_User__c;
        }
      }

      List<FEC_Stage_Change__c> changelst = [
        SELECT Id, FEC_Previous_Stage__c, FEC_Next_Stage__c
        FROM FEC_Stage_Change__c
        WHERE
          FEC_Previous_Stage__c = :updatedCase.FEC_Current_Case_Stage__c
          AND FEC_Active__c = TRUE
          AND FEC_Action_Button__c = :actionId
      ];

      if (changelst.isEmpty()) {
        throw new CaseBusinessServiceException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{'Stage Change'}));
      }

      FEC_Stage_Change__c selectedChange = changelst.get(0);

      if (
        String.isBlank(updatedCase.FEC_Actual_Nature_of_Case__c) &&
        (String.isBlank(updatedCase.FEC_Current_Case_Stage__c) ||
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

      update updatedCase;

      FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
        FEC_Perform_User__c = UserInfo.getUserId(),
        FEC_Previous_Stage__c = selectedChange.FEC_Previous_Stage__c,
        FEC_Next_Stage__c = selectedChange.FEC_Next_Stage__c,
        FEC_Routing_Action__c = ROUTE_TO,
        FEC_Case__c = caseId
      );

      insert history;
    } catch (Exception e) {
      throw new CaseBusinessServiceException(e.getMessage());
    }
  }

  private static void cancel(String caseId) {
    try {
      List<Case> caselst = [
        SELECT Id, OwnerId, Status
        FROM Case
        WHERE Id = :caseId
      ];

      if (caselst.isEmpty())
        throw new CaseBusinessServiceException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ CASE_ID }));

      Case updatedCase = caselst.get(0);
      updatedCase.Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED;

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
        throw new CaseBusinessServiceException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ CASE_ID }));

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
        throw new CaseBusinessServiceException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ CASE_ID }));

      Case updatedCase = caselst.get(0);
      updatedCase.Status = FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED;

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
        throw new CaseBusinessServiceException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ CASE_ID }));
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
            Label.FEC_CaseBusinessService_Msg_001
          );
        }
      } else {
        throw new CaseBusinessServiceException(
          Label.FEC_CaseBusinessService_Msg_002
        );
      }

      update updatedCase;
    } catch (Exception e) {
      // It's better practice to include the original exception as a cause if your custom exception supports it
      throw new CaseBusinessServiceException(
        String.format(Label.FEC_CaseBusinessService_Msg_003, new List<String>{ e.getMessage() })
      );
    }
  }

  private static void revert(String caseId) {
    try {
      List<Case> caselst = [
        SELECT
          Id,
          OwnerId,
          FEC_Current_Case_Stage__c,
          FEC_Current_Case_Stage__r.FEC_Default_Stage__c
        FROM Case
        WHERE Id = :caseId
      ];

      if (caselst.isEmpty()) {
        throw new CaseBusinessServiceException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ CASE_ID }));
      }

      Case updatedCase = caselst.get(0);

      List<String> validActionlst = new List<String>{ ROUTE_TO };

      List<FEC_Routing_Action_History__c> historylst = [
        SELECT
          Id,
          FEC_Previous_Stage__c,
          FEC_Previous_Stage__r.FEC_Default_Stage__c,
          FEC_Routing_Action__c,
          FEC_Perform_User__c,
          FEC_Perform_User__r.FEC_Main_Queue__c,
          FEC_Perform_User__r.FEC_User_Division_Group__c,
          FEC_Next_Stage__c,
          CreatedDate
        FROM FEC_Routing_Action_History__c
        WHERE
          FEC_Next_Stage__c = :updatedCase.FEC_Current_Case_Stage__c
          AND FEC_Routing_Action__c IN :validActionlst
          AND FEC_Case__c = :caseId
        ORDER BY CreatedDate DESC
        LIMIT 1
      ];

      String queueId;

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
                Type = 'Queue'
                AND DeveloperName = :history.FEC_Perform_User__r.FEC_Main_Queue__c
            ];

            if (!queuelst.isEmpty()) {
              queueId = queuelst.get(0).Id;
            }
          } else {
            queueId = history.FEC_Perform_User__c;
          }

          FEC_Routing_Action_History__c newHistory = new FEC_Routing_Action_History__c(
            FEC_Perform_User__c = UserInfo.getUserId(),
            FEC_Previous_Stage__c = updatedCase.FEC_Current_Case_Stage__c,
            FEC_Next_Stage__c = history.FEC_Previous_Stage__c,
            FEC_Routing_Action__c = REVERT,
            FEC_Case__c = caseId
          );

          updatedCase.FEC_Current_Case_Stage__c = history.FEC_Previous_Stage__c;
          updatedCase.OwnerId = queueId;
          update updatedCase;

          insert newHistory;
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

    if (sourcelst.isEmpty()) {
      throw new CaseBusinessServiceException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{'Nature of Case'}));
    }

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
        FEC_Field_Reverted__c
      FROM FEC_Master_Data_Setting__c
      WHERE FEC_Nature_of_Case__c = :natureOfCaseId
      // AND FEC_Stage_Name__c = :stageNameId
    ];

    if (sourcelst.isEmpty()) {
      throw new CaseBusinessServiceException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{'Master Data Setting'}));
    }

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
      Set<String> fields = objToFieldlstMap.get(objName);

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

      soqlMap.put(objName, sObjectlst.isEmpty() ? null : sObjectlst.get(0));
    }

    return soqlMap;
  }

  private static Field transform(
    Sobject masterDataItem,
    SObject objTemp,
    String userGr,
    Boolean isStageRevert
  ) {
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

    return new Field(
      (String) masterDataItem.get('FEC_Field_API_Name__c'),
      (String) masterDataItem.get('FEC_Field_Label_Name__c'),
      value,
      (Boolean) masterDataItem.get('FEC_Field_ReadOnly__c'),
      isEditable ||
      String.isNotBlank(editableGr) && editableGr.contains(userGr),
      (Boolean) masterDataItem.get('FEC_Field_Mandatory__c'),
      (Decimal) masterDataItem.get('FEC_Field_Order_Display__c'),
      (Boolean) masterDataItem.get('FEC_Field_Masking__c'),
      null
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

    // Date
    if (dtype == Schema.DisplayType.Date) {
      return ((Date) value).format(); // user locale
    }

    // DateTime
    if (dtype == Schema.DisplayType.DateTime) {
      return ((DateTime) value).format(); // user locale
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
    public FEC_CommonUltils.PicklistOption nextQueue;

    @AuraEnabled
    public String lastUser;

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
      String helpText
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

  @AuraEnabled
  public static void recall(Id caseId) {
      Id currentUserId = UserInfo.getUserId();

          // 1. Query Case & Owner Info (Lấy thêm Owner.Type để đỡ phải check prefix ID)
          Case c = [SELECT Id, Status, OwnerId, Owner.Type
                    FROM Case 
                    WHERE Id = :caseId 
                    LIMIT 1];

          // 2. Query History gần nhất (Query vào List để tránh lỗi No Rows)
          List<FEC_Routing_Action_History__c> historyList = [
              SELECT Id, FEC_Perform_User__c, FEC_Updated_User_Queue__c, FEC_Updated_User_Queue_ID__c
              FROM FEC_Routing_Action_History__c 
              WHERE FEC_Case__c = :caseId 
              AND FEC_Routing_Action__c = 'Route to' 
              ORDER BY CreatedDate DESC 
              LIMIT 1
          ];
          System.debug('historyList: ' + historyList);
          if (historyList.isEmpty()) {
               throw new AuraHandledException(Label.FEC_CaseBusinessService_Msg_004);
          }
          
          FEC_Routing_Action_History__c lastAction = historyList[0];
          System.debug('lastAction: ' + lastAction);
          if (lastAction.FEC_Updated_User_Queue_ID__c != currentUserId) {
            throw new AuraHandledException(Label.FEC_CaseBusinessService_Msg_005);          
          }
      try {
          if (c.Owner.Type == 'Queue' && c.OwnerId == lastAction.FEC_Updated_User_Queue_ID__c) {
              c.OwnerId = currentUserId;
              update c;
          }

      } catch (Exception e) {
          // Log lỗi hệ thống
          System.debug('Error in recall: ' + e.getMessage());
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
      errorlst.add(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ CUSTOMER_HISTORY }));
    }

    FEC_Customer_History__c selectedHistory = cHistorylst.get(0);

    if (validStatuslst.contains(selectedHistory.FEC_Account_Status__c))
      errorlst.add('Account Status = ' + selectedHistory.FEC_Account_Status__c);

    if (validBlockCodelst.contains(selectedHistory.FEC_Block_Code__c))
      errorlst.add('Block Code = ' + selectedHistory.FEC_Block_Code__c);

    if (validBlockCode1lst.contains(selectedHistory.FEC_Block_Code_1__c))
      errorlst.add('Block Code 1 = ' + selectedHistory.FEC_Block_Code_1__c);

    if (validBlockCode2lst.contains(selectedHistory.FEC_Block_Code_2__c))
      errorlst.add('Block Code 2 = ' + selectedHistory.FEC_Block_Code_2__c);

    if (errorlst.isEmpty())
      return new Error();

    return new Error(Label.FEC_CaseBusinessService_Msg_006, errorlst);
  }

  private static void phoneUpdate(Case selectedCase) {
    selectedCase.FEC_Original_Info_Phone_Number__c = selectedCase.FEC_Account_or_Contract__r.FEC_Primary_Phone__c;
    selectedCase.FEC_Updated_Info_Phone_Number__c = selectedCase.FEC_Original_Info_Phone_Number__c;

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

  public class CaseBusinessServiceException extends Exception {
  }
}