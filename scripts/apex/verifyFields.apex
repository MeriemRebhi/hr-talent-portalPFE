// Use dynamic SOQL to bypass compile-time checks
try {
    String q = 'SELECT Id, Gaming_Test_DateTime__c, Gaming_Test_Score__c, Gaming_Test_Status__c, Gaming_Meet_Link__c FROM Opportunity LIMIT 3';
    List<SObject> results = Database.query(q);
    System.debug('Dynamic SOQL SUCCESS - got ' + results.size() + ' records');
    for (SObject r : results) {
        System.debug('  -> ' + r.get('Gaming_Test_DateTime__c') + ' | Score: ' + r.get('Gaming_Test_Score__c') + ' | Status: ' + r.get('Gaming_Test_Status__c'));
    }
} catch (Exception e) {
    System.debug('Dynamic SOQL FAILED: ' + e.getMessage());
}

// Test calling the actual controller
try {
    List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE RecordType.DeveloperName = 'Application' AND StageName = 'Gaming' LIMIT 1];
    if (!opps.isEmpty()) {
        Map<String, Object> info = GamingTestController.getTestInfo(opps[0].Id);
        System.debug('getTestInfo SUCCESS: ' + info);
    } else {
        System.debug('No Gaming opp found');
    }
} catch (Exception e) {
    System.debug('getTestInfo FAILED: ' + e.getMessage());
}
