// Préparer le test : reset password + reset LastPasswordChangeDate
// Cela simulera une "première connexion" pour déclencher le formulaire de changement MDP

String testEmail = 'm.rebhi24292@pi.tn';

List<User> users = [
    SELECT Id, Username, Email, IsActive, CreatedDate, LastPasswordChangeDate, LastLoginDate
    FROM User
    WHERE Email = :testEmail
    AND UserType IN ('CspLitePortal','CustomerPortal','PowerCustomerSuccess','PowerPartner')
    LIMIT 1
];

if (users.isEmpty()) {
    System.debug('❌ Aucun user portail trouvé pour: ' + testEmail);
} else {
    User u = users[0];
    System.debug('📋 User: ' + u.Username);
    System.debug('   Active: ' + u.IsActive);
    System.debug('   CreatedDate: ' + u.CreatedDate);
    System.debug('   LastPasswordChangeDate: ' + u.LastPasswordChangeDate);
    System.debug('   LastLoginDate: ' + u.LastLoginDate);

    // 1. S'assurer que le user est actif
    if (!u.IsActive) {
        u.IsActive = true;
        update u;
        System.debug('✅ User réactivé');
    }

    // 2. Définir un mot de passe temporaire connu
    String tempPwd = 'Portal2026!New';
    System.setPassword(u.Id, tempPwd);
    System.debug('');
    System.debug('✅ Mot de passe temporaire défini');
    System.debug('');
    System.debug('═══════════════════════════════════════');
    System.debug('  IDENTIFIANTS DE TEST');
    System.debug('═══════════════════════════════════════');
    System.debug('  Email    : ' + testEmail);
    System.debug('  Password : ' + tempPwd);
    System.debug('═══════════════════════════════════════');
    System.debug('');

    // 3. Vérifier si isFirstLogin détectera bien "première connexion"
    // LastPasswordChangeDate sera très récent (maintenant) mais CreatedDate est ancien
    // → Diff > 300 sec → isFirstLogin retournera FALSE
    Long diffSeconds = (DateTime.now().getTime() - u.CreatedDate.getTime()) / 1000;
    System.debug('⚠️ Diff CreatedDate vs Now: ' + diffSeconds + ' secondes');
    if (diffSeconds > 300) {
        System.debug('⚠️ Le user a été créé il y a plus de 5 min');
        System.debug('   → isFirstLogin() retournera FALSE avec la logique actuelle');
        System.debug('   → Il faut ajuster la logique pour ce test');
    }
}
