import 'package:flutter/material.dart';
import '../services/app_constants.dart';

class CarbonCircle extends StatelessWidget {
  final double co2Value;    // grams
  final double energyValue; // mAh

  const CarbonCircle({
    Key? key,
    required this.co2Value,
    required this.energyValue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double co2Kg = co2Value / 1000.0;
    final double diameter = MediaQuery.of(context).size.width * 0.8;

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kCardBackground,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              co2Kg.toStringAsFixed(3),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: diameter * 0.15,
              ),
            ),
            Text(
              'kg of CO₂',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: diameter * 0.07,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              energyValue.toStringAsFixed(2),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: diameter * 0.15,
              ),
            ),
            Text(
              'mAh of Energy',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: diameter * 0.07,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
