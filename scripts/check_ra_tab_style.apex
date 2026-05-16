// Tìm tab style của FEC_Routing_Assignment__c qua metadata
List<ApexClass> cls = [SELECT Id FROM ApexClass WHERE Name = 'FEC_NocRoutingAssignmentController' LIMIT 1];
System.debug('Controller exists: ' + !cls.isEmpty());

// Query object icon via EntityDefinition
List<EntityDefinition> defs = [
    SELECT QualifiedApiName, Label, MasterLabel
    FROM EntityDefinition
    WHERE QualifiedApiName = 'FEC_Routing_Assignment__c'
    LIMIT 1
];
System.debug('EntityDef: ' + defs);
