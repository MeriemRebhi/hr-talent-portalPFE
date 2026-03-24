// Diagnostique la création de contact pour le dernier Lead
Lead lead = [
    SELECT Id, FirstName, LastName, Email, Phone, Score_Matching__c
    FROM Lead
    WHERE LeadSource = 'Talent Portal'
    ORDER BY CreatedDate DESC LIMIT 1
];
System.debug('Lead: ' + lead.FirstName + ' ' + lead.LastName + ' | Email: ' + lead.Email);

// Vérifier si un contact existe déjà pour cet email
List<Contact> existing = [SELECT Id, Name, AccountId FROM Contact WHERE Email = :lead.Email LIMIT 5];
System.debug('Contacts existants avec cet email: ' + existing.size());
for(Contact c : existing) System.debug('  → ' + c.Name + ' | ' + c.Id);

// Tenter un insert de test pour voir l'erreur exacte
Id accountId;
List<Account> accs = [SELECT Id FROM Account WHERE Name = 'Candidats Portal' LIMIT 1];
if (!accs.isEmpty()) {
    accountId = accs[0].Id;
} else {
    Account acc = new Account(Name = 'Candidats Portal');
    insert acc;
    accountId = acc.Id;
}

Contact testContact = new Contact(
    FirstName = lead.FirstName,
    LastName  = lead.LastName,
    Email     = lead.Email,
    Phone     = lead.Phone,
    AccountId = accountId
);
Database.DMLOptions opts = new Database.DMLOptions();
opts.DuplicateRuleHeader.allowSave = true;
testContact.setOptions(opts);

Database.SaveResult result = Database.insert(testContact, false);
if (result.isSuccess()) {
    System.debug('✅ Contact créé avec succès: ' + result.getId());
    // Supprimer le contact de test
    delete testContact;
    System.debug('(Test contact supprimé)');
} else {
    for(Database.Error err : result.getErrors()) {
        System.debug('❌ Erreur: ' + err.getStatusCode() + ' | ' + err.getMessage());
        System.debug('   Champs: ' + err.getFields());
    }
}
