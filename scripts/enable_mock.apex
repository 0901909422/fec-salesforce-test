FEC_API_Setting__c s = FEC_API_Setting__c.getOrgDefaults();
s.FEC_Call_Mock__c = true;
upsert s;
System.debug('Mock enabled: ' + s.FEC_Call_Mock__c);
