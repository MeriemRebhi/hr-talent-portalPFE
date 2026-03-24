// Lister toutes les règles de doublon actives sur Contact
List<DuplicateRule> rules = [
    SELECT Id, DeveloperName, IsActive, MasterLabel
    FROM DuplicateRule
    WHERE SObjectType = 'Contact'
];
System.debug('Règles doublon Contact trouvées: ' + rules.size());
for(DuplicateRule r : rules) {
    System.debug('  → ' + r.MasterLabel + ' | Active: ' + r.IsActive + ' | Id: ' + r.Id);
}
