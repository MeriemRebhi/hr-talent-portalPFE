Map<String, Object> data = InternalDashboardController.getRecruteurData();
List<Map<String,Object>> rows = (List<Map<String,Object>>) data.get('rows');
System.debug('Total candidats pour ce recruteur: ' + rows.size());
for (Map<String,Object> row : rows) {
    System.debug('  > ' + row.get('Name') + ' | Stage: ' + row.get('StageName') + ' | Job: ' + row.get('jobTitle'));
}
