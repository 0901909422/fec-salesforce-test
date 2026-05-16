User u = [SELECT FEC_User_Group__c, Name, Username FROM User WHERE Id = :UserInfo.getUserId()];
System.debug('Name: ' + u.Name + ' | Username: ' + u.Username + ' | UserGroup: ' + u.FEC_User_Group__c);
