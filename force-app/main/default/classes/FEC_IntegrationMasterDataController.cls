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
        // Build UI-friendly structure
        Map<String, Object> ui = buildUiMasterData();
        return JSON.serializePretty(ui);
    }    

    public static Map<String, Object> buildUiMasterData() {

        Map<String, Object> result = new Map<String, Object>();
        List<Map<String, Object>> categories = new List<Map<String, Object>>();

        // Load full master data
        List<FEC_Master_Data_Integration__c> recs = [
            SELECT 
                FEC_Source_Id__c,
                FEC_Source_Parent_Id__c,
                FEC_Source_Name__c,
                FEC_Source_NameVN__c,
                FEC_Source_Type__c,
                FEC_Source_Field_Type__c,
                FEC_Source_Enum_Value__c,
                FEC_Source_Enum_Label__c,
                FEC_Source_Enum_LabelVN__c,
                FEC_Source_Is_Mandatory__c,
                FEC_PosOrder__c
            FROM FEC_Master_Data_Integration__c
            ORDER BY FEC_PosOrder__c NULLS LAST
        ];
        System.debug('➡ Load full master data        = ' + JSON.serializePretty(recs));

        // Group records by Type
        Map<String, List<FEC_Master_Data_Integration__c>> typeMap = new Map<String, List<FEC_Master_Data_Integration__c>>();
        for (FEC_Master_Data_Integration__c r : recs) {
            String t = r.FEC_Source_Type__c != null ? r.FEC_Source_Type__c : 'UNKNOWN';
            if (!typeMap.containsKey(t)) {
                typeMap.put(t, new List<FEC_Master_Data_Integration__c>());
            }
            typeMap.get(t).add(r);
        }

        // Safe shortcuts
        List<FEC_Master_Data_Integration__c> categoryList        = typeMap.containsKey('Category')         ? typeMap.get('Category')         : new List<FEC_Master_Data_Integration__c>();
        List<FEC_Master_Data_Integration__c> subCategoryList    = typeMap.containsKey('SubCategory')      ? typeMap.get('SubCategory')      : new List<FEC_Master_Data_Integration__c>();
        List<FEC_Master_Data_Integration__c> subCodeList        = typeMap.containsKey('SubCode')          ? typeMap.get('SubCode')          : new List<FEC_Master_Data_Integration__c>();
        List<FEC_Master_Data_Integration__c> additionalList     = typeMap.containsKey('AdditionalProperty')? typeMap.get('AdditionalProperty'): new List<FEC_Master_Data_Integration__c>();
        List<FEC_Master_Data_Integration__c> availableValueList = typeMap.containsKey('AvailableValue')   ? typeMap.get('AvailableValue')   : new List<FEC_Master_Data_Integration__c>();
        System.debug('➡ Load full master categoryList        = ' + JSON.serializePretty(categoryList));
        System.debug('➡ Load full master subCategoryList        = ' + JSON.serializePretty(subCategoryList));
        System.debug('➡ Load full master additionalList        = ' + JSON.serializePretty(additionalList));
        System.debug('➡ Load full master availableValueList        = ' + JSON.serializePretty(availableValueList));
        // ------------------------------------------------------------
        // BUILD TREE: Category → SubCategory → SubCode → AP → Values
        // ------------------------------------------------------------
        for (FEC_Master_Data_Integration__c cat : categoryList) {

            Map<String, Object> catNode = new Map<String, Object>{
                'id'            => cat.FEC_Source_Id__c,
                'name'          => cat.FEC_Source_Name__c,
                'nameVN'        => cat.FEC_Source_NameVN__c,
                'posOrder'      => cat.FEC_PosOrder__c,
                'subCategories' => new List<Object>()
            };

            // ---------------- SUBCATEGORY ----------------
            for (FEC_Master_Data_Integration__c sub : subCategoryList) {
                if (sub.FEC_Source_Parent_Id__c == cat.FEC_Source_Id__c) {

                    Map<String, Object> subNode = new Map<String, Object>{
                        'id'        => sub.FEC_Source_Id__c,
                        'name'      => sub.FEC_Source_Name__c,
                        'nameVN'    => sub.FEC_Source_NameVN__c,
                        'subCodes'  => new List<Object>()
                    };

                    // ---------------- SUBCODE ----------------
                    for (FEC_Master_Data_Integration__c sc : subCodeList) {
                        if (sc.FEC_Source_Parent_Id__c == sub.FEC_Source_Id__c) {

                            Map<String, Object> scNode = new Map<String, Object>{
                                'id'        => sc.FEC_Source_Id__c,
                                'name'      => sc.FEC_Source_Name__c,
                                'nameVN'    => sc.FEC_Source_NameVN__c,
                                'additionalProperties' => new List<Object>()
                            };

                            // ---------------- ADDITIONAL PROPERTY ----------------
                            for (FEC_Master_Data_Integration__c ap : additionalList) {
                                if (ap.FEC_Source_Parent_Id__c == sc.FEC_Source_Id__c) {

                                    Map<String, Object> apNode = new Map<String, Object>{
                                        'id'            => ap.FEC_Source_Id__c,
                                        'name'          => ap.FEC_Source_Name__c,
                                        'nameVN'        => ap.FEC_Source_NameVN__c,
                                        'type'          => ap.FEC_Source_Field_Type__c,
                                        'mandatory'     => ap.FEC_Source_Is_Mandatory__c,
                                        'availableValues' => new List<Object>()
                                    };

                                    // ---------------- AVAILABLE VALUES ----------------
                                    for (FEC_Master_Data_Integration__c av : availableValueList) {
                                        if (av.FEC_Source_Parent_Id__c == ap.FEC_Source_Id__c) {

                                            List<Object> avList = (List<Object>) apNode.get('availableValues');
                                            if (avList == null) {
                                                avList = new List<Object>();
                                                apNode.put('availableValues', avList);
                                            }

                                            avList.add(new Map<String, Object>{
                                                'id'     => av.FEC_Source_Enum_Value__c,
                                                'name'   => av.FEC_Source_Enum_Label__c,
                                                'nameVN' => av.FEC_Source_Enum_LabelVN__c
                                            });
                                        }
                                    }

                                    // Add AP → SubCode
                                    ((List<Object>)scNode.get('additionalProperties')).add(apNode);
                                }
                            }

                            // Add SubCode → SubCategory
                            ((List<Object>)subNode.get('subCodes')).add(scNode);
                        }
                    }

                    // Add SubCategory → Category
                    ((List<Object>)catNode.get('subCategories')).add(subNode);
                }
            }

            categories.add(catNode);
        }
        System.debug('➡ Load full all categories = ' + JSON.serializePretty(categories));
        result.put('categories', categories);
        return result;
    }

}