// Test if Technical_Interview_Status__c can be used via dynamic DML
// Maybe the REST/Apex describe cache just hasn't refreshed
try {
    List<SObject> opps = Database.query('SELECT Id FROM Opportunity LIMIT 1');
    if (!opps.isEmpty()) {
        // Try dynamic put
        opps[0].put('Technical_Interview_Status__c', 'TestValue');
        update opps[0];
        System.debug('WRITE SUCCESS - field IS real!');
    }
} catch (Exception e) {
    System.debug('WRITE FAILURE: ' + e.getMessage());
}

// Try to read via dynamic SOQL
try {
    List<SObject> opps = Database.query('SELECT Id, Technical_Interview_Status__c FROM Opportunity LIMIT 1');
    System.debug('READ SUCCESS: ' + opps[0].get('Technical_Interview_Status__c'));
} catch (Exception e) {
    System.debug('READ FAILURE: ' + e.getMessage());
}

// Also test Gaming_Test_Score__c for comparison
try {
    List<SObject> opps = Database.query('SELECT Id, Gaming_Test_Score__c FROM Opportunity LIMIT 1');
    System.debug('GAMING READ SUCCESS: ' + opps[0].get('Gaming_Test_Score__c'));
} catch (Exception e) {
    System.debug('GAMING READ FAILURE: ' + e.getMessage());
}

// Test Score_Matching__c (known to exist)
try {
    List<SObject> opps = Database.query('SELECT Id, Score_Matching__c FROM Opportunity LIMIT 1');
    System.debug('MATCHING READ SUCCESS: ' + opps[0].get('Score_Matching__c'));
} catch (Exception e) {
    System.debug('MATCHING READ FAILURE: ' + e.getMessage());
}
