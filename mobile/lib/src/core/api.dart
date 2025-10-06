import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Api {
  Api._();
  static final Api I = Api._();

  final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:5050',
      // 👇 allow 4xx to be handled manually
      validateStatus: (status) => status != null && status < 500,
      // optional: get response body on errors too
      receiveDataWhenStatusError: true,
    ),
  );

  bool _installed = false;
  Future<void> install() async {
    if (_installed) return;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opts, handler) async {
          final sp = await SharedPreferences.getInstance();
          final t = sp.getString('token');
          if (t != null) opts.headers['Authorization'] = 'Bearer $t';
          handler.next(opts);
        },
      ),
    );
    _installed = true;
  }
}
