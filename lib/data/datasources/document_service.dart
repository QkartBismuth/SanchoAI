import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:doc_text_extractor/doc_text_extractor.dart';

class DocumentService {
  Future<String> extractText(String filePath) async {
    final extension = filePath.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'pdf':
        return await _extractPdfText(filePath);
      case 'docx':
        return await _extractDocxText(filePath);
      case 'txt':
        return await _extractTxtText(filePath);
      case 'doc':
        return 'Error: .doc format not supported. Please convert to .docx or PDF.';
      default:
        return 'Error: Unsupported file format. Supported: .pdf, .docx, .txt';
    }
  }

  Future<String> _extractPdfText(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final StringBuffer textBuffer = StringBuffer();
      
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      for (int i = 0; i < document.pages.count; i++) {
        final String pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        textBuffer.writeln(pageText);
      }
      
      document.dispose();
      return textBuffer.toString().trim();
    } catch (e) {
      return 'Error reading PDF: $e';
    }
  }

  Future<String> _extractDocxText(String filePath) async {
    try {
      final extractor = TextExtractor();
      final result = await extractor.extractText(filePath, isUrl: false);
      return result.text.trim();
    } catch (e) {
      return 'Error reading DOCX: $e';
    }
  }

  Future<String> _extractTxtText(String filePath) async {
    try {
      final file = File(filePath);
      final text = await file.readAsString();
      return text.trim();
    } catch (e) {
      return 'Error reading TXT: $e';
    }
  }
}
