public without sharing class FEC_CaseEditNOCController {
  @AuraEnabled
  public static List<String> getProductTypeIds(String recordId) {
    try {
      List<String> productTypeIds = new List<String>();
      Case objCase = [
        SELECT Id, FEC_Customer_Type__c
        FROM Case
        WHERE Id = :recordId
      ];
      User currentUser = [
        SELECT Id, FEC_User_Group__c
        FROM User
        WHERE Id = :UserInfo.getUserId()
      ];
      List<AggregateResult> natureOfCases = [
        SELECT FEC_Product_Type__c
        FROM FEC_Nature_of_Case__c
        WHERE
          FEC_User_Group__c INCLUDES (:currentUser.FEC_User_Group__c)
          AND FEC_Customer_Type__c != NULL
          AND FEC_Customer_Type__c = :objCase.FEC_Customer_Type__c
          AND FEC_Product_Type__c != NULL
        GROUP BY FEC_Product_Type__c
      ];
      for (AggregateResult ar : natureOfCases) {
        productTypeIds.add(String.valueOf(ar.get('FEC_Product_Type__c')));
      }
      return productTypeIds;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static List<String> getCategoryIds(
    String recordId,
    String productTypeId
  ) {
    try {
      List<String> categoryIds = new List<String>();
      Case objCase = [
        SELECT Id, FEC_Customer_Type__c
        FROM Case
        WHERE Id = :recordId
      ];
      User currentUser = [
        SELECT Id, FEC_User_Group__c
        FROM User
        WHERE Id = :UserInfo.getUserId()
      ];
      List<AggregateResult> natureOfCases = [
        SELECT FEC_Category__c
        FROM FEC_Nature_of_Case__c
        WHERE
          FEC_User_Group__c INCLUDES (:currentUser.FEC_User_Group__c)
          AND FEC_Customer_Type__c != NULL
          AND FEC_Customer_Type__c = :objCase.FEC_Customer_Type__c
          AND FEC_Product_Type__c = :productTypeId
          AND FEC_Category__c != NULL
        GROUP BY FEC_Category__c
      ];
      for (AggregateResult ar : natureOfCases) {
        categoryIds.add(String.valueOf(ar.get('FEC_Category__c')));
      }
      return categoryIds;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static List<String> getSubCategoryIds(
    String recordId,
    String productTypeId,
    String categoryId
  ) {
    try {
      List<String> subCategoryIds = new List<String>();
      Case objCase = [
        SELECT Id, FEC_Customer_Type__c
        FROM Case
        WHERE Id = :recordId
      ];
      User currentUser = [
        SELECT Id, FEC_User_Group__c
        FROM User
        WHERE Id = :UserInfo.getUserId()
      ];
      List<AggregateResult> natureOfCases = [
        SELECT FEC_Sub_Category__c
        FROM FEC_Nature_of_Case__c
        WHERE
          FEC_User_Group__c INCLUDES (:currentUser.FEC_User_Group__c)
          AND FEC_Customer_Type__c != NULL
          AND FEC_Customer_Type__c = :objCase.FEC_Customer_Type__c
          AND FEC_Product_Type__c = :productTypeId
          AND FEC_Category__c = :categoryId
          AND FEC_Sub_Category__c != NULL
        GROUP BY FEC_Sub_Category__c
      ];
      for (AggregateResult ar : natureOfCases) {
        subCategoryIds.add(String.valueOf(ar.get('FEC_Sub_Category__c')));
      }
      return subCategoryIds;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static List<String> getSubCodeIds(
    String recordId,
    String productTypeId,
    String categoryId,
    String subCategoryId
  ) {
    try {
      List<String> subCodeIds = new List<String>();
      Case objCase = [
        SELECT Id, FEC_Customer_Type__c
        FROM Case
        WHERE Id = :recordId
      ];
      User currentUser = [
        SELECT Id, FEC_User_Group__c
        FROM User
        WHERE Id = :UserInfo.getUserId()
      ];
      for (FEC_Nature_of_Case__c noc : [
        SELECT FEC_Sub_Code__c
        FROM FEC_Nature_of_Case__c
        WHERE
          FEC_User_Group__c INCLUDES (:currentUser.FEC_User_Group__c)
          AND FEC_Customer_Type__c != NULL
          AND FEC_Customer_Type__c = :objCase.FEC_Customer_Type__c
          AND FEC_Product_Type__c = :productTypeId
          AND FEC_Category__c = :categoryId
          AND FEC_Sub_Category__c = :subCategoryId
          AND FEC_Sub_Code__c != NULL
      ]) {
        subCodeIds.add(noc.FEC_Sub_Code__c);
      }
      return subCodeIds;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static FEC_Nature_of_Case__c getNatureOfCase(
    String productTypeId,
    String categoryId,
    String subCategoryId,
    String subCodeId
  ) {
    try {
      List<FEC_Nature_of_Case__c> natureOfCases = [
        SELECT Id, FEC_Business_Process__c
        FROM FEC_Nature_of_Case__c
        WHERE
          FEC_Product_Type__c = :productTypeId
          AND FEC_Category__c = :categoryId
          AND FEC_Sub_Category__c = :subCategoryId
          AND FEC_Sub_Code__c = :subCodeId
        LIMIT 1
      ];
      if (!natureOfCases.isEmpty()) {
        return natureOfCases.get(0);
      }
      return null;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * PhongBT 07/05/26: fix case nếu đang chọn bộ noc đủ subcode mà chuyển sang muốn submit bộ không có subcode thì lại
   * lưu bộ có subcode chứ không phải bộ không subcode định submit
   * Bộ NOC chỉ tới Sub-Category: không có Sub-Code trong master (getSubCodelst rỗng).
   * Dùng bản ghi FEC_Nature_of_Case__c có FEC_Sub_Code__c = null cho cùng bộ 3 Id.
   */
  @AuraEnabled
  public static FEC_Nature_of_Case__c getNatureOfCaseWithoutSubCode(
    String productTypeId,
    String categoryId,
    String subCategoryId
  ) {
    try {
      if (
        String.isBlank(productTypeId) ||
        String.isBlank(categoryId) ||
        String.isBlank(subCategoryId)
      ) {
        return null;
      }
      List<FEC_Nature_of_Case__c> natureOfCases = [
        SELECT Id, FEC_Business_Process__c
        FROM FEC_Nature_of_Case__c
        WHERE
          FEC_Product_Type__c = :productTypeId
          AND FEC_Category__c = :categoryId
          AND FEC_Sub_Category__c = :subCategoryId
          AND FEC_Sub_Code__c = NULL
        LIMIT 1
      ];
      if (!natureOfCases.isEmpty()) {
        return natureOfCases.get(0);
      }
      return null;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static Case getCase(String recordId) {
    try {
      return [
        SELECT
          Id,
          CaseNumber,
          FEC_Account_or_Contract__c,
          FEC_Account_Contract_Number_PL__c,
          FEC_Product_Type__c,
          FEC_Product_Type__r.Name,
          FEC_Category__c,
          FEC_Category__r.Name,
          FEC_SubCategory__c,
          FEC_SubCategory__r.Name,
          FEC_SubCode__c,
          FEC_SubCode__r.Name,
          FEC_Is_Submited__c,
          FEC_Interaction_View_Mode__c,
          RecordType.DeveloperName,
          FEC_Is_Call_API_Success__c,
          //PhongBT: update bộ noc chọn ở updated khi revert về
          FEC_Current_Case_Stage__r.Name,
          FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c
        FROM Case
        WHERE Id = :recordId
      ];
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  //   new methods for comboboxes
  @AuraEnabled
  public static List<FEC_CommonUltils.PicklistOption> getProductTypelst(
    String recordId
  ) {
    try {
      List<FEC_CommonUltils.PicklistOption> productTypelst = new List<FEC_CommonUltils.PicklistOption>();
      Case objCase = [
        SELECT Id, FEC_Customer_Type__c
        FROM Case
        WHERE Id = :recordId
      ];
      User currentUser = [
        SELECT Id, FEC_User_Group__c
        FROM User
        WHERE Id = :UserInfo.getUserId()
      ];

      List<String> customerTypelst = new List<String>{
        'All',
        objCase.FEC_Customer_Type__c
      };

      List<AggregateResult> natureOfCases = [
        SELECT FEC_Product_Type__c, FEC_Product_Type__r.Name name
        FROM FEC_Nature_of_Case__c
        WHERE
          FEC_User_Group__c INCLUDES (:currentUser.FEC_User_Group__c)
          AND FEC_Customer_Type__c != NULL
          AND FEC_Customer_Type__c IN :customerTypelst
          AND FEC_Product_Type__c != NULL
        GROUP BY FEC_Product_Type__c, FEC_Product_Type__r.Name
      ];
      for (AggregateResult ar : natureOfCases) {
        productTypelst.add(
          new FEC_CommonUltils.PicklistOption(
            String.valueOf(ar.get('name')),
            String.valueOf(ar.get('FEC_Product_Type__c')),
            null
          )
        );
      }
      return productTypelst;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static List<FEC_CommonUltils.PicklistOption> getCategorylst(
    String recordId,
    String productTypeId
  ) {
    try {
      List<FEC_CommonUltils.PicklistOption> categorylst = new List<FEC_CommonUltils.PicklistOption>();
      Case objCase = [
        SELECT Id, FEC_Customer_Type__c
        FROM Case
        WHERE Id = :recordId
      ];
      User currentUser = [
        SELECT Id, FEC_User_Group__c
        FROM User
        WHERE Id = :UserInfo.getUserId()
      ];

      List<String> customerTypelst = new List<String>{
        'All',
        objCase.FEC_Customer_Type__c
      };

      List<AggregateResult> natureOfCases = [
        SELECT FEC_Category__c, FEC_Category__r.Name name
        FROM FEC_Nature_of_Case__c
        WHERE
          FEC_User_Group__c INCLUDES (:currentUser.FEC_User_Group__c)
          AND FEC_Customer_Type__c != NULL
          AND FEC_Customer_Type__c IN :customerTypelst
          AND FEC_Product_Type__c = :productTypeId
          AND FEC_Category__c != NULL
        GROUP BY FEC_Category__c, FEC_Category__r.Name
      ];

      for (AggregateResult ar : natureOfCases) {
        categorylst.add(
          new FEC_CommonUltils.PicklistOption(
            String.valueOf(ar.get('name')),
            String.valueOf(ar.get('FEC_Category__c')),
            null
          )
        );
      }
      return categorylst;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static List<FEC_CommonUltils.PicklistOption> getSubCategorylst(
    String recordId,
    String productTypeId,
    String categoryId
  ) {
    try {
      List<FEC_CommonUltils.PicklistOption> subCategorylst = new List<FEC_CommonUltils.PicklistOption>();
      Case objCase = [
        SELECT Id, FEC_Customer_Type__c
        FROM Case
        WHERE Id = :recordId
      ];
      User currentUser = [
        SELECT Id, FEC_User_Group__c
        FROM User
        WHERE Id = :UserInfo.getUserId()
      ];

      List<String> customerTypelst = new List<String>{
        'All',
        objCase.FEC_Customer_Type__c
      };

      List<AggregateResult> natureOfCases = [
        SELECT FEC_Sub_Category__c, FEC_Sub_Category__r.Name name
        FROM FEC_Nature_of_Case__c
        WHERE
          FEC_User_Group__c INCLUDES (:currentUser.FEC_User_Group__c)
          AND FEC_Customer_Type__c != NULL
          AND FEC_Customer_Type__c IN :customerTypelst
          AND FEC_Product_Type__c = :productTypeId
          AND FEC_Category__c = :categoryId
          AND FEC_Sub_Category__c != NULL
        GROUP BY FEC_Sub_Category__c, FEC_Sub_Category__r.Name
      ];
      for (AggregateResult ar : natureOfCases) {
        subCategorylst.add(
          new FEC_CommonUltils.PicklistOption(
            String.valueOf(ar.get('name')),
            String.valueOf(ar.get('FEC_Sub_Category__c')),
            null
          )
        );
      }
      return subCategorylst;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  // [NOC-HANDLING-STAGE-UPDATE] Task 1.1: Kiểm tra Case có Auto-Routing Assignment không
  // Query FEC_Assignment__c với FEC_Case__c = caseId AND FEC_Assignment_Type__c = 'Routing'
  // Nếu có ít nhất 1 record → return true → ẩn Updated Information section
  @AuraEnabled
  public static Boolean hasAutoRoutingAssignment(String caseId) {
    try {
      List<FEC_Assignment__c> assignments = [
        SELECT Id
        FROM FEC_Assignment__c
        WHERE FEC_Case__c = :caseId
          AND FEC_Assignment_Type__c = 'Routing'
        LIMIT 1
      ];
      return !assignments.isEmpty();
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  //PhongBT: query FEC_Case_Flow_History__c sau khi đổi bộ noc khác để lấy lại giá trị đã nhập lên
  @AuraEnabled
  public static String getPropertyFieldsFromFlowHistory(String caseId) {
    try {
      // FEC_Field_List__c là Long Text Area — không filter được trong WHERE, lấy nhiều rồi tìm record có giá trị
      List<FEC_Case_Flow_History__c> historyList = [
        SELECT Id, FEC_Field_List__c
        FROM FEC_Case_Flow_History__c
        WHERE FEC_Case__c = :caseId
        ORDER BY CreatedDate DESC
        LIMIT 10
      ];
      for (FEC_Case_Flow_History__c h : historyList) {
        if (String.isNotBlank(h.FEC_Field_List__c)) {
          return h.FEC_Field_List__c;
        }
      }
      return null;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * PhongBT: Original Information của NOC lấy từ FEC_Case_Flow_History__c
   */
  @AuraEnabled
  public static Map<String, String> getOriginalNOCFromFlowHistory(String caseId) {
    try {
      List<FEC_Case_Flow_History__c> historyList = [
        SELECT
          Id,
          FEC_Nature_of_Cases__c,
          FEC_Nature_of_Cases__r.FEC_Business_Process__r.FEC_Code__c,
          FEC_Nature_of_Cases__r.FEC_Product_Type__r.Name,
          FEC_Nature_of_Cases__r.FEC_Category__r.Name,
          FEC_Nature_of_Cases__r.FEC_Sub_Category__r.Name,
          FEC_Nature_of_Cases__r.FEC_Sub_Code__r.Name
        FROM FEC_Case_Flow_History__c
        WHERE FEC_Case__c = :caseId
        ORDER BY CreatedDate ASC
        LIMIT 1
      ];
      if (historyList.isEmpty()) {
        return null;
      }
      FEC_Case_Flow_History__c history = historyList[0];
      Map<String, String> result = new Map<String, String>();
      if (history.FEC_Nature_of_Cases__c != null) {
          result.put('businessProcessCode', history.FEC_Nature_of_Cases__r?.FEC_Business_Process__r?.FEC_Code__c);
        result.put('productType', history.FEC_Nature_of_Cases__r?.FEC_Product_Type__r?.Name);
        result.put('category',    history.FEC_Nature_of_Cases__r?.FEC_Category__r?.Name);
        result.put('subCategory', history.FEC_Nature_of_Cases__r?.FEC_Sub_Category__r?.Name);
        result.put('subCode',     history.FEC_Nature_of_Cases__r?.FEC_Sub_Code__r?.Name);
      }
      return result;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static List<FEC_CommonUltils.PicklistOption> getSubCodelst(
    String recordId,
    String productTypeId,
    String categoryId,
    String subCategoryId
  ) {
    try {
      List<FEC_CommonUltils.PicklistOption> subCodelst = new List<FEC_CommonUltils.PicklistOption>();
      Case objCase = [
        SELECT Id, FEC_Customer_Type__c
        FROM Case
        WHERE Id = :recordId
      ];
      User currentUser = [
        SELECT Id, FEC_User_Group__c
        FROM User
        WHERE Id = :UserInfo.getUserId()
      ];

      List<String> customerTypelst = new List<String>{
        'All',
        objCase.FEC_Customer_Type__c
      };

      for (FEC_Nature_of_Case__c noc : [
        SELECT FEC_Sub_Code__c, FEC_Sub_Code__r.Name
        FROM FEC_Nature_of_Case__c
        WHERE
          FEC_User_Group__c INCLUDES (:currentUser.FEC_User_Group__c)
          AND FEC_Customer_Type__c != NULL
          AND FEC_Customer_Type__c IN :customerTypelst
          AND FEC_Product_Type__c = :productTypeId
          AND FEC_Category__c = :categoryId
          AND FEC_Sub_Category__c = :subCategoryId
          AND FEC_Sub_Code__c != NULL
      ]) {
        subCodelst.add(
          new FEC_CommonUltils.PicklistOption(
            String.valueOf(noc.FEC_Sub_Code__r.Name),
            String.valueOf(noc.FEC_Sub_Code__c),
            null
          )
        );
      }
      return subCodelst;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }
  
  /**
   * Xóa bộ NOC trên Case khi reload màn (chỉ Case chưa submit).
   * Mọi user mở trang đều clear — không giới hạn Owner (tránh non-owner vẫn thấy NOC draft).
   * Toannd61
   */
  @AuraEnabled
  public static void clearCaseNOC(String recordId) {
    if (String.isBlank(recordId)) {
      return;
    }

    List<Case> caselst = [
      SELECT Id, FEC_Is_Submited__c, FEC_Is_Call_API_Success__c
      FROM Case
      WHERE Id = :recordId
      LIMIT 1
    ];
    if (caselst.isEmpty()) {
      return;
    }

    Case c = caselst[0];
    if (c.FEC_Is_Submited__c == true || c.FEC_Is_Call_API_Success__c == true) {
      return;
    }

    try {
      update new Case(
        Id = recordId,
        FEC_Category__c = null,
        FEC_SubCategory__c = null,
        FEC_SubCode__c = null,
        FEC_Actual_Nature_of_Case__c = null
      );
    } catch (Exception e) {
      throw new AuraHandledException('Clear NOC failed: ' + e.getMessage());
    }
  }

  //HieuTT74-[UPDATE - 5/5/2026]: Lưu NOC sau khi call api Reset Pin,....
  @AuraEnabled
  public static void saveNOC(
    String recordId,
    String productTypeId,
    String categoryId,
    String subCategoryId,
    String subCodeId
  ){
    Case cs = new Case(
      Id = recordId,
      FEC_Product_Type__c = productTypeId,
      FEC_Category__c = categoryId,
      FEC_SubCategory__c = subCategoryId,
      FEC_SubCode__c = subCodeId,
      FEC_Is_Call_API_Success__c = true
    );
    
    try {
      update cs;
    } catch (Exception e) {
      throw new AuraHandledException('Update failed: ' + e.getMessage());
    }
  }

}