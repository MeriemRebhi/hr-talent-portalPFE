List<NavigationMenuItem> items = [SELECT Label, Target, Type FROM NavigationMenuItem LIMIT 50];
System.debug('Navigation items: ' + items.size());
for (NavigationMenuItem n : items) {
    System.debug('NAV: ' + n.Label + ' -> ' + n.Target + ' [' + n.Type + ']');
}
Network n2 = [SELECT Id, Name, UrlPathPrefix FROM Network WHERE Id = '0DBfj000001sohhGAA'];
System.debug('Network: ' + n2.Name + ' prefix: ' + n2.UrlPathPrefix);
