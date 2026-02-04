public with sharing class FEC_FecServiceTypeMappingController {
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getServiceTypeTree() {
        // 1. Lấy danh sách tất cả Business Process (Cấp cha)
        Map<Id, FEC_MDM_Business_Process__c> bpMap = new Map<Id, FEC_MDM_Business_Process__c>(
            [SELECT Id, Name FROM FEC_MDM_Business_Process__c ORDER BY Name]
            );
        
        // 2. Truy vấn Master Data Setting thông qua đường dẫn Nature of Case
        List<FEC_MDM_Master_Data_Setting__c> allSettings = [
            SELECT Id, Name,FEC_Additional_Field__r.Name, Property_Reference__c, 
                   FEC_Nature_Of_Case__r.FEC_Business_Process_Name__c 
            FROM FEC_MDM_Master_Data_Setting__c
            WHERE FEC_Nature_Of_Case__r.FEC_Business_Process_Name__c IN :bpMap.keySet()
            AND FEC_Additional_Field__c != null
            ORDER BY Name
        ];
        
        // 3. Nhóm các Property vào Business Process tương ứng
        Map<Id, List<Map<String, Object>>> bpToProperties = new Map<Id, List<Map<String, Object>>>();
        for(FEC_MDM_Master_Data_Setting__c setting : allSettings) {
            Id bpId = setting.FEC_Nature_Of_Case__r.FEC_Business_Process_Name__c;
            if(!bpToProperties.containsKey(bpId)) {
                bpToProperties.put(bpId, new List<Map<String, Object>>());
            }
            
            // Lấy nhãn hiển thị: Ưu tiên Name của Additional Field, nếu null thì dùng Name của Setting
            String displayLabel = setting.FEC_Additional_Field__r.Name;
            
            bpToProperties.get(bpId).add(new Map<String, Object>{
                'label' => displayLabel,
                'name' => setting.Id,
                'propertyRef' => setting.Property_Reference__c,
                'parentName' => bpMap.get(bpId).Name
            });
        }
        
        // 4. Xây dựng cấu trúc cây
        List<Map<String, Object>> treeData = new List<Map<String, Object>>();
        for(FEC_MDM_Business_Process__c bp : bpMap.values()) {
            // Lấy danh sách con, nếu không có thì trả về list rỗng thay vì null
            List<Map<String, Object>> children = bpToProperties.containsKey(bp.Id)
                ? bpToProperties.get(bp.Id)
                : new List<Map<String, Object>>();
            
            // LUÔN THÊM vào treeData bất kể có con hay không
            treeData.add(new Map<String, Object>{
                'label' => bp.Name,
                'name' => bp.Id,
                'expanded' => false,
                'items' => children // Nếu children rỗng, Tree chỉ hiển thị cấp cha và không có nút expand
            });
        }
        System.debug('Service Type Tree Data: ' + treeData);
        return treeData;
    }
    
    @AuraEnabled
    public static void savePropertyMapping(Id settingId, String newRef) {
        try {
            update new FEC_MDM_Master_Data_Setting__c(
                Id = settingId,
            Property_Reference__c = newRef
                );
        } catch (Exception e) {
            // Lấy lỗi hệ thống khác
            throw new AuraHandledException('System Error: ' + e.getMessage());
        }
    }
}
