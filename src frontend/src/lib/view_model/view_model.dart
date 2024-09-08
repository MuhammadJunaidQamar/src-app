import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:src/model/model.dart';
import 'package:src/utils/const/constants.dart';

class ViewModel {
  static Future<Model> fetchWorldStates(String type) async {
    try {
      final String typeEncoded = Uri.encodeComponent(type);
      final String url =
          '${Constants.baseUrl}${Constants.getDataUrl}?Type=$typeEncoded';
      final response = await http.get(Uri.parse(url));

      if (kDebugMode) {
        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');
        print('Response headers: ${response.headers}');
      }

      if (response.statusCode == 200) {
        // String cleanedResponse = response.body.trim();
        // print(cleanedResponse);
        try {
          var dataFromBackend = jsonDecode(response.body);
          if (dataFromBackend == null || dataFromBackend.isEmpty) {
            throw Exception('No data found.');
          }
          return Model.fromJson(dataFromBackend);
        } catch (e) {
          print('Error decoding JSON: $e');
          throw Exception('Error decoding JSON.');
        }
      } else {
        throw Exception(
            'Request failed with status: ${response.statusCode}. Response body: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error occurred: $e');
      }
      throw Exception('An error occurred: ${e}');
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
