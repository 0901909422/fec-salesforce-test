/**
 * @description Controller for fetching and structuring data for the Nature of Case Lightning Tree.
 * @date 2025-12-09
 * @author DAT NGO
 */
public with sharing class FEC_NatureOfCaseTreeController {
    
    // payload keys and aggregate alias moved to FEC_Constants
    
    @AuraEnabled
    public static Integer getNextPosOrder(String parentId, String childFieldName) {
            String targetChildField;
            if (childFieldName == FEC_Constants.NOC_FIELD_PRODUCT_TYPE) targetChildField = FEC_Constants.NOC_FIELD_BUSINESS_PROCESS;
            else if (childFieldName == FEC_Constants.NOC_FIELD_BUSINESS_PROCESS) targetChildField = FEC_Constants.NOC_FIELD_CATEGORY;
            else if (childFieldName == FEC_Constants.NOC_FIELD_CATEGORY) targetChildField = FEC_Constants.NOC_FIELD_SUB_CATEGORY;
            else if (childFieldName == FEC_Constants.NOC_FIELD_SUB_CATEGORY) targetChildField = FEC_Constants.NOC_FIELD_SUB_CODE;
            else targetChildField = FEC_Constants.NOC_FIELD_PRODUCT_TYPE;
            
            String query = FEC_Constants.SQL_SELECT_COUNT_DISTINCT + targetChildField + FEC_Constants.SQL_FROM_NOC;
            
            if (String.isNotBlank(parentId) && String.isNotBlank(childFieldName)) {
                query += ' WHERE ' + childFieldName + ' = :parentId AND ' + targetChildField + ' != NULL';
            }
            
            AggregateResult[] results = Database.query(query);
            Integer uniqueCount = (Integer)results[0].get(FEC_Constants.AGG_EXPR0);
            
            return uniqueCount + 1;
    }
    
    /**
     * @description Retrieves all Nature of Case records and structures them into a list
     * of Lightning Tree Items based on the hierarchy: Product Type > Business Process > Category > Sub Category > Sub Code.
     * @param
     * @return List<NatureOfCaseTreeItem> The list of tree items.
     * @author DAT NGO
     */
    @AuraEnabled(cacheable=true)
    public static List<NatureOfCaseTreeItem> getNatureOfCaseTreeData() {
        List<NatureOfCaseTreeItem> treeItems = new List<NatureOfCaseTreeItem>();
        try {
            // SOQL đã bao gồm tất cả các trường chi tiết
            List<FEC_MDM_Nature_Of_Case__c> listNOC = [
                SELECT 
                        Id, 
                        Name, 
                        Process_Change_Status__c, 
                        FEC_Customer_Type__c, 

                        FEC_Product_Type_Name__c, 
                        FEC_Product_Type_Name__r.Name, 
                        FEC_Product_Type_Name__r.FEC_Alias__c, 
                        FEC_Product_Type_Name__r.FEC_Code__c, 
                        FEC_Product_Type_Name__r.FEC_Name_VN__c, 
                        FEC_Product_Type_Name__r.FEC_Pos_Order__c, 
                        FEC_Product_Type_Name__r.FEC_Status__c, 
                        FEC_Product_Type_Name__r.Process_Change_Status__c, 
                        
                        FEC_Business_Process_Name__c, 
                        FEC_Business_Process_Name__r.Name, 
                        FEC_Business_Process_Name__r.FEC_Alias__c, 
                        FEC_Business_Process_Name__r.FEC_Code__c, 
                        FEC_Business_Process_Name__r.FEC_Name_VN__c, 
                        FEC_Business_Process_Name__r.FEC_Pos_Order__c, 
                        FEC_Business_Process_Name__r.FEC_Status__c, 
                        FEC_Business_Process_Name__r.Process_Change_Status__c, 
                        
                        FEC_Category_Name__c, 
                        FEC_Category_Name__r.Name, 
                        FEC_Category_Name__r.FEC_Alias__c, 
                        FEC_Category_Name__r.FEC_Code__c, 
                        FEC_Category_Name__r.FEC_Name_VN__c, 
                        FEC_Category_Name__r.FEC_Pos_Order__c, 
                        FEC_Category_Name__r.FEC_Status__c, 
                        FEC_Category_Name__r.Process_Change_Status__c,  
                        
                        FEC_Sub_Category_Name__c, 
                        FEC_Sub_Category_Name__r.Name, 
                        FEC_Sub_Category_Name__r.FEC_Alias__c, 
                        FEC_Sub_Category_Name__r.FEC_Code__c, 
                        FEC_Sub_Category_Name__r.FEC_Name_VN__c, 
                        FEC_Sub_Category_Name__r.FEC_Pos_Order__c, 
                        FEC_Sub_Category_Name__r.FEC_Status__c, 
                        FEC_Sub_Category_Name__r.Process_Change_Status__c, 

                        FEC_Sub_Code__c, 
                        FEC_Sub_Code__r.Name,
                        FEC_Sub_Code__r.FEC_Alias__c, 
                        FEC_Sub_Code__r.FEC_Code__c, 
                        FEC_Sub_Code__r.FEC_Name_VN__c, 
                        FEC_Sub_Code__r.FEC_Pos_Order__c, 
                        FEC_Sub_Code__r.FEC_Status__c,
                        FEC_Sub_Code__r.Process_Change_Status__c

                    FROM 
                        FEC_MDM_Nature_Of_Case__c
                    ORDER BY 
                        FEC_Product_Type_Name__r.FEC_Pos_Order__c ASC,
                        FEC_Business_Process_Name__r.FEC_Pos_Order__c ASC,
                        FEC_Category_Name__r.FEC_Pos_Order__c ASC,
                        FEC_Sub_Category_Name__r.FEC_Pos_Order__c ASC,
                        FEC_Sub_Code__r.FEC_Pos_Order__c ASC
                LIMIT :FEC_Constants.QUERY_LIMIT
            ];
            
            Map<String, NatureOfCaseTreeItem> mapProductType = new Map<String, NatureOfCaseTreeItem>();
            
            for (FEC_MDM_Nature_Of_Case__c noc : listNOC) {
                String productTypeCode = noc.FEC_Product_Type_Name__r?.FEC_Code__c;
                String businessProcessCode = noc.FEC_Business_Process_Name__r?.FEC_Code__c;
                String categoryCode = noc.FEC_Category_Name__r?.FEC_Code__c;
                String subCategoryCode = noc.FEC_Sub_Category_Name__r?.FEC_Code__c;
                String subCodeCode = noc.FEC_Sub_Code__r?.FEC_Code__c;
                
                String ptId = noc.FEC_Product_Type_Name__c;
                String bpId = noc.FEC_Business_Process_Name__c;
                String catId = noc.FEC_Category_Name__c;
                String scatId = noc.FEC_Sub_Category_Name__c;
                String scodeId = noc.FEC_Sub_Code__c;
                
                String ptKey = FEC_Constants.PT_PREFIX + ptId;
                String bpsKey = FEC_Constants.BP_PREFIX + ptId + '_' + bpId;
                String cataKey = FEC_Constants.CAT_PREFIX + ptId + '_' + bpId + '_' + catId;
                String scatKey = FEC_Constants.SCAT_PREFIX + ptId + '_' + bpId + '_' + catId + '_' + scatId;
                String scodeKey = FEC_Constants.SCODE_PREFIX + ptId + '_' + bpId + '_' + catId + '_' + scatId + '_' + scodeId;
                
                // 1. Product Type Node (Root)
                NatureOfCaseTreeItem ptNode;
                if (productTypeCode != null) {
                    if (!mapProductType.containsKey(productTypeCode)) {
                        // 🚨 Gán các trường chi tiết cho Product Type
                        ptNode = new NatureOfCaseTreeItem(
                            productTypeCode,
                        ptKey,
                        new List<NatureOfCaseTreeItem>(),
                        noc.FEC_Product_Type_Name__r.FEC_Alias__c,
                        noc.FEC_Product_Type_Name__r.FEC_Code__c,
                        noc.FEC_Product_Type_Name__r.FEC_Name_VN__c,
                        noc.FEC_Product_Type_Name__r.FEC_Pos_Order__c,
                        noc.FEC_Product_Type_Name__r.FEC_Status__c,
                        noc.FEC_Product_Type_Name__r.Process_Change_Status__c,
                        noc.FEC_Product_Type_Name__r.Name,
                        noc.FEC_Product_Type__c,
                        noc.FEC_Customer_Type__c,
                        noc.Id,
                        FEC_Constants.LABEL_PRODUCT_TYPE
                            );
                        mapProductType.put(productTypeCode, ptNode);
                    } else {
                        ptNode = mapProductType.get(productTypeCode);
                    }
                    if (noc.FEC_Product_Type_Name__r.FEC_Status__c == false) {
                        continue;
                    }
                } else {
                    continue;
                }
                
                // 2. Business Process Node
                NatureOfCaseTreeItem bpNode;
                if (businessProcessCode != null) {
                    String bpKey = productTypeCode + '_' + businessProcessCode;
                    if (ptNode.mapChilds == null) ptNode.mapChilds = new Map<String, NatureOfCaseTreeItem>();
                    
                    if (!ptNode.mapChilds.containsKey(bpKey)) {
                        // 🚨 Gán các trường chi tiết cho Business Process
                        bpNode = new NatureOfCaseTreeItem(
                            businessProcessCode,
                        bpsKey,
                        new List<NatureOfCaseTreeItem>(),
                        noc.FEC_Business_Process_Name__r.FEC_Alias__c,
                        noc.FEC_Business_Process_Name__r.FEC_Code__c,
                        noc.FEC_Business_Process_Name__r.FEC_Name_VN__c,
                        noc.FEC_Business_Process_Name__r.FEC_Pos_Order__c,
                        noc.FEC_Business_Process_Name__r.FEC_Status__c,
                        noc.FEC_Business_Process_Name__r.Process_Change_Status__c,
                        noc.FEC_Business_Process_Name__r.Name,
                        noc.FEC_Business_Process_Name__c,
                        noc.FEC_Customer_Type__c,
                        noc.Id,
                        FEC_Constants.LABEL_BUSINESS_PROCESS
                            );
                        ptNode.mapChilds.put(bpKey, bpNode);
                    } else {
                        bpNode = ptNode.mapChilds.get(bpKey);
                    }
                    if (noc.FEC_Business_Process_Name__r.FEC_Status__c == false) {
                        continue;
                    }
                } else {
                    continue;
                }
                
                // 3. Category Node
                NatureOfCaseTreeItem catNode;
                if (categoryCode != null) {
                    String catKey = bpNode.code + '_' + categoryCode;
                    if (bpNode.mapChilds == null) bpNode.mapChilds = new Map<String, NatureOfCaseTreeItem>();
                    
                    if (!bpNode.mapChilds.containsKey(catKey)) {
                        // 🚨 Gán các trường chi tiết cho Category
                        catNode = new NatureOfCaseTreeItem(
                            categoryCode,
                        cataKey,
                        new List<NatureOfCaseTreeItem>(),
                        noc.FEC_Category_Name__r.FEC_Alias__c,
                        noc.FEC_Category_Name__r.FEC_Code__c,
                        noc.FEC_Category_Name__r.FEC_Name_VN__c,
                        noc.FEC_Category_Name__r.FEC_Pos_Order__c,
                        noc.FEC_Category_Name__r.FEC_Status__c,
                        noc.FEC_Category_Name__r.Process_Change_Status__c,
                        noc.FEC_Category_Name__r.Name,
                        noc.FEC_Category_Name__c,
                        noc.FEC_Customer_Type__c,
                        noc.Id,
                        FEC_Constants.LABEL_CATEGORY
                            );
                        bpNode.mapChilds.put(catKey, catNode);
                    } else {
                        catNode = bpNode.mapChilds.get(catKey);
                    }
                    if (noc.FEC_Category_Name__r.FEC_Status__c == false) {
                        continue;
                    }
                } else {
                    continue;
                }
                
                // 4. Sub Category Node
                NatureOfCaseTreeItem subCatNode;
                if (subCategoryCode != null) {
                    String subCatKey = catNode.code + '_' + subCategoryCode;
                    if (catNode.mapChilds == null) catNode.mapChilds = new Map<String, NatureOfCaseTreeItem>();
                    
                    if (!catNode.mapChilds.containsKey(subCatKey)) {
                        // 🚨 Gán các trường chi tiết cho Sub Category
                        subCatNode = new NatureOfCaseTreeItem(
                            subCategoryCode,
                        scatKey,
                        new List<NatureOfCaseTreeItem>(),
                        noc.FEC_Sub_Category_Name__r.FEC_Alias__c,
                        noc.FEC_Sub_Category_Name__r.FEC_Code__c,
                        noc.FEC_Sub_Category_Name__r.FEC_Name_VN__c,
                        noc.FEC_Sub_Category_Name__r.FEC_Pos_Order__c,
                        noc.FEC_Sub_Category_Name__r.FEC_Status__c,
                        noc.FEC_Sub_Category_Name__r.Process_Change_Status__c,
                        noc.FEC_Sub_Category_Name__r.Name,
                        noc.FEC_Sub_Category_Name__c,
                        noc.FEC_Customer_Type__c,
                        noc.Id,
                        FEC_Constants.LABEL_SUB_CATEGORY
                            );
                        catNode.mapChilds.put(subCatKey, subCatNode);
                    } else {
                        subCatNode = catNode.mapChilds.get(subCatKey);
                    }
                    if (noc.FEC_Sub_Category_Name__r.FEC_Status__c == false) {
                        continue;
                    }
                } else {
                    continue;
                }
                
                // 5. Sub Code Node (Leaf Node)
                if (subCodeCode != null) {
                    String scKey = subCatNode.code + '_' + subCodeCode;
                    if (subCatNode.mapChilds == null) subCatNode.mapChilds = new Map<String, NatureOfCaseTreeItem>();
                    
                    if (!subCatNode.mapChilds.containsKey(scKey)) {
                        // 🚨 Gán các trường chi tiết cho Sub Code
                        NatureOfCaseTreeItem scNode = new NatureOfCaseTreeItem(
                            subCodeCode,
                        scodeKey, // Dùng ID Sub Code
                        null,
                        noc.FEC_Sub_Code__r.FEC_Alias__c,
                        noc.FEC_Sub_Code__r.FEC_Code__c,
                        noc.FEC_Sub_Code__r.FEC_Name_VN__c,
                        noc.FEC_Sub_Code__r.FEC_Pos_Order__c,
                        noc.FEC_Sub_Code__r.FEC_Status__c,
                        noc.FEC_Sub_Code__r.Process_Change_Status__c,
                        noc.FEC_Sub_Code__r.Name,
                        noc.FEC_Sub_Code__c,
                        noc.FEC_Customer_Type__c,
                        noc.Id,
                        FEC_Constants.LABEL_SUB_CODE
                            );
                        subCatNode.mapChilds.put(scKey, scNode);
                    }
                    if (noc.FEC_Sub_Code__r.FEC_Status__c == false) {
                        continue;
                    }
                }
            }
            
            // Chuyển đổi Map sang List cho Node gốc
            for (NatureOfCaseTreeItem ptItem : mapProductType.values()) {
                ptItem.convertMapToList();
                treeItems.add(ptItem);
            }
        } catch (Exception e) {
            System.debug('FEC_NatureOfCaseTreeController.getNatureOfCaseTreeData error: ' + e);
            // Return empty list on failure to avoid throwing raw exceptions to UI
            return new List<NatureOfCaseTreeItem>();
        }
        
        return treeItems;
    }
    
    /**
     * Inner class to represent a node in the lightning-tree data structure.
     * @date 2025-12-09
     * @author DAT NGO
     */
    public class NatureOfCaseTreeItem {
        @AuraEnabled public String label;
        @AuraEnabled public String name;
        @AuraEnabled public String FEC_Customer_Type;
        @AuraEnabled public String NameEN;
        @AuraEnabled public String Alias;
        @AuraEnabled public String ChangeStatus;
        @AuraEnabled public String iconName;
        @AuraEnabled public String Code;
        @AuraEnabled public String nameVN;
        @AuraEnabled public String idType;
        @AuraEnabled public String id;
        @AuraEnabled public String type;
        @AuraEnabled public Decimal PosOrder;
        @AuraEnabled public Boolean Status;
        @AuraEnabled public List<NatureOfCaseTreeItem> items; // Các node con
        
        // Dùng transient map để dễ dàng xây dựng cấu trúc tree (Quy tắc: Tái sử dụng/Thao tác Dữ liệu bằng Map)
        @AuraEnabled public transient Map<String, NatureOfCaseTreeItem> mapChilds;
        
        // 🚨 CẬP NHẬT CONSTRUCTOR
        public NatureOfCaseTreeItem(String label, String name, List<NatureOfCaseTreeItem> items,
        String alias, String code, String nameVN, Decimal posOrder, Boolean status,String changeStatus,String nameEN,String idType,String FEC_Customer_Type,String id,String type) {
            this.label = label;
            this.name = name;
            this.FEC_Customer_Type = FEC_Customer_Type;
            this.items = items;
            this.Alias = alias;
            this.Code = code;
            this.nameVN = nameVN;
            this.PosOrder = posOrder;
            this.Status = status;
            this.ChangeStatus = changeStatus;
            this.nameEN = nameEN;
            this.idType = idType;
            this.id = id;
            this.type = type;
            this.mapChilds = new Map<String, NatureOfCaseTreeItem>();
            
            if (status == true) {
                this.iconName = FEC_Constants.ICON_RECORD; // Icon bình thường
            } else {
                this.iconName = FEC_Constants.ICON_LOCK; // Icon biểu thị ngắt kết nối/inactive
            }
        }
        
        // Tái sử dụng: Hàm đệ quy chuyển đổi Map Child sang List Child
        public void convertMapToList() {
            if (this.mapChilds != null && !this.mapChilds.isEmpty()) {
                this.items = new List<NatureOfCaseTreeItem>();
                for (NatureOfCaseTreeItem child : this.mapChilds.values()) {
                    child.convertMapToList(); // Gọi đệ quy cho node con
                    this.items.add(child);
                }
                this.mapChilds.clear();
            }
        }
    }
    
    // Danh sách TẤT CẢ các trường Lookup trên FEC_MDM_Nature_Of_Case__c (để copy chuỗi tổ tiên)
    private static final List<String> ALL_NOC_LOOKUP_FIELDS = new List<String>{
        FEC_Constants.NOC_FIELD_PRODUCT_TYPE,
        FEC_Constants.NOC_FIELD_BUSINESS_PROCESS,
        FEC_Constants.NOC_FIELD_CATEGORY,
        FEC_Constants.NOC_FIELD_SUB_CATEGORY,
        FEC_Constants.NOC_FIELD_SUB_CODE // Đây là trường NOC cho cấp thấp nhất
    };
    
    // Ánh xạ Lookup SObject (Key) tới [Field trỏ tới SObject đó, Immediate Parent NOC Field (để Query)] trên FEC_MDM_Nature_Of_Case__c
    private static final Map<String, List<String>> NOC_MAPPING = new Map<String, List<String>>{
        // Child Object             => [Child NOC Field, Immediate Parent NOC Field (để Query)]
        FEC_Constants.KEY_MDM_BUSINESS_PROCESS => new List<String>{FEC_Constants.NOC_FIELD_BUSINESS_PROCESS, FEC_Constants.NOC_FIELD_PRODUCT_TYPE},
        FEC_Constants.KEY_MDM_CATEGORY         => new List<String>{FEC_Constants.NOC_FIELD_CATEGORY, FEC_Constants.NOC_FIELD_BUSINESS_PROCESS},
        FEC_Constants.KEY_MDM_SUB_CATEGORY     => new List<String>{FEC_Constants.NOC_FIELD_SUB_CATEGORY, FEC_Constants.NOC_FIELD_CATEGORY},
        FEC_Constants.KEY_MDM_SUB_CODE         => new List<String>{FEC_Constants.NOC_FIELD_SUB_CODE, FEC_Constants.NOC_FIELD_SUB_CATEGORY}
    };
    /**
     * @description Inserts a new record into a specified Lookup Object (Tất cả đều có FEC_ prefix).
     * @param strObjectType API Name của đối tượng mục tiêu (e.g., 'FEC_MDM_Product_Type__c').
     * @param strParentId ID của node cha.
     * @param strAlias Alias cho bản ghi mới.
     * @param strCode Code cho bản ghi mới.
     * @param strNameVN Tên Tiếng Việt cho bản ghi mới.
     * @param intPosOrder Position Order cho bản ghi mới.
     * @param isStatus Status của bản ghi mới.
     * @return String The ID của bản ghi Lookup mới được tạo.
     * @author DAT NGO
     */
    @AuraEnabled
    public static String saveNewLookupNode(String strObjectType, String strCustomerType, String strParentId,String strName, String strAlias, String strCode, String strNameVN, Integer intPosOrder, Boolean isStatus) {
        String newRecordId;
        System.debug('---[START] saveNewLookupNode---');
        
        Map<String, String> labelToApiMap = new Map<String, String>();
        labelToApiMap.put(FEC_Constants.LABEL_PRODUCT_TYPE, FEC_Constants.OBJ_MDM_PRODUCT_TYPE);
        labelToApiMap.put(FEC_Constants.LABEL_BUSINESS_PROCESS, FEC_Constants.OBJ_MDM_BUSINESS_PROCESS);
        labelToApiMap.put(FEC_Constants.LABEL_CATEGORY, FEC_Constants.OBJ_MDM_CATEGORY);
        labelToApiMap.put(FEC_Constants.LABEL_SUB_CATEGORY, FEC_Constants.OBJ_MDM_SUB_CATEGORY);
        labelToApiMap.put(FEC_Constants.LABEL_SUB_CODE, FEC_Constants.OBJ_MDM_SUB_CODE);
        
        String apiName = labelToApiMap.containsKey(strObjectType)
            ? labelToApiMap.get(strObjectType)
            : strObjectType;
        
        SObject newRecord;
        Schema.SObjectType targetSObjectType = Schema.getGlobalDescribe().get(apiName);
        newRecord = targetSObjectType.newSObject();
        newRecord.put(FEC_Constants.FIELD_ALIAS, strAlias);
        newRecord.put(FEC_Constants.FIELD_CODE, strCode);
        newRecord.put(FEC_Constants.FIELD_NAME_VN, strNameVN);
        newRecord.put(FEC_Constants.FIELD_STATUS, isStatus);
        newRecord.put(FEC_Constants.FIELD_NAME, strName);
        
        Map<String, Schema.SObjectField> fieldMap = newRecord.getSobjectType().getDescribe().fields.getMap();
        if (fieldMap.containsKey(FEC_Constants.FIELD_POS_ORDER)) {
            newRecord.put(FEC_Constants.FIELD_POS_ORDER, intPosOrder);
        }
        
        try {
            Database.insert(newRecord);
            newRecordId = (String)newRecord.get(FEC_Constants.FIELD_ID);
        } catch (DmlException e) {
            throw new AuraHandledException('Lỗi khi lưu bản ghi Lookup (' + strObjectType + '). Chi tiết lỗi: ' + e.getMessage());
        }
        
        try {
            String objectTypeUpper = apiName.toUpperCase();
            System.debug('objectTypeUpper: ' + objectTypeUpper);
            
            FEC_MDM_Nature_Of_Case__c nocRecord = new FEC_MDM_Nature_Of_Case__c(
                Name = strCode,
            FEC_Customer_Type__c = strCustomerType
                );
            System.debug('nocRecord (init): ' + nocRecord);
            
            if (objectTypeUpper.equalsIgnoreCase(FEC_Constants.KEY_MDM_PRODUCT_TYPE)) {
                nocRecord.FEC_Product_Type_Name__c = newRecordId;
                System.debug('Root node, set FEC_Product_Type_Name__c: ' + newRecordId);
            } else if (strParentId != null && !String.isBlank(strParentId) && NOC_MAPPING.containsKey(objectTypeUpper)) {
                List<String> mapping = NOC_MAPPING.get(objectTypeUpper);
                String childNocField = mapping[0];
                String parentNocField = mapping[1];
                
                String queryFields = String.join(ALL_NOC_LOOKUP_FIELDS, ',');
                System.debug('Querying parentNocs with parentNocField=' + parentNocField + ', strParentId=' + strParentId);
                
                List<FEC_MDM_Nature_Of_Case__c> parentNocs = Database.query(
                    'SELECT ' + queryFields + ' FROM FEC_MDM_Nature_Of_Case__c WHERE ' + parentNocField + ' = :strParentId LIMIT 1'
                    );
                if (parentNocs.isEmpty()) {
                    throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' Could not find Parent Nature of Case record: ' + strParentId);
                }
                FEC_MDM_Nature_Of_Case__c parentNoc = parentNocs[0];
                for (String fieldApiName : ALL_NOC_LOOKUP_FIELDS) {
                    Object fieldValue = parentNoc.get(fieldApiName);
                    if (fieldValue != null) {
                        nocRecord.put(fieldApiName, fieldValue);
                    }
                }
                nocRecord.put(childNocField, newRecordId);
            }
            
            Database.insert(nocRecord);
        } catch (Exception e) {
            throw new AuraHandledException('Lỗi không xác định trong quá trình liên kết FEC_MDM_Nature_Of_Case__c: ' + e.getMessage());
        }
        return newRecordId;
    }
    
    @AuraEnabled
    public static void deleteNodeApex(String typeRecordId, String typeName) {
        try {
            Set<Id> ptIds = new Set<Id>();
            Set<Id> bpIds = new Set<Id>();
            Set<Id> catIds = new Set<Id>();
            Set<Id> scatIds = new Set<Id>();
            Set<Id> scodeIds = new Set<Id>();
            
            String query = FEC_Constants.SQL_SELECT_NOC_FIELDS;
            
            if (typeName == FEC_Constants.LABEL_PRODUCT_TYPE) query += FEC_Constants.NOC_FIELD_PRODUCT_TYPE + ' = :typeRecordId';
            else if (typeName == FEC_Constants.LABEL_BUSINESS_PROCESS) query += FEC_Constants.NOC_FIELD_BUSINESS_PROCESS + ' = :typeRecordId';
            else if (typeName == FEC_Constants.LABEL_CATEGORY) query += FEC_Constants.NOC_FIELD_CATEGORY + ' = :typeRecordId';
            else if (typeName == FEC_Constants.LABEL_SUB_CATEGORY) query += FEC_Constants.NOC_FIELD_SUB_CATEGORY + ' = :typeRecordId';
            else if (typeName == FEC_Constants.LABEL_SUB_CODE) query += FEC_Constants.NOC_FIELD_SUB_CODE + ' = :typeRecordId';
            
            List<FEC_MDM_Nature_Of_Case__c> relatedNocs = Database.query(query);
            
            for (FEC_MDM_Nature_Of_Case__c n : relatedNocs) {
                if (n.FEC_Product_Type_Name__c != null) ptIds.add(n.FEC_Product_Type_Name__c);
                if (n.FEC_Business_Process_Name__c != null) bpIds.add(n.FEC_Business_Process_Name__c);
                if (n.FEC_Category_Name__c != null) catIds.add(n.FEC_Category_Name__c);
                if (n.FEC_Sub_Category_Name__c != null) scatIds.add(n.FEC_Sub_Category_Name__c);
                if (n.FEC_Sub_Code__c != null) scodeIds.add(n.FEC_Sub_Code__c);
            }
            
            // 2. XÓA MAPPING (NOC) TRƯỚC
            if (!relatedNocs.isEmpty()) delete relatedNocs;
            
            // Lưu ý: Chỉ xóa những gì thuộc về nhánh đang chọn
            if (typeName == FEC_Constants.LABEL_SUB_CODE) {
                deleteRecords(FEC_Constants.OBJ_MDM_SUB_CODE, scodeIds);
            }
            else if (typeName == FEC_Constants.LABEL_SUB_CATEGORY) {
                deleteRecords(FEC_Constants.OBJ_MDM_SUB_CODE, scodeIds);
                deleteRecords(FEC_Constants.OBJ_MDM_SUB_CATEGORY, scatIds);
            }
            else if (typeName == FEC_Constants.LABEL_CATEGORY) {
                deleteRecords(FEC_Constants.OBJ_MDM_SUB_CODE, scodeIds);
                deleteRecords(FEC_Constants.OBJ_MDM_SUB_CATEGORY, scatIds);
                deleteRecords(FEC_Constants.OBJ_MDM_CATEGORY, catIds);
            }
            else if (typeName == FEC_Constants.LABEL_BUSINESS_PROCESS) {
                deleteRecords(FEC_Constants.OBJ_MDM_SUB_CODE, scodeIds);
                deleteRecords(FEC_Constants.OBJ_MDM_SUB_CATEGORY, scatIds);
                deleteRecords(FEC_Constants.OBJ_MDM_CATEGORY, catIds);
                deleteRecords(FEC_Constants.OBJ_MDM_BUSINESS_PROCESS, bpIds);
            }
            else if (typeName == FEC_Constants.LABEL_PRODUCT_TYPE) {
                deleteRecords(FEC_Constants.OBJ_MDM_SUB_CODE, scodeIds);
                deleteRecords(FEC_Constants.OBJ_MDM_SUB_CATEGORY, scatIds);
                deleteRecords(FEC_Constants.OBJ_MDM_CATEGORY, catIds);
                deleteRecords(FEC_Constants.OBJ_MDM_BUSINESS_PROCESS, bpIds);
                deleteRecords(FEC_Constants.OBJ_MDM_PRODUCT_TYPE, ptIds);
            }
            
        } catch (Exception e) {
            throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }
    
    private static void deleteRecords(String objName, Set<Id> ids) {
        String dmlQuery = 'SELECT Id FROM ' + objName + ' WHERE Id IN :ids';
        delete Database.query(dmlQuery);
    }
    
    @AuraEnabled
    public static void updateMultipleNodes(List<Map<String, Object>> listData) {
        // 1. Khởi tạo các danh sách để gom nhóm update
        List<FEC_MDM_Product_Type__c> ptUpdates = new List<FEC_MDM_Product_Type__c>();
        List<FEC_MDM_Business_Process__c> bpUpdates = new List<FEC_MDM_Business_Process__c>();
        List<FEC_MDM_Category__c> catUpdates = new List<FEC_MDM_Category__c>();
        List<FEC_MDM_Sub_Category__c> scatUpdates = new List<FEC_MDM_Sub_Category__c>();
        List<FEC_MDM_Sub_Code__c> scodeUpdates = new List<FEC_MDM_Sub_Code__c>();
        
        try {
            for (Map<String, Object> data : listData) {
                String type = (String)data.get(FEC_Constants.PAYLOAD_TYPE);
                String recordId = (String)data.get(FEC_Constants.PAYLOAD_IDTYPE); // ID của Object Master gốc
                
                if (String.isBlank(recordId)) continue;
                
                // 2. Phân loại và gán giá trị field dựa trên Type
                if (type == FEC_Constants.LABEL_PRODUCT_TYPE) {
                    ptUpdates.add(new FEC_MDM_Product_Type__c(
                        Id = recordId,
                    Name = (String)data.get(FEC_Constants.PAYLOAD_NAMEEN),
                    FEC_Name_VN__c = (String)data.get(FEC_Constants.PAYLOAD_NAMEVN),
                    FEC_Alias__c = (String)data.get(FEC_Constants.PAYLOAD_ALIAS),
                    FEC_Code__c = (String)data.get(FEC_Constants.PAYLOAD_CODE),
                    FEC_Pos_Order__c = Decimal.valueOf(String.valueOf(data.get(FEC_Constants.PAYLOAD_POSORDER))),
                    FEC_Status__c = (Boolean)data.get(FEC_Constants.PAYLOAD_STATUS)
                        ));
                }
                else if (type == FEC_Constants.LABEL_BUSINESS_PROCESS) {
                    bpUpdates.add(new FEC_MDM_Business_Process__c(
                        Id = recordId,
                    Name = (String)data.get(FEC_Constants.PAYLOAD_NAMEEN),
                    FEC_Name_VN__c = (String)data.get(FEC_Constants.PAYLOAD_NAMEVN),
                    FEC_Alias__c = (String)data.get(FEC_Constants.PAYLOAD_ALIAS),
                    FEC_Code__c = (String)data.get(FEC_Constants.PAYLOAD_CODE),
                    FEC_Pos_Order__c = Decimal.valueOf(String.valueOf(data.get(FEC_Constants.PAYLOAD_POSORDER))),
                    FEC_Status__c = (Boolean)data.get(FEC_Constants.PAYLOAD_STATUS)
                        ));
                }
                else if (type == FEC_Constants.LABEL_CATEGORY) {
                    catUpdates.add(new FEC_MDM_Category__c(
                        Id = recordId,
                    Name = (String)data.get(FEC_Constants.PAYLOAD_NAMEEN),
                    FEC_Name_VN__c = (String)data.get(FEC_Constants.PAYLOAD_NAMEVN),
                    FEC_Alias__c = (String)data.get(FEC_Constants.PAYLOAD_ALIAS),
                    FEC_Code__c = (String)data.get(FEC_Constants.PAYLOAD_CODE),
                    FEC_Pos_Order__c = Decimal.valueOf(String.valueOf(data.get(FEC_Constants.PAYLOAD_POSORDER))),
                    FEC_Status__c = (Boolean)data.get(FEC_Constants.PAYLOAD_STATUS)
                        ));
                }
                else if (type == FEC_Constants.LABEL_SUB_CATEGORY) {
                    scatUpdates.add(new FEC_MDM_Sub_Category__c(
                        Id = recordId,
                    Name = (String)data.get(FEC_Constants.PAYLOAD_NAMEEN),
                    FEC_Name_VN__c = (String)data.get(FEC_Constants.PAYLOAD_NAMEVN),
                    FEC_Alias__c = (String)data.get(FEC_Constants.PAYLOAD_ALIAS),
                    FEC_Code__c = (String)data.get(FEC_Constants.PAYLOAD_CODE),
                    FEC_Pos_Order__c = Decimal.valueOf(String.valueOf(data.get(FEC_Constants.PAYLOAD_POSORDER))),
                    FEC_Status__c = (Boolean)data.get(FEC_Constants.PAYLOAD_STATUS)
                        ));
                }
                else if (type == FEC_Constants.LABEL_SUB_CODE) {
                    scodeUpdates.add(new FEC_MDM_Sub_Code__c(
                        Id = recordId,
                    Name = (String)data.get(FEC_Constants.PAYLOAD_NAMEEN),
                    FEC_Name_VN__c = (String)data.get(FEC_Constants.PAYLOAD_NAMEVN),
                    FEC_Alias__c = (String)data.get(FEC_Constants.PAYLOAD_ALIAS),
                    FEC_Code__c = (String)data.get(FEC_Constants.PAYLOAD_CODE),
                    FEC_Pos_Order__c = Decimal.valueOf(String.valueOf(data.get(FEC_Constants.PAYLOAD_POSORDER))),
                    FEC_Status__c = (Boolean)data.get(FEC_Constants.PAYLOAD_STATUS)
                        ));
                }
            }
            
            // 3. Thực thi DML hàng loạt
            if (!ptUpdates.isEmpty()) update ptUpdates;
            if (!bpUpdates.isEmpty()) update bpUpdates;
            if (!catUpdates.isEmpty()) update catUpdates;
            if (!scatUpdates.isEmpty()) update scatUpdates;
            if (!scodeUpdates.isEmpty()) update scodeUpdates;
            
        } catch (Exception e) {
            throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }
    
    /**
     * Update existing node
     */
    @AuraEnabled
    public static void updateNode(Map<String, Object> updateData) {
        String IdNOC = (String)updateData.get(FEC_Constants.PAYLOAD_ID);
        String nodeId = (String)updateData.get(FEC_Constants.PAYLOAD_IDTYPE);
        String nodeType = (String)updateData.get(FEC_Constants.PAYLOAD_TYPE);
        SObject targetSObject;
        
        if (nodeType == FEC_Constants.LABEL_PRODUCT_TYPE) {
            targetSObject = [SELECT Id FROM FEC_MDM_Product_Type__c WHERE Id = :nodeId LIMIT 1];
        } else if (nodeType == FEC_Constants.LABEL_BUSINESS_PROCESS) {
            targetSObject = [SELECT Id FROM FEC_MDM_Business_Process__c WHERE Id = :nodeId LIMIT 1];
        } else if (nodeType == FEC_Constants.LABEL_CATEGORY) {
            targetSObject = [SELECT Id FROM FEC_MDM_Category__c WHERE Id = :nodeId LIMIT 1];
        } else if (nodeType == FEC_Constants.LABEL_SUB_CATEGORY) {
            targetSObject = [SELECT Id FROM FEC_MDM_Sub_Category__c WHERE Id = :nodeId LIMIT 1];
        } else if (nodeType == FEC_Constants.LABEL_SUB_CODE) {
            targetSObject = [SELECT Id FROM FEC_MDM_Sub_Code__c WHERE Id = :nodeId LIMIT 1];
        }
        
        // Gán các giá trị chung
        targetSObject.put(FEC_Constants.FIELD_ALIAS, (String)updateData.get(FEC_Constants.PAYLOAD_ALIAS));
        targetSObject.put(FEC_Constants.FIELD_CODE, (String)updateData.get(FEC_Constants.PAYLOAD_CODE));
        targetSObject.put(FEC_Constants.FIELD_NAME_VN, (String)updateData.get(FEC_Constants.PAYLOAD_NAMEVN));
        targetSObject.put(FEC_Constants.FIELD_STATUS, (Boolean)updateData.get(FEC_Constants.PAYLOAD_STATUS));
        targetSObject.put(FEC_Constants.FIELD_NAME, (String)updateData.get(FEC_Constants.PAYLOAD_NAMEEN));
        targetSObject.put(FEC_Constants.FIELD_POS_ORDER, (Decimal)updateData.get(FEC_Constants.PAYLOAD_POSORDER));
        
        try {
            update targetSObject;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }
    
    /**
     * Get all master data mappings
     */
    @AuraEnabled(cacheable=true)
    public static List<FEC_MDM_Nature_Of_Case__c> getMasterDataMappings() {
        return [
                SELECT 
                    Id, Name, 
                    FEC_Product_Type_Name__c, 
                    FEC_Product_Type_Name__r.Name, 
                    FEC_Product_Type_Name__r.FEC_Name_VN__c, 
                    // THÊM CÁC TRƯỜNG MỚI CHO Product Line
                    FEC_Product_Type_Name__r.FEC_Alias__c, 
                    FEC_Product_Type_Name__r.FEC_Code__c, 
                    FEC_Product_Type_Name__r.FEC_Pos_Order__c, 
                    FEC_Product_Type_Name__r.FEC_Status__c,
                    
                    FEC_Business_Process_Name__c, 
                    FEC_Business_Process_Name__r.Name, 
                    FEC_Business_Process_Name__r.FEC_Name_VN__c,
                    // THÊM CÁC TRƯỜNG MỚI CHO Service Type
                    FEC_Business_Process_Name__r.FEC_Alias__c,
                    FEC_Business_Process_Name__r.FEC_Code__c,
                    FEC_Business_Process_Name__r.FEC_Pos_Order__c,
                    FEC_Business_Process_Name__r.FEC_Status__c,

                    FEC_Category_Name__c, 
                    FEC_Category_Name__r.Name, 
                    FEC_Category_Name__r.FEC_Name_VN__c,
                    // THÊM CÁC TRƯỜNG MỚI CHO Category
                    FEC_Category_Name__r.FEC_Alias__c,
                    FEC_Category_Name__r.FEC_Code__c,
                    FEC_Category_Name__r.FEC_Pos_Order__c,
                    FEC_Category_Name__r.FEC_Status__c,

                    FEC_Sub_Category_Name__c, 
                    FEC_Sub_Category_Name__r.Name, 
                    FEC_Sub_Category_Name__r.FEC_Name_VN__c,
                    // THÊM CÁC TRƯỜNG MỚI CHO Sub Category
                    FEC_Sub_Category_Name__r.FEC_Alias__c,
                    FEC_Sub_Category_Name__r.FEC_Code__c,
                    FEC_Sub_Category_Name__r.FEC_Pos_Order__c,
                    FEC_Sub_Category_Name__r.FEC_Status__c,

                    FEC_Sub_Code__c, 
                    FEC_Sub_Code__r.Name, 
                    FEC_Sub_Code__r.FEC_Name_VN__c,
                    // THÊM CÁC TRƯỜNG MỚI CHO Action
                    FEC_Sub_Code__r.FEC_Alias__c,
                    FEC_Sub_Code__r.FEC_Code__c,
                    FEC_Sub_Code__r.FEC_Pos_Order__c,
                    FEC_Sub_Code__r.FEC_Status__c
                FROM FEC_MDM_Nature_Of_Case__c
                ORDER BY FEC_Product_Type_Name__r.Name, FEC_Business_Process_Name__r.Name, 
                        FEC_Category_Name__r.Name, FEC_Sub_Category_Name__r.Name, FEC_Sub_Code__r.Name
             LIMIT :FEC_Constants.QUERY_LIMIT
         ];
     }
 }
