import 'dart:io';
import 'package:docx_creator/docx_creator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

class DocumentGenerator {
  Future<String> createDocx(String content, String fileName) async {
    try {
      final doc = docx()
        ..p(content);
      
      final builtDoc = doc.build();
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${directory.path}/${fileName}_$timestamp.docx';
      
      await DocxExporter().exportToFile(builtDoc, outputPath);
      
      return outputPath;
    } catch (e) {
      return 'Error creating document: $e';
    }
  }

  Future<String> saveDocx(String content, String suggestedName) async {
    try {
      final doc = docx()
        ..p(content);
      
      final builtDoc = doc.build();
      final bytes = await DocxExporter().exportToBytes(builtDoc);
      
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Document',
        fileName: '$suggestedName.docx',
        type: FileType.custom,
        allowedExtensions: ['docx'],
      );
      
      if (result != null) {
        final file = File(result);
        await file.writeAsBytes(bytes);
        return result;
      }
      
      return 'Cancelled';
    } catch (e) {
      return 'Error saving document: $e';
    }
  }
}
