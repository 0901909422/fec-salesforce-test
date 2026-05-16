// Check điều kiện của 2 notification rules đang match CSM Mailbox
List<FEC_Notification__c> rules = [
    SELECT Id, Name, FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c,
           FEC_Customer_Type__c, FEC_Schedule_Start_Time__c, FEC_Schedule_End_Time__c,
           FEC_Receivers__c
    FROM FEC_Notification__c
    WHERE Id IN ('a08Az00000Pm3y6IAB', 'a08Az00000PmCEzIAN')
];
for (FEC_Notification__c r : rules) {
    System.debug('Rule: ' + r.Name + ' | ProductType=' + r.FEC_Product_Type__c
        + ' | Category=' + r.FEC_Category__c + ' | SubCat=' + r.FEC_SubCategory__c
        + ' | SubCode=' + r.FEC_SubCode__c + ' | CustomerType=' + r.FEC_Customer_Type__c
        + ' | ScheduleStart=' + r.FEC_Schedule_Start_Time__c + ' | ScheduleEnd=' + r.FEC_Schedule_End_Time__c
        + ' | Receivers=' + r.FEC_Receivers__c);
}

// Check case hiện tại
Case c = [SELECT Id, FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c, FEC_Customer_Type__c
          FROM Case WHERE Id = '500Az00000M8FmqIAF'];
System.debug('Case: ProductType=' + c.FEC_Product_Type__c + ' Category=' + c.FEC_Category__c
    + ' SubCat=' + c.FEC_SubCategory__c + ' SubCode=' + c.FEC_SubCode__c + ' CustomerType=' + c.FEC_Customer_Type__c);

// Check current time
Time nowTime = FEC_CommonUltils.getCurrentLocalTime();
System.debug('Current local time: ' + nowTime);
