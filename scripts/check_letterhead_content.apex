FEC_Enhanced_Letterhead__c lh = [SELECT Id, FEC_Header__c, FEC_Footer__c FROM FEC_Enhanced_Letterhead__c WHERE Id = 'a0xAz000000jS4zIAE' LIMIT 1];
System.debug('Header length: ' + (lh.FEC_Header__c != null ? lh.FEC_Header__c.length() : 0));
System.debug('Header: ' + (lh.FEC_Header__c != null ? lh.FEC_Header__c.left(500) : 'null'));
System.debug('Footer length: ' + (lh.FEC_Footer__c != null ? lh.FEC_Footer__c.length() : 0));
