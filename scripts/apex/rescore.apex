// Re-test conversion avec le Lead existant
// Remet le statut à "Open" pour pouvoir retenter la conversion
Lead l = [SELECT Id, Status, IsConverted FROM Lead WHERE Id = '00Qfj00000CXr55EAD' LIMIT 1];
System.debug('Lead status actuel: ' + l.Status + ' | IsConverted: ' + l.IsConverted);

// Relance uniquement la partie conversion (sans Groq)
// pour tester que Contact + Opportunity se créent bien
Lead lead = [
    SELECT Id, FirstName, LastName, Email, Phone,
           Score_Matching__c, AI_Recommendation__c,
           AI_Points_Forts__c, AI_Points_Faibles__c,
           IsConverted, Description
    FROM Lead WHERE Id = '00Qfj00000CXr55EAD' LIMIT 1
];

System.debug('Test resolveContact pour: ' + lead.FirstName + ' ' + lead.LastName + ' | Email: ' + lead.Email);

// Test direct création Contact
Id accountId;
List<Account> acc = [SELECT Id FROM Account WHERE Name = 'Candidats Portal' LIMIT 1];
if (acc.isEmpty()) {
    Account a = new Account(Name = 'Candidats Portal');
    insert a;
    accountId = a.Id;
    System.debug('✅ Account créé: ' + accountId);
} else {
    accountId = acc[0].Id;
    System.debug('✅ Account existant: ' + accountId);
}

// Vérifier si Contact existe déjà
List<Contact> existing = [SELECT Id, Email FROM Contact WHERE Email = :lead.Email ORDER BY CreatedDate DESC LIMIT 1];
if (!existing.isEmpty()) {
    System.debug('ℹ️ Contact déjà existant: ' + existing[0].Id);
} else {
    Contact c = new Contact(
        FirstName = lead.FirstName,
        LastName  = lead.LastName,
        Email     = lead.Email,
        Phone     = lead.Phone,
        AccountId = accountId
    );
    Database.DMLOptions opts = new Database.DMLOptions();
    opts.DuplicateRuleHeader.allowSave = true;
    c.setOptions(opts);
    Database.SaveResult sr = Database.insert(c, false);
    if (sr.isSuccess()) {
        System.debug('✅ Contact créé: ' + sr.getId());
    } else {
        System.debug('❌ Erreur Contact: ' + sr.getErrors()[0].getStatusCode() + ' - ' + sr.getErrors()[0].getMessage());
    }
}
