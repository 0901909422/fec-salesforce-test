// Check FEC_ID_Search__c và các custom fields của Case 00003949
Case c = [SELECT Id, CaseNumber, Origin, Status, RecordTypeId,
                 FEC_ID_Search__c, FEC_Channel__c, FEC_Interaction_Subchannel__c,
                 FEC_Interaction_Email__c, FEC_Send_To__c
          FROM Case WHERE CaseNumber = '00003949' LIMIT 1];

System.debug('=== CASE 00003949 ===');
System.debug('Id: ' + c.Id);
System.debug('CaseNumber: ' + c.CaseNumber);
System.debug('Origin: ' + c.Origin);
System.debug('Status: ' + c.Status);
System.debug('RecordTypeId: ' + c.RecordTypeId);
System.debug('FEC_ID_Search__c: ' + c.FEC_ID_Search__c);
System.debug('FEC_Channel__c: ' + c.FEC_Channel__c);
System.debug('FEC_Interaction_Subchannel__c: ' + c.FEC_Interaction_Subchannel__c);
System.debug('FEC_Interaction_Email__c: ' + c.FEC_Interaction_Email__c);
System.debug('FEC_Send_To__c: ' + c.FEC_Send_To__c);

// Check RecordType name
RecordType rt = [SELECT Id, DeveloperName, Name FROM RecordType WHERE Id = :c.RecordTypeId LIMIT 1];
System.debug('RecordType DeveloperName: ' + rt.DeveloperName);
System.debug('RecordType Name: ' + rt.Name);
