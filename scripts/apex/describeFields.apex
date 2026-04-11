Map<String, Schema.SObjectField> fMap = Schema.SObjectType.Technical_Question__c.fields.getMap();
System.debug('Total fields: ' + fMap.size());
for(String f : fMap.keySet()) {
    System.debug('FIELD: ' + f);
}
