import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:testapp/Bloc/PriceBloc/Bloc.dart';
import 'package:testapp/Screens/PriceAleart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PriceBloc(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Test App',
        home: const PriceAlertScreen(),
      ),
    );
  }
}