// Préparer un compte de test frais pour tester le portail en bout en bout
// email unique avec timestamp pour éviter les doublons

String testTs = String.valueOf(DateTime.now().getTime());
String testEmail = 'test.portail.' + testTs + '@yopmail.com';
String testFirstName = 'TestPortail';
String testLastName = 'Demo';

System.debug('=== COMPTE TEST PRÊT ===');
System.debug('Email test: ' + testEmail);
System.debug('Prénom: ' + testFirstName);
System.debug('Nom: ' + testLastName);
System.debug('URL portail: https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2/s/loginp');
System.debug('Utiliser ce compte pour postuler depuis le portail.');

// Vérifier qu'aucun lead n'existe déjà avec cet email
List<Lead> existing = [SELECT Id, Email FROM Lead WHERE Email = :testEmail];
System.debug('Leads existants avec cet email: ' + existing.size() + ' (doit être 0)');

// Vérifier les offres disponibles pour postuler
List<Opportunity> jobs = [
    SELECT Id, Name, Localisation__c, Type_de_Contrat__c
    FROM Opportunity
    WHERE RecordType.DeveloperName = 'Job_Posting' AND IsClosed = false
    ORDER BY Name
];
System.debug('=== OFFRES DISPONIBLES (' + jobs.size() + ') ===');
for(Opportunity j : jobs) {
    System.debug('  [' + j.Id + '] ' + j.Name + ' | ' + j.Localisation__c);
}
System.debug('=== FIN PRÉPARATION TEST ===');
