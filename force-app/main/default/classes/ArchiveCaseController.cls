/*------------------------------------------------------------
Author:        Thanh Van
Company:       Amaris
Description:   Handle Archive Case
Test Class:    ArchiveCaseController_Test
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/04/01     Thanh Van          Init
------------------------------------------------------------*/
public with sharing class ArchiveCaseController {

    @TestVisible private static List<AthenaCases__x> mockExternalRecords;
    public String errorMessage { get; set; }
    public Boolean hasError { get; set; }
    public AthenaCases__x athenaCaseRecord;

    // Map of child/related object API name → Case lookup field name
    // Used for both parsing (to distinguish child records from lookup relationships)
    // and for inserting child records after Case creation
    private static final Map<String, String> CHILD_OBJECT_CASE_FIELD = new Map<String, String>{
        // Master-Detail relationships
        'FEC_Watcher__c' => 'FEC_Case__c',
        'FEC_Case_Remarks__c' => 'FEC_Case__c',
        'FEC_Case_Flow_History__c' => 'FEC_Case__c',
        'FEC_Additional_Info__c' => 'FEC_Case__c',
        'FEC_Sensitive_Data__c' => 'FEC_Case__c',
        'FEC_Routing_Action_History__c' => 'FEC_Case__c',
        'FEC_RePayment_Schedule__c' => 'FEC_Case__c',
        'FEC_Process_Action_History__c' => 'FEC_Case__c',
        'FEC_Pending_Disbursement__c' => 'FEC_Case__c',
        'FEC_Notification_History__c' => 'FEC_Case__c',
        'FEC_Do_Not_Bother__c' => 'FEC_Case__c',
        'FEC_ChatHistory__c' => 'FEC_Case__c',
        'FEC_Case_Refund_Details__c' => 'FEC_Case__c',
        'FEC_Card_Delivery__c' => 'FEC_Case__c',
        'FEC_Assignment__c' => 'FEC_Case__c',
        'FEC_Asset__c' => 'FEC_Case__c',
        'FEC_Application_History__c' => 'FEC_Case__c',
        'FEC_KYC_Result__c' => 'FEC_Case__c',
        // Lookup relationships to Case
        'FEC_Address_Info__c' => 'FEC_Case__c',
        'FEC_IPP__c' => 'FEC_IPP_Closure_Case__c',
        'FEC_Card_Payment__c' => 'FEC_Case__c',
        'FEC_Relevant_Ticket__c' => 'FEC_Related_To__c',
        'FEC_Process_Action__c' => 'FEC_Linked_Case__c',
        'FEC_Integration_Case__c' => 'FEC_Integrate_Case_ID__c'
    };

    public ArchiveCaseController(ApexPages.StandardController stdController) {
        this.athenaCaseRecord = (AthenaCases__x) stdController.getRecord();
        hasError = false;
    }
    // public String errorMessage { get; set; }
    // public Boolean hasError { get; set; }
    // public Account athenaCaseRecord;
    // public ArchiveCaseController(ApexPages.StandardController stdController) {
    //     this.athenaCaseRecord = (Account) stdController.getRecord();
    //     hasError = false;
    // }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Fetch Case from archive and redirect
    Returns:       PageReference
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/04/16      Thanh Van           Init
    ------------------------------------------------------------*/
    // public PageReference fetchAndRedirect() {
    //     try {
    //         String archiveExternalId = 'FECREDIT-BASE-CS-WORK-SCM S-308515';
    //         //String archiveExternalId = 'FECREDIT-BASE-CS-WORK-SCM S-295296';

    //         Id caseId;
    //         System.debug('athenaCaseRecord ' + athenaCaseRecord);
    //         if (athenaCaseRecord == null) {
    //             hasError = true;
    //             errorMessage = label.FEC_Toast_Error_Generic;
    //             return null;
    //         }

    //         List<Case> cases = [SELECT Id, RecordTypeId FROM Case 
    //                             WHERE ArchiveExternalId__c = :archiveExternalId];
    //         if (!cases.isEmpty()) caseId = cases[0].Id;
    //         else caseId = getCaseDetailAndCreateCaseTemp(archiveExternalId);

    //         PageReference pageRef = new PageReference('/' + caseId);
    //         pageRef.setRedirect(true);
    //         return pageRef;
            
    //     } catch (Exception ex) {
    //         hasError = true;
    //         errorMessage = 'Error: ' + ex.getMessage();
    //         System.debug('ArchiveCaseController error: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
    //         return null;
    //     }
    // }
    public PageReference fetchAndRedirect() {
        try {
            System.debug('athenaCaseRecord ' + athenaCaseRecord);
            if (athenaCaseRecord == null) {
                hasError = true;
                errorMessage = label.FEC_Toast_Error_Generic;
                return null;
            }

            List<AthenaCases__x> archiveCases;
            String caseId;
            String sfIdForExternalRec = athenaCaseRecord.Id;
            System.debug('sfIdForExternalRec ' + sfIdForExternalRec);

            if (Test.isRunningTest() && mockExternalRecords != null) {
                archiveCases = mockExternalRecords;
            } else {
                archiveCases = [SELECT Id, ExternalId, s3_path__c, 
                                migration_source__c, case_id__c 
                                FROM AthenaCases__x 
                                WHERE Id = :sfIdForExternalRec];
            }

            if (archiveCases.isEmpty()) {
                hasError = true;
                errorMessage = label.FEC_Toast_Error_Generic;
                return null;
            }

            AthenaCases__x archiveCaseIns = archiveCases[0];
            List<Case> cases = [SELECT Id, RecordTypeId FROM Case 
                                WHERE ArchiveExternalId__c = :archiveCaseIns.case_id__c];
            if (!cases.isEmpty()) caseId = cases[0].Id;
            else caseId = getCaseDetailAndCreateCaseTemp(archiveCaseIns);

            if (caseId != null) {
                PageReference pageRef = new PageReference('/' + caseId);
                pageRef.setRedirect(true);
                return pageRef;
            } else {
                hasError = true;
                errorMessage = label.FEC_Toast_Error_Generic;
                return null;
            }
        } catch (Exception ex) {
            hasError = true;
            errorMessage = 'Error: ' + ex.getMessage();
            System.debug('ArchiveCaseController error: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
            return null;
        }
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Get RecordTypeId
    Returns:       
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2025/04/01      Thanh Van           Init
    ------------------------------------------------------------*/
    //public static Id getCaseDetailAndCreateCaseTemp(String archiveExternalId) {
    public static Id getCaseDetailAndCreateCaseTemp(AthenaCases__x archiveCaseIns) {

        Id caseId;
        Map<String, Object> mapOfFieldAndValue = new Map<String, Object>();
        String methodOfApi = FEC_ConstantCommon.API_METHOD_GET;
        String recTypeName = label.TECH_CASE_RECORDTYPE_NAME_CUSTOMER_CASE;
        String archieveExternalId = archiveCaseIns.case_id__c;
        //String archieveExternalId = archiveExternalId;
        String migrationSource = archiveCaseIns.migration_source__c;
        List<String> listOfAttIgnored = label.TECH_LIST_ATT_IGNORED.split(',');
        String attachmentStr = '';
        String resBody = '';
        String resStatusCode = '';
        String serviceName = label.TECH_API_GET_ARCHIVE_DETAIL_CASE;
        String attrString = 'attributes';
        String s3PatchPrefix = 'fec-integration-s3/';
        String s3Patch = archiveCaseIns.s3_path__c.containsIgnoreCase(s3PatchPrefix) 
                            ? archiveCaseIns.s3_path__c.substringAfter(s3PatchPrefix) 
                            : archiveCaseIns.s3_path__c;

        //resStatusCode = '201';
        //resBody = jsonOfResponse();

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(serviceName);
        String endpoint = FEC_MockupEndpoint.GET_CASE_ARCHIVE_ENDPOINT_MOCKUP 
                        + s3Patch + '&source=' + migrationSource;
        if (apiConfig != null && String.isNotBlank(apiConfig.FEC_Endpoint__c)) {
            endpoint = apiSetting?.FEC_Call_Mock__c ? endpoint 
                        : (apiSetting?.FEC_Endpoint__c + apiConfig.FEC_Endpoint__c) 
                            + s3Patch + '&source=' + migrationSource;
        }

        Map<String,String> headers = new Map<String,String>{
            'X-API-KEY' => 'RkVDX1NBTEVTRk9SQ0U='
        };
        HttpResponse resp = FEC_CommonUltils.calloutApiWithHeaders(endpoint, methodOfApi, headers, null);
        resBody = resp.getBody();
        resStatusCode = String.valueOf(resp.getStatusCode());
        System.debug('ArchiveCase.getStatusCode() ' + resStatusCode);
        System.debug('ArchiveCase.getBody() ' + resBody);

        FEC_IntegrationFraudCaseUtil.logIntegrationService(serviceName, '', '', '', 
                                                            endpoint, resBody, resStatusCode, '', '');

        // Collect relationship objects separately for lookup resolution
        Map<String, Map<String, Object>> mapRelationshipObjects = new Map<String, Map<String, Object>>();
        Map<String, List<Map<String, Object>>> mapChildRecords = new Map<String, List<Map<String, Object>>>();
        List<Map<String, Object>> attachmentsList = new List<Map<String, Object>>();

        if (resStatusCode.equals('200') || resStatusCode.equals('201')) {
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(resBody);

            // Case fields are now inside the "Case" key
            Map<String, Object> jsonDetailCase = jsonResponse.containsKey('Case')
                ? (Map<String, Object>) jsonResponse.get('Case')
                : jsonResponse;

            // Iterate over the full response to collect relationship objects, child records, and RecordType
            for (String keyOfAtt : jsonResponse.keySet()) {
                if (keyOfAtt == 'Case') continue;
                if (listOfAttIgnored.contains(keyOfAtt)) continue;

                Object valObj = jsonResponse.get(keyOfAtt);
                if (valObj == null) continue;

                if (keyOfAtt == 'RecordType') {
                    try {
                        Map<String, Object> objChild = (Map<String, Object>) valObj;
                        recTypeName = (String) objChild.get('Name');
                    } catch (Exception ex) {
                        recTypeName = String.valueOf(valObj);
                    }
                    continue;
                }

                if (keyOfAtt == 'FEC_Case_Attachments') {
                    try {
                        List<Object> rawList = (List<Object>) valObj;
                        if (rawList != null && !rawList.isEmpty()) attachmentStr = JSON.serialize(rawList);
                    } catch (Exception ex) {
                        System.debug('Could not parse Attachments array: ' + ex.getMessage());
                    }
                    continue;
                }

                // Child record arrays: value is a List (master-detail children)
                if (valObj instanceof List<Object>) {
                    List<Object> rawList = (List<Object>) valObj;
                    List<Map<String, Object>> childList = new List<Map<String, Object>>();
                    for (Object item : rawList) {
                        if (item instanceof Map<String, Object>) {
                            childList.add((Map<String, Object>) item);
                        }
                    }
                    if (!childList.isEmpty()) {
                        mapChildRecords.put(keyOfAtt, childList);
                    }
                    continue;
                }

                // Relationship objects or child records: value is a Map (single record)
                // Distinguish by checking if the key matches a known child object name
                if (valObj instanceof Map<String, Object>) {
                    Map<String, Object> relMap = (Map<String, Object>) valObj;

                    // Determine the SObject type: prefer attributes.type if available, fallback to key name
                    String objType = keyOfAtt;
                    if (relMap.containsKey(attrString)) {
                        try {
                            Map<String, Object> attrMap = (Map<String, Object>) relMap.get(attrString);
                            String attrType = (String) attrMap.get('type');
                            if (String.isNotBlank(attrType)) objType = attrType;
                        } catch (Exception ex) {}
                    }

                    if (CHILD_OBJECT_CASE_FIELD.containsKey(objType) 
                        || CHILD_OBJECT_CASE_FIELD.containsKey(keyOfAtt)) {
                        // Single child record — wrap in list for uniform processing
                        mapChildRecords.put(keyOfAtt, new List<Map<String, Object>>{ relMap });
                    } else {
                        mapRelationshipObjects.put(keyOfAtt, relMap);
                    }
                    continue;
                }
            }

            // Now iterate Case fields
            for (String keyOfAtt : jsonDetailCase.keySet()) {
                if (listOfAttIgnored.contains(keyOfAtt)) continue;
                if (keyOfAtt == attrString) continue;
                mapOfFieldAndValue.put(keyOfAtt.toLowerCase(), jsonDetailCase.get(keyOfAtt));
            }
        }

        System.debug('mapOfFieldAndValue ' + mapOfFieldAndValue);
        System.debug('mapRelationshipObjects keys ' + mapRelationshipObjects.keySet());
        System.debug('mapChildRecords keys ' + mapChildRecords.keySet());

        if (mapOfFieldAndValue.size() > 0) {
            Map<String, Schema.SObjectField> fieldMap = Case.sObjectType.getDescribe().fields.getMap();
            Set<String> setPotentialIds = new Set<String>();
            Map<String, UserRecordAccess> mapIdCanAccess;

            Case caseIns = new Case();

            // Resolve lookup objects to real Ids in current org
            resolveRelationshipLookups(mapOfFieldAndValue, mapRelationshipObjects);
            buildSetPotentialIds(setPotentialIds, fieldMap, mapOfFieldAndValue);
            mapIdCanAccess = getRelatedRecordCanAccess(setPotentialIds);
            System.debug('mapIdCanAccess ' + mapIdCanAccess);

            buildCaseFieldsAndValue(fieldMap, mapOfFieldAndValue, caseIns, mapIdCanAccess);
            caseIns.ArchiveExternalId__c = archieveExternalId;
            caseIns.FEC_ID_Search__c = archieveExternalId;
            caseIns.RecordTypeId = getRecordTypeId(recTypeName);
            caseIns.ArchiveAttachment__c = attachmentStr;
            caseIns.ArchiveMigrationSource__c = migrationSource;
            processSpecialValueForCase(caseIns);
            caseId = saveCaseRecord(caseIns);

            // Insert child records (master-detail) after Case is created
            if (caseId != null && !mapChildRecords.isEmpty()) {
                insertChildRecords(caseId, mapChildRecords);
            }
        }

        return caseId;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Resolve relationship objects to real Ids in current org.
                   In the new JSON format, relationship objects are keyed by their
                   SObject API name (e.g. 'FEC_Category__c', 'User') instead of __r.
                   IDs from the archive JSON may not exist in the current org.
                   We match records by their unique code/name fields instead.
    Returns:       void (mutates mapOfFieldAndValue in place)
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/04/07      Thanh Van           Init
    2026/05/07      Thanh Van           Updated for new JSON format (no __r keys)
    ------------------------------------------------------------*/
    public static void resolveRelationshipLookups(
        Map<String, Object> mapOfFieldAndValue,
        Map<String, Map<String, Object>> mapRelationshipObjects
    ) {
        if (mapRelationshipObjects.isEmpty()) return;

        String codeFiled = 'FEC_Code__c';
        String productTypeAPIName = 'FEC_Product_Type__c';
        String categoryAPIName = 'FEC_Category__c';
        String subCategoryAPIName = 'FEC_Sub_Category__c';
        String subCodeAPIName = 'FEC_Sub_Code__c';
        String newCategoryAPIName = 'FEC_New_Category__c';
        String newSubCategoryAPIName = 'FEC_New_SubCategory__c';
        String newSubCodeAPIName = 'FEC_New_SubCode__c';
        String businessProcessAPIName = 'FEC_Business_Process__c';
        String customerHistoryAPIName = 'FEC_Customer_History__c';

        // --- Simple code-based lookups ---
        // Key in mapRelationshipObjects is now the SObject API name (same as field name in new JSON format)
        // FEC_Product_Type__c → FEC_Product_Type__c.FEC_Code__c
        resolveByCode(mapOfFieldAndValue, mapRelationshipObjects,
            productTypeAPIName, productTypeAPIName.toLowerCase(),
            productTypeAPIName, codeFiled);

        // FEC_Category__c → FEC_Category__c.FEC_Code__c
        resolveByCode(mapOfFieldAndValue, mapRelationshipObjects,
            categoryAPIName, categoryAPIName.toLowerCase(),
            categoryAPIName, codeFiled);

        // FEC_SubCategory__c → FEC_Sub_Category__c.FEC_Code__c
        resolveByCode(mapOfFieldAndValue, mapRelationshipObjects,
            subCategoryAPIName, 'fec_subcategory__c',
            subCategoryAPIName, codeFiled);

        // FEC_SubCode__c → FEC_Sub_Code__c.FEC_Code__c
        resolveByCode(mapOfFieldAndValue, mapRelationshipObjects,
            subCodeAPIName, 'fec_subcode__c',
            subCodeAPIName, codeFiled);

        // FEC_New_Category__c
        resolveByCode(mapOfFieldAndValue, mapRelationshipObjects,
            newCategoryAPIName, newCategoryAPIName.toLowerCase(),
            categoryAPIName, codeFiled);

        // FEC_New_SubCategory__c
        resolveByCode(mapOfFieldAndValue, mapRelationshipObjects,
            newSubCategoryAPIName, newSubCategoryAPIName.toLowerCase(),
            subCategoryAPIName, codeFiled);

        // FEC_New_SubCode__c
        resolveByCode(mapOfFieldAndValue, mapRelationshipObjects,
            newSubCodeAPIName, newSubCodeAPIName.toLowerCase(),
            subCodeAPIName, codeFiled);

        // FEC_Business_Process__c → FEC_Business_Process__c.FEC_Code__c
        resolveByCode(mapOfFieldAndValue, mapRelationshipObjects,
            businessProcessAPIName, businessProcessAPIName.toLowerCase(),
            businessProcessAPIName, codeFiled);

        // --- FEC_Account_or_Contract__c → FEC_Customer_History__c matched by Name (account number) ---
        if (mapRelationshipObjects.containsKey(customerHistoryAPIName)) {
            Map<String, Object> relObj = mapRelationshipObjects.get(customerHistoryAPIName);
            String accountName = (String) relObj.get('Name');
            if (String.isNotBlank(accountName)) {
                List<FEC_Customer_History__c> matches = [
                    SELECT Id FROM FEC_Customer_History__c
                    WHERE Name = :accountName LIMIT 1
                ];
                if (!matches.isEmpty()) {
                    mapOfFieldAndValue.put('fec_account_or_contract__c', matches[0].Id);
                } else {
                    Id tempId = insertTempRecord(customerHistoryAPIName, relObj);
                    mapOfFieldAndValue.put('fec_account_or_contract__c', tempId);
                }
            }
        }

        // --- FEC_Interaction__c → Case matched by ArchiveExternalId__c ---
        // In new JSON format, the key might be "FEC_Interaction__c" as an object
        // but typically it's just an Id in the Case fields, so skip if not present as object

        // --- Owner/User → User matched by Username ---
        // if (mapRelationshipObjects.containsKey('User')) {
        //     Map<String, Object> relObj = mapRelationshipObjects.get('User');
        //     String username = (String) relObj.get('Username');
        //     if (String.isNotBlank(username)) {
        //         List<User> matches = [SELECT Id FROM User WHERE Username = :username AND IsActive = true LIMIT 1];
        //         if (!matches.isEmpty()) {
        //             mapOfFieldAndValue.put('ownerid', matches[0].Id);
        //         } else {
        //             mapOfFieldAndValue.put('ownerid', UserInfo.getUserId());
        //         }
        //     }
        // }

        // --- FEC_Actual_Nature_of_Case__c → composite match ---
        resolveActualNatureOfCase(mapOfFieldAndValue, mapRelationshipObjects);
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Resolve a simple lookup field by querying the target object using FEC_Code__c
                   from the corresponding relationship object in the JSON.
                   The relKey is now the SObject API name (e.g. 'FEC_Category__c') instead of __r.
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/04/07      Thanh Van           Init
    ------------------------------------------------------------*/
    private static void resolveByCode(
        Map<String, Object> mapOfFieldAndValue,
        Map<String, Map<String, Object>> mapRelationshipObjects,
        String relKey,           // e.g. 'FEC_Product_Type__c' (key in mapRelationshipObjects)
        String fieldKeyLower,    // e.g. 'fec_product_type__c'  (lowercase, as stored in map)
        String sObjectApiName,   // e.g. 'FEC_Product_Type__c'
        String codeField         // e.g. 'FEC_Code__c'
    ) {
        if (!mapRelationshipObjects.containsKey(relKey)) return;

        Map<String, Object> relObj = mapRelationshipObjects.get(relKey);
        String codeValue = (String) relObj.get(codeField);
        if (String.isBlank(codeValue)) return;

        String soql = 'SELECT Id FROM ' + sObjectApiName 
                        + ' WHERE ' + codeField + ' = :codeValue LIMIT 1';
        List<SObject> matches = Database.query(soql);
        if (!matches.isEmpty()) {
            mapOfFieldAndValue.put(fieldKeyLower, matches[0].Id);
        } else {
            // Record not found in org — insert a temp record from JSON data so the Case can reference it
            Id tempId = insertTempRecord(sObjectApiName, relObj);
            mapOfFieldAndValue.put(fieldKeyLower, tempId);
        }
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Insert a temporary SObject record from __r JSON data.
                   Sets IsArchiveTemp__c = true so the cleanup job can delete it.
                   Only maps fields that are createable on the target object.
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/04/07      Thanh Van           Init
    ------------------------------------------------------------*/
    private static Id insertTempRecord(String sObjectApiName, Map<String, Object> relObj) {
        try {
            SObject tempRec = (SObject) Type.forName(sObjectApiName).newInstance();
            tempRec.put('IsArchiveTemp__c', true);

            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
                .get(sObjectApiName).getDescribe().fields.getMap();

            for (String key : relObj.keySet()) {
                if (key == 'attributes' || key == 'Id') continue;
                Object val = relObj.get(key);
                if (val == null) continue;

                String keyLower = key.toLowerCase();
                if (!fieldMap.containsKey(keyLower)) continue;

                Schema.DescribeFieldResult fd = fieldMap.get(keyLower).getDescribe();
                if (!fd.isCreateable()) continue;

                // Skip REFERENCE fields — nested lookups inside relationship objects are not resolved
                castAndSetFieldValue(tempRec, key, val, fd, null);
            }

            insert tempRec;
            return tempRec.Id;
        } catch (Exception ex) {
            System.debug('insertTempRecord failed for ' + sObjectApiName + ': ' + ex.getMessage());
            return null;
        }
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Resolve FEC_Actual_Nature_of_Case__c by matching on the combination of
                   ProductType + Category + SubCategory + SubCode + BusinessProcess.
                   Uses the already-resolved Ids from mapOfFieldAndValue (resolved by resolveByCode).
                   Falls back to extracting codes from the relationship object if present.
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/04/07      Thanh Van           Init
    2026/05/07      Thanh Van           Updated for new JSON format (no __r keys)
    ------------------------------------------------------------*/
    private static void resolveActualNatureOfCase(
        Map<String, Object> mapOfFieldAndValue,
        Map<String, Map<String, Object>> mapRelationshipObjects
    ) {
        // In new JSON format, FEC_Actual_Nature_of_Case__c may be present as an object
        // or the individual dimension Ids are already resolved in mapOfFieldAndValue
        Map<String, Object> nocObj = mapRelationshipObjects.containsKey('FEC_Actual_Nature_of_Case__c')
            ? mapRelationshipObjects.get('FEC_Actual_Nature_of_Case__c')
            : null;

        // Use already-resolved Ids from mapOfFieldAndValue (set by resolveByCode earlier)
        Id productTypeId = mapOfFieldAndValue.get('fec_product_type__c') instanceof Id
            ? (Id) mapOfFieldAndValue.get('fec_product_type__c') : null;
        Id categoryId = mapOfFieldAndValue.get('fec_category__c') instanceof Id
            ? (Id) mapOfFieldAndValue.get('fec_category__c') : null;
        Id subCategoryId = mapOfFieldAndValue.get('fec_subcategory__c') instanceof Id
            ? (Id) mapOfFieldAndValue.get('fec_subcategory__c') : null;
        Id subCodeId = mapOfFieldAndValue.get('fec_subcode__c') instanceof Id
            ? (Id) mapOfFieldAndValue.get('fec_subcode__c') : null;
        Id bizProcessId = mapOfFieldAndValue.get('fec_business_process__c') instanceof Id
            ? (Id) mapOfFieldAndValue.get('fec_business_process__c') : null;

        // If nocObj has nested objects with codes, try to extract and resolve from there as fallback
        if (nocObj != null) {
            if (productTypeId == null) productTypeId = resolveIdByCode('FEC_Product_Type__c', 'FEC_Code__c', extractNestedCode(nocObj, 'FEC_Product_Type__c', 'FEC_Code__c'));
            if (categoryId == null)    categoryId    = resolveIdByCode('FEC_Category__c',     'FEC_Code__c', extractNestedCode(nocObj, 'FEC_Category__c',     'FEC_Code__c'));
            if (subCategoryId == null) subCategoryId = resolveIdByCode('FEC_Sub_Category__c', 'FEC_Code__c', extractNestedCode(nocObj, 'FEC_Sub_Category__c', 'FEC_Code__c'));
            if (subCodeId == null)     subCodeId     = resolveIdByCode('FEC_Sub_Code__c',     'FEC_Code__c', extractNestedCode(nocObj, 'FEC_Sub_Code__c',     'FEC_Code__c'));
            if (bizProcessId == null)  bizProcessId  = resolveIdByCode('FEC_Business_Process__c', 'FEC_Code__c', extractNestedCode(nocObj, 'FEC_Business_Process__c', 'FEC_Code__c'));
        }

        System.debug('resolveActualNatureOfCase Ids: ' + productTypeId + '|' + categoryId + '|' + subCategoryId + '|' + subCodeId + '|' + bizProcessId);

        if (productTypeId == null && categoryId == null 
            && subCategoryId == null && subCodeId == null) {
            mapOfFieldAndValue.put('fec_actual_nature_of_case__c', null);
            return;
        }

        // Always insert new record FEC_Actual_Nature_of_Case__c
        // The Actual NOC is the parent, when the case is archived >> Actual NOC is deleted
        // >> Do not need to query
        try {
            FEC_Actual_Nature_of_Case__c tempNoc = new FEC_Actual_Nature_of_Case__c();
            tempNoc.IsArchiveTemp__c = true;
            if (productTypeId != null) tempNoc.FEC_Product_Type__c = productTypeId;
            if (categoryId != null)    tempNoc.FEC_Category__c = categoryId;
            if (subCategoryId != null) tempNoc.FEC_Sub_Category__c = subCategoryId;
            if (subCodeId != null)     tempNoc.FEC_Sub_Code__c = subCodeId;
            if (bizProcessId != null)  tempNoc.FEC_Business_Process__c = bizProcessId;
            if (nocObj != null) {
                String customerType = (String) nocObj.get('FEC_Customer_Type__c');
                if (String.isNotBlank(customerType)) tempNoc.FEC_Customer_Type__c = customerType;

                String userGroup = (String) nocObj.get('FEC_User_Group__c');
                if (String.isNotBlank(userGroup)) tempNoc.FEC_User_Group__c = userGroup;
            }

            insert tempNoc;
            mapOfFieldAndValue.put('fec_actual_nature_of_case__c', tempNoc.Id);

        } catch (Exception ex) {
            System.debug('insertTempRecord failed for FEC_Actual_Nature_of_Case__c: ' + ex.getMessage());
            mapOfFieldAndValue.put('fec_actual_nature_of_case__c', null);
        }
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Extract a code value from a nested object within a parent relationship map.
                   Works with both old __r format and new direct SObject key format.
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/04/07      Thanh Van           Init
    ------------------------------------------------------------*/
    private static String extractNestedCode(Map<String, Object> parentObj, String relKey, String codeField) {
        Object nested = parentObj.get(relKey);
        if (nested == null) return null;
        try {
            Map<String, Object> nestedMap = (Map<String, Object>) nested;
            return (String) nestedMap.get(codeField);
        } catch (Exception ex) {
            return null;
        }
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Query a single Id from an SObject by a code field value
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/04/07      Thanh Van           Init
    ------------------------------------------------------------*/
    private static Id resolveIdByCode(String sObjectApiName, String codeField, String codeValue) {
        if (String.isBlank(codeValue)) return null;
        String soql = 'SELECT Id FROM ' + sObjectApiName + ' WHERE ' + codeField + ' = :codeValue LIMIT 1';
        List<SObject> results = Database.query(soql);
        return results.isEmpty() ? null : results[0].Id;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Get RecordTypeId
    Returns:       
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2025/04/01      Thanh Van           Init
    ------------------------------------------------------------*/
    public static Id getRecordTypeId(String externalType) {

        Map<String, String> mapExternalTypeAndRecordType = new Map<String, String>{
            label.TECH_CASE_RECORDTYPE_NAME_CUSTOMER_CASE => FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME,
            label.TECH_CASE_RECORDTYPE_NAME_INTERACTION => FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME,
            label.TECH_CASE_RECORDTYPE_NAME_SEARCH_INTERACTION => FEC_ConstantCommon.CASE_SEARCH_RECORD_TYPE_DEV_NAME,
            label.TECH_CASE_RECORDTYPE_NAME_INTERNAL_CASE => FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME
        };

        String recTypeDevName = String.valueOf(mapExternalTypeAndRecordType.get(externalType));
        return Schema.SObjectType.Case
            .getRecordTypeInfosByDeveloperName()
            .get(recTypeDevName)
            .getRecordTypeId();
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Build SetPotentialIds
    Returns:       
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2025/04/01      Thanh Van           Init
    ------------------------------------------------------------*/
    public static void buildSetPotentialIds(Set<String> setPotentialIds, 
                                            Map<String, Schema.SObjectField> fieldMap, 
                                            Map<String, Object> mapOfFieldAndValue) {

        list<String> listFields = new list<String>();
        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDetail = fieldMap.get(fieldName).getDescribe();
            if (!fieldDetail.isCreateable()) continue;

            Schema.DisplayType fieldType = fieldDetail.getType();

            Object rawValue = mapOfFieldAndValue.get(fieldName.toLowerCase());
            if (rawValue != null && fieldType == Schema.DisplayType.REFERENCE) setPotentialIds.add((String) rawValue);
        }
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Get Related Record Can Access
    Returns:       
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2025/04/01      Thanh Van           Init
    ------------------------------------------------------------*/
    public static Map<String, UserRecordAccess> getRelatedRecordCanAccess(Set<String> setPotentialIds) {
        Map<String, UserRecordAccess> accessMap = new Map<String, UserRecordAccess>([
                                                    SELECT RecordId, HasReadAccess 
                                                    FROM UserRecordAccess 
                                                    WHERE UserId = :UserInfo.getUserId() 
                                                    AND RecordId IN :setPotentialIds]);
        return accessMap;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   build Case Fields And Value
    Returns:       
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2025/04/01      Thanh Van           Init
    ------------------------------------------------------------*/
    public static void buildCaseFieldsAndValue(Map<String, Schema.SObjectField> fieldMap, 
                                            Map<String, Object> mapOfFieldAndValue, 
                                            Case caseIns, Map<String, UserRecordAccess> mapIdCanAccess) {
 
        String devFieldTmp = '';
        Map<String, String> jsonDevField = getMapReplaceFields();

        for (String fieldName : fieldMap.keySet()) {
            Object rawValue = mapOfFieldAndValue.get(fieldName.toLowerCase());
            if (rawValue != null) {
                devFieldTmp = mappingDevField(fieldName, jsonDevField);

                Schema.DescribeFieldResult fieldDetail = fieldMap.get(devFieldTmp).getDescribe();
                if (!fieldDetail.isCreateable()) continue;

                castAndSetFieldValue(caseIns, devFieldTmp, rawValue, fieldDetail, mapIdCanAccess);
            }
        }
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Validate and set picklist/multipicklist value for any SObject field.
                   If the value from JSON does not exist in the field's valid picklist entries,
                   set null to avoid DML exceptions. For multipicklist, only valid values are kept.
    Returns:       void
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/05/07      Thanh Van           Extracted generic version from Case-specific method
    ------------------------------------------------------------*/
    private static void setPicklistValue(SObject record, String fieldName, Object rawValue,
                                         Schema.DescribeFieldResult fieldDetail, 
                                         Schema.DisplayType fieldType) {
        String strValue = String.valueOf(rawValue);
        if (String.isBlank(strValue)) return;

        Set<String> validValues = new Set<String>();
        for (Schema.PicklistEntry ple : fieldDetail.getPicklistValues()) {
            validValues.add(ple.getValue());
        }

        if (fieldType == Schema.DisplayType.MULTIPICKLIST) {
            List<String> validSelected = new List<String>();
            for (String val : strValue.split(';')) {
                String trimmed = val.trim();
                if (validValues.contains(trimmed)) {
                    validSelected.add(trimmed);
                }
            }
            record.put(fieldName, validSelected.isEmpty() ? null : String.join(validSelected, ';'));
        } else {
            record.put(fieldName, validValues.contains(strValue) ? strValue : null);
        }
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Cast a raw JSON value to the appropriate Apex type based on field describe
                   and set it on the SObject record. Handles all common field types.
                   For REFERENCE fields:
                   - If mapIdCanAccess is provided, validates access before setting.
                     If no access, sets null (or UserInfo.getUserId() for OwnerId).
                   - If mapIdCanAccess is null and keepReference is true, sets value as-is.
                   - If mapIdCanAccess is null and keepReference is false, skips (returns false).
    Returns:       true if the field was set, false if it was skipped
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/05/07      Thanh Van           Init
    ------------------------------------------------------------*/
    private static Boolean castAndSetFieldValue(SObject record, String fieldName, Object rawValue,
                                                 Schema.DescribeFieldResult fieldDetail, 
                                                 Map<String, UserRecordAccess> mapIdCanAccess) {
        Schema.DisplayType ft = fieldDetail.getType();

        if (ft == Schema.DisplayType.DOUBLE || ft == Schema.DisplayType.CURRENCY) {
            record.put(fieldName, Decimal.valueOf(String.valueOf(rawValue)));
        } else if (ft == Schema.DisplayType.INTEGER) {
            record.put(fieldName, Integer.valueOf(String.valueOf(rawValue)));
        } else if (ft == Schema.DisplayType.DATE) {
            record.put(fieldName, Date.valueOf(String.valueOf(rawValue)));
        } else if (ft == Schema.DisplayType.DATETIME) {
            String dtStr = String.valueOf(rawValue).replace('T', ' ');
            if (dtStr.contains('+')) dtStr = dtStr.substringBefore('+');
            record.put(fieldName, Datetime.valueOfGMT(dtStr));
        } else if (ft == Schema.DisplayType.BOOLEAN) {
            record.put(fieldName, Boolean.valueOf(String.valueOf(rawValue)));
        } else if (ft == Schema.DisplayType.PICKLIST || ft == Schema.DisplayType.MULTIPICKLIST) {
            setPicklistValue(record, fieldName, rawValue, fieldDetail, ft);
        } else if (ft == Schema.DisplayType.REFERENCE) {
            String idStr = String.valueOf(rawValue);
            Boolean noReading = mapIdCanAccess.containsKey(idStr) 
                                    && !mapIdCanAccess.get(idStr).HasReadAccess;
            if (!mapIdCanAccess.containsKey(idStr) || noReading) {
                if (fieldName.equalsIgnoreCase('OwnerId')) record.put(fieldName, UserInfo.getUserId());
                else record.put(fieldName, null);
            } else {
                record.put(fieldName, idStr);
            }
        } else {
            // STRING, TEXTAREA, EMAIL, PHONE, URL, etc.
            record.put(fieldName, String.valueOf(rawValue));
        }
        return true;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   build Case Fields And Value
    Returns:       
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2025/04/01      Thanh Van           Init
    ------------------------------------------------------------*/
    public static Id saveCaseRecord(Case caseIns) {
        Id caseId;
        Boolean isSuccess = false;
        Integer timeRetry = 0;
        while (!isSuccess && timeRetry < 140) {
            timeRetry ++;
            System.debug('try-InsertcaseIns ' + caseIns);
            insert caseIns;
            caseId = caseIns.Id;
            isSuccess = true;
        }

        // while (!isSuccess && timeRetry < 140) {
        //     try {
        //         timeRetry ++;
        //         System.debug('try-InsertcaseIns ' + caseIns);
        //         insert caseIns;
        //         caseId = caseIns.Id;
        //         isSuccess = true;
        //     } catch (DmlException dmlEx) {
        //         for (Integer i = 0; i < dmlEx.getNumDml(); i++) {
        //             List<Schema.SObjectField> fields = dmlEx.getDmlFields(i);
        //             if (fields != null && !fields.isEmpty()) {
        //                 for (Schema.SObjectField keyOfField : fields) {
        //                     caseIns.put(keyOfField, null);
        //                 }
        //             }
        //         }
        //     }
        // }

        return caseId;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Insert child records (master-detail) related to the Case.
                   Each child object has a lookup/master-detail field to Case (FEC_Case__c).
                   Only createable fields are mapped from the JSON data.
    Returns:       void
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/05/07      Thanh Van           Init
    ------------------------------------------------------------*/
    private static void insertChildRecords(Id caseId, Map<String, List<Map<String, Object>>> mapChildRecords) {

        for (String childKey : mapChildRecords.keySet()) {
            String sObjectApiName = childKey;
            String caseFieldName = CHILD_OBJECT_CASE_FIELD.get(sObjectApiName);
            if (String.isBlank(caseFieldName)) {
                System.debug('insertChildRecords: No case field mapping for ' + sObjectApiName);
                continue;
            }

            List<Map<String, Object>> childDataList = mapChildRecords.get(childKey);
            if (childDataList == null || childDataList.isEmpty()) continue;

            try {
                List<SObject> recordsToInsert = buildChildSObjects(sObjectApiName, caseFieldName, caseId, childDataList);
                if (!recordsToInsert.isEmpty()) {
                    insert recordsToInsert;
                    System.debug('insertChildRecords: Inserted ' + recordsToInsert.size() + ' records for ' + sObjectApiName);
                }
            } catch (Exception ex) {
                System.debug('insertChildRecords failed for ' + sObjectApiName + ': ' + ex.getMessage());
            }
        }
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Build a list of SObject records from JSON child data.
                   Maps only createable fields and sets the Case lookup field.
                   Validates REFERENCE fields using the same access-check pattern as Case.
    Returns:       List<SObject>
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/05/07      Thanh Van           Init
    ------------------------------------------------------------*/
    private static List<SObject> buildChildSObjects(String sObjectApiName, String caseFieldName, 
                                                     Id caseId, List<Map<String, Object>> childDataList) {
        List<SObject> records = new List<SObject>();
        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(sObjectApiName);
        if (sObjType == null) {
            System.debug('buildChildSObjects: SObject type not found: ' + sObjectApiName);
            return records;
        }

        Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe().fields.getMap();

        // Collect all potential reference Ids across all child records for access check
        Set<String> setPotentialIds = new Set<String>();
        for (Map<String, Object> childData : childDataList) {
            for (String key : childData.keySet()) {
                if (key == 'attributes' || key == 'Id' || key == caseFieldName) continue;
                Object val = childData.get(key);
                if (val == null) continue;
                String keyLower = key.toLowerCase();
                if (!fieldMap.containsKey(keyLower)) continue;
                Schema.DescribeFieldResult fd = fieldMap.get(keyLower).getDescribe();
                if (fd.isCreateable() && fd.getType() == Schema.DisplayType.REFERENCE) {
                    setPotentialIds.add(String.valueOf(val));
                }
            }
        }
        Map<String, UserRecordAccess> mapIdCanAccess = getRelatedRecordCanAccess(setPotentialIds);

        for (Map<String, Object> childData : childDataList) {
            SObject rec = sObjType.newSObject();
            rec.put(caseFieldName, caseId);

            for (String key : childData.keySet()) {
                if (key == 'attributes' || key == 'Id') continue;
                // Skip the Case lookup field — already set above
                if (key == caseFieldName) continue;

                Object val = childData.get(key);
                if (val == null) continue;
                // Skip nested objects (sub-relationships)
                if (val instanceof Map<String, Object> || val instanceof List<Object>) continue;

                String keyLower = key.toLowerCase();
                if (!fieldMap.containsKey(keyLower)) continue;

                Schema.DescribeFieldResult fd = fieldMap.get(keyLower).getDescribe();
                if (!fd.isCreateable()) continue;

                try {
                    castAndSetFieldValue(rec, key, val, fd, mapIdCanAccess);
                } catch (Exception ex) {
                    System.debug('buildChildSObjects: Could not set field ' + key + ' on ' + sObjectApiName + ': ' + ex.getMessage());
                }
            }

            records.add(rec);
        }

        return records;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Mapping Developer Field Name
    Returns:       
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2025/04/01      Thanh Van           Init
    ------------------------------------------------------------*/
    public static String mappingDevField(String fieldName, Map<String, String> jsonDevField) {

        String fieldNameTmp = '';
        if (jsonDevField != null) {
            fieldNameTmp = jsonDevField.get(fieldName);
            if (fieldNameTmp != null) fieldName = fieldNameTmp;
        }

        return fieldName;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Process Special Value For Case
    Returns:       
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2025/04/01      Thanh Van           Init
    ------------------------------------------------------------*/
    public static void processSpecialValueForCase(Case caseIns) {
        String interactionId = caseIns.ArchiveInteractionId__c;
        Id interactionRtId = FEC_CommonUltils.getRecordTypeIdByDev(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME);

        if (String.isNotBlank(interactionId)) {
            if (interactionId.contains('</a>')) interactionId = interactionId.substringBetween('>', '</a>');
            caseIns.ArchiveInteractionId__c = interactionId;
        }

        // case is not Interaction >> FEC_External_Interaction_ID__c should be null
        // If it is the same value with the Interaction case record >> error (External ID) (Unique Case Sensitive)
        if (interactionRtId != caseIns.RecordTypeId) caseIns.FEC_External_Interaction_ID__c = null;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Get Map Replace Fields
    Returns:       
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2025/04/01      Thanh Van           Init
    ------------------------------------------------------------*/
    public static Map<String, String> getMapReplaceFields() {
        String strMapping = label.TECH_ARCHIEVE_MAPPING_DEV_FIELD;
        Map<String, String> jsonDevField;
        Map<String, String> jsonDevFieldTmp = new Map<String, String>();
        if (String.isNotBlank(strMapping)) {
            jsonDevField = (Map<String, String>) JSON.deserialize(strMapping, Map<String, String>.class);
            for (String devFieldStr : jsonDevField.keySet()) {
                jsonDevFieldTmp.put(devFieldStr.toLowerCase(), jsonDevField.get(devFieldStr));
            }
        }

        return jsonDevFieldTmp;
    }

    // public static String jsonOfResponse() {
    //     String res = '{' +
    //         '\"attributes\": {' +
    //             '\"type\": \"Case\",' +
    //             '\"url\": \"/services/data/v66.0/sobjects/Case/5008600000EfFe9AAF\"' +
    //         '},' +
    //         '\"Id\": \"5008600000EfFe9AAF\",' +
    //         '\"CaseNumber\": \"00001094\",' +
    //         '\"Status\": \"Pending\",' +
    //         '\"CreatedById\": \"00586000002D4FxAAK\",' +
    //         '\"LastModifiedById\": \"00586000002CXNMAA4\",' +
    //         '\"OwnerId\": \"00586000002CXNFAA4\",' +
    //         '\"ParentId\": null,' +
    //         '\"FEC_External_Interaction_ID__c\": null,' +
    //         '\"FEC_Channel__c\": \"Inbound\",' +
    //         '\"FEC_Case_Channel__c\": null,' +
    //         '\"FEC_Created_by__c\": null,' +
    //         '\"FEC_Created_On__c\": null,' +
    //         '\"FEC_Interaction_Start_On__c\": null,' +
    //         '\"FEC_Interaction_End_On__c\": null,' +
    //         '\"FEC_Interaction_Duration__c\": null,' +
    //         '\"FEC_Interaction_Resolved_By__c\": null,' +
    //         '\"FEC_Phone_Number__c\": null,' +
    //         '\"FEC_Transcription__c\": null,' +
    //         '\"FEC_KYC_Method__c\": null,' +
    //         '\"FEC_Interaction_Subchannel__c\": null,' +
    //         '\"FEC_Other_Subchannel__c\": null,' +
    //         '\"FEC_Customer_Name__c\": null,' +
    //         '\"FEC_Genesys_Campaign_Name__c\": null,' +
    //         '\"FEC_Routing_Action__c\": null,' +
    //         '\"FEC_Interaction__c\": \"5008600000EfEbgAAF\",' +
    //         '\"FEC_Interaction_Remarks__c\": null,' +
    //         '\"FEC_Interaction_Resolved_By__r\": null,' +
    //         '\"FEC_Customer_Type__c\": \"Existing\",' +
    //         '\"FEC_Phone_Type__c\": null,' +
    //         '\"FEC_Updated_Info_Phone_Type__c\": \"Primary Phone\",' +
    //         '\"FEC_Interaction_Email__c\": null,' +
    //         '\"FEC_Account_Number__c\": null,' +
    //         '\"FEC_Contract_Number__c\": null,' +
    //         '\"FEC_National_ID_Passport_ID__c\": null,' +
    //         '\"FEC_Email_From__c\": null,' +
    //         '\"FEC_Email_CC__c\": null,' +
    //         '\"FEC_Account_or_Contract__c\": \"a0I86000000R4NhEAK\",' +
    //         '\"FEC_CIF_Number__c\": null,' +
    //         '\"FEC_Case_Email__c\": null,' +
    //         '\"FEC_Account_or_Contract__r\": {' +
    //             '\"attributes\": {' +
    //             '\"type\": \"FEC_Customer_History__c\",' +
    //             '\"url\": \"/services/data/v66.0/sobjects/FEC_Customer_History__c/a0I86000000R4NhEAK\"' +
    //             '},' +
    //             '\"Id\": \"a0I86000000R4NhEAK\",' +
    //             '\"Name\": \"0001500040006525520\",' +
    //             '\"CreatedById\": \"00586000002D4FxAAK\",' +
    //             '\"LastModifiedById\": \"00586000002D4FxAAK\",' +
    //             '\"FEC_Account_Close_Date__c\": null,' +
    //             '\"FEC_Account_Number__c\": \"0001500040006525520\",' +
    //             '\"FEC_Account_Open_Date__c\": null,' +
    //             '\"FEC_Account_Status__c\": null,' +
    //             '\"FEC_Account_Status_Change_Date__c\": null,' +
    //             '\"FEC_Address__c\": null,' +
    //             '\"FEC_Address_Type__c\": null,' +
    //             '\"FEC_Agent_Code__c\": null,' +
    //             '\"FEC_Agent_Name__c\": null,' +
    //             '\"FEC_Agreement_Date__c\": null,' +
    //             '\"FEC_Annual_Fee__c\": null,' +
    //             '\"FEC_API_Cache__c\": null,' +
    //             '\"FEC_API_Cache_Secondary_Demo__c\": null,' +
    //             '\"FEC_Application_ID__c\": null,' +
    //             '\"FEC_Available_Cash_Limit__c\": null,' +
    //             '\"FEC_Available_Points__c\": null,' +
    //             '\"FEC_Bank_Name__c\": null,' +
    //             '\"FEC_Billing_Cycle__c\": null,' +
    //             '\"FEC_Block_Code__c\": null,' +
    //             '\"FEC_Block_Code_1__c\": null,' +
    //             '\"FEC_Block_Code_2__c\": null,' +
    //             '\"FEC_Block_Date__c\": null,' +
    //             '\"FEC_Block_Date_1__c\": null,' +
    //             '\"FEC_Block_Date_2__c\": null,' +
    //             '\"FEC_Blocked_By__c\": null,' +
    //             '\"FEC_Branch_Name__c\": null,' +
    //             '\"FEC_Buyer_DOB__c\": null,' +
    //             '\"FEC_Buyer_Gender__c\": null,' +
    //             '\"FEC_Buyer_Name__c\": null,' +
    //             '\"FEC_Buyer_NID__c\": null,' +
    //             '\"FEC_Cancel_Date__c\": null,' +
    //             '\"FEC_Card_Activation_Date__c\": null,' +
    //             '\"FEC_Card_Activation_Status__c\": null,' +
    //             '\"FEC_Card_Number__c\": null,' +
    //             '\"FEC_Card_Type__c\": null,' +
    //             '\"FEC_Case__c\": \"5008600000EfEbgAAF\",' +
    //             '\"FEC_CC_Code__c\": null,' +
    //             '\"FEC_CC_Name__c\": null,' +
    //             '\"FEC_Charge_Off_Date__c\": null,' +
    //             '\"FEC_CIF_Number__c\": null,' +
    //             '\"Close_Fee_Amount__c\": null,' +
    //             '\"FEC_Company_Name__c\": null,' +
    //             '\"FEC_Contract_Number__c\": null,' +
    //             '\"FEC_Contract_Status__c\": null,' +
    //             '\"FEC_Contract_Type__c\": null,' +
    //             '\"FEC_Credit_Limit__c\": null,' +
    //             '\"FEC_Current_Balance__c\": null,' +
    //             '\"FEC_Customer_Name__c\": null,' +
    //             '\"FEC_Customer_Segment__c\": null,' +
    //             '\"FEC_Customer_Type__c\": \"Existing\",' +
    //             '\"FEC_Daily_Cash_Limit__c\": null,' +
    //             '\"FEC_Daily_Cash_Number__c\": null,' +
    //             '\"FEC_Daily_Ecommerce_Limit__c\": null,' +
    //             '\"FEC_Daily_Ecommerce_Number__c\": null,' +
    //             '\"FEC_Daily_Retail_Limit__c\": null,' +
    //             '\"FEC_Daily_Retail_Number__c\": null,' +
    //             '\"FEC_Date_Assigned__c\": null,' +
    //             '\"FEC_Date_of_Birth__c\": null,' +
    //             '\"FEC_Date_of_Issue__c\": null,' +
    //             '\"FEC_Days_Past_Due__c\": null,' +
    //             '\"FEC_Debt_Sale_Type__c\": null,' +
    //             '\"FEC_Delinquency_Date__c\": null,' +
    //             '\"FEC_Digital_Card_ID__c\": null,' +
    //             '\"FEC_Disbursement_Channel__c\": null,' +
    //             '\"FEC_Disbursement_Date__c\": null,' +
    //             '\"FEC_DSA_Code__c\": null,' +
    //             '\"FEC_DSA_Name__c\": null,' +
    //             '\"FEC_E_Commerce_Status__c\": null,' +
    //             '\"FEC_E_sign_Status__c\": null,' +
    //             '\"FEC_Effective_Date__c\": null,' +
    //             '\"FEC_Email__c\": null,' +
    //             '\"FEC_Embossing_Name__c\": null,' +
    //             '\"FEC_EMI__c\": null,' +
    //             '\"FEC_Expiry_Date__c\": null,' +
    //             '\"FEC_First_Effective_Date__c\": null,' +
    //             '\"FEC_First_Name__c\": null,' +
    //             '\"FEC_First_Payment_Date__c\": null,' +
    //             '\"FEC_First_Transaction_Amount__c\": null,' +
    //             '\"FEC_Fraud_Monitor_Date__c\": null,' +
    //             '\"FEC_Fraud_Monitor_Flag__c\": null,' +
    //             '\"FEC_Full_IPP_Payment_Amount__c\": null,' +
    //             '\"FEC_Full_Payment_Amount__c\": null,' +
    //             '\"FEC_Full_Payment_Without_IPP__c\": null,' +
    //             '\"FEC_Gender__c\": \"Male\",' +
    //             '\"FEC_Hold_Amount__c\": null,' +
    //             '\"FEC_Installments_Remaining__c\": null,' +
    //             '\"FEC_Insurance_Amount__c\": null,' +
    //             '\"FEC_Insurance_Flag__c\": null,' +
    //             '\"FEC_Interest_Sold__c\": null,' +
    //             '\"FEC_Is_Top_Up_Account__c\": null,' +
    //             '\"FEC_Last_Advance_Amount__c\": null,' +
    //             '\"FEC_Last_Advance_Date__c\": null,' +
    //             '\"FEC_Last_AF_Date__c\": null,' +
    //             '\"FEC_Last_Credit_Limit__c\": null,' +
    //             '\"FEC_Last_Credit_Limit_Date__c\": null,' +
    //             '\"FEC_Last_Effective_Date__c\": null,' +
    //             '\"FEC_Last_Name__c\": null,' +
    //             '\"FEC_Last_Payment_Amount__c\": null,' +
    //             '\"FEC_Last_Payment_Date__c\": null,' +
    //             '\"FEC_Last_PIN_Action_Date__c\": null,' +
    //             '\"FEC_Last_PIN_Status__c\": null,' +
    //             '\"FEC_Last_Statement_Date__c\": null,' +
    //             '\"FEC_Last_Transaction_Amount__c\": null,' +
    //             '\"FEC_Loan_Amount__c\": null,' +
    //             '\"FEC_Local_Use__c\": null,' +
    //             '\"FEC_Mailing_Address__c\": null,' +
    //             '\"FEC_Marital_Status__c\": null,' +
    //             '\"FEC_Memorable_Question__c\": null,' +
    //             '\"FEC_Middle_Name__c\": null,' +
    //             '\"FEC_Minimum_Payment_Due__c\": null,' +
    //             '\"FEC_Mobile_App_Account__c\": null,' +
    //             '\"FEC_National_ID_Passport_ID__c\": null,' +
    //             '\"FEC_Next_Due_Date__c\": null,' +
    //             '\"FEC_Next_Statement_Date__c\": null,' +
    //             '\"FEC_One_Time_Cash_Limit__c\": null,' +
    //             '\"FEC_One_Time_Ecommerce_Limit__c\": null,' +
    //             '\"FEC_One_Time_Retail_Limit__c\": null,' +
    //             '\"FEC_OTB__c\": null,' +
    //             '\"FEC_Payment_Due_Date__c\": null,' +
    //             '\"FEC_Payment_ID__c\": null,' +
    //             '\"FEC_PID_Number__c\": null,' +
    //             '\"FEC_Place_of_Issue__c\": null,' +
    //             '\"FEC_Plan_Payment_Amount__c\": null,' +
    //             '\"FEC_Plastic_ID__c\": null,' +
    //             '\"FEC_Policy_Number__c\": null,' +
    //             '\"FEC_Premium_Fee__c\": null,' +
    //             '\"FEC_Primary_Phone__c\": null,' +
    //             '\"FEC_Principal_Sold__c\": null,' +
    //             '\"FEC_Product_Association__c\": \"Not defined\",' +
    //             '\"FEC_Product_Code__c\": null,' +
    //             '\"FEC_Rate__c\": null,' +
    //             '\"FEC_Reason_1__c\": null,' +
    //             '\"FEC_Reason_2__c\": null,' +
    //             '\"FEC_Remark__c\": null,' +
    //             '\"FEC_Responsible_Person__c\": null,' +
    //             '\"FEC_Responsible_Unit__c\": null,' +
    //             '\"FEC_Sale_Channel__c\": null,' +
    //             '\"FEC_Scheme_Desc__c\": null,' +
    //             '\"FEC_Scheme_ID__c\": null,' +
    //             '\"FEC_Sold_Amount__c\": null,' +
    //             '\"FEC_Sold_Date__c\": null,' +
    //             '\"FEC_Sold_Note__c\": null,' +
    //             '\"FEC_Statement_Notification_Type__c\": null,' +
    //             '\"FEC_Status__c\": null,' +
    //             '\"FEC_Sub_Channel__c\": null,' +
    //             '\"FEC_Tenure__c\": null,' +
    //             '\"FEC_Top_Up_Loan_Amount_Requested__c\": null,' +
    //             '\"FEC_Top_Up_Old_Account_App_ID__c\": null,' +
    //             '\"FEC_Top_Up_Old_A_c_Outstanding__c\": 0,' +
    //             '\"FEC_Total_Accrued_Interest__c\": 0,' +
    //             '\"FEC_Total_Balance__c\": null,' +
    //             '\"FEC_Total_Close_Fee_Amount__c\": 0,' +
    //             '\"FEC_Total_Current_Balance__c\": 0,' +
    //             '\"FEC_Total_Deferred_Interest__c\": 0,' +
    //             '\"FEC_Total_IPP_Accrued_Interest__c\": 0,' +
    //             '\"FEC_Total_IPP_Balance__c\": 0,' +
    //             '\"FEC_Total_IPP_Current_Balance__c\": 0,' +
    //             '\"FEC_Total_Payment_Amount__c\": 0,' +
    //             '\"FEC_Total_Payment_Due__c\": null,' +
    //             '\"FEC_Total_Per_Diem__c\": 0,' +
    //             '\"FEC_Total_Plan_Payment_Amount__c\": 0,' +
    //             '\"FEC_TSA_Code__c\": null,' +
    //             '\"FEC_TSA_Name__c\": null,' +
    //             '\"FEC_User_ID__c\": null,' +
    //             '\"FEC_Warning_Code__c\": null,' +
    //             '\"FEC_Website_Account__c\": null,' +
    //             '\"FEC_Work_Phone__c\": null,' +
    //             '\"FEC_Zalo_Follower__c\": null' +
    //         '},' +
    //         '\"FEC_Product_Type__c\": \"a0a8600000CBiV4AAL\",' +
    //         '\"FEC_Category__c\": \"a0E86000000T4ugEAC\",' +
    //         '\"FEC_SubCategory__c\": \"a0j86000001EJF3AAO\",' +
    //         '\"FEC_SubCode__c\": \"a0k86000002Xf8ZAAS\",' +
    //         '\"FEC_New_Category__c\": null,' +
    //         '\"FEC_New_SubCategory__c\": null,' +
    //         '\"FEC_New_SubCode__c\": null,' +
    //         '\"FEC_Stage_Name__c\": \"Phone Update - Card - Stage 2\",' +
    //         '\"FEC_Complain_Type__c\": null,' +
    //         '\"FEC_Original_Info_Phone_Type__c\": \"Primary Phone\",' +
    //         '\"FEC_Actual_Nature_of_Case__c\": \"a0486000000G8rFAAS\",' +
    //         '\"FEC_Product_Type__r\": {' +
    //             '\"attributes\": {' +
    //             '\"type\": \"FEC_Product_Type__c\",' +
    //             '\"url\": \"/services/data/v66.0/sobjects/FEC_Product_Type__c/a0a8600000CBiV4AAL\"' +
    //             '},' +
    //             '\"Id\": \"a0a8600000CBiV4AAL\",' +
    //             '\"Name\": \"Card\",' +
    //             '\"FEC_Code__c\": \"Card\",' +
    //             '\"FEC_Name_VN__c\": \"Card\",' +
    //             '\"FEC_Alias__c\": \"Card\",' +
    //             '\"FEC_Order__c\": null' +
    //         '},' +
    //         '\"FEC_Category__r\": {' +
    //             '\"attributes\": {' +
    //             '\"type\": \"FEC_Category__c\",' +
    //             '\"url\": \"/services/data/v66.0/sobjects/FEC_Category__c/a0E86000000T4ugEAC\"' +
    //             '},' +
    //             '\"Id\": \"a0E86000000T4ugEAC\",' +
    //             '\"Name\": \"Request\",' +
    //             '\"FEC_Code__c\": \"Request\",' +
    //             '\"FEC_Name_VN__c\": \"Request\",' +
    //             '\"FEC_Alias__c\": \"Request\",' +
    //             '\"FEC_Order__c\": null' +
    //         '},' +
    //         '\"FEC_SubCategory__r\": {' +
    //             '\"attributes\": {' +
    //             '\"type\": \"FEC_Sub_Category__c\",' +
    //             '\"url\": \"/services/data/v66.0/sobjects/FEC_Sub_Category__c/a0j86000001EJF3AAO\"' +
    //             '},' +
    //             '\"Id\": \"a0j86000001EJF3AAO\",' +
    //             '\"Name\": \"RC09-Cập nhật thông tin\",' +
    //             '\"FEC_Code__c\": \"RC09\",' +
    //             '\"FEC_Alias__c\": \"RC09\",' +
    //             '\"FEC_Name_VN__c\": \"RC09-Cập nhật thông tin\",' +
    //             '\"FEC_Order__c\": null' +
    //         '},' +
    //         '\"FEC_SubCode__r\": {' +
    //             '\"attributes\": {' +
    //             '\"type\": \"FEC_Sub_Code__c\",' +
    //             '\"url\": \"/services/data/v66.0/sobjects/FEC_Sub_Code__c/a0k86000002Xf8ZAAS\"' +
    //             '},' +
    //             '\"Id\": \"a0k86000002Xf8ZAAS\",' +
    //             '\"Name\": \"RC09.01-Cập nhật số điện thoại\",' +
    //             '\"FEC_Code__c\": \"RC09.01\",' +
    //             '\"FEC_Name_VN__c\": \"RC09.01-Cập nhật số điện thoại\",' +
    //             '\"FEC_Alias__c\": \"RC09.01\",' +
    //             '\"FEC_Order__c\": null' +
    //         '},' +
    //         '\"FEC_New_Category__r\": null,' +
    //         '\"FEC_New_SubCategory__r\": null,' +
    //         '\"FEC_New_SubCode__r\": null,' +
    //         '\"FEC_Actual_Nature_of_Case__r\": {' +
    //             '\"attributes\": {' +
    //             '\"type\": \"FEC_Actual_Nature_of_Case__c\",' +
    //             '\"url\": \"/services/data/v66.0/sobjects/FEC_Actual_Nature_of_Case__c/a0486000000G8rFAAS\"' +
    //             '},' +
    //             '\"Id\": \"a0486000000G8rFAAS\",' +
    //             '\"Name\": \"a0486000000G8rF\",' +
    //             '\"FEC_Customer_Type__c\": \"Existing\",' +
    //             '\"FEC_User_Group__c\": \"CC;EC;F2F;IB;OB;QC;SP\",' +
    //             '\"FEC_Business_Process__c\": \"a0986000002fPPeAAM\",' +
    //             '\"FEC_Business_Process__r\": {' +
    //             '\"attributes\": {' +
    //                 '\"type\": \"FEC_Business_Process__c\",' +
    //                 '\"url\": \"/services/data/v66.0/sobjects/FEC_Business_Process__c/a0986000002fPPeAAM\"' +
    //             '},' +
    //             '\"Id\": \"a0986000002fPPeAAM\",' +
    //             '\"Name\": \"Phone Update\",' +
    //             '\"FEC_Code__c\": \"Phone Update\",' +
    //             '\"FEC_Alias__c\": \"Phone Update\",' +
    //             '\"FEC_Name_VN__c\": null,' +
    //             '\"FEC_Order__c\": null' +
    //             '},' +
    //             '\"FEC_Product_Type__r\": {' +
    //             '\"attributes\": {' +
    //                 '\"type\": \"FEC_Product_Type__c\",' +
    //                 '\"url\": \"/services/data/v66.0/sobjects/FEC_Product_Type__c/a0a8600000CBiV4AAL\"' +
    //             '},' +
    //             '\"Id\": \"a0a8600000CBiV4AAL\",' +
    //             '\"Name\": \"Card\",' +
    //             '\"FEC_Code__c\": \"Card\",' +
    //             '\"FEC_Alias__c\": \"Card\",' +
    //             '\"FEC_Name_VN__c\": \"Card\",' +
    //             '\"FEC_Order__c\": null' +
    //             '},' +
    //             '\"FEC_Category__r\": {' +
    //             '\"attributes\": {' +
    //                 '\"type\": \"FEC_Category__c\",' +
    //                 '\"url\": \"/services/data/v66.0/sobjects/FEC_Category__c/a0E86000000T4ugEAC\"' +
    //             '},' +
    //             '\"Id\": \"a0E86000000T4ugEAC\",' +
    //             '\"Name\": \"Request\",' +
    //             '\"FEC_Code__c\": \"Request\",' +
    //             '\"FEC_Alias__c\": \"Request\",' +
    //             '\"FEC_Name_VN__c\": \"Request\",' +
    //             '\"FEC_Order__c\": null' +
    //             '},' +
    //             '\"FEC_Sub_Category__r\": {' +
    //             '\"attributes\": {' +
    //                 '\"type\": \"FEC_Sub_Category__c\",' +
    //                 '\"url\": \"/services/data/v66.0/sobjects/FEC_Sub_Category__c/a0j86000001EJF3AAO\"' +
    //             '},' +
    //             '\"Id\": \"a0j86000001EJF3AAO\",' +
    //             '\"Name\": \"RC09-Cập nhật thông tin\",' +
    //             '\"FEC_Code__c\": \"RC09\",' +
    //             '\"FEC_Alias__c\": \"RC09\",' +
    //             '\"FEC_Name_VN__c\": \"RC09-Cập nhật thông tin\",' +
    //             '\"FEC_Order__c\": null' +
    //             '},' +
    //             '\"FEC_Sub_Code__r\": {' +
    //             '\"attributes\": {' +
    //                 '\"type\": \"FEC_Sub_Code__c\",' +
    //                 '\"url\": \"/services/data/v66.0/sobjects/FEC_Sub_Code__c/a0k86000002Xf8ZAAS\"' +
    //             '},' +
    //             '\"Id\": \"a0k86000002Xf8ZAAS\",' +
    //             '\"Name\": \"RC09.01-Cập nhật số điện thoại\",' +
    //             '\"FEC_Code__c\": \"RC09.01\",' +
    //             '\"FEC_Alias__c\": \"RC09.01\",' +
    //             '\"FEC_Name_VN__c\": \"RC09.01-Cập nhật số điện thoại\",' +
    //             '\"FEC_Order__c\": null' +
    //             '}' +
    //         '},' +
    //         '\"FEC_Service_Case_Owner__c\": \"thanh.vu.5\",' +
    //         '\"FEC_Final_Status__c\": \"Pending - CSOperations \",' +
    //         '\"FEC_Task__c\": null,' +
    //         '\"FEC_Remarks__c\": null,' +
    //         '\"FEC_Team__c\": \"CSOperations \",' +
    //         '\"FEC_Completed_User__c\": null,' +
    //         '\"FEC_Follow_Up_User__c\": \"00586000002D4FxAAK|R;00586000002CXNMAA4|R;00586000002CXNFAA4|R\",' +
    //         '\"FEC_Is_My_Follow_Up__c\": false,' +
    //         '\"FEC_Is_Submited__c\": true,' +
    //         '\"FEC_Is_Save_Closed__c\": false,' +
    //         '\"FEC_Draft_Remarks__c\": null,' +
    //         '\"FEC_SLA_Notification_1__c\": null,' +
    //         '\"FEC_SLA_Notification_2__c\": null,' +
    //         '\"FEC_SLA_Notification_3__c\": null,' +
    //         '\"FEC_FCR__c\": false,' +
    //         '\"FEC_Case_Created_On__c\": \"2026-03-03T15:50:55.000+0000\",' +
    //         '\"FEC_Case_Created_By__c\": \"trangll2\",' +
    //         '\"FEC_Last_Updated_On__c\": \"2026-03-27T03:00:13.000+0000\",' +
    //         '\"FEC_Last_Updated_By__c\": \"huyen.nguyen.7\",' +
    //         '\"CreatedDate\": \"2026-03-03T15:50:55.000+0000\",' +
    //         '\"LastModifiedDate\": \"2026-03-27T03:00:13.000+0000\",' +
    //         '\"ClosedDate\": null,' +
    //         '\"FEC_Link_ID__c\": \"<a href=\\\"/5008600000EfFe9\\\" target=\\\"_self\\\">S-0032</a>\",' +
    //         '\"FEC_Interaction_Status__c\": \"Auto-Closed\",' +
    //         '\"FEC_Case_ID__c\": \"<a href=\\\"/5008600000EfFe9\\\" target=\\\"_self\\\">S-0032</a>\",' +
    //         '\"FEC_Interaction_ID__c\": \"<a href=\\\"/5008600000EfEbg\\\" target=\\\"_self\\\">I-0016</a>\",' +
    //         '\"FEC_Customer_Username__c\": null,' +
    //         '\"FEC_Interaction_Owner__c\": null,' +
    //         '\"FEC_Original_Info_Phone_Number__c\": null,' +
    //         '\"FEC_Updated_Info_Phone_Number__c\": \"0987654332\",' +
    //         '\"FEC_Correct_Contract_Number__c\": null,' +
    //         '\"FEC_User_Email_ID__c\": null,' +
    //         '\"FEC_Is_In_Create_new_mode__c\": false,' +
    //         '\"FEC_Show_Action__c\": true,' +
    //         '\"FEC_Has_Account_or_Contract__c\": true,' +
    //         '\"EntitlementId\": null,' +
    //         '\"FEC_Business_Process__c\": null,' +
    //         '\"FEC_Business_Process__r\": null,' +
    //         '\"FEC_SLA_Violating_Warning__c\": null,' +
    //         '\"FEC_SLA_Warning__c\": null,' +
    //         '\"FEC_Genesys_Campaign__c\": null,' +
    //         '\"FEC_CS_D2C_Assessment_Type__c\": null,' +
    //         '\"FEC_CS_D2C_Risk_Level__c\": null,' +
    //         '\"FEC_Outcome_Code__c\": null,' +
    //         '\"FEC_Application_ID__c\": null,' +
    //         '\"FEC_ID_Search__c\": \"S-0032\",' +
    //         '\"FEC_Interaction_Masked_Phone__c\": null,' +
    //         '\"FEC_Case_Phone_Number__c\": null,' +
    //         '\"FEC_Account_Contract_Number_Text__c\": \"0001500040006525520\",' +
    //         '\"RecordTypeId\": \"012860000008vYzAAI\",' +
    //         '\"RecordType\": {' +
    //             '\"attributes\": {' +
    //             '\"type\": \"RecordType\",' +
    //             '\"url\": \"/services/data/v66.0/sobjects/RecordType/012860000008vYzAAI\"' +
    //             '},' +
    //             '\"Name\": \"Customer Case\"' +
    //         '},' +
    //         '\"Attachments\": [' +
    //             '{' +
    //             '\"s3Key\": \"cases/CASE-999/attachments/a1-b2-c3_contract.pdf\",' +
    //             '\"filename\": \"contract.pdf\",' +
    //             '\"contentType\": \"application/pdf\",' +
    //             '\"fileSize\": 25600,' +
    //             '\"uploadedAt\": \"2026-03-01T08:00:00Z\",' +
    //             '\"uploadedBy\": \"system_bot\"' +
    //             '},' +
    //             '{' +
    //             '\"s3Key\": \"cases/CASE-999/attachments/d4-e5-f6_signature.png\",' +
    //             '\"filename\": \"signature.png\",' +
    //             '\"contentType\": \"image/png\",' +
    //             '\"fileSize\": 512000,' +
    //             '\"uploadedAt\": \"2026-03-02T15:30:45Z\",' +
    //             '\"uploadedBy\": \"agent_07\"' +
    //             '}' +
    //         ']' +
    //         '}';
    //     return res;
    // }
}