// Test if the fields are actually writable even if describe says MISSING
// Use dynamic DML to bypass compile-time checks
try {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    SObject sobj = (SObject) opp;
    sobj.put('Technical_Interview_Status__c', 'Test');
    update sobj;
    System.debug('SUCCESS: Field is writable!');
    
    // Read it back
    Opportunity recheck = [SELECT Technical_Interview_Status__c FROM Opportunity WHERE Id = :opp.Id];
    System.debug('READ BACK: ' + recheck.get('Technical_Interview_Status__c'));
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
}
