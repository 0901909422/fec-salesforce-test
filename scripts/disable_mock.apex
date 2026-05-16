FEC_API_Setting__c s = FEC_API_Setting__c.getOrgDefaults();
s.FEC_Call_Mock__c = false;
upsert s;
System.debug('Mock disabled: ' + s.FEC_Call_Mock__c);
