// Check which fields are actually accessible on Password_Reset_Token__c
Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Password_Reset_Token__c.fields.getMap();
System.debug('=== Fields on Password_Reset_Token__c ===');
for (String fieldName : fieldMap.keySet()) {
    Schema.DescribeFieldResult fr = fieldMap.get(fieldName).getDescribe();
    System.debug(fr.getName() + ' (' + fr.getType() + ') - accessible=' + fr.isAccessible() + ', custom=' + fr.isCustom());
}
