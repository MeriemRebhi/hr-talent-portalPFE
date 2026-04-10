Map<String, Schema.SObjectField> fields = Schema.SObjectType.Opportunity.fields.getMap();
for (String fname : fields.keySet()) {
    if (fname.containsIgnoreCase('gaming') || fname.containsIgnoreCase('meet')) {
        System.debug('FIELD: ' + fname);
    }
}

// Chercher le candidat par email
List<Lead> leads = [
    SELECT Id, FirstName, LastName, Email, IsConverted, ConvertedOpportunityId, ConvertedContactId
    FROM Lead
    WHERE Email = 'm.rebhi24292@pi.tn'
    LIMIT 5
];
System.debug('=== LEADS avec email m.rebhi24292@pi.tn: ' + leads.size() + ' ===');
for (Lead l : leads) {
    System.debug('Lead: ' + l.FirstName + ' ' + l.LastName + ' | Converted: ' + l.IsConverted + ' | ConvertedOppId: ' + l.ConvertedOpportunityId);
}

// Chercher toutes les opps Application avec Marioumti
List<Opportunity> opps = [
    SELECT Id, Name, StageName, AccountId, Account.Name
    FROM Opportunity
    WHERE Name LIKE '%Marioumti%' AND RecordType.DeveloperName = 'Application'
    LIMIT 5
];
System.debug('=== OPPS Marioumti: ' + opps.size() + ' ===');
for (Opportunity o : opps) {
    System.debug('Opp: ' + o.Id + ' | ' + o.Name + ' | Account: ' + o.Account.Name);
    
    List<Lead> convLeads = [
        SELECT Id, Email FROM Lead WHERE ConvertedOpportunityId = :o.Id LIMIT 1
    ];
    System.debug('  Leads via ConvertedOpportunityId: ' + convLeads.size());
    if (!convLeads.isEmpty()) {
        System.debug('  Email: ' + convLeads[0].Email);
    }
    
    List<Contact> contacts = [
        SELECT Id, FirstName, LastName, Email FROM Contact WHERE AccountId = :o.AccountId LIMIT 3
    ];
    System.debug('  Contacts sur Account: ' + contacts.size());
    for (Contact c : contacts) {
        System.debug('  -> ' + c.FirstName + ' ' + c.LastName + ' | ' + c.Email);
    }
}

// Email deliverability check
System.debug('=== EMAIL LIMITS ===');
System.debug('Invocations: ' + Limits.getEmailInvocations() + '/' + Limits.getLimitEmailInvocations());
