// Tìm tab style của FEC_Routing_Assignment__c
List<CustomTab> tabs = [SELECT Name, SobjectName, CustomObject FROM CustomTab WHERE SobjectName = 'FEC_Routing_Assignment__c' LIMIT 1];
System.debug('Tabs: ' + tabs);
for (CustomTab t : tabs) {
    System.debug('Name=' + t.Name + ' SObject=' + t.SobjectName);
}
