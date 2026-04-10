// Tester la logique de createPortalUserAsync de manière synchrone (sans @future)
String email = 'm.rebhi24292@pi.com';
Id contactId = '003fj00000kpFXKAA2';
String firstName = 'Rebhi';
String lastName = 'Marioumti';

// Check 1: user portail existant?
List<User> existing = [
    SELECT Id, IsActive, ContactId, Username, UserType
    FROM User
    WHERE (Email = :email OR ContactId = :contactId)
    AND UserType IN ('CspLitePortal','CustomerPortal','PowerCustomerSuccess','PowerPartner')
    LIMIT 1
];
System.debug('Users portail existants: ' + existing.size());

// Check 2: user interne?
List<User> internal = [SELECT Id, Username, UserType FROM User WHERE Email = :email LIMIT 5];
System.debug('Tous les users avec cet email:');
for (User u : internal) {
    System.debug('  → ' + u.Username + ' | Type: ' + u.UserType);
}

// Check 3: profil
List<Profile> profiles = [SELECT Id, Name FROM Profile WHERE Name = 'Customer Community Login User' LIMIT 1];
System.debug('Profil Community Login: ' + (profiles.isEmpty() ? 'NON TROUVÉ' : profiles[0].Id));

// Check 4: essai de création
if (!profiles.isEmpty() && internal.isEmpty()) {
    try {
        String suffix = String.valueOf(DateTime.now().getTime());
        User u = new User(
            ContactId = contactId,
            ProfileId = profiles[0].Id,
            FirstName = firstName,
            LastName = lastName,
            Email = email,
            Username = email + '.' + suffix,
            Alias = 'rmariou',
            CommunityNickname = 'RebhiM' + suffix.right(10),
            TimeZoneSidKey = 'Africa/Tunis',
            LocaleSidKey = 'fr_TN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'fr',
            IsActive = true
        );
        insert u;
        System.debug('✅ User créé: ' + u.Id + ' | ' + u.Username);
        
        String pwd = CVScoringService.generateTempPassword();
        System.setPassword(u.Id, pwd);
        System.debug('✅ Mot de passe défini: ' + pwd);
    } catch (Exception e) {
        System.debug('❌ ERREUR CREATION: ' + e.getMessage());
        System.debug('Stack: ' + e.getStackTraceString());
    }
} else {
    System.debug('⚠️ Skipped - user interne existe OU profil manquant');
}
