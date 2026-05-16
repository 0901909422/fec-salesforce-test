// Setup trace flag cho Automated Process user để capture trigger logs
User automatedUser = [SELECT Id FROM User WHERE Name = 'Automated Process' LIMIT 1];
System.debug('Automated Process UserId: ' + automatedUser.Id);

// Check existing trace flag
List<TraceFlag> existing = [SELECT Id, ExpirationDate FROM TraceFlag WHERE TracedEntityId = :automatedUser.Id LIMIT 1];
if (!existing.isEmpty()) {
    System.debug('Trace flag already exists, expires: ' + existing[0].ExpirationDate);
} else {
    System.debug('No trace flag found for Automated Process');
}
