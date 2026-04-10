// Diagnostic complet pour le Contact 003fj00000kLM6HAAW (yamina ben harath)
Id contactId = '003fj00000kLM6HAAW';

System.debug('═══ DIAGNOSTIC CONVERSION ═══');

// 1. Contact
List<Contact> contacts = [
    SELECT Id, FirstName, LastName, Email, AccountId, Account.Name, CreatedDate
    FROM Contact WHERE Id = :contactId LIMIT 1
];
if (contacts.isEmpty()) {
    System.debug('❌ Contact non trouvé: ' + contactId);
} else {
    Contact c = contacts[0];
    System.debug('📋 Contact: ' + c.FirstName + ' ' + c.LastName + ' | Email: ' + c.Email);
    System.debug('   Account: ' + c.Account.Name + ' | Créé: ' + c.CreatedDate);
}

// 2. Lead source
List<Lead> leads = [
    SELECT Id, FirstName, LastName, Email, Status, Score_Matching__c, Rating,
           IsConverted, ConvertedContactId, ConvertedAccountId, ConvertedOpportunityId,
           AI_Recommendation__c, AI_Points_Forts__c, AI_Points_Faibles__c,
           CreatedDate, LastModifiedDate
    FROM Lead WHERE ConvertedContactId = :contactId
    ORDER BY LastModifiedDate DESC
];
System.debug('');
System.debug('📋 Leads convertis vers ce contact: ' + leads.size());
for (Lead l : leads) {
    System.debug('  → Lead ' + l.Id + ' | ' + l.FirstName + ' ' + l.LastName);
    System.debug('    Email: ' + l.Email + ' | Score: ' + l.Score_Matching__c + ' | Rating: ' + l.Rating);
    System.debug('    Status: ' + l.Status + ' | Converti: ' + l.IsConverted);
    System.debug('    Opp: ' + l.ConvertedOpportunityId);
    System.debug('    AI Reco: ' + (l.AI_Recommendation__c != null ? l.AI_Recommendation__c.left(200) : 'null'));
    System.debug('    Créé: ' + l.CreatedDate + ' | Modifié: ' + l.LastModifiedDate);
}

// 3. Opportunity liée
Set<Id> oppIds = new Set<Id>();
for (Lead l : leads) {
    if (l.ConvertedOpportunityId != null) oppIds.add(l.ConvertedOpportunityId);
}
if (!oppIds.isEmpty()) {
    List<Opportunity> opps = [
        SELECT Id, Name, StageName, Score_Matching__c,
               RecordType.Name, CreatedDate, Description
        FROM Opportunity WHERE Id IN :oppIds
    ];
    System.debug('');
    System.debug('📋 Opportunities:');
    for (Opportunity o : opps) {
        System.debug('  → ' + o.Name + ' | Stage: ' + o.StageName + ' | Score: ' + o.Score_Matching__c);
        System.debug('    RT: ' + o.RecordType.Name);
        System.debug('    Créé: ' + o.CreatedDate);
    }
}

// 4. User portail
String email = contacts.isEmpty() ? null : contacts[0].Email;
System.debug('');
System.debug('📋 Users portail pour email=' + email + ' ou contactId=' + contactId + ':');
List<User> portalUsers = [
    SELECT Id, Username, Email, ContactId, IsActive, UserType, Profile.Name,
           LastLoginDate, CreatedDate
    FROM User
    WHERE (Email = :email OR ContactId = :contactId)
    AND UserType IN ('CspLitePortal','CustomerPortal','PowerCustomerSuccess','PowerPartner')
];
if (portalUsers.isEmpty()) {
    System.debug('❌ Aucun user portail trouvé !');
    System.debug('   → L\'email de bienvenue n\'a jamais été envoyé');
} else {
    for (User u : portalUsers) {
        System.debug('  → Username: ' + u.Username);
        System.debug('    Email: ' + u.Email + ' | Active: ' + u.IsActive);
        System.debug('    ContactId: ' + u.ContactId + ' | Profile: ' + u.Profile.Name);
        System.debug('    Dernier login: ' + u.LastLoginDate + ' | Créé: ' + u.CreatedDate);
    }
}

// 5. ContentDocumentLink (CV uploadé)
Set<Id> entityIds = new Set<Id>{ contactId };
for (Lead l : leads) entityIds.add(l.Id);
List<ContentDocumentLink> cdls = [
    SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension,
           ContentDocument.ContentSize, SystemModstamp
    FROM ContentDocumentLink
    WHERE LinkedEntityId IN :entityIds
    ORDER BY SystemModstamp DESC LIMIT 5
];
System.debug('');
System.debug('📋 Fichiers CV:');
if (cdls.isEmpty()) {
    System.debug('  Aucun fichier trouvé');
} else {
    for (ContentDocumentLink cdl : cdls) {
        System.debug('  → ' + cdl.ContentDocument.Title + '.' + cdl.ContentDocument.FileExtension
            + ' (' + cdl.ContentDocument.ContentSize + ' bytes) | ' + cdl.SystemModstamp);
    }
}

System.debug('');
System.debug('═══ FIN DIAGNOSTIC ═══');
