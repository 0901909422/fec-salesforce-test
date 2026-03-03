public without sharing class FEC_ClickToCallHandler {
    public class PhoneWrapper {
        @AuraEnabled public String phone;
        
        public PhoneWrapper(String label, String phone) {
            this.phone = phone;
        }
    }
    
    
    public class CallResponse {
        @AuraEnabled public Integer statusCode;
        @AuraEnabled public String message;
        @AuraEnabled public String status;
        @AuraEnabled public Map<String, Object> requestResult;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<PhoneWrapper> getPhoneList(Id caseId) {
        List<PhoneWrapper> phoneList = new List<PhoneWrapper>();
        
        Map<String, Schema.SObjectField> fieldMap = Schema.Case.SObjectType.getDescribe().fields.getMap();
        List<String> phoneFields = new List<String>();
        
        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult describeResult = fieldMap.get(fieldName).getDescribe();
            if (describeResult.getType() == Schema.DisplayType.Phone) {
                phoneFields.add(fieldName);
            }
        }
        
        if (phoneFields.isEmpty()) return phoneList;
        
        String query = 'SELECT ' + String.join(phoneFields, ',') + ' FROM Case WHERE Id = :caseId LIMIT 1';
        Case c = Database.query(query);
        
        for (String fieldName : phoneFields) {
            Object val = c.get(fieldName);
            if (val != null) {
                phoneList.add(new PhoneWrapper(fieldName, String.valueOf(val)));
            }
        }
        
        return phoneList;
    }
}