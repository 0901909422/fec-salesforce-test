public with sharing class FEC_IntegrationMasterDataController {

    //--------------
    //Master data
    @AuraEnabled
    public static String syncFraudMasterData() {
        Integer created = FEC_IntegrationFraudService.syncMasterDataIntegration();
        return 'Imported/Updated ' + created + ' records from XML.';
    }
    // Return hierarchical master data as JSON for LWC
    @AuraEnabled(cacheable=true)
    public static String getMasterDataForUI() {
        fecSoapFraudcaseServices.Sys sys = new fecSoapFraudcaseServices.Sys();
        sys.Channel = 'PEGACSM';

        fecSoapFraudcaseServices.GetFraudMasterDataResponse_element res = FEC_IntegrationFraudCaseClient.getMasterData(sys);

        // Build UI-friendly structure
        Map<String, Object> ui = FEC_IntegrationFraudService.buildUiMasterData();
        return JSON.serializePretty(ui);
    }


    @AuraEnabled(cacheable=true)
    public static List<FEC_Master_Data_Integration__c> getMappings(Integer limitSize, Integer offsetSize) {
        if (limitSize == null) limitSize = 100;
        if (offsetSize == null) offsetSize = 0;

        return [
            SELECT
            FEC_Source_Type__c,
            FEC_Source_Id__c,
            FEC_Source_Parent_Id__c,
            FEC_Source_Name__c,
            FEC_Source_NameVN__c,
            FEC_Source_Field_Type__c,
            FEC_Source_Enum_Value__c,
            FEC_Source_Enum_Label__c,
            FEC_Source_Enum_LabelVN__c,
            FEC_Source_Is_Mandatory__c,
            FEC_Source_Path__c
        FROM FEC_Master_Data_Integration__c
            ORDER BY FEC_Source_Path__c NULLS LAST, FEC_Source_Id__c
            LIMIT :limitSize OFFSET :offsetSize
        ];
    }

    @AuraEnabled
    public static List<FEC_Master_Data_Integration__c> saveMappings(List<FEC_Master_Data_Integration__c> records) {
        if (records == null || records.isEmpty()) return records;

        try {
            upsert records;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to save: ' + e.getMessage());
        }
        return records;
    }

    
    // Add this method into MasterDataMappingController.cls (or a new controller)
@AuraEnabled(cacheable=true)
public static List<FEC_Master_Data_Integration__c> getAllMappings() {
    // Return all mapping records needed for the tree
    return [
        SELECT
            FEC_Source_Type__c,
            FEC_Source_Id__c,
            FEC_Source_Parent_Id__c,
            FEC_Source_Name__c,
            FEC_Source_NameVN__c,
            FEC_Source_Field_Type__c,
            FEC_Source_Enum_Value__c,
            FEC_Source_Enum_Label__c,
            FEC_Source_Enum_LabelVN__c,
            FEC_Source_Is_Mandatory__c,
            FEC_Source_Path__c
        FROM FEC_Master_Data_Integration__c
        ORDER BY FEC_Source_Path__c NULLS LAST, FEC_Source_Id__c
    ];
}
@AuraEnabled(cacheable=true)
public static Map<String, List<FEC_Master_Data_Integration__c>> getMappingHierarchy() {

    Map<String, List<FEC_Master_Data_Integration__c>> result = new Map<String, List<FEC_Master_Data_Integration__c>>();

    List<FEC_Master_Data_Integration__c> all = [
        SELECT
            FEC_Source_Type__c,
            FEC_Source_Id__c,
            FEC_Source_Parent_Id__c,
            FEC_Source_Name__c,
            FEC_Source_NameVN__c,
            FEC_Source_Field_Type__c,
            FEC_Source_Enum_Value__c,
            FEC_Source_Enum_Label__c,
            FEC_Source_Enum_LabelVN__c,
            FEC_Source_Is_Mandatory__c,
            FEC_Source_Path__c
        FROM FEC_Master_Data_Integration__c
    ];

    result.put('Product',  new List<FEC_Master_Data_Integration__c>());
    result.put('CaseType', new List<FEC_Master_Data_Integration__c>());
    result.put('Category', new List<FEC_Master_Data_Integration__c>());
    result.put('SubCategory', new List<FEC_Master_Data_Integration__c>());
    result.put('SubCode', new List<FEC_Master_Data_Integration__c>());
    result.put('AdditionalProperty', new List<FEC_Master_Data_Integration__c>());
    result.put('AvailableValue', new List<FEC_Master_Data_Integration__c>());

    for (FEC_Master_Data_Integration__c rec : all) {
        result.get(rec.FEC_Source_Type__c).add(rec);
    }

    return result;
}


}