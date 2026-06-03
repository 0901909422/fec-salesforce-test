public with sharing class FEC_FecServiceTypeMappingController {
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getServiceTypeTree() {
        try {
            // 1. Load all BPs
            Map<Id, FEC_MDM_Business_Process__c> bpMap = new Map<Id, FEC_MDM_Business_Process__c>(
                [SELECT Id, Name FROM FEC_MDM_Business_Process__c
                 WITH SECURITY_ENFORCED
                 ORDER BY Name]
            );

            // 2. Load all active Stages thuộc các BP đó (sort theo Order, fallback Name)
            List<FEC_MDM_Case_Stage__c> allStages = [
                SELECT Id, Name, FEC_Business_Process__c, FEC_Order__c
                FROM FEC_MDM_Case_Stage__c
                WHERE FEC_Business_Process__c IN :bpMap.keySet()
                  AND FEC_Active__c = true
                WITH SECURITY_ENFORCED
                ORDER BY FEC_Order__c ASC NULLS LAST, Name ASC
            ];

            // bpId → list<Stage>
            Map<Id, List<FEC_MDM_Case_Stage__c>> bpToStages = new Map<Id, List<FEC_MDM_Case_Stage__c>>();
            for (FEC_MDM_Case_Stage__c st : allStages) {
                Id bpId = st.FEC_Business_Process__c;
                if (!bpToStages.containsKey(bpId)) {
                    bpToStages.put(bpId, new List<FEC_MDM_Case_Stage__c>());
                }
                bpToStages.get(bpId).add(st);
            }

            // 3. Load all Settings thuộc các BP đó
            List<FEC_MDM_Master_Data_Setting__c> allSettings = [
                SELECT Id, Name, FEC_Additional_Field__r.Name, Property_Reference__c,
                       FEC_Nature_Of_Case__r.FEC_Business_Process__c,
                       FEC_Stage_Name__c,
                       FEC_Field_Label_Name__c, FEC_Field_API_Name__c
                FROM FEC_MDM_Master_Data_Setting__c
                WHERE FEC_Nature_Of_Case__r.FEC_Business_Process__c IN :bpMap.keySet()
                  AND (FEC_Additional_Field__c != null OR FEC_Field_API_Name__c != null)
                WITH SECURITY_ENFORCED
                ORDER BY Name
            ];

            // bpId → stageId (or null) → list<settingNode>
            Map<Id, Map<Id, List<Map<String, Object>>>> bpToStageToFields = new Map<Id, Map<Id, List<Map<String, Object>>>>();
            for (FEC_MDM_Master_Data_Setting__c setting : allSettings) {
                Id bpId = setting.FEC_Nature_Of_Case__r.FEC_Business_Process__c;
                Id stageId = setting.FEC_Stage_Name__c; // có thể null

                if (!bpToStageToFields.containsKey(bpId)) {
                    bpToStageToFields.put(bpId, new Map<Id, List<Map<String, Object>>>());
                }
                Map<Id, List<Map<String, Object>>> stageMap = bpToStageToFields.get(bpId);
                if (!stageMap.containsKey(stageId)) {
                    stageMap.put(stageId, new List<Map<String, Object>>());
                }

                String fieldLabelName = setting.FEC_Field_Label_Name__c;
                String fallbackName = setting.FEC_Additional_Field__r != null ? setting.FEC_Additional_Field__r.Name : setting.Name;
                String displayLabel = String.isNotBlank(fieldLabelName) ? fieldLabelName : fallbackName;

                stageMap.get(stageId).add(new Map<String, Object>{
                    FEC_UIConstants.MAP_LABEL => displayLabel,
                    FEC_UIConstants.MAP_NAME => setting.Id,
                    FEC_UIConstants.MAP_PROPERTY_REF => setting.Property_Reference__c,
                    FEC_UIConstants.MAP_PARENT_NAME => bpMap.get(bpId).Name,
                    FEC_UIConstants.MAP_FIELD_LABEL => displayLabel,
                    FEC_UIConstants.MAP_FIELD_API_NAME => setting.FEC_Field_API_Name__c,
                    FEC_UIConstants.MAP_NODE_TYPE => FEC_UIConstants.NODE_TYPE_FIELD,
                    FEC_UIConstants.MAP_STAGE_NAME => null
                });
            }

            // 4. Build tree: BP → Stage children → Field grandchildren
            String noStageLabel = System.Label.FEC_Label_NoStage;
            List<Map<String, Object>> treeData = new List<Map<String, Object>>();
            for (FEC_MDM_Business_Process__c bp : bpMap.values()) {
                List<Map<String, Object>> stageNodes = new List<Map<String, Object>>();
                Map<Id, List<Map<String, Object>>> stageMap = bpToStageToFields.containsKey(bp.Id)
                    ? bpToStageToFields.get(bp.Id)
                    : new Map<Id, List<Map<String, Object>>>();

                // Real Stage nodes (from FEC_MDM_Case_Stage__c table) — Stage là LEAF của tree.
                // Field list được attach qua key MAP_FIELDS (không phải MAP_ITEMS) để lightning-tree
                // không render field nodes — user chỉ thấy 2 cấp BP → Stage.
                List<FEC_MDM_Case_Stage__c> stagesForBp = bpToStages.containsKey(bp.Id)
                    ? bpToStages.get(bp.Id)
                    : new List<FEC_MDM_Case_Stage__c>();
                for (FEC_MDM_Case_Stage__c st : stagesForBp) {
                    List<Map<String, Object>> stageFields = stageMap.containsKey(st.Id)
                        ? injectStageOnFields(stageMap.get(st.Id), st.Name)
                        : new List<Map<String, Object>>();
                    stageNodes.add(new Map<String, Object>{
                        FEC_UIConstants.MAP_LABEL => st.Name,
                        FEC_UIConstants.MAP_NAME => FEC_UIConstants.STAGE_NODE_PREFIX + st.Id,
                        FEC_UIConstants.MAP_EXPANDED => false,
                        FEC_UIConstants.MAP_FIELDS => stageFields,
                        FEC_UIConstants.MAP_NODE_TYPE => FEC_UIConstants.NODE_TYPE_STAGE,
                        FEC_UIConstants.MAP_PARENT_NAME => bp.Name,
                        FEC_UIConstants.MAP_STAGE_NAME => st.Name
                    });
                }

                // Virtual "(No Stage)" node — chứa setting có FEC_Stage_Name__c = null
                if (stageMap.containsKey(null) && !stageMap.get(null).isEmpty()) {
                    List<Map<String, Object>> noStageFields = injectStageOnFields(stageMap.get(null), noStageLabel);
                    stageNodes.add(new Map<String, Object>{
                        FEC_UIConstants.MAP_LABEL => noStageLabel,
                        FEC_UIConstants.MAP_NAME => FEC_UIConstants.NO_STAGE_NODE_PREFIX + bp.Id,
                        FEC_UIConstants.MAP_EXPANDED => false,
                        FEC_UIConstants.MAP_FIELDS => noStageFields,
                        FEC_UIConstants.MAP_NODE_TYPE => FEC_UIConstants.NODE_TYPE_STAGE,
                        FEC_UIConstants.MAP_PARENT_NAME => bp.Name,
                        FEC_UIConstants.MAP_STAGE_NAME => noStageLabel
                    });
                }

                treeData.add(new Map<String, Object>{
                    FEC_UIConstants.MAP_LABEL => bp.Name,
                    FEC_UIConstants.MAP_NAME => bp.Id,
                    FEC_UIConstants.MAP_EXPANDED => false,
                    FEC_UIConstants.MAP_ITEMS => stageNodes,
                    FEC_UIConstants.MAP_NODE_TYPE => FEC_UIConstants.NODE_TYPE_BP
                });
            }
            System.debug(FEC_Constants.DEBUG_SERVICE_TYPE_TREE_PREFIX + treeData);
            return treeData;
        } catch (System.QueryException qe) {
            // QueryException khi WITH SECURITY_ENFORCED phát hiện FLS/CRUD denial
            System.debug('FEC_FecServiceTypeMappingController.getServiceTypeTree FLS denied: ' + qe);
            throw new AuraHandledException(System.Label.FEC_Error_FLS_Denied);
        } catch (Exception e) {
            System.debug('FEC_FecServiceTypeMappingController.getServiceTypeTree error: ' + e);
            throw new AuraHandledException(System.Label.FEC_Error_FLS_Denied);
        }
    }

    /**
     * Helper: clone field nodes and inject stageName onto each (vì 1 field reference chỉ thuộc 1 stage,
     * nhưng giúp UI hiển thị stage context khi flatten ở BP-level view).
     */
    private static List<Map<String, Object>> injectStageOnFields(List<Map<String, Object>> fields, String stageName) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (Map<String, Object> f : fields) {
            Map<String, Object> clone = new Map<String, Object>(f);
            clone.put(FEC_UIConstants.MAP_STAGE_NAME, stageName);
            result.add(clone);
        }
        return result;
    }
    
    /**
     * @description Trả về danh sách Case field + relationship parents 1-cấp dùng cho field picker.
     * Output gồm direct Case fields và parent fields của 1 số relationship phổ biến (Account, Owner,
     * Contact, CreatedBy, RecordType + custom relationship FEC_*__r). Chỉ field user có FLS read mới
     * xuất hiện. Cú pháp value đảm bảo đúng định dạng SOQL/Schema để imp Case auto-mapping ăn được:
     *   - Direct: ApiName (vd "CaseNumber", "FEC_Application_ID__c")
     *   - Relationship: Parent.ChildApi (vd "Account.Name", "FEC_Customer__r.Phone")
     * @return List<Map<String, Object>> với keys: label, value, group, apiName.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getCaseFieldOptions() {
        try {
            List<Map<String, Object>> options = new List<Map<String, Object>>();
            Schema.DescribeSObjectResult caseDescribe = Case.SObjectType.getDescribe();
            Map<String, Schema.SObjectField> caseFields = caseDescribe.fields.getMap();

            // 1. Direct Case fields
            List<Map<String, Object>> caseDirect = new List<Map<String, Object>>();
            for (String apiName : caseFields.keySet()) {
                Schema.SObjectField sf = caseFields.get(apiName);
                Schema.DescribeFieldResult dfr = sf.getDescribe();
                if (!dfr.isAccessible()) continue;
                // Skip system fields ít dùng để picker gọn hơn
                if (dfr.isCalculated() && dfr.getType() == Schema.DisplayType.Address) continue;

                String label = dfr.getLabel();
                String displayApiName = dfr.getName();
                caseDirect.add(new Map<String, Object>{
                    'label' => label + ' (' + displayApiName + ')',
                    'value' => displayApiName,
                    'apiName' => displayApiName,
                    'group' => System.Label.FEC_Group_CaseFields
                });
            }

            // 2. Relationship parents 1-cấp — group theo từng parent object
            // Standard: Account, Owner, Contact, CreatedBy, RecordType
            // Custom: bất cứ field __c nào là Reference type → thêm vào
            Set<String> relationshipNames = new Set<String>();
            for (String apiName : caseFields.keySet()) {
                Schema.DescribeFieldResult dfr = caseFields.get(apiName).getDescribe();
                if (dfr.getType() != Schema.DisplayType.Reference) continue;
                String relName = dfr.getRelationshipName();
                if (String.isBlank(relName)) continue;
                if (!dfr.isAccessible()) continue;
                relationshipNames.add(relName);
            }

            // Mỗi parent → 1 group riêng (vd "Account Fields", "Owner Fields")
            // Map<groupName, List<options>> để sort group alphabet
            Map<String, List<Map<String, Object>>> parentGroupMap = new Map<String, List<Map<String, Object>>>();
            for (String relName : relationshipNames) {
                Schema.SObjectField relField = caseFields.get(getReferenceFieldApiName(relName, caseFields));
                if (relField == null) continue;
                Schema.DescribeFieldResult relDfr = relField.getDescribe();
                List<Schema.SObjectType> refTos = relDfr.getReferenceTo();
                if (refTos == null || refTos.isEmpty()) continue;
                Schema.DescribeSObjectResult parentDescribe = refTos[0].getDescribe();
                if (!parentDescribe.isAccessible()) continue;

                String groupName = relName + ' Fields';
                List<Map<String, Object>> groupItems = new List<Map<String, Object>>();

                Map<String, Schema.SObjectField> parentFields = parentDescribe.fields.getMap();
                for (String pApiName : parentFields.keySet()) {
                    Schema.DescribeFieldResult pDfr = parentFields.get(pApiName).getDescribe();
                    if (!pDfr.isAccessible()) continue;
                    // Skip lookup ID fields trên parent — tránh nested 2-cấp
                    if (pDfr.getType() == Schema.DisplayType.Reference) continue;
                    String pName = pDfr.getName();
                    String pLabel = pDfr.getLabel();
                    groupItems.add(new Map<String, Object>{
                        'label' => pLabel + ' (' + relName + '.' + pName + ')',
                        'value' => relName + '.' + pName,
                        'apiName' => relName + '.' + pName,
                        'group' => groupName
                    });
                }
                if (!groupItems.isEmpty()) {
                    groupItems.sort(new FieldOptionLabelComparator());
                    parentGroupMap.put(groupName, groupItems);
                }
            }

            // Sort each group theo label
            caseDirect.sort(new FieldOptionLabelComparator());

            // Output order: Case Fields trước → parent groups (alphabet sort theo group name)
            options.addAll(caseDirect);
            List<String> sortedGroups = new List<String>(parentGroupMap.keySet());
            sortedGroups.sort();
            for (String g : sortedGroups) {
                options.addAll(parentGroupMap.get(g));
            }
            return options;
        } catch (System.QueryException qe) {
            System.debug('FEC_FecServiceTypeMappingController.getCaseFieldOptions FLS denied: ' + qe);
            throw new AuraHandledException(System.Label.FEC_Error_FLS_Denied);
        } catch (Exception e) {
            System.debug('FEC_FecServiceTypeMappingController.getCaseFieldOptions error: ' + e);
            throw new AuraHandledException(System.Label.FEC_Error_FLS_Denied);
        }
    }

    /**
     * Helper: tìm apiName của field reference dựa vào relationshipName.
     * Vd relationshipName "Account" → field api "AccountId"; "FEC_Customer__r" → "FEC_Customer__c".
     */
    private static String getReferenceFieldApiName(String relName, Map<String, Schema.SObjectField> fields) {
        for (String fApi : fields.keySet()) {
            Schema.DescribeFieldResult dfr = fields.get(fApi).getDescribe();
            if (dfr.getType() == Schema.DisplayType.Reference
                && relName.equalsIgnoreCase(dfr.getRelationshipName())) {
                return dfr.getName();
            }
        }
        return null;
    }

    /**
     * Comparator: sort field options theo 'label' ASC (case-insensitive).
     */
    public class FieldOptionLabelComparator implements Comparator<Map<String, Object>> {
        public Integer compare(Map<String, Object> a, Map<String, Object> b) {
            String la = String.valueOf(a.get('label')).toLowerCase();
            String lb = String.valueOf(b.get('label')).toLowerCase();
            return la.compareTo(lb);
        }
    }

    @AuraEnabled
    public static void savePropertyMapping(Id settingId, String newRef) {
        if (settingId == null) throw new AuraHandledException(FEC_UIConstants.ERROR_INVALID_ID);
        try {
            Schema.SObjectType t = FEC_MDM_Master_Data_Setting__c.SObjectType;
            Schema.DescribeSObjectResult dsr = t.getDescribe();
            if (!dsr.isUpdateable()) {
                throw new AuraHandledException(FEC_UIConstants.ERROR_NO_UPDATE_PERMISSION);
            }
            Schema.SObjectField sf = dsr.fields.getMap().get(FEC_FieldConstants.FIELD_PROPERTY_REFERENCE.toLowerCase());
            if (sf == null) {
                throw new AuraHandledException(FEC_UIConstants.ERROR_INVALID_FIELD);
            }
            if (!sf.getDescribe().isUpdateable()) {
                throw new AuraHandledException(FEC_UIConstants.ERROR_NO_FIELD_UPDATE_PERMISSION);
            }
            update new FEC_MDM_Master_Data_Setting__c(
                Id = settingId,
                Property_Reference__c = newRef
            );
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            // Log minimal details, return friendly message
            System.debug('FEC_FecServiceTypeMappingController.savePropertyMapping error: ' + e);
            throw new AuraHandledException(System.Label.FEC_Error_Save_Property_Mapping);
        }
     }

    @AuraEnabled
    public static void savePropertyMappings(String mappingsJson) {
        if (String.isBlank(mappingsJson)) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_INVALID_ID);
        }
        try {
            List<Object> mappingsList = (List<Object>) JSON.deserializeUntyped(mappingsJson);
            if (mappingsList.isEmpty()) {
                throw new AuraHandledException(FEC_UIConstants.ERROR_INVALID_ID);
            }

            // Validate object-level update permission
            Schema.SObjectType t = FEC_MDM_Master_Data_Setting__c.SObjectType;
            Schema.DescribeSObjectResult dsr = t.getDescribe();
            if (!dsr.isUpdateable()) {
                throw new AuraHandledException(FEC_UIConstants.ERROR_NO_UPDATE_PERMISSION);
            }

            // Validate field-level update permission for Property_Reference__c
            Schema.SObjectField sf = dsr.fields.getMap().get(FEC_FieldConstants.FIELD_PROPERTY_REFERENCE.toLowerCase());
            if (sf == null) {
                throw new AuraHandledException(FEC_UIConstants.ERROR_INVALID_FIELD);
            }
            if (!sf.getDescribe().isUpdateable()) {
                throw new AuraHandledException(FEC_UIConstants.ERROR_NO_FIELD_UPDATE_PERMISSION);
            }

            // Build list of records to update
            List<FEC_MDM_Master_Data_Setting__c> recordsToUpdate = new List<FEC_MDM_Master_Data_Setting__c>();
            for (Object item : mappingsList) {
                Map<String, Object> mapping = (Map<String, Object>) item;
                String settingId = (String) mapping.get('settingId');
                String newRef = (String) mapping.get('newRef');
                recordsToUpdate.add(new FEC_MDM_Master_Data_Setting__c(
                    Id = (Id) settingId,
                    Property_Reference__c = newRef
                ));
            }

            update recordsToUpdate;
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            System.debug('FEC_FecServiceTypeMappingController.savePropertyMappings error: ' + e);
            throw new AuraHandledException(System.Label.FEC_Error_Save_Property_Mapping);
        }
    }
 }