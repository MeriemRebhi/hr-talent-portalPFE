// Republish Experience Cloud sites
List<Network> networks = [SELECT Id, Name, Status FROM Network];
for (Network n : networks) {
    System.debug('Network: ' + n.Id + ' | ' + n.Name + ' | ' + n.Status);
}

// Use Site.publish
List<Site> sites = [SELECT Id, Name, Status FROM Site WHERE Name LIKE '%Talan_Talent_Intelligence_RH2%'];
for (Site s : sites) {
    System.debug('Site: ' + s.Id + ' | ' + s.Name + ' | ' + s.Status);
}

// Try SiteDetail 
List<Network> rh2Networks = [SELECT Id, Name, Status, UrlPathPrefix FROM Network WHERE UrlPathPrefix = 'home2'];
if (!rh2Networks.isEmpty()) {
    System.debug('Found home2 network: ' + rh2Networks[0].Id + ' | ' + rh2Networks[0].Name);
}
