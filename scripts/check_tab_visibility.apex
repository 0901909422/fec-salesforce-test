// Check tab visibility for current user
String userId = UserInfo.getUserId();
User u = [SELECT ProfileId, Profile.Name FROM User WHERE Id = :userId LIMIT 1];
System.debug('Profile: ' + u.Profile.Name + ' | ProfileId: ' + u.ProfileId);

// Check if FEC_Clear_Session__c tab exists
List<TabDefinition> tabs = [SELECT Id, Name, Label FROM TabDefinition WHERE Name = 'FEC_Clear_Session__c' LIMIT 1];
System.debug('Tab found: ' + tabs.size() + ' | ' + (tabs.isEmpty() ? 'NOT FOUND' : tabs[0].Label));
