User u = [SELECT Id, Name, AboutMe, FEC_Agent_ID__c, UserPreferencesActivityRemindersPopup, ReceivesAdminInfoEmails FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
System.debug('Name: ' + u.Name);
System.debug('AboutMe: ' + u.AboutMe);
System.debug('FEC_Agent_ID__c: ' + u.FEC_Agent_ID__c);
System.debug('UserPreferencesActivityRemindersPopup: ' + u.UserPreferencesActivityRemindersPopup);
System.debug('ReceivesAdminInfoEmails: ' + u.ReceivesAdminInfoEmails);
