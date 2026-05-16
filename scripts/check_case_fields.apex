// Check Case fields liên quan đến account number
Case c = [SELECT Id, CaseNumber, AccountId, FEC_Account_Number__c FROM Case ORDER BY LastModifiedDate DESC LIMIT 1];
System.debug('CaseNumber: ' + c.CaseNumber);
System.debug('AccountId: ' + c.AccountId);
System.debug('FEC_Account_Number__c: ' + c.FEC_Account_Number__c);
