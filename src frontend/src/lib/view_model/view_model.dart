import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:src/model/model.dart';
import 'package:src/utils/constants/constants.dart';

class ViewModel {
  static Future<Model> fetchWorldStates(String type) async {
    try {
      final String typeEncoded = Uri.encodeComponent(type);
      final String url =
          '${Constants.baseUrl}${Constants.getDataUrl}?dataType=$typeEncoded';
      final response = await http.get(Uri.parse(url));

      if (kDebugMode) {
        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');
        print('Response headers: ${response.headers}');
      }

      if (response.statusCode == 200) {
        try {
          var dataFromBackend = jsonDecode(response.body);
          if (dataFromBackend == null || dataFromBackend.isEmpty) {
            throw Exception('No data found.');
          }
          return Model.fromJson(dataFromBackend);
        } catch (e) {
          if (kDebugMode) {
            print('Error decoding JSON: $e');
          }
          throw Exception('Error decoding JSON.');
        }
      } else {
        String errorMessage =
            'Request failed with status: ${response.statusCode} - Response body: ${response.body}';
        if (kDebugMode) {
          print(errorMessage);
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Network error occurred: $e');
      }
      String errorMessage = "";
      if (e is SocketException) {
        errorMessage =
            'You are offline. Please check your internet connection.';
      } else if (e is HttpException && e.message.contains('404')) {
        errorMessage = 'Resource not found.';
      } else {
        errorMessage = e.toString();
      }

      throw Exception(errorMessage);
    }
  }

  // static Future<void> removeWorldStates(String name) async {
  //   try {
  //     final response = await http.delete(
  //       Uri.parse('${Constants.baseUrl}${Constants.deleteDataUrl}?Name=$name'),
  //     );
  //     if (response.statusCode == 200) {
  //       if (kDebugMode) {
  //         print('data deleted successfully');
  //       }
  //     } else {
  //       throw Exception('some error ${response.body}');
  //     }
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('Error occurred: $e');
  //     }
  //     throw Exception('some error ${e}');
  //   }
  // }

  // Future<void> takeAwayWorldStates(
  //     String left, String right, String up, String down) async {
  //   Model model = Model(
  //       left: left, right: right, up: up, down: down);
  //   var data = jsonEncode(model.toJson());

  //   try {
  //     final response = await http.post(
  //       Uri.parse(Constants.baseUrl + Constants.postDataUrl),
  //       headers: {"Content-Type": "application/json"},
  //       body: data,
  //     );

  //     if (response.statusCode == 200) {
  //       print('data sent successfully');
  //     } else {
  //       throw Exception('some error ${response.body}');
  //     }
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('Error occurred: $e');
  //     }
  //     throw Exception('some error ${e}');
  //   }
  // }
}
