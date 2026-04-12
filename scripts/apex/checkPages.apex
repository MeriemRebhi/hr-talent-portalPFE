// Try to create a page via ConnectApi
// First check what API is available
String networkId = '0DBfj000001sohhGAA';

// Let's try using ConnectApi.ManagedContent to see available pages
try {
    ConnectApi.NavigationMenuItemCollection navItems = ConnectApi.NavigationMenu.getNavigationMenuItems(
        networkId, null, null, ConnectApi.PublishStatus.Live, false, true, null
    );
    System.debug('Nav menus found: ' + navItems.menuItems.size());
    for (ConnectApi.NavigationMenuItem item : navItems.menuItems) {
        System.debug('Menu: ' + item.label + ' -> ' + item.actionValue + ' type: ' + item.actionType);
    }
} catch(Exception e) {
    System.debug('Nav error: ' + e.getMessage());
}

// Check if we can list managed content pages
try {
    // List existing community pages through SOQL on NetworkMember or similar
    List<NetworkPageOverride> overrides = [SELECT Id, Network.Name FROM NetworkPageOverride WHERE NetworkId = :networkId];
    System.debug('Page overrides: ' + overrides.size());
} catch(Exception e) {
    System.debug('Override error: ' + e.getMessage());
}
