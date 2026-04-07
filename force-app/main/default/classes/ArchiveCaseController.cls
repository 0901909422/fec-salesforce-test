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

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Get Or Create Case temp
    Returns:       
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2025/04/01      Thanh Van           Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static Id getOrCreateCase(String sfIdForExternalRec) {
        System.debug('sfIdForExternalRec ' + sfIdForExternalRec);

        Id caseId;
        List<AthenaCases__x> archiveCases;

        if (Test.isRunningTest() && mockExternalRecords != null) {
            archiveCases = mockExternalRecords;
        } else {
            archiveCases = [SELECT Id, ExternalId 
                            FROM AthenaCases__x 
                            WHERE Id = :sfIdForExternalRec];
        }

        if (archiveCases.isEmpty()) return null;

        AthenaCases__x archiveCaseIns = archiveCases[0];
        List<Case> cases = [SELECT Id, RecordTypeId FROM Case 
                            WHERE ArchiveExternalId__c = :archiveCaseIns.ExternalId];
        if (!cases.isEmpty()) caseId = cases[0].Id;
        else {
            caseId = getCaseDetailAndCreateCaseTemp(archiveCaseIns);
        }

        return caseId;
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
        String strRelationship = '__r';
        List<String> listOfAttIgnored = label.TECH_LIST_ATT_IGNORED.split(',');

        // TODO: Need to use this setting. For now the endpoint is just for testing
        // s3://fec-integration-s3/pegacsm/archive/2022/10/27/FC-6016.json
        String endpoint = FEC_MockupEndpoint.GET_CASE_ARCHIVE_ENDPOINT_MOCKUP;
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(label.TECH_API_GET_ARCHIVE_DETAIL_CASE);
        if (apiConfig != null) {
            endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_CASE_ARCHIVE_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
        }

        Map<String,String> headers = new Map<String,String>{
            'X-API-KEY' => 'RkVDX1NBTEVTRk9SQ0U='
        };
        HttpResponse resp = FEC_CommonUltils.calloutApiWithHeaders(endpoint, methodOfApi, headers, null);
        System.debug('resp.getStatusCode() ' + resp.getStatusCode());
        System.debug('resp.getBody() ' + resp.getBody());

        // Collect __r relationship objects separately for lookup resolution
        Map<String, Map<String, Object>> mapRelationshipObjects = new Map<String, Map<String, Object>>();
        List<Map<String, Object>> attachmentsList = new List<Map<String, Object>>();

        if (resp.getStatusCode() == 200 || resp.getStatusCode() == 201) {
            Map<String, Object> jsonDetailCase = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());

            for (String keyOfAtt : jsonDetailCase.keySet()) {
                if (listOfAttIgnored.contains(keyOfAtt)) continue;

                if (keyOfAtt == 'RecordType') {
                    try {
                        Map<String, Object> objChild = (Map<String, Object>) jsonDetailCase.get(keyOfAtt);
                        recTypeName = (String) objChild.get('Name');
                    } catch (Exception ex) {
                        recTypeName = (String) jsonDetailCase.get(keyOfAtt);
                    }
                    continue;
                }

                // Parse Attachments array separately — handled via Queueable after Case insert
                if (keyOfAtt == 'Attachments') {
                    try {
                        List<Object> rawList = (List<Object>) jsonDetailCase.get(keyOfAtt);
                        for (Object item : rawList) {
                            attachmentsList.add((Map<String, Object>) item);
                        }
                    } catch (Exception ex) {
                        System.debug('Could not parse Attachments array: ' + ex.getMessage());
                    }
                    continue;
                }

                // Collect __r objects for lookup resolution; skip adding them as direct field values
                if (keyOfAtt.endsWith(strRelationship)) {
                    Object relObj = jsonDetailCase.get(keyOfAtt);
                    if (relObj != null) {
                        try {
                            mapRelationshipObjects.put(keyOfAtt, (Map<String, Object>) relObj);
                        } catch (Exception ex) {
                            System.debug('Could not cast __r object for key: ' + keyOfAtt);
                        }
                    }
                    continue;
                }

                mapOfFieldAndValue.put(keyOfAtt.toLowerCase(), jsonDetailCase.get(keyOfAtt));
            }
        }
        FEC_CommonUltils.logApi(label.TECH_API_GET_ARCHIVE_DETAIL_CASE, endpoint, methodOfApi, null, resp, null);

        System.debug('mapOfFieldAndValue ' + mapOfFieldAndValue);
        System.debug('mapRelationshipObjects keys ' + mapRelationshipObjects.keySet());

        if (mapOfFieldAndValue.size() > 0) {
            Case caseIns = new Case();
            caseIns.ArchiveExternalId__c = archiveCaseIns.ExternalId;
            caseIns.RecordTypeId = getRecordTypeId(recTypeName);

            // Resolve __r lookup objects to real Ids in current org
            resolveRelationshipLookups(mapOfFieldAndValue, mapRelationshipObjects);

            Map<String, Schema.SObjectField> fieldMap = Case.sObjectType.getDescribe().fields.getMap();
            Set<String> setPotentialIds = new Set<String>();
            buildSetPotentialIds(setPotentialIds, fieldMap, mapOfFieldAndValue);
            Map<String, UserRecordAccess> mapIdCanAccess = getRelatedRecordCanAccess(setPotentialIds);
            System.debug('mapIdCanAccess ' + mapIdCanAccess);

            buildCaseFieldsAndValue(fieldMap, mapOfFieldAndValue, caseIns, mapIdCanAccess);
            caseId = saveCaseRecord(caseIns);

            // Enqueue attachment download chain — must be in separate transaction (after DML)
            // TODO: Need to use this for inserting the attachment. For now, we have no the endpoint
            if (caseId != null && !attachmentsList.isEmpty()) {
                //System.enqueueJob(new ArchiveCaseAttachmentQueueable(caseId, attachmentsList, 0));
            }
        }

        return caseId;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Resolve __r relationship objects to real Ids in current org.
                   IDs from the archive JSON are deleted and cannot be reused.
                   We match records by their unique code/name fields instead.
    Returns:       void (mutates mapOfFieldAndValue in place)
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/04/07      Thanh Van           Init
    ------------------------------------------------------------*/
    public static void resolveRelationshipLookups(
        Map<String, Object> mapOfFieldAndValue,
        Map<String, Map<String, Object>> mapRelationshipObjects
    ) {
        if (mapRelationshipObjects.isEmpty()) return;

        // --- Simple code-based lookups ---
        // FEC_Product_Type__c → FEC_Product_Type__c.FEC_Code__c
        resolveByCode(mapOfFieldAndValue, mapRelationshipObjects,
            'FEC_Product_Type__r', 'fec_product_type__c',
            'FEC_Product_Type__c', 'FEC_Code__c');

        // FEC_Category__c → FEC_Category__c.FEC_Code__c
        resolveByCode(mapOfFieldAndValue, mapRelationshipObjects,
            'FEC_Category__r', 'fec_category__c',
            'FEC_Category__c', 'FEC_Code__c');

        // FEC_SubCategory__c → FEC_Sub_Category__c.FEC_Code__c
        resolveByCode(mapOfFieldAndValue, mapRelationshipObjects,
            'FEC_SubCategory__r', 'fec_subcategory__c',
            'FEC_Sub_Category__c', 'FEC_Code__c');

        // FEC_SubCode__c → FEC_Sub_Code__c.FEC_Code__c
        resolveByCode(mapOfFieldAndValue, mapRelationshipObjects,
            'FEC_SubCode__r', 'fec_subcode__c',
            'FEC_Sub_Code__c', 'FEC_Code__c');

        // FEC_New_Category__c
        resolveByCode(mapOfFieldAndValue, mapRelationshipObjects,
            'FEC_New_Category__r', 'fec_new_category__c',
            'FEC_Category__c', 'FEC_Code__c');

        // FEC_New_SubCategory__c
        resolveByCode(mapOfFieldAndValue, mapRelationshipObjects,
            'FEC_New_SubCategory__r', 'fec_new_subcategory__c',
            'FEC_Sub_Category__c', 'FEC_Code__c');

        // FEC_New_SubCode__c
        resolveByCode(mapOfFieldAndValue, mapRelationshipObjects,
            'FEC_New_SubCode__r', 'fec_new_subcode__c',
            'FEC_Sub_Code__c', 'FEC_Code__c');

        // FEC_Business_Process__c → FEC_Business_Process__c.FEC_Code__c
        resolveByCode(mapOfFieldAndValue, mapRelationshipObjects,
            'FEC_Business_Process__r', 'fec_business_process__c',
            'FEC_Business_Process__c', 'FEC_Code__c');

        // --- FEC_Account_or_Contract__c → FEC_Customer_History__c matched by Name (account number) ---
        if (mapRelationshipObjects.containsKey('FEC_Account_or_Contract__r')) {
            Map<String, Object> relObj = mapRelationshipObjects.get('FEC_Account_or_Contract__r');
            String accountName = (String) relObj.get('Name');
            if (String.isNotBlank(accountName)) {
                List<FEC_Customer_History__c> matches = [
                    SELECT Id FROM FEC_Customer_History__c
                    WHERE Name = :accountName LIMIT 1
                ];
                if (!matches.isEmpty()) {
                    mapOfFieldAndValue.put('fec_account_or_contract__c', matches[0].Id);
                } else {
                    Id tempId = insertTempRecord('FEC_Customer_History__c', relObj);
                    mapOfFieldAndValue.put('fec_account_or_contract__c', tempId);
                }
            }
        }

        // --- FEC_Interaction__c → Case matched by ArchiveExternalId__c ---
        // The __r key for this is FEC_Interaction__r (not present in JSON sample but handle defensively)
        if (mapRelationshipObjects.containsKey('FEC_Interaction__r')) {
            Map<String, Object> relObj = mapRelationshipObjects.get('FEC_Interaction__r');
            String extId = (String) relObj.get('ArchiveExternalId__c');
            if (String.isNotBlank(extId)) {
                List<Case> matches = [SELECT Id FROM Case WHERE ArchiveExternalId__c = :extId LIMIT 1];
                if (!matches.isEmpty()) {
                    mapOfFieldAndValue.put('fec_interaction__c', matches[0].Id);
                } else {
                    mapOfFieldAndValue.put('fec_interaction__c', null);
                }
            }
        }

        // --- FEC_Interaction_Resolved_By__c → User matched by Username ---
        if (mapRelationshipObjects.containsKey('FEC_Interaction_Resolved_By__r')) {
            Map<String, Object> relObj = mapRelationshipObjects.get('FEC_Interaction_Resolved_By__r');
            String username = (String) relObj.get('Username');
            if (String.isNotBlank(username)) {
                List<User> matches = [SELECT Id FROM User WHERE Username = :username AND IsActive = true LIMIT 1];
                if (!matches.isEmpty()) {
                    mapOfFieldAndValue.put('fec_interaction_resolved_by__c', matches[0].Id);
                } else {
                    mapOfFieldAndValue.put('fec_interaction_resolved_by__c', null);
                }
            }
        }

        // --- FEC_Actual_Nature_of_Case__c → composite match on ProductType + Category + SubCategory + SubCode + BusinessProcess ---
        // Must be resolved AFTER the individual lookups above so we can use the resolved Ids
        resolveActualNatureOfCase(mapOfFieldAndValue, mapRelationshipObjects);
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Resolve a simple lookup field by querying the target object using FEC_Code__c
                   from the corresponding __r relationship object in the JSON.
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/04/07      Thanh Van           Init
    ------------------------------------------------------------*/
    private static void resolveByCode(
        Map<String, Object> mapOfFieldAndValue,
        Map<String, Map<String, Object>> mapRelationshipObjects,
        String relKey,           // e.g. 'FEC_Product_Type__r'
        String fieldKeyLower,    // e.g. 'fec_product_type__c'  (lowercase, as stored in map)
        String sObjectApiName,   // e.g. 'FEC_Product_Type__c'
        String codeField         // e.g. 'FEC_Code__c'
    ) {
        if (!mapRelationshipObjects.containsKey(relKey)) return;

        Map<String, Object> relObj = mapRelationshipObjects.get(relKey);
        String codeValue = (String) relObj.get(codeField);
        if (String.isBlank(codeValue)) return;

        String soql = 'SELECT Id FROM ' + sObjectApiName + ' WHERE ' + codeField + ' = :codeValue LIMIT 1';
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

                Schema.DisplayType ft = fd.getType();
                if (ft == Schema.DisplayType.STRING || ft == Schema.DisplayType.TEXTAREA
                    || ft == Schema.DisplayType.PICKLIST || ft == Schema.DisplayType.EMAIL
                    || ft == Schema.DisplayType.PHONE || ft == Schema.DisplayType.URL) {
                    tempRec.put(key, String.valueOf(val));
                } else if (ft == Schema.DisplayType.DOUBLE || ft == Schema.DisplayType.CURRENCY) {
                    tempRec.put(key, Decimal.valueOf(String.valueOf(val)));
                } else if (ft == Schema.DisplayType.INTEGER) {
                    tempRec.put(key, Integer.valueOf(String.valueOf(val)));
                } else if (ft == Schema.DisplayType.BOOLEAN) {
                    tempRec.put(key, Boolean.valueOf(String.valueOf(val)));
                } else if (ft == Schema.DisplayType.DATE) {
                    tempRec.put(key, Date.valueOf(String.valueOf(val)));
                } else if (ft == Schema.DisplayType.DATETIME) {
                    tempRec.put(key, Datetime.valueOfGMT(String.valueOf(val).replace('T', ' ')));
                }
                // Skip REFERENCE fields — nested __r inside __r are not resolved further
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
                   ProductType + Category + SubCategory + SubCode + BusinessProcess codes
                   extracted from the nested __r data inside FEC_Actual_Nature_of_Case__r.
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/04/07      Thanh Van           Init
    ------------------------------------------------------------*/
    private static void resolveActualNatureOfCase(
        Map<String, Object> mapOfFieldAndValue,
        Map<String, Map<String, Object>> mapRelationshipObjects
    ) {
        if (!mapRelationshipObjects.containsKey('FEC_Actual_Nature_of_Case__r')) return;

        Map<String, Object> nocObj = mapRelationshipObjects.get('FEC_Actual_Nature_of_Case__r');
        if (nocObj == null) return;

        // Extract codes from nested __r objects inside FEC_Actual_Nature_of_Case__r
        String productTypeCode  = extractNestedCode(nocObj, 'FEC_Product_Type__r',  'FEC_Code__c');
        String categoryCode     = extractNestedCode(nocObj, 'FEC_Category__r',      'FEC_Code__c');
        String subCategoryCode  = extractNestedCode(nocObj, 'FEC_Sub_Category__r',  'FEC_Code__c');
        String subCodeCode      = extractNestedCode(nocObj, 'FEC_Sub_Code__r',      'FEC_Code__c');
        String bizProcessCode   = extractNestedCode(nocObj, 'FEC_Business_Process__r', 'FEC_Code__c');

        System.debug('resolveActualNatureOfCase codes: ' + productTypeCode + '|' + categoryCode + '|' + subCategoryCode + '|' + subCodeCode + '|' + bizProcessCode);

        if (String.isBlank(productTypeCode) && String.isBlank(categoryCode) 
            && String.isBlank(subCategoryCode) && String.isBlank(subCodeCode)) {
            mapOfFieldAndValue.put('fec_actual_nature_of_case__c', null);
            return;
        }

        // Resolve each dimension to an Id first
        Id productTypeId  = resolveIdByCode('FEC_Product_Type__c',  'FEC_Code__c', productTypeCode);
        Id categoryId     = resolveIdByCode('FEC_Category__c',      'FEC_Code__c', categoryCode);
        Id subCategoryId  = resolveIdByCode('FEC_Sub_Category__c',  'FEC_Code__c', subCategoryCode);
        Id subCodeId      = resolveIdByCode('FEC_Sub_Code__c',      'FEC_Code__c', subCodeCode);
        Id bizProcessId   = resolveIdByCode('FEC_Business_Process__c', 'FEC_Code__c', bizProcessCode);

        // Build dynamic SOQL with only non-null conditions to avoid false negatives
        String soql = 'SELECT Id FROM FEC_Actual_Nature_of_Case__c WHERE ';
        List<String> conditions = new List<String>();

        if (productTypeId != null)  { conditions.add('FEC_Product_Type__c = \'' + productTypeId + '\''); }
        if (categoryId != null)     { conditions.add('FEC_Category__c = \'' + categoryId + '\''); }
        if (subCategoryId != null)  { conditions.add('FEC_Sub_Category__c = \'' + subCategoryId + '\''); }
        if (subCodeId != null)      { conditions.add('FEC_Sub_Code__c = \'' + subCodeId + '\''); }
        if (bizProcessId != null)   { conditions.add('FEC_Business_Process__c = \'' + bizProcessId + '\''); }

        if (conditions.isEmpty()) {
            mapOfFieldAndValue.put('fec_actual_nature_of_case__c', null);
            return;
        }

        soql += String.join(conditions, ' AND ') + ' LIMIT 1';
        System.debug('resolveActualNatureOfCase SOQL: ' + soql);

        List<SObject> matches = Database.query(soql);
        if (!matches.isEmpty()) {
            mapOfFieldAndValue.put('fec_actual_nature_of_case__c', matches[0].Id);
        } else {
            // Insert a temp FEC_Actual_Nature_of_Case__c with the resolved dimension Ids
            try {
                FEC_Actual_Nature_of_Case__c tempNoc = new FEC_Actual_Nature_of_Case__c();
                tempNoc.IsArchiveTemp__c = true;
                if (productTypeId != null) tempNoc.FEC_Product_Type__c = productTypeId;
                if (categoryId != null)    tempNoc.FEC_Category__c = categoryId;
                if (subCategoryId != null) tempNoc.FEC_Sub_Category__c = subCategoryId;
                if (subCodeId != null)     tempNoc.FEC_Sub_Code__c = subCodeId;
                if (bizProcessId != null)  tempNoc.FEC_Business_Process__c = bizProcessId;
                // Copy scalar fields from nocObj
                String customerType = (String) nocObj.get('FEC_Customer_Type__c');
                if (String.isNotBlank(customerType)) tempNoc.FEC_Customer_Type__c = customerType;
                String userGroup = (String) nocObj.get('FEC_User_Group__c');
                if (String.isNotBlank(userGroup)) tempNoc.FEC_User_Group__c = userGroup;
                insert tempNoc;
                mapOfFieldAndValue.put('fec_actual_nature_of_case__c', tempNoc.Id);
            } catch (Exception ex) {
                System.debug('insertTempRecord failed for FEC_Actual_Nature_of_Case__c: ' + ex.getMessage());
                mapOfFieldAndValue.put('fec_actual_nature_of_case__c', null);
            }
        }
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Extract a code value from a nested __r object within a parent relationship map
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
        String strMapping = label.TECH_ARCHIEVE_MAPPING_DEV_FIELD;
        Map<String, String> jsonDevField;
        if (String.isNotBlank(strMapping)) jsonDevField = (Map<String, String>) JSON.deserialize(strMapping, Map<String, String>.class);

        for (String fieldName : fieldMap.keySet()) {
            Object rawValue = mapOfFieldAndValue.get(fieldName.toLowerCase());
            if (rawValue != null) {
                devFieldTmp = mappingDevField(fieldName, jsonDevField);

                Schema.DescribeFieldResult fieldDetail = fieldMap.get(devFieldTmp).getDescribe();
                if (!fieldDetail.isCreateable()) continue;

                Schema.DisplayType fieldType = fieldDetail.getType();

                if (fieldType == Schema.DisplayType.DOUBLE || fieldType == Schema.DisplayType.CURRENCY) {
                    caseIns.put(devFieldTmp, Decimal.valueOf(String.valueOf(rawValue)));
                } 
                else if (fieldType == Schema.DisplayType.INTEGER) {
                    caseIns.put(devFieldTmp, Integer.valueOf(String.valueOf(rawValue)));
                } 
                else if (fieldType == Schema.DisplayType.DATE) {
                    caseIns.put(devFieldTmp, Date.valueOf(String.valueOf(rawValue)));
                } 
                else if (fieldType == Schema.DisplayType.DATETIME) {
                    String dtStr = String.valueOf(rawValue).replace('T', ' ');
                    caseIns.put(devFieldTmp, Datetime.valueOfGMT(dtStr));
                } 
                else if (fieldType == Schema.DisplayType.BOOLEAN) {
                    caseIns.put(devFieldTmp, Boolean.valueOf(String.valueOf(rawValue)));
                } 
                else if (fieldType == Schema.DisplayType.REFERENCE) {
                    // set default value for Lookup fields
                    // If the Id does not exist or cannot access, we need to set null value
                    String idStr = (String) rawValue;
                    if (mapIdCanAccess.containsKey(idStr) 
                        && !mapIdCanAccess.get(idStr).HasReadAccess) {

                        if (devFieldTmp.equalsIgnoreCase('OwnerId')) caseIns.OwnerId = UserInfo.getUserId();
                        else caseIns.put(devFieldTmp, null);
                    } else {
                        caseIns.put(devFieldTmp, rawValue);
                    }
                }
                else {
                    caseIns.put(devFieldTmp, rawValue);
                }
            }
        }
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
        while (!isSuccess && timeRetry < 149) {
            try {
                timeRetry ++;
                System.debug('try-InsertcaseIns ' + caseIns);
                insert caseIns;
                caseId = caseIns.Id;
                isSuccess = true;
            } catch (DmlException dmlEx) {
                for (Integer i = 0; i < dmlEx.getNumDml(); i++) {
                    List<Schema.SObjectField> fields = dmlEx.getDmlFields(i);
                    if (fields != null && !fields.isEmpty()) {
                        for (Schema.SObjectField keyOfField : fields) {
                            caseIns.put(keyOfField, null);
                        }
                    }
                }
            }
        }

        return caseId;
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
}