Case c = [SELECT Id, CaseNumber, FEC_Interaction_View_Mode__c, FEC_Has_Account_or_Contract__c, FEC_Channel__c, FEC_Is_In_Create_new_mode__c
          FROM Case WHERE Id = '500Az00000Mr8ysIAB'];
System.debug('ViewMode: ' + c.FEC_Interaction_View_Mode__c);
System.debug('HasAccountOrContract: ' + c.FEC_Has_Account_or_Contract__c);
System.debug('Channel: ' + c.FEC_Channel__c);
System.debug('IsInCreateNewMode: ' + c.FEC_Is_In_Create_new_mode__c);
