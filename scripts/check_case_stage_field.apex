Map<String, Schema.SObjectField> fields = Schema.SObjectType.Case.fields.getMap();
for (String fn : fields.keySet()) {
    if (fn.containsIgnoreCase('stage')) System.debug('Case field: ' + fn);
}
