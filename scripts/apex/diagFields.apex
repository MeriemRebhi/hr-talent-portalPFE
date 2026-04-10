// Describe Opportunity custom fields
Map<String, Schema.SObjectField> fields = Schema.SObjectType.Opportunity.fields.getMap();
System.debug('=== GAMING FIELDS ON OPPORTUNITY ===');
for (String fname : fields.keySet()) {
    String lower = fname.toLowerCase();
    if (lower.contains('gaming') || lower.contains('test') || lower.contains('score')) {
        Schema.DescribeFieldResult dfr = fields.get(fname).getDescribe();
        System.debug('FIELD: ' + dfr.getName() + ' | Label: ' + dfr.getLabel() + ' | Type: ' + dfr.getType());
    }
}

// Check all recent opportunities modified today
List<Opportunity> recent = [SELECT Id, Name, StageName, LastModifiedDate FROM Opportunity ORDER BY LastModifiedDate DESC LIMIT 5];
System.debug('=== RECENT OPPORTUNITIES ===');
for (Opportunity o : recent) {
    System.debug('OPP: ' + o.Name + ' | Stage: ' + o.StageName + ' | Modified: ' + o.LastModifiedDate);
}
