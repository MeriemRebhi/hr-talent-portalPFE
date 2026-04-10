// Supprimer les Opportunités parasites qui ont le nom "Candidature" mais le RT Job_Posting
List<Opportunity> parasites = [
    SELECT Id, Name, RecordType.DeveloperName
    FROM Opportunity
    WHERE RecordType.DeveloperName = 'Job_Posting'
    AND Name LIKE '%Candidature%'
];

System.debug('=== OPPORTUNITÉS PARASITES À SUPPRIMER ===');
for (Opportunity o : parasites) {
    System.debug('Deleting: ' + o.Name + ' (RT: ' + o.RecordType.DeveloperName + ')');
}

if (!parasites.isEmpty()) {
    delete parasites;
    System.debug('✅ ' + parasites.size() + ' opportunités parasites supprimées');
} else {
    System.debug('Aucun parasite trouvé');
}
