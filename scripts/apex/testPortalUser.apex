// Tester la création du user portail manuellement
Contact c = [SELECT Id, FirstName, LastName, Email, AccountId FROM Contact WHERE Id = '003fj00000kpFXKAA2' LIMIT 1];
System.debug('Contact: ' + c.FirstName + ' ' + c.LastName + ' | Email: ' + c.Email + ' | AccountId: ' + c.AccountId);

// Vérifier les profils Community disponibles
List<Profile> profiles = [SELECT Id, Name FROM Profile WHERE Name LIKE '%Community%' OR Name LIKE '%Portal%' OR Name LIKE '%Customer%'];
for (Profile p : profiles) {
    System.debug('Profil disponible: ' + p.Name + ' | Id: ' + p.Id);
}

// Tester directement
try {
    CVScoringService.createPortalUserAsync(c.Id, c.FirstName, c.LastName, c.Email);
    System.debug('✅ createPortalUserAsync exécuté');
} catch (Exception e) {
    System.debug('❌ Erreur: ' + e.getMessage() + '\n' + e.getStackTraceString());
}
