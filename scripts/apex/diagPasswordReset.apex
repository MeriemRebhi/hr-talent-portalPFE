// Diagnostic : vérifier les audit logs et l'état du token
System.debug('=== AUDIT LOGS (latest 10) ===');
List<Security_Audit_Log__c> logs = [
    SELECT Action__c, Email__c, Severity__c, Details__c, Timestamp__c
    FROM Security_Audit_Log__c
    ORDER BY Timestamp__c DESC LIMIT 10
];
for (Security_Audit_Log__c log : logs) {
    System.debug(log.Timestamp__c + ' | ' + log.Severity__c + ' | ' + log.Action__c + ' | ' + log.Details__c);
}

System.debug('=== PASSWORD RESET TOKENS ===');
List<Password_Reset_Token__c> tokens = [
    SELECT Id, Token_Hash__c, Email__c, Expiration__c, Attempts__c, Is_Used__c, User__c, CreatedDate
    FROM Password_Reset_Token__c
    ORDER BY CreatedDate DESC LIMIT 5
];
for (Password_Reset_Token__c t : tokens) {
    System.debug('Created=' + t.CreatedDate + ' | Email=' + t.Email__c + ' | Exp=' + t.Expiration__c + ' | Used=' + t.Is_Used__c + ' | Attempts=' + t.Attempts__c);
}

// Test validatePasswordStrength directly
String testPwd = 'Rabhimariem421991+';
String result = PasswordResetController.validatePasswordStrength(testPwd);
System.debug('validatePasswordStrength("Rabhimariem421991+") = ' + result);
