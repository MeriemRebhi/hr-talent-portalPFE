// List all pages in the Experience Cloud site
// Try NavigationMenuItem
List<NavigationMenuItem> items = [SELECT Label, Target, Type FROM NavigationMenuItem LIMIT 50];
System.debug('Navigation items: ' + items.size());
for (NavigationMenuItem n : items) {
    System.debug('NAV: ' + n.Label + ' -> ' + n.Target + ' [' + n.Type + ']');
}

// Try NetworkPageOverride (custom pages)
// Not available in all orgs

// Check the LWC meta to see isExposed and targets
System.debug('');
System.debug('═══ Checking what pages Ahmed sees ═══');

// The dashboard is an LWC exposed to communities
// The page route in Experience Cloud is created via Builder, not code
// Let me check if there's a custom tab or anything
List<CustomTab> tabs = new List<CustomTab>();

System.debug('');
System.debug('Check the site URL prefix');
Network n2 = [SELECT Id, Name, UrlPathPrefix FROM Network WHERE Id = '0DBfj000001sohhGAA'];
System.debug('Network: ' + n2.Name + ' prefix: ' + n2.UrlPathPrefix);
