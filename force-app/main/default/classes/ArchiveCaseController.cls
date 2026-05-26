/*------------------------------------------------------------
Author:        Thanh Van
Company:       Amaris
Description:   Handle Archive Case
Test Class:    ArchiveCaseController_Test
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/04/01     Thanh Van          Init
------------------------------------------------------------*/
public without sharing class ArchiveCaseController {

    @TestVisible private static List<AthenaCases__x> mockExternalRecords;
    public String errorMessage { get; set; }
    public Boolean hasError { get; set; }
    public static Boolean isCasePega = false;
    public AthenaCases__x athenaCaseRecord;

    // Lookup relationships to Case: FEC_IPP__c, FEC_Card_Payment__c, FEC_Process_Action__c, FEC_Integration_Case__c
    public static Map<String, String> masterDetailFieldsToCase = getMasterDetailOrLookupFieldsToCase(label.TECH_LIST_OBJ_IS_MASTER_DETAIL.split(','), true);
    public static List<String> listObjIsArchiveTemp = label.TECH_LIST_OBJ_IS_ARCHIVE_TEMP.split(',');
    public static Map<String, String> lookupFieldsToCase = getMasterDetailOrLookupFieldsToCase(listObjIsArchiveTemp, false);
    public static Map<String, String> CHILD_OBJECT_CASE_FIELD = new Map<String, String>();
    static {
        CHILD_OBJECT_CASE_FIELD.putAll(masterDetailFieldsToCase);
        CHILD_OBJECT_CASE_FIELD.putAll(lookupFieldsToCase);
    }

    public ArchiveCaseController(ApexPages.StandardController stdController) {
        this.athenaCaseRecord = (AthenaCases__x) stdController.getRecord();
        hasError = false;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Fetch Case from archive and redirect
    Returns:       PageReference
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/04/16      Thanh Van           Init
    ------------------------------------------------------------*/
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

            if (Test.isRunningTest() && mockExternalRecords != null) archiveCases = mockExternalRecords;
            else archiveCases = queryArchiveCases(sfIdForExternalRec, null);

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
    Description:   Query Archive Cases
    Returns:       
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2025/04/01      Thanh Van           Init
    ------------------------------------------------------------*/
    public static List<AthenaCases__x> queryArchiveCases(String sfIdForExternalRec, 
                                                        String archiveExternalInter) {

        String queryString = 'SELECT Id, ExternalId, s3_path__c,' 
                                + ' migration_source__c, case_id__c'
                                + ' FROM AthenaCases__x ' 
                                + ' WHERE';
        if (String.isNotBlank(sfIdForExternalRec)) queryString += ' Id = ' + '\''+ sfIdForExternalRec + '\'';
        else if (String.isNotBlank(archiveExternalInter)) queryString += ' case_id__c = ' + '\''+ archiveExternalInter + '\'';

        List<AthenaCases__x> archiveCases = Database.query(queryString);
        return archiveCases;
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
    public static Id getCaseDetailAndCreateCaseTemp(AthenaCases__x archiveCaseIns) {

        Id caseId;
        Map<String, Object> mapOfFieldAndValue = new Map<String, Object>();
        String methodOfApi = FEC_ConstantCommon.API_METHOD_GET;
        String recTypeName = label.TECH_CASE_RECORDTYPE_NAME_CUSTOMER_CASE;
        String archieveExternalId = archiveCaseIns.case_id__c;
        String migrationSourceStr = archiveCaseIns.migration_source__c;
        if (String.isNotBlank(migrationSourceStr)) {
            if (migrationSourceStr.containsIgnoreCase(label.TECH_PEGA_SOURCE) 
                & !migrationSourceStr.equalsIgnoreCase(label.TECH_PEGA_SOURCE_S3))
                migrationSourceStr = Label.TECH_PEGA_SOURCE_S3;

            migrationSourceStr = migrationSourceStr.toUpperCase();
            isCasePega = migrationSourceStr.containsIgnoreCase(label.TECH_PEGA_SOURCE) ? true : false;
        }
        String migrationSource = String.isNotBlank(migrationSourceStr) ? migrationSourceStr : '';
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
        String specialArchiveFieldSt = Label.TECH_LIST_SPECIAL_ARCHIVE_FIELD_AND_OBJECT;
        Map<String, String> mapSpecialArchiveField = (Map<String, String>) JSON.deserialize(specialArchiveFieldSt, Map<String, String>.class);
        Map<String, String> mapSpecialArchiveFieldAndValue = new Map<String, String>();
        Map<String, Map<String, Object>> mapRelationshipObjects = new Map<String, Map<String, Object>>();
        Map<String, List<Map<String, Object>>> mapChildRecords = new Map<String, List<Map<String, Object>>>();
        List<Map<String, Object>> attachmentsList = new List<Map<String, Object>>();

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

                if (mapSpecialArchiveField.get(keyOfAtt) != null) mapSpecialArchiveFieldAndValue.put(keyOfAtt, (String) jsonDetailCase.get(keyOfAtt));
            }
        }

        System.debug('mapOfFieldAndValue ' + mapOfFieldAndValue);
        System.debug('mapRelationshipObjects keys ' + mapRelationshipObjects.keySet());
        System.debug('mapChildRecords keys ' + mapChildRecords.keySet());

        if (mapOfFieldAndValue.size() > 0) {
            Map<String, Schema.SObjectField> fieldMap = Case.sObjectType.getDescribe().fields.getMap();
            Set<String> setPotentialIds = new Set<String>();
            Map<String, UserRecordAccess> mapIdCanAccess;
            List<BusinessHours> businessHours = [SELECT Id FROM BusinessHours WHERE IsActive = TRUE AND IsDefault = TRUE];

            Case caseIns = new Case();

            // Resolve lookup objects to real Ids in current org
            resolveRelationshipLookups(mapOfFieldAndValue, mapRelationshipObjects);
            buildSetPotentialIds(setPotentialIds, fieldMap, mapOfFieldAndValue);
            mapIdCanAccess = getRelatedRecordCanAccess(setPotentialIds);
            System.debug('mapIdCanAccess ' + mapIdCanAccess);

            buildCaseFieldsAndValue(fieldMap, mapOfFieldAndValue, caseIns, mapIdCanAccess);
            Id recTypeIdOfThisRecord = getRecordTypeId(recTypeName);
            caseIns.ArchiveExternalId__c = archieveExternalId;
            caseIns.FEC_ID_Search__c = archieveExternalId;
            caseIns.RecordTypeId = recTypeIdOfThisRecord;
            caseIns.ArchiveAttachment__c = attachmentStr;
            caseIns.ArchiveMigrationSource__c = migrationSource;
            if (!businessHours.isEmpty()) caseIns.BusinessHoursId = businessHours[0].Id;
            processSpecialValueForCase(caseIns);
            caseId = saveCaseRecord(caseIns);

            // Insert child records (master-detail) after Case is created
            if (caseId != null) {
                Id interactionRtId = FEC_CommonUltils.getRecordTypeIdByDev(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME);

                if (!mapChildRecords.isEmpty()) insertChildRecords(caseId, mapChildRecords, 
                                                                recTypeIdOfThisRecord, interactionRtId, 
                                                                mapSpecialArchiveField.values());

                Id interactionCaseId = getInteractionCaseId(caseIns.ArchiveInteractionId__c, interactionRtId);
                updatesSpecialValueForCases(caseId, interactionCaseId, interactionRtId, 
                                            mapSpecialArchiveFieldAndValue, 
                                            mapSpecialArchiveField);
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
    public static void resolveRelationshipLookups(Map<String, Object> mapOfFieldAndValue, 
                                                Map<String, Map<String, Object>> mapRelationshipObjects) {

        if (mapRelationshipObjects.isEmpty()) return;

        // These 3 fields are not used in the system. Also checked the function (Where is this used ?)
        // FEC_New_Category__c, FEC_New_SubCategory__c, FEC_New_SubCode__c

        String codeField = 'FEC_Code__c';
        List<String> lookupFieldNames = label.TECH_LIST_FIELD_PARENT_OF_CASE.split(',');
        Map<String, String> mapObjNameAndFieldOnCase = getLookupObjectMapByFields(lookupFieldNames);

        for (String objName : mapObjNameAndFieldOnCase.keySet()) {
            String fieldOnCase = mapObjNameAndFieldOnCase.get(objName);
            resolveByCode(mapOfFieldAndValue, mapRelationshipObjects,
                        objName, fieldOnCase.toLowerCase(),
                        objName, codeField);
        }

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
                castAndSetFieldValue(tempRec, key, val, fd, new Map<String, UserRecordAccess>{});
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
    public static String extractNestedCode(Map<String, Object> parentObj, String relKey, String codeField) {
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
    public static Id resolveIdByCode(String sObjectApiName, String codeField, String codeValue) {
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
            String valueStr = String.valueOf(rawValue);
            if (!valueStr.contains('-') && valueStr.length() == 8) {
                valueStr = valueStr.substring(0, 4) + '-' + 
                          valueStr.substring(4, 6) + '-' + 
                          valueStr.substring(6, 8);
            }
            record.put(fieldName, Date.valueOf(valueStr));
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
    private static void insertChildRecords(Id caseId, Map<String, List<Map<String, Object>>> mapChildRecords, 
                                            Id recTypeIdOfThisRecord, Id interactionRtId, 
                                            List<String> listSpecialArchiveObject) {

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
                List<SObject> recordsToInsert = buildChildSObjects(sObjectApiName, caseFieldName, 
                                                                    caseId, childDataList, 
                                                                    listSpecialArchiveObject);
                if (!recordsToInsert.isEmpty()) {
                    insert recordsToInsert;
                    System.debug('insertChildRecords: Inserted ' + recordsToInsert.size() + ' records for ' + sObjectApiName);

                    // Handle nested child records (e.g. FEC_Address_Info__c inside FEC_Customer_History__c)
                    if (sObjectApiName == 'FEC_Customer_History__c') {
                        insertNestedAddressInfo(recordsToInsert, childDataList, listSpecialArchiveObject);
                    }
                }
            } catch (Exception ex) {
                System.debug('insertChildRecords failed for ' + sObjectApiName + ': ' + ex.getMessage());
            }
        }
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Insert FEC_Address_Info__c records nested inside FEC_Customer_History__c.
                   FEC_Address_Info__c has a Master-Detail to FEC_Customer_History__c.
                   After FEC_Customer_History__c records are inserted, extract nested
                   FEC_Address_Info__c arrays and insert them with the correct parent Id.
    Returns:       void
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/05/18      Thanh Van           Init
    ------------------------------------------------------------*/
    private static void insertNestedAddressInfo(List<SObject> insertedCustHistRecords, 
                                                 List<Map<String, Object>> custHistDataList,
                                                 List<String> listSpecialArchiveObject) {
        // insertedCustHistRecords and custHistDataList are in the same order
        for (Integer i = 0; i < custHistDataList.size(); i++) {
            Map<String, Object> custHistData = custHistDataList[i];
            Object addressInfoObj = custHistData.get('FEC_Address_Info__c');
            if (addressInfoObj == null) continue;

            List<Map<String, Object>> addressInfoList = new List<Map<String, Object>>();
            if (addressInfoObj instanceof List<Object>) {
                for (Object item : (List<Object>) addressInfoObj) {
                    if (item instanceof Map<String, Object>) {
                        addressInfoList.add((Map<String, Object>) item);
                    }
                }
            } else if (addressInfoObj instanceof Map<String, Object>) {
                // Single record case
                addressInfoList.add((Map<String, Object>) addressInfoObj);
            }

            if (addressInfoList.isEmpty()) continue;

            Id custHistId = insertedCustHistRecords[i].Id;
            try {
                // FEC_Address_Info__c Master-Detail field to FEC_Customer_History__c
                List<SObject> addressRecords = buildChildSObjects('FEC_Address_Info__c', 
                                                                   'FEC_Customer_History__c', 
                                                                   custHistId, addressInfoList,
                                                                   listSpecialArchiveObject);
                if (!addressRecords.isEmpty()) {
                    Object caseRef = insertedCustHistRecords[i].get('FEC_Case__c');
                    if (caseRef != null) {
                        for (SObject addrRec : addressRecords) {
                            addrRec.put('FEC_Case__c', (Id) caseRef);
                        }
                    }

                    insert addressRecords;
                    System.debug('insertNestedAddressInfo: Inserted ' + addressRecords.size() + ' FEC_Address_Info__c for CustHist ' + custHistId);
                }
            } catch (Exception ex) {
                System.debug('insertNestedAddressInfo failed for CustHist ' + custHistId + ': ' + ex.getMessage());
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
                                                     Id caseId, List<Map<String, Object>> childDataList, 
                                                     List<String> listSpecialArchiveObject) {
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
            if (listObjIsArchiveTemp.contains(sObjectApiName)) rec.put('IsArchiveTemp__c', true);

            for (String key : childData.keySet()) {
                Object val = childData.get(key);
                if (val == null) continue;

                if (key == 'Id' 
                    && listSpecialArchiveObject.contains(sObjectApiName)) rec.put('ArchiveExternalId__c', String.valueOf(val));

                if (key == 'attributes' || key == 'Id') continue;
                // Skip the Case lookup field — already set above
                if (key == caseFieldName) continue;

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

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Get Interaction Case Id
    Returns:       
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2025/04/01      Thanh Van           Init
    ------------------------------------------------------------*/
    public static Id getInteractionCaseId(String archieveInteractionId, Id interactionRtId) {
        Id interactionCaseId;
        List<Case> interractionCases = [SELECT Id FROM Case 
                                        WHERE ArchiveExternalId__c = :archieveInteractionId 
                                        AND RecordTypeId = :interactionRtId 
                                        AND ArchiveExternalId__c != NULL 
                                        AND ArchiveExternalId__c != '' 
                                        LIMIT 1];

        interactionCaseId = !interractionCases.isEmpty() ? interractionCases[0].Id : null;
        return interactionCaseId;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Updates Special Value For Cases
    Returns:       
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2025/04/01      Thanh Van           Init
    ------------------------------------------------------------*/
    public static void updatesSpecialValueForCases(Id caseId, 
                                            Id interactionCaseId, Id interactionRtId, 
                                            Map<String, String> mapSpecialArchiveFieldAndValue, 
                                            Map<String, String> mapSpecialArchiveField) {

        List<Case> listCaseUpdated = new List<Case>();
        Map<String, String> mapIdRecOfSpecialObj = new Map<String, String>();
        getIdRecOfSpecialObject(mapSpecialArchiveFieldAndValue, mapSpecialArchiveField, 
                                mapIdRecOfSpecialObj, caseId);
        for (Case caseIns : [SELECT Id, FEC_Interaction__c, RecordTypeId, 
                            FEC_Account_or_Contract__c, FEC_Selected_Address__c 
                            FROM Case 
                            WHERE Id = :caseId]) {

            if (interactionCaseId != null && caseIns.RecordTypeId != interactionRtId 
                && String.isBlank(caseIns.FEC_Interaction__c)) 
                caseIns.FEC_Interaction__c = interactionCaseId;

            for (String specialFieldName : mapIdRecOfSpecialObj.keySet()) {
                if (String.isBlank((String) caseIns.get(specialFieldName))) {
                    caseIns.put(specialFieldName, mapIdRecOfSpecialObj.get(specialFieldName));
                }
            }

            listCaseUpdated.add(caseIns);
        }

        // Query all Customer Case to update FEC_Interaction__c
        // Except the current case (caseId variable)
        List<Case> interactionCase = [SELECT Id, ArchiveInteractionId__c 
                                        FROM Case 
                                        WHERE Id = :interactionCaseId 
                                        AND RecordTypeId = :interactionRtId
                                        LIMIT 1];
        if (!interactionCase.isEmpty()) {
            Case interactionIns = interactionCase[0];
            String archiveInteractionId = interactionIns.ArchiveInteractionId__c;
            List<Case> listAllCases = new List<Case>();
            List<String> listArchiveAccOrContract = new List<String>();
            List<String> listArchiveSelectedAddr = new List<String>();
            Map<String, String> mapCusHistoryAndId = new Map<String, String>();
            Map<String, String> mapAddrInfoAndId = new Map<String, String>();
            String cusHistoryId = '';
            String addrInfoId = '';

            for (Case caseIns : [SELECT Id, FEC_Interaction__c, RecordTypeId, 
                                FEC_Account_or_Contract__c, FEC_Selected_Address__c, 
                                ArchiveAccOrContract__c, ArchiveSelectedAddress__c 
                                FROM Case 
                                WHERE ArchiveInteractionId__c = :archiveInteractionId 
                                AND Id != :caseId]) {

                listAllCases.add(caseIns);
                listArchiveAccOrContract.add(caseIns.ArchiveAccOrContract__c);
                listArchiveSelectedAddr.add(caseIns.ArchiveSelectedAddress__c);
            }

            mapCusHistoryAndId = getMapCusHistoryArchiveId(listArchiveAccOrContract);
            mapAddrInfoAndId = getMapAddrInfoArchiveId(listArchiveSelectedAddr);

            for (Case caseIns : listAllCases) {
                if (caseIns.RecordTypeId != interactionRtId 
                    && String.isBlank(caseIns.FEC_Interaction__c)) 
                    caseIns.FEC_Interaction__c = interactionCaseId;

                cusHistoryId = mapCusHistoryAndId.get(caseIns.ArchiveAccOrContract__c);
                if (String.isNotBlank(cusHistoryId)) 
                    caseIns.FEC_Account_or_Contract__c = cusHistoryId;

                addrInfoId = mapAddrInfoAndId.get(caseIns.ArchiveSelectedAddress__c);
                if (String.isNotBlank(addrInfoId)) 
                    caseIns.FEC_Selected_Address__c = addrInfoId;

                listCaseUpdated.add(caseIns);
            }
        }

        System.debug('listCaseUpdated ' + listCaseUpdated);
        if (!listCaseUpdated.isEmpty()) update listCaseUpdated;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Get Id Record Of Special Object
    Returns:       
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2025/04/01      Thanh Van           Init
    ------------------------------------------------------------*/
    public static void getIdRecOfSpecialObject(Map<String, String> mapSpecialArchiveFieldAndValue, 
                                            Map<String, String> mapSpecialArchiveField, 
                                            Map<String, String> mapIdRecOfSpecialObj, 
                                            Id caseId) {

        for (String archiveField : mapSpecialArchiveFieldAndValue.keySet()) {
            String valueOfArchiveFiled = mapSpecialArchiveFieldAndValue.get(archiveField);
            // Ex: specialObj = FEC_Customer_History__c or FEC_Address_Info__c
            String specialObj = mapSpecialArchiveField.get(archiveField);
            
            // Need to put the query in the loop.
            // The mapIdRecOfSpecialObj just have some object
            if (specialObj != null && valueOfArchiveFiled != null) {
                String queryStr = 'SELECT Id FROM ' + specialObj 
                                + ' WHERE ArchiveExternalId__c =' 
                                + ' :valueOfArchiveFiled LIMIT 1';
                List<SObject> recOfspecialObjs = Database.query(queryStr);

                if (!recOfspecialObjs.isEmpty()) mapIdRecOfSpecialObj.put(archiveField, recOfspecialObjs[0].Id);
            }
        }

        // If case is from Pega. We just need to query the child record and link it to special archive field
        if (isCasePega) {
            for (String archiveFieldIns : mapSpecialArchiveField.keySet()) {
                String specialObjIns = mapSpecialArchiveField.get(archiveFieldIns);

                String queryStr = 'SELECT Id FROM ' + specialObjIns 
                                + ' WHERE FEC_Case__c =' 
                                + ' :caseId LIMIT 1';
                List<SObject> recOfspecialObjs = Database.query(queryStr);

                if (!recOfspecialObjs.isEmpty()) mapIdRecOfSpecialObj.put(archiveFieldIns, recOfspecialObjs[0].Id);
            }
        }
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Get Map Customer History Archive Id
    Returns:       
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2025/04/01      Thanh Van           Init
    ------------------------------------------------------------*/
    public static Map<String, String> getMapCusHistoryArchiveId(List<String> listArchiveAccOrContract) {
        Map<String, String> mapCusHistoryAndId = new Map<String, String>();
        for (FEC_Customer_History__c cusHisIns : [SELECT Id, ArchiveExternalId__c 
                                                FROM FEC_Customer_History__c 
                                                WHERE ArchiveExternalId__c IN :listArchiveAccOrContract]) {
            mapCusHistoryAndId.put(cusHisIns.ArchiveExternalId__c, cusHisIns.Id);
        }

        return mapCusHistoryAndId;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Get Map Address Info Archive Id
    Returns:       
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2025/04/01      Thanh Van           Init
    ------------------------------------------------------------*/
    public static Map<String, String> getMapAddrInfoArchiveId(List<String> listArchiveSelectedAddr) {
        Map<String, String> mapAddrInfoAndId = new Map<String, String>();
        for (FEC_Address_Info__c addrInfoIns : [SELECT Id, ArchiveExternalId__c 
                                                FROM FEC_Address_Info__c 
                                                WHERE ArchiveExternalId__c IN :listArchiveSelectedAddr]) {
            mapAddrInfoAndId.put(addrInfoIns.ArchiveExternalId__c, addrInfoIns.Id);
        }

        return mapAddrInfoAndId;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   For a given list of lookup field API names on Case,
                   find the related object each field references.
                   Returns Map<String, String> where:
                     Key   = Related Object API Name (e.g. 'FEC_Sub_Category__c')
                     Value = Field API Name on Case (e.g. 'FEC_SubCategory__c')
    Returns:       Map<String, String>
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/05/22      Thanh Van           Init
    ------------------------------------------------------------*/
    public static Map<String, String> getLookupObjectMapByFields(List<String> lookupFieldNames) {
        Map<String, String> result = new Map<String, String>();
        Map<String, Schema.SObjectField> caseFieldMap = Case.sObjectType.getDescribe().fields.getMap();

        for (String fieldName : lookupFieldNames) {
            String trimmed = fieldName.trim();
            String fieldKey = trimmed.toLowerCase();
            if (!caseFieldMap.containsKey(fieldKey)) continue;

            Schema.DescribeFieldResult fieldDesc = caseFieldMap.get(fieldKey).getDescribe();
            if (fieldDesc.getType() != Schema.DisplayType.REFERENCE) continue;

            List<Schema.SObjectType> referenceTo = fieldDesc.getReferenceTo();
            if (!referenceTo.isEmpty()) {
                String objApiName = referenceTo[0].getDescribe().getName();
                result.put(objApiName, trimmed);
            }
        }

        return result;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Get Master-Detail / Lookup fields to Case for a list of child objects.
    Returns:       Map<String, String>
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/05/18      Thanh Van           Init
    ------------------------------------------------------------*/
    public static Map<String, String> getMasterDetailOrLookupFieldsToCase(List<String> objectApiNames, 
                                                                        Boolean checkMasterDetail) {
        Map<String, String> result = new Map<String, String>();

        for (String objName : objectApiNames) {
            String trimmedName = objName.trim();
            Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(trimmedName);
            if (sObjType == null) continue;

            Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe().fields.getMap();
            for (Schema.SObjectField field : fieldMap.values()) {
                Schema.DescribeFieldResult fieldRs = field.getDescribe();
                if (fieldRs.getType() != Schema.DisplayType.REFERENCE) continue;

                // Master-Detail is NOT nillable
                // Lookup IS nillable
                if (checkMasterDetail && fieldRs.isNillable()) continue;
                else if (!checkMasterDetail && !fieldRs.isNillable()) continue;

                for (Schema.SObjectType refTo : fieldRs.getReferenceTo()) {
                    if (refTo == Case.SObjectType) {
                        result.put(trimmedName, fieldRs.getName());
                        break;
                    }
                }
                if (result.containsKey(trimmedName)) break;
            }
        }

        return result;
    }
}