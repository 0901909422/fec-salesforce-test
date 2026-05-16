// Test inlineImages trong Queueable context (có callout)
FEC_Enhanced_Letterhead__c lh = [SELECT Id, FEC_Header__c FROM FEC_Enhanced_Letterhead__c WHERE Id = 'a0xAz000000jS4zIAE' LIMIT 1];
String header = lh.FEC_Header__c;
System.debug('Original header: ' + header);

String result = FEC_NotificationService.inlineImages(header);
System.debug('Result starts with data: ' + result.startsWith('<p><img src="data:'));
System.debug('Result length: ' + result.length());
System.debug('Result: ' + result.left(200));
