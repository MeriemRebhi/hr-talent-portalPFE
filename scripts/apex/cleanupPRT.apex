// Delete ghost CustomField records via Tooling API approach
// First, let's try to delete and recreate the object
// We need to delete the custom object Password_Reset_Token__c

// Step 1: Check if any records exist
Integer count = [SELECT COUNT() FROM Password_Reset_Token__c];
System.debug('Existing records: ' + count);

// Step 2: Delete all records first
if (count > 0) {
    delete [SELECT Id FROM Password_Reset_Token__c];
    System.debug('Deleted all records');
}
System.debug('Object is clean, ready for deletion via Setup');
