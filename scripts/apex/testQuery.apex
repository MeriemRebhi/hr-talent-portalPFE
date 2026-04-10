// Simple test - query Password_Reset_Token__c with all fields
List<Password_Reset_Token__c> tokens = [
    SELECT Id, Token_Hash__c, Expiration__c
    FROM Password_Reset_Token__c LIMIT 1
];
System.debug('Query with basic fields: OK. Count=' + tokens.size());

// Now try Email__c
try {
    List<SObject> tokens2 = Database.query('SELECT Id, Email__c, User__c, Attempts__c, Is_Used__c FROM Password_Reset_Token__c LIMIT 1');
    System.debug('Dynamic query with all fields: OK. Count=' + tokens2.size());
} catch (Exception e) {
    System.debug('Dynamic query FAILED: ' + e.getMessage());
}
