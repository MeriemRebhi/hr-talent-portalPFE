// Vérifier si le user portail a été créé et l'email envoyé
Lead l = [SELECT Id, Email, ConvertedContactId FROM Lead WHERE LastName = 'Marioumti' AND IsConverted = true LIMIT 1];
System.debug('Lead converti: ' + l.Id + ' | Email: ' + l.Email + ' | ContactId: ' + l.ConvertedContactId);

// Vérifier le contact
Contact c = [SELECT Id, Email, AccountId FROM Contact WHERE Id = :l.ConvertedContactId LIMIT 1];
System.debug('Contact: ' + c.Id + ' | Email: ' + c.Email);

// Vérifier si un user portail existe
List<User> users = [
    SELECT Id, Username, IsActive, ContactId, UserType, CreatedDate
    FROM User
    WHERE (Email = :l.Email OR ContactId = :l.ConvertedContactId)
    AND UserType IN ('CspLitePortal','CustomerPortal','PowerCustomerSuccess','PowerPartner')
    LIMIT 1
];
if (!users.isEmpty()) {
    System.debug('✅ User portail existe: ' + users[0].Username + ' | Actif: ' + users[0].IsActive + ' | Créé: ' + users[0].CreatedDate);
} else {
    System.debug('❌ Aucun user portail trouvé pour ' + l.Email);
}

// Vérifier les emails envoyés récemment
List<EmailMessage> emails = [
    SELECT Id, Subject, ToAddress, CreatedDate FROM EmailMessage
    WHERE ToAddress = :l.Email ORDER BY CreatedDate DESC LIMIT 5
];
System.debug('Emails trouvés: ' + emails.size());
for (EmailMessage em : emails) {
    System.debug('📧 ' + em.Subject + ' → ' + em.ToAddress + ' | ' + em.CreatedDate);
}
