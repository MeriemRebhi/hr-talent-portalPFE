// Diagnostic complet : email Eya Boudidah pour Gaming Test
// Vérifie les 3 niveaux de fallback + Email Deliverability

// 1) Trouver l'opportunité de Boudidah en stage Gaming
List<Opportunity> opps = [
    SELECT Id, Name, StageName, AccountId
    FROM Opportunity
    WHERE Name LIKE '%Boudidah%'
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('=== OPPORTUNITÉS BOUDIDAH ===');
for (Opportunity o : opps) {
    System.debug('Opp: ' + o.Name + ' | Stage: ' + o.StageName 
        + ' | AccountId: ' + o.AccountId);
}

if (opps.isEmpty()) {
    System.debug('❌ Aucune opportunité trouvée pour Boudidah');
} else {
    Id oppId = opps[0].Id;
    Id accountId = opps[0].AccountId;
    System.debug('>>> Diagnostic pour opp: ' + oppId);

    // 2) Niveau 1 — Lead converti
    List<Lead> leads = [
        SELECT Id, FirstName, LastName, Email, ConvertedOpportunityId, IsConverted
        FROM Lead WHERE ConvertedOpportunityId = :oppId LIMIT 1
    ];
    System.debug('=== NIVEAU 1 : LEAD CONVERTI ===');
    if (leads.isEmpty()) {
        System.debug('⚠️ Aucun Lead trouvé avec ConvertedOpportunityId = ' + oppId);
    } else {
        System.debug('✅ Lead trouvé: ' + leads[0].FirstName + ' ' + leads[0].LastName 
            + ' | Email: ' + leads[0].Email 
            + ' | IsConverted: ' + leads[0].IsConverted);
    }

    // 3) Niveau 2 — OpportunityContactRole
    List<OpportunityContactRole> ocrs = [
        SELECT ContactId, Contact.FirstName, Contact.LastName, Contact.Email, Role
        FROM OpportunityContactRole
        WHERE OpportunityId = :oppId AND Contact.Email != null
        LIMIT 5
    ];
    System.debug('=== NIVEAU 2 : OPPORTUNITY CONTACT ROLE ===');
    if (ocrs.isEmpty()) {
        System.debug('⚠️ Aucun OpportunityContactRole trouvé');
    } else {
        for (OpportunityContactRole ocr : ocrs) {
            System.debug('✅ OCR: ' + ocr.Contact.FirstName + ' ' + ocr.Contact.LastName 
                + ' | Email: ' + ocr.Contact.Email + ' | Role: ' + ocr.Role);
        }
    }

    // 4) Niveau 3 — Contact par AccountId
    System.debug('=== NIVEAU 3 : CONTACT PAR ACCOUNT ===');
    if (accountId == null) {
        System.debug('⚠️ Pas d\'AccountId sur l\'opportunité');
    } else {
        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, Email, AccountId
            FROM Contact WHERE AccountId = :accountId AND Email != null LIMIT 5
        ];
        if (contacts.isEmpty()) {
            System.debug('⚠️ Aucun Contact trouvé pour AccountId = ' + accountId);
        } else {
            for (Contact c : contacts) {
                System.debug('✅ Contact: ' + c.FirstName + ' ' + c.LastName + ' | Email: ' + c.Email);
            }
        }
    }

    // 5) Chercher aussi les Leads par nom (au cas où ConvertedOpportunityId est null)
    List<Lead> allLeads = [
        SELECT Id, FirstName, LastName, Email, IsConverted, ConvertedOpportunityId, ConvertedContactId
        FROM Lead WHERE LastName = 'Boudidah' LIMIT 5
    ];
    System.debug('=== TOUS LES LEADS BOUDIDAH ===');
    for (Lead l : allLeads) {
        System.debug('Lead: ' + l.FirstName + ' ' + l.LastName 
            + ' | Email: ' + l.Email
            + ' | Converted: ' + l.IsConverted 
            + ' | ConvertedOppId: ' + l.ConvertedOpportunityId
            + ' | ConvertedContactId: ' + l.ConvertedContactId);
    }

    // 6) Vérifier les limites d'email
    System.debug('=== EMAIL LIMITS ===');
    System.debug('Single Emails envoyés aujourd\'hui: ' + Limits.getEmailInvocations() + '/' + Limits.getLimitEmailInvocations());
}
