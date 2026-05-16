// tungnm37: check API setting và config cho MarkNFU
FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
System.debug('FEC_Call_Mock__c: ' + apiSetting?.FEC_Call_Mock__c);
System.debug('FEC_Endpoint__c: ' + apiSetting?.FEC_Endpoint__c);

FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Mark_NFU');
System.debug('API Config FEC_Endpoint__c: ' + apiConfig?.FEC_Endpoint__c);
System.debug('API Config FEC_SOAP_Action__c: ' + apiConfig?.FEC_SOAP_Action__c);
