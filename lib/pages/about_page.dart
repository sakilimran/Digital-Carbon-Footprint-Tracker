import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'About This App',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'The Digital Carbon Footprint Tracker is an educational and '
              'research-focused mobile app designed to help users understand '
              'the environmental impact of their social media usage. By '
              'monitoring app usage, this app calculates carbon emissions '
              'based on real-time data and promotes awareness about digital '
              'sustainability.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            SizedBox(height: 12),
            Text(
              'The app includes AI Tips that analyse your usage '
              'patterns and suggest personalised ways to reduce your digital '
              'carbon footprint over time. Usage history can be exported as a '
              'CSV file via the Data Management screen.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            SizedBox(height: 12),
            Text(
              'This application is developed as part of a master\'s thesis '
              'research at LUT University, Finland, investigating AI-enhanced '
              'digital carbon footprint awareness under the Software Engineering '
              'and Digital Transformation programme.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            SizedBox(height: 24),
            Text(
              'Developer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'S M Sakil Imran',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            SizedBox(height: 24),
            Text(
              'Thesis Supervisors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Professor Jari Porras',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            SizedBox(height: 4),
            Text(
              'Post-Doctoral Researcher Md Sanaul Haque',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            SizedBox(height: 24),
            Text(
              'Version',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '2.1.0',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
