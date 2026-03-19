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
        
        try {
            
            if (caseId == null) {
                return phoneList;
            }
            
            Map<String, Schema.SObjectField> fieldMap =
                Case.SObjectType.getDescribe().fields.getMap();
            
            List<String> phoneFields = new List<String>();
            
            for (Schema.SObjectField f : fieldMap.values()) {
                
                Schema.DescribeFieldResult d = f.getDescribe();
                
                if (d.getType() == Schema.DisplayType.Phone && d.isAccessible()) {
                    phoneFields.add(d.getName());
                }
            }
            
            if (phoneFields.isEmpty()) {
                return phoneList;
            }

            System.debug('Phone fields to query: ' + phoneFields);
            
            String query =
                'SELECT ' + String.join(phoneFields, ',') +
                ' FROM Case WHERE Id = :caseId LIMIT 1';
            
            List<Case> results = Database.query(query);
            
            if (results.isEmpty()) {
                return phoneList;
            }
            
            Case c = results[0];
            
            for (String fieldName : phoneFields) {
                
                Object val = c.get(fieldName);
                
                if (val != null) {
                    phoneList.add(new PhoneWrapper(fieldName, String.valueOf(val)));
                }
            }
            
        } catch (Exception e) {
            
            // Log full error for debugging
            System.debug('Error in getPhoneList: ' + e.getMessage());
            
            // Optional: rethrow user-friendly message
            // throw new AuraHandledException('Unable to load phone fields.');
            
        }
        
        return phoneList;
    }
}