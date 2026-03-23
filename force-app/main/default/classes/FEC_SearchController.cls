public with sharing class FEC_SearchController {
    /**
     * Returns minimal Case context for fec_Search initialization.
     * Selects only fields needed by the component.
     */
    @AuraEnabled(cacheable=true)
    public static Case getCase(Id caseId) {
        if (caseId == null) {
            return null;
        }

        // Query with field-level security and sharing respected
        Case c;
        try {
            c = [
                SELECT Id, FEC_Channel__c, FEC_National_ID_Passport_ID__c,
                 FEC_Phone_Number__c, FEC_Contract_Number__c, RecordType.Name,
                 FEC_Skip_Search_Internal_Case__c, FEC_Has_Account_or_Contract__c,
                 FEC_Search_Account_Number__c, FEC_Search_Application_ID__c,
                 FEC_Search_Contract_Number__c, FEC_Search_Customer_Number__c,
                 FEC_Search_Email_Address__c, FEC_Search_National_ID__c,
                 FEC_Search_Phone_Number__c,
                 (SELECT Id FROM Customer_Histories__r)
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
        } catch (Exception e) {
            // If user lacks field/object access, return null (component remains usable)
            return null;
        }
        return c;
    }

    @AuraEnabled
    public static Id createHistory(String value, String fieldName, Id caseId, String searchProducts, String selectedType, String cifNumber, String phone, String customerName) {
    // 1. Validation
    if (String.isBlank(value) || String.isBlank(fieldName)) {
        throw new AuraHandledException(System.Label.FEC_MSG_Create_Customer_History_Field_Null);
    }

    try {
        // 2. Xử lý Product Type
        Id productTypeId = null;
        if (String.isNotBlank(selectedType)) {
            List<FEC_Product_Type__c> types = [SELECT Id FROM FEC_Product_Type__c WHERE Name = :selectedType LIMIT 1];
            if (!types.isEmpty()) { productTypeId = types[0].Id; }
        }

        // 3. Khởi tạo và xử lý Case TRƯỚC (để lấy ID cho trường bắt buộc của History)
        Case objCase = new Case();
        if (caseId != null) {
            objCase.Id = caseId;
        } else {
            Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
            Schema.RecordTypeInfo rtInfo = rtMap.get(FEC_ConstantCommon.CASE_SEARCH_RECORD_TYPE_DEV_NAME);

            if (rtInfo == null) {
                rtInfo = rtMap.get(FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME);
            }

            if (rtInfo == null) {
                throw new CalloutException( 
                    String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'RecordType'}));
            }

            objCase.RecordTypeId = rtInfo.getRecordTypeId();
            objCase.FEC_ID_Search__c = value != null ? value.trim() : null;
        }

        // Gán các field cơ bản cho Case
        objCase.FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE;
        objCase.FEC_CIF_Number__c = cifNumber;
        objCase.FEC_First_Access__c = true;
        objCase.FEC_Search_Products__c = searchProducts;
        objCase.FEC_Product_Type__c = productTypeId;
        objCase.FEC_Customer_Name__c = customerName;
        if (fieldName == 'AccountNumber') {
            objCase.FEC_Account_Number__c = value;
        }
        if (fieldName == 'ContractNumber') {
            objCase.FEC_Contract_Number__c = value;
        }
        objCase.FEC_ID_Search__c = value;

       if (caseId != null) {
            update objCase;
        } else {
            upsert objCase FEC_ID_Search__c;
        }

        // 4. Khởi tạo và Insert History (Trường FEC_Case__c bây giờ chắc chắn có giá trị)
        FEC_Customer_History__c rec = new FEC_Customer_History__c();
        rec.FEC_Account_Number__c = value;
        rec.Name = value;
        rec.FEC_CIF_Number__c = cifNumber;
        rec.FEC_Work_Phone__c = phone;
        rec.FEC_Case__c = objCase.Id; // Gán ID vừa tạo/update vào trường bắt buộc

        insert rec;

        // 5. Cập nhật lại Case để liên kết ngược với History record vừa tạo
        objCase.FEC_Account_or_Contract__c = rec.Id;
        update objCase;

        return objCase.Id;

    } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
    }
}

    @AuraEnabled
    public static List<FEC_B2_Contract__c> getB2Contracts(String contractNumber) {
        try {
            return [
                SELECT Name, FEC_ID_Card__c, FEC_Code__c, FEC_Full_Name__c, FEC_Product_Code__c, FEC_Installment__c, FEC_Principal__c, FEC_Monthly_Fee__c, FEC_Term__c, FEC_City__c
                FROM FEC_B2_Contract__c WHERE Name =: contractNumber
                ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<FEC_Cash_24_Contract__c> getCash24Contracts(String contractNumber) {
        try {
            return [
                SELECT Name, FEC_Sold_Date__c, FEC_Balance_Amount__c, FEC_Note__c, FEC_Contract_Status__c, FEC_Product__c
                FROM FEC_Cash_24_Contract__c WHERE Name =: contractNumber
                ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Case createCustomerCase(String fullName, String nationalId) {
        try{
            Case c = new Case();
            c.FEC_Customer_Name__c = fullName;
            c.FEC_National_ID_Passport_ID__c = nationalId;
            c.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Customer_Case').getRecordTypeId();
            insert c;
            return c;
        }   
        catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
   * @description Checks if the current user has edit access to specific fields on a given SObject.
   * @param sObjectType The SObject type (e.g., 'Account', 'Custom_Object__c')
   * @param fieldNames A list of field API names to check
   * @return Map<String, Boolean> A map where the key is the field name and the value is true if editable.
   */

    @AuraEnabled(cacheable=true)
    public static Map<String, Boolean> checkFieldEditPermissions(String sObjectType, List<String> fieldNames) {
        Map<String, Boolean> fieldPermissions = new Map<String, Boolean>();
        
        // Get the describe result for the object
        SObjectType targetType = Schema.getGlobalDescribe().get(sObjectType);
        if (targetType == null) {
            return fieldPermissions; 
        }
        
        Map<String, SObjectField> fieldsMap = targetType.getDescribe().fields.getMap();
        
        for (String fieldName : fieldNames) {
            if (fieldsMap.containsKey(fieldName)) {
                // Check if the field is updateable by the current user
                fieldPermissions.put(fieldName, fieldsMap.get(fieldName).getDescribe().isUpdateable());
            } else {
                fieldPermissions.put(fieldName, false); // Field doesn't exist or isn't accessible
            }
        }
        
        return fieldPermissions;
    }

    @AuraEnabled
    public static void revealNationalId(Id recordId) {
        
        try {
            Case c = [
            SELECT Id
            FROM Case
            WHERE Id = :recordId
            LIMIT 1
            ];
            
            User u = [
            SELECT Username, UserRole.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            ];
            
            
            // 🔐 Audit sensitive access
            FEC_CommonUltils.logSensitiveAccess(
                FEC_ConstantCommon.SECTION_SEARCH_INFORMARION,
                FEC_ConstantCommon.SECTION_NATIONAL_PASSPORT,
                u.Username.split('@')[0],
                u.UserRole != null ? u.UserRole.Name : null,
                c.Id);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Executes the Card Basic Info integration call using a specific Account Number.
     * @param accountNumber The account number to search for.
     * @return FEC_GetCardBasicInfo.ResponseWrapper The API response containing card details.
     */
    @AuraEnabled
    public static FEC_GetCardBasicInfo.ResponseWrapper getCardInfoByAccountNumber(String accountNumber) {
        if (String.isBlank(accountNumber)) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Account Number'}));
        }

        try {
            // Generate integration metadata as per your requirement
            String requestId = String.valueOf(UUID.randomUUID());
            String requestor = FEC_ConstantCommon.REQUESTOR_CRM;
            String timestamp = Datetime.now().formatGmt(FEC_ConstantCommon.DATETIME_FORMAT);

            // Call the integration service
            FEC_GetCardBasicInfo.ResponseWrapper res = FEC_GetCardBasicInfo.callGetCardBasicInfo(
                requestId,
                requestor,
                timestamp,
                accountNumber
            );

            return res;
        } catch (Exception e) {
            // Log error and pass to the UI
            throw new AuraHandledException(System.Label.FEC_Account_Card_Fetch_Error + ' [' + accountNumber + ']. ' + e.getMessage());
        }
    }
}