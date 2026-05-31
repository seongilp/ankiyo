import 'package:sembast_web/sembast_web.dart';

Future<Database> openAppDatabase() async {
  return databaseFactoryWeb.openDatabase('ankiyo.db');
}
