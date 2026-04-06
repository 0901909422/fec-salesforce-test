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
        String strIgnored = '__r';
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

        if (resp.getStatusCode() == 200 || resp.getStatusCode() == 201) {
            Map<String, Object> jsonDetailCase = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());

            for (String keyOfAtt : jsonDetailCase.keySet()) {
                if (listOfAttIgnored.contains(keyOfAtt) || keyOfAtt.endsWith(strIgnored)) continue;
                System.debug('keyOfAtt ' + keyOfAtt);

                if (keyOfAtt == 'RecordType') {
                    try {
                        Map<String, Object> objChild = (Map<String, Object>) jsonDetailCase.get(keyOfAtt);
                        recTypeName = (String) objChild.get('Name') ;
                    } catch (Exception ex) {
                        recTypeName = (String) jsonDetailCase.get(keyOfAtt);
                    }
                    continue;
                }

                mapOfFieldAndValue.put(keyOfAtt.toLowerCase(), jsonDetailCase.get(keyOfAtt));
            }
        }
        FEC_CommonUltils.logApi(label.TECH_API_GET_ARCHIVE_DETAIL_CASE, endpoint, methodOfApi, null, resp, null);

        System.debug('mapOfFieldAndValue ' + mapOfFieldAndValue);
        if (mapOfFieldAndValue.size() > 0) {
            Set<String> setPotentialIds = new Set<String>();

            Case caseIns = new Case();
            caseIns.ArchiveExternalId__c = archiveCaseIns.ExternalId;
            caseIns.RecordTypeId = getRecordTypeId(recTypeName);

            Map<String, Schema.SObjectField> fieldMap = Case.sObjectType.getDescribe().fields.getMap();
            buildSetPotentialIds(setPotentialIds, fieldMap, mapOfFieldAndValue);
            Map<String, UserRecordAccess> mapIdCanAccess = getRelatedRecordCanAccess(setPotentialIds);
            System.debug('mapIdCanAccess ' + mapIdCanAccess);

            buildCaseFieldsAndValue(fieldMap, mapOfFieldAndValue, caseIns, mapIdCanAccess);
            caseId = saveCaseRecord(caseIns);
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
 
        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDetail = fieldMap.get(fieldName).getDescribe();
            if (!fieldDetail.isCreateable()) continue;

            Schema.DisplayType fieldType = fieldDetail.getType();

            Object rawValue = mapOfFieldAndValue.get(fieldName.toLowerCase());
            if (rawValue != null) {
                if (fieldType == Schema.DisplayType.DOUBLE || fieldType == Schema.DisplayType.CURRENCY) {
                    caseIns.put(fieldName, Decimal.valueOf(String.valueOf(rawValue)));
                } 
                else if (fieldType == Schema.DisplayType.INTEGER) {
                    caseIns.put(fieldName, Integer.valueOf(String.valueOf(rawValue)));
                } 
                else if (fieldType == Schema.DisplayType.DATE) {
                    caseIns.put(fieldName, Date.valueOf(String.valueOf(rawValue)));
                } 
                else if (fieldType == Schema.DisplayType.DATETIME) {
                    caseIns.put(fieldName, DateTime.valueOf(String.valueOf(rawValue)));
                } 
                else if (fieldType == Schema.DisplayType.BOOLEAN) {
                    caseIns.put(fieldName, Boolean.valueOf(String.valueOf(rawValue)));
                } 
                else if (fieldType == Schema.DisplayType.REFERENCE) {
                    // set default value for Lookup fields
                    // If the Id does not exist or cannot access, we need to set null value
                    String idStr = (String) rawValue;
                    if (mapIdCanAccess.containsKey(idStr) 
                        && !mapIdCanAccess.get(idStr).HasReadAccess) {

                        if (fieldName.equalsIgnoreCase('OwnerId')) caseIns.OwnerId = UserInfo.getUserId();
                        else caseIns.put(fieldName, null);
                    } else {
                        caseIns.put(fieldName, rawValue);
                    }
                }
                else {
                    caseIns.put(fieldName, rawValue);
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
}