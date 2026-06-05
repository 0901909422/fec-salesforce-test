/**
 * @description Service layer for MDM Field Options used by LWC condition forms.
 *              Extracted from FEC_MDM_WorkflowEngine in Phase 2.2 refactor.
 *              Provides field options aggregated from Additional Fields and
 *              Master Data Settings (per Business Process / per Stage).
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.2
 */
public with sharing class FEC_MDMFieldOptionService {

    /**
     * Get all active Additional Field options for condition form lookup.
     */
    public static List<Map<String, Object>> getAdditionalFieldOptions() {
        List<FEC_MDM_Additional_Field__c> fields = (List<FEC_MDM_Additional_Field__c>) Security.stripInaccessible(
            AccessType.READABLE,
            [
                SELECT Id, Name,
                       FEC_Code__c,
                       FEC_Name_VN__c,
                       FEC_Unique_ID__c,
                       FEC_Type__c,
                       FEC_Field_Status__c
                FROM   FEC_MDM_Additional_Field__c
                WHERE  FEC_Field_Status__c = true
                ORDER BY Name ASC
            ]
        ).getRecords();

        List<Map<String, Object>> options = new List<Map<String, Object>>();
        for (FEC_MDM_Additional_Field__c f : fields) {
            options.add(buildAdditionalFieldOption(f));
        }
        return options;
    }

    private static Map<String, Object> buildAdditionalFieldOption(FEC_MDM_Additional_Field__c f) {
        Map<String, Object> populated = f.getPopulatedFieldsAsMap();
        String nameVn = populated.containsKey('FEC_Name_VN__c') ? (String) f.FEC_Name_VN__c : null;
        String code = populated.containsKey('FEC_Code__c') ? f.FEC_Code__c : null;
        String uniqueId = populated.containsKey('FEC_Unique_ID__c') ? f.FEC_Unique_ID__c : null;
        String displayLabel = (nameVn != null ? nameVn : f.Name)
            + ' (' + (uniqueId != null ? uniqueId : (code != null ? code : '')) + ')';
        return new Map<String, Object>{
            'label'        => displayLabel,
            'value'        => f.Id,
            'fieldApiName' => uniqueId,
            'fieldCode'    => code,
            'fieldNameVN'  => nameVn,
            'dataType'     => populated.containsKey('FEC_Type__c') ? f.FEC_Type__c : null
        };
    }

    /**
     * Get all MDS field options for a Business Process (across all Stages, deduplicated).
     */
    public static List<Map<String, String>> getFieldsForBusinessProcess(Id businessProcessId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        if (businessProcessId == null) return options;

        try {
            List<FEC_MDM_Master_Data_Setting__c> mdsList = (List<FEC_MDM_Master_Data_Setting__c>) Security.stripInaccessible(
                AccessType.READABLE,
                [
                    SELECT Id,
                           FEC_Field_Label_Name__c,
                           FEC_Field_API_Name__c,
                           FEC_Field_Object_Name__c,
                           Name
                    FROM FEC_MDM_Master_Data_Setting__c
                    WHERE FEC_Stage_Name__r.FEC_Business_Process__c = :businessProcessId
                      AND FEC_Field_Status__c = true
                    ORDER BY FEC_Field_Order_Display__c ASC
                ]
            ).getRecords();

            Set<Id> seen = new Set<Id>();
            for (FEC_MDM_Master_Data_Setting__c mds : mdsList) {
                if (seen.contains(mds.Id)) continue;
                seen.add(mds.Id);
                options.add(buildMDSOption(mds));
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_Load_Field_List + ' ' + e.getMessage());
        }
    }

    /**
     * Get all MDS field options for a single Stage.
     */
    public static List<Map<String, String>> getFieldsForStage(String stageId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        if (String.isBlank(stageId)) return options;

        try {
            List<FEC_MDM_Master_Data_Setting__c> mdsList = (List<FEC_MDM_Master_Data_Setting__c>) Security.stripInaccessible(
                AccessType.READABLE,
                [
                    SELECT Id,
                           FEC_Field_Label_Name__c,
                           FEC_Field_API_Name__c,
                           FEC_Field_Object_Name__c,
                           Name
                    FROM FEC_MDM_Master_Data_Setting__c
                    WHERE FEC_Stage_Name__c = :stageId
                      AND FEC_Field_Status__c = true
                    ORDER BY FEC_Field_Order_Display__c ASC
                ]
            ).getRecords();

            for (FEC_MDM_Master_Data_Setting__c mds : mdsList) {
                options.add(buildMDSOption(mds));
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_Load_Field_List + ' ' + e.getMessage());
        }
    }

    private static Map<String, String> buildMDSOption(FEC_MDM_Master_Data_Setting__c mds) {
        Map<String, Object> populated = mds.getPopulatedFieldsAsMap();
        String fieldLabelName = populated.containsKey('FEC_Field_Label_Name__c') ? (String) mds.FEC_Field_Label_Name__c : null;
        String fieldApiName = populated.containsKey('FEC_Field_API_Name__c') ? (String) mds.FEC_Field_API_Name__c : null;
        String fieldObjName = populated.containsKey('FEC_Field_Object_Name__c') ? (String) mds.FEC_Field_Object_Name__c : null;
        String labelName = String.isNotBlank(fieldLabelName) ? fieldLabelName : mds.Name;
        String apiName = String.isNotBlank(fieldApiName) ? fieldApiName : mds.Name;
        return new Map<String, String>{
            'label'        => labelName + ' (' + apiName + ')',
            'value'        => (String) mds.Id,
            'fieldApiName' => apiName,
            'dataType'     => FEC_MDMConditionUtils.resolveFieldDataType(fieldObjName, apiName)
        };
    }
}