// Activer le flag Must_Change_Password sur le user portail pour le test
List<User> users = [
    SELECT Id, Username, Email, Must_Change_Password__c
    FROM User
    WHERE Email = 'm.rebhi24292@pi.tn'
    AND UserType IN ('CspLitePortal','CustomerPortal','PowerCustomerSuccess','PowerPartner')
    LIMIT 1
];
if (!users.isEmpty()) {
    User u = users[0];
    System.debug('User: ' + u.Username + ' | Must_Change_Password: ' + u.Must_Change_Password__c);
    u.Must_Change_Password__c = true;
    update u;
    System.debug('✅ Flag Must_Change_Password activé');
    System.debug('');
    System.debug('═══════════════════════════════════');
    System.debug('  IDENTIFIANTS DE TEST');
    System.debug('═══════════════════════════════════');
    System.debug('  Email    : m.rebhi24292@pi.tn');
    System.debug('  Password : Portal2026!New');
    System.debug('═══════════════════════════════════');
    System.debug('  → Allez sur la page de login du portail');
    System.debug('  → Connectez-vous avec ces identifiants');
    System.debug('  → Le formulaire de changement de MDP doit apparaître');
} else {
    System.debug('❌ User portail non trouvé');
}
