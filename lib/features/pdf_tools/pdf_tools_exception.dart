/// User-facing PDF-tool failure. [toString] is the message shown in UI.
class PdfToolsException implements Exception {
  const PdfToolsException(this.message);

  final String message;

  factory PdfToolsException.password() => const PdfToolsException(
        "This PDF is password protected. ScanMe can't modify it without the password.",
      );

  factory PdfToolsException.invalid() => const PdfToolsException(
        "This PDF looks damaged or isn't a valid PDF. Try another file.",
      );

  factory PdfToolsException.empty() => const PdfToolsException(
        'This PDF has no pages.',
      );

  factory PdfToolsException.tooFew({int min = 2}) => PdfToolsException(
        min == 2
            ? 'Choose at least two PDFs to merge.'
            : 'Need at least $min pages for this action.',
      );

  factory PdfToolsException.needPages({int min = 2}) => PdfToolsException(
        'This PDF needs at least $min pages to split this way.',
      );

  factory PdfToolsException.selectPages() => const PdfToolsException(
        'Select at least one page.',
      );

  factory PdfToolsException.keepOne() => const PdfToolsException(
        'Keep at least one page in the PDF.',
      );

  factory PdfToolsException.cancelled() => const PdfToolsException(
        'Cancelled.',
      );

  @override
  String toString() => message;
}
