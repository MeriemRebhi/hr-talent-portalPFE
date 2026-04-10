Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName();
for (String key : rtMap.keySet()) {
    Schema.RecordTypeInfo rti = rtMap.get(key);
    System.debug('RT: ' + key + ' | Id: ' + rti.getRecordTypeId() + ' | Active: ' + rti.isActive() + ' | Available: ' + rti.isAvailable());
}
