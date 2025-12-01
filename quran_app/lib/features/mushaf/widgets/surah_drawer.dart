import 'package:flutter/material.dart';

class SurahDrawer extends StatelessWidget {
  final Function(int) onSurahSelected;

  const SurahDrawer({super.key, required this.onSurahSelected});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Center(
              child: Text(
                'Surah Index',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 114,
              itemBuilder: (context, index) {
                final surahNumber = index + 1;
                return ListTile(
                  title: Text('Surah $surahNumber'),
                  onTap: () {
                    onSurahSelected(surahNumber);
                    Navigator.pop(context); // Close the drawer
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
