// Direct query for gaming fields
Map<String, Schema.SObjectField> fields = Schema.SObjectType.Opportunity.fields.getMap();
System.debug('Total Opportunity fields: ' + fields.size());
System.debug('Has Gaming_Test_DateTime__c: ' + fields.containsKey('gaming_test_datetime__c'));
System.debug('Has Gaming_Test_Score__c: ' + fields.containsKey('gaming_test_score__c'));
System.debug('Has Gaming_Test_Status__c: ' + fields.containsKey('gaming_test_status__c'));
System.debug('Has Gaming_Test_Duration__c: ' + fields.containsKey('gaming_test_duration__c'));
System.debug('Has Gaming_Meet_Link__c: ' + fields.containsKey('gaming_meet_link__c'));

// Try direct query
try {
    List<Opportunity> opps = Database.query('SELECT Id, Name, Gaming_Test_DateTime__c, Gaming_Test_Status__c FROM Opportunity ORDER BY LastModifiedDate DESC LIMIT 3');
    System.debug('=== QUERY SUCCESS ===');
    for (Opportunity o : opps) {
        System.debug('OPP: ' + o.Name + ' | DateTime: ' + o.get('Gaming_Test_DateTime__c') + ' | Status: ' + o.get('Gaming_Test_Status__c'));
        
        List<Lead> leads = [SELECT Id, FirstName, LastName, Email FROM Lead WHERE ConvertedOpportunityId = :o.Id LIMIT 1];
        if (leads.isEmpty()) {
            System.debug('  >> NO LEAD FOUND');
        } else {
            System.debug('  >> Lead: ' + leads[0].FirstName + ' ' + leads[0].LastName + ' | Email: ' + leads[0].Email);
        }
    }
} catch(Exception e) {
    System.debug('QUERY ERROR: ' + e.getMessage());
}
