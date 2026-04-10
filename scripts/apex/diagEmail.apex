// Diagnostic : pourquoi l'email d'invitation Gaming n'arrive pas ?

// 1. Vérifier l'email deliverability de l'org
System.debug('=== 1. EMAIL DELIVERABILITY ===');
System.debug('Si "Access level" = "No access", les emails ne partent pas.');
System.debug('Aller dans Setup > Deliverability > Access level = "All Email"');

// 2. Trouver l'opportunité Marioumti (celle visible dans le screenshot)
List<Opportunity> opps = [
    SELECT Id, Name, StageName, Gaming_Test_DateTime__c, Gaming_Meet_Link__c, AccountId, Account.Name
    FROM Opportunity
    WHERE Name LIKE '%Marioumti%' AND RecordType.DeveloperName = 'Application'
    LIMIT 5
];

System.debug('=== 2. OPPORTUNITÉS TROUVÉES: ' + opps.size() + ' ===');
for (Opportunity o : opps) {
    System.debug('  Id: ' + o.Id);
    System.debug('  Name: ' + o.Name);
    System.debug('  Gaming DateTime: ' + o.Gaming_Test_DateTime__c);
    System.debug('  Meet Link: ' + o.Gaming_Meet_Link__c);
    
    // 3. Chercher le Lead converti lié
    List<Lead> leads = [
        SELECT Id, FirstName, LastName, Email, IsConverted, ConvertedOpportunityId
        FROM Lead
        WHERE ConvertedOpportunityId = :o.Id
        LIMIT 1
    ];
    
    System.debug('  === LEAD via ConvertedOpportunityId ===');
    if (leads.isEmpty()) {
        System.debug('  AUCUN LEAD TROUVE ! Cause du probleme.');
        
        // Chercher par email ou nom
        List<Lead> byName = [
            SELECT Id, FirstName, LastName, Email, IsConverted, ConvertedOpportunityId, ConvertedContactId
            FROM Lead
            WHERE LastName LIKE '%Marioumti%' OR LastName LIKE '%marioumti%'
            LIMIT 5
        ];
        System.debug('  === LEADS par nom: ' + byName.size() + ' ===');
        for (Lead l : byName) {
            System.debug('    Lead Id: ' + l.Id + ' | ' + l.FirstName + ' ' + l.LastName);
            System.debug('    Email: ' + l.Email);
            System.debug('    IsConverted: ' + l.IsConverted);
            System.debug('    ConvertedOpportunityId: ' + l.ConvertedOpportunityId);
            System.debug('    ConvertedContactId: ' + l.ConvertedContactId);
        }
        
        // Essayer via Contact
        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, Email, AccountId
            FROM Contact
            WHERE AccountId = :o.AccountId
            LIMIT 5
        ];
        System.debug('  === CONTACTS sur le même Account: ' + contacts.size() + ' ===');
        for (Contact c : contacts) {
            System.debug('    Contact: ' + c.FirstName + ' ' + c.LastName + ' | ' + c.Email);
        }
    } else {
        Lead l = leads[0];
        System.debug('  ✅ Lead trouvé: ' + l.FirstName + ' ' + l.LastName);
        System.debug('  Email: ' + l.Email);
        if (String.isBlank(l.Email)) {
            System.debug('  EMAIL VIDE ! Email ne peut pas partir.');
        }
    }
}

// 4. Vérifier les limites d'envoi
System.debug('=== 4. LIMITES EMAIL ===');
System.debug('SingleEmail envoyes aujourdhui: ' + Limits.getEmailInvocations() + '/' + Limits.getLimitEmailInvocations());
