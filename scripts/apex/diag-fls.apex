Map<String,Schema.SObjectField> m = Schema.SObjectType.Case.fields.getMap();
System.debug('=== Has FEC_Archive_Status__c: ' + m.containsKey('FEC_Archive_Status__c'));
