// Check FEC_RelevantTicketController body trên FecUat
List<ApexClass> classes = [
    SELECT Id, Name, Body
    FROM ApexClass
    WHERE Name IN ('FEC_RelevantTicketController', 'FEC_RelevantTicketTriggerHandler')
    ORDER BY Name
];
for (ApexClass c : classes) {
    System.debug('=== ' + c.Name + ' ===');
    System.debug(c.Body);
}
