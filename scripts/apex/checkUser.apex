// Vérifier si le user portail a été créé maintenant
List<User> users = [
    SELECT Id, Username, IsActive, ContactId, UserType, Email, CreatedDate
    FROM User
    WHERE Email = 'm.rebhi24292@pi.com'
    AND UserType IN ('CspLitePortal','CustomerPortal','PowerCustomerSuccess','PowerPartner')
    LIMIT 1
];
if (!users.isEmpty()) {
    System.debug('✅ User portail créé: ' + users[0].Username + ' | Actif: ' + users[0].IsActive + ' | Créé: ' + users[0].CreatedDate);
} else {
    System.debug('❌ Toujours pas de user portail');
    // Vérifier les users internes avec cet email
    List<User> internal = [SELECT Id, Username, UserType FROM User WHERE Email = 'm.rebhi24292@pi.com' LIMIT 5];
    for (User u : internal) {
        System.debug('User trouvé: ' + u.Username + ' | Type: ' + u.UserType);
    }
}

// Vérifier les Apex Jobs récents en erreur
List<AsyncApexJob> jobs = [
    SELECT Id, Status, ExtendedStatus, ApexClass.Name, CreatedDate
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'CVScoringService'
    ORDER BY CreatedDate DESC LIMIT 5
];
for (AsyncApexJob j : jobs) {
    System.debug('Job: ' + j.ApexClass.Name + ' | Status: ' + j.Status + ' | ' + j.ExtendedStatus + ' | ' + j.CreatedDate);
}
