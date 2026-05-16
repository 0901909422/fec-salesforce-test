Map<String, Schema.SObjectField> fields = Schema.SObjectType.EnhancedLetterhead.fields.getMap();
for (String f : fields.keySet()) {
    System.debug(fields.get(f).getDescribe().getName() + ' | ' + fields.get(f).getDescribe().getType());
}
