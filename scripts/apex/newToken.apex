// Générer un nouveau token frais pour tester la page set-password
String testEmail = 'm.rebhi24292@pi.tn';

User u = [
    SELECT Id, Email, FirstName 
    FROM User 
    WHERE Email = :testEmail AND IsActive = true 
    LIMIT 1
];

// Générer un nouveau token (invalide automatiquement les anciens)
String token = PasswordResetController.generateResetToken(u.Id, u.Email);
String resetUrl = PasswordResetController.buildResetUrl(token);

System.debug('════════════════════════════════════════════');
System.debug('NOUVEAU TOKEN GÉNÉRÉ');
System.debug('URL complète: ' + resetUrl);
System.debug('════════════════════════════════════════════');
