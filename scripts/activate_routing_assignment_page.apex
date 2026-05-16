// tungnm37: Activate Routing_Assignment_Record_Page làm org default
// Chạy script này để set page làm default cho FEC_Routing_Assignment__c

List<FlexiPageRegion> pages = [
    SELECT Id, DeveloperName, MasterLabel
    FROM FlexiPage
    WHERE DeveloperName = 'Routing_Assignment_Record_Page'
    LIMIT 1
];
System.debug('FlexiPage found: ' + pages);
