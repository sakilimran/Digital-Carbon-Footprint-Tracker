import 'package:flutter/material.dart';
import '../services/app_constants.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 100,
            child: DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.only(left: 16),
              decoration: const BoxDecoration(color: kPrimaryGreen),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Menu',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.black),
                ),
              ),
            ),
          ),
          _item(context, Icons.home, 'Home', '/'),
          _item(context, Icons.show_chart, 'Usage Statistics', '/stats'),
          _item(context, Icons.assessment, 'Total Impact', '/totalImpact'),
          _item(context, Icons.lightbulb_outline, 'Smart Tips', '/recommendations'),
          _item(context, Icons.folder_open, 'Export Data', '/dataManagement'),
          _item(context, Icons.info, 'About', '/about'),
        ],
      ),
    );
  }

  Widget _item(
      BuildContext context, IconData icon, String label, String route) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushReplacementNamed(context, route);
      },
    );
  }
}
