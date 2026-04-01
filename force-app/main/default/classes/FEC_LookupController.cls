public with sharing class FEC_LookupController {
    @AuraEnabled
    public static List<LookupSearchResult> searchLookupRecords(String searchTerm, List<String> selectedIds, String sObjectName, String field, String subField, Integer maxResults, 
    String selectedProductTypeId, String selectedCategoryId, String selectedSubCategoryId) {
        
        List<LookupSearchResult> results = new List<LookupSearchResult>();
        String searchKey = '%' + searchTerm + '%';
        
        // Xác định trường định danh (Key): Nếu là Group thì dùng DeveloperName, ngược lại dùng Id
        String keyField = (sObjectName == 'Group') ? 'DeveloperName' : 'Id';
        
        String strQuery = 'SELECT ' + keyField + ', ' + field + (String.isNotBlank(subField) ? ' ,' + subField : '') + ' FROM ' + sObjectName;
        strQuery += ' WHERE ' + field + ' LIKE :searchKey' + ' AND ';  
        strQuery += keyField + ' NOT IN :selectedIds';

        // Lọc Queue khi object là Group
        if (sObjectName == 'Group') {
            strQuery += ' AND Type = \'Queue\'';
        }

        // Logic filter đặc thù cho các đối tượng FEC
        if (sObjectName == 'FEC_Product_Type__c') {
            strQuery += ' AND Id IN (SELECT FEC_Product_Type__c FROM FEC_Nature_of_Case__c WHERE FEC_Product_Type__c != NULL)';
        } else if (sObjectName == 'FEC_Category__c') {
            strQuery += ' AND Id IN (SELECT FEC_Category__c FROM FEC_Nature_of_Case__c WHERE FEC_Category__c != NULL AND FEC_Product_Type__c = :selectedProductTypeId)';
        } else if (sObjectName == 'FEC_Sub_Category__c') {
            strQuery += ' AND Id IN (SELECT FEC_Sub_Category__c FROM FEC_Nature_of_Case__c WHERE FEC_Sub_Category__c != NULL AND FEC_Product_Type__c = :selectedProductTypeId AND FEC_Category__c = :selectedCategoryId)';
        } else if (sObjectName == 'FEC_Sub_Code__c') {
            strQuery += ' AND Id IN (SELECT FEC_Sub_Code__c FROM FEC_Nature_of_Case__c WHERE FEC_Sub_Code__c != NULL AND FEC_Product_Type__c = :selectedProductTypeId AND FEC_Category__c = :selectedCategoryId AND FEC_Sub_Category__c = :selectedSubCategoryId)';
        }

        strQuery += ' ORDER BY ' + field + ' LIMIT :maxResults';
        
        List<sObject> searchResults = Database.query(strQuery);   
        if(searchResults != null && !searchResults.isEmpty()){
            for(sObject sObj : searchResults){
                LookupSearchResult res = new LookupSearchResult();
                // Gán API Name vào res.id nếu là Group, nếu không thì gán Id
                res.id = String.valueOf(sObj.get(keyField));
                res.title = String.valueOf(sObj.get(field));
                if(String.isNotBlank(subField) && sObj.get(subField) != null){
                    res.subtitle = String.valueOf(sObj.get(subField));
                } else {
                    res.subtitle = sObjectName;
                }
                results.add(res);
            } 
        }
        return results;        
    }
    
    @AuraEnabled
    public static LookupSearchResult getRecentlyCreatedRecord(String sObjectName, String recordId, String field, String subField) {
        LookupSearchResult result = new LookupSearchResult();
        String strQuery = 'SELECT Id, '+field + (String.isNotBlank(subField) ? ' ,'+subField : '')+' FROM '+sObjectName +' WHERE Id =:recordId LIMIT 1';
        List<sObject> searchResults = Database.query(strQuery);   
        if(searchResults != NUll && !searchResults.isEmpty()){
            sObject sObj = searchResults.get(0);
            LookupSearchResult res = new LookupSearchResult();
            result.Id = sObj.Id;
            result.title = String.valueOf(sObj.get(field));
            if(String.isNotBlank(subField) && sObj.get(subField) != NULL){
                result.subtitle = String.valueOf(sObj.get(subField));
            }else{
                result.subtitle = sObjectName;
            }
        }
        return result;        
    }
    
    public class LookupSearchResult {
        @AuraEnabled public String id{get;set;}
        @AuraEnabled public String title{get;set;}
        @AuraEnabled public String subtitle{get;set;}
    }
}