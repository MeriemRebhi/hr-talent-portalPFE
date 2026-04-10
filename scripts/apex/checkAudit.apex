// Vérification finale : audit log du flow complet
List<Security_Audit_Log__c> logs = [
    SELECT Action__c, Email__c, Severity__c, Details__c, Timestamp__c
    FROM Security_Audit_Log__c
    ORDER BY Timestamp__c DESC LIMIT 5
];
System.debug('=== AUDIT LOG FINAL ===');
for (Security_Audit_Log__c log : logs) {
    System.debug(log.Severity__c + ' | ' + log.Action__c + ' | ' + log.Details__c);
}
