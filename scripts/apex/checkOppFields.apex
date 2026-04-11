// Create Technical_ fields on Opportunity via Tooling API workaround
// Since metadata deploy creates phantom fields, we use DML to set values directly

// First check which fields are already accessible
Map<String, Schema.SObjectField> oppFields = Schema.SObjectType.Opportunity.fields.getMap();
String[] techFields = new String[]{
    'Technical_Meet_Link__c',
    'Technical_Interview_Status__c',
    'Technical_Interview_Score__c',
    'Technical_Interview_Duration__c',
    'Technical_Interview_DateTime__c',
    'Technical_Composite_Score__c'
};
for (String f : techFields) {
    System.debug(f + ': ' + (oppFields.containsKey(f.toLowerCase()) ? 'EXISTS' : 'MISSING'));
}
