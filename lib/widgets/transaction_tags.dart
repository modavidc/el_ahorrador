import 'package:flutter/material.dart';

class TransactionTags extends StatelessWidget {
  final String? sourceApp;
  final String? sourceType;
  final String? ocrConfidence;
  final bool isVerified;

  const TransactionTags({
    super.key,
    this.sourceApp,
    this.sourceType,
    this.ocrConfidence,
    this.isVerified = false,
  });

  @override
  Widget build(BuildContext context) {
    final tags = <Widget>[];

    // Etiqueta de fuente (Yape, Manual, etc.)
    if (sourceApp != null) {
      tags.add(_buildSourceTag());
    }

    // Etiqueta de confianza OCR
    if (sourceType == 'OCR' && ocrConfidence != null) {
      tags.add(_buildConfidenceTag());
    }

    // Etiqueta de verificación
    if (isVerified) {
      tags.add(_buildVerifiedTag());
    }

    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 4.0,
      runSpacing: 2.0,
      children: tags,
    );
  }

  Widget _buildSourceTag() {
    Color backgroundColor;
    Color textColor;
    String text;
    IconData icon;

    switch (sourceApp?.toLowerCase()) {
      case 'yape':
        backgroundColor = Colors.purple.shade100;
        textColor = Colors.purple.shade800;
        text = 'Yape';
        icon = Icons.phone_android;
        break;
      case 'binance':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        text = 'Binance';
        icon = Icons.currency_bitcoin;
        break;
      case 'banco':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        text = 'Banco';
        icon = Icons.account_balance;
        break;
      case 'manual':
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
        text = 'Manual';
        icon = Icons.edit;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
        text = sourceApp ?? 'Otro';
        icon = Icons.receipt;
        break;
    }

    return _buildTag(
      backgroundColor: backgroundColor,
      textColor: textColor,
      text: text,
      icon: icon,
    );
  }

  Widget _buildConfidenceTag() {
    final confidence = int.tryParse(ocrConfidence ?? '0') ?? 0;
    
    Color backgroundColor;
    Color textColor;
    
    if (confidence >= 80) {
      backgroundColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
    } else if (confidence >= 60) {
      backgroundColor = Colors.orange.shade100;
      textColor = Colors.orange.shade800;
    } else {
      backgroundColor = Colors.red.shade100;
      textColor = Colors.red.shade800;
    }

    return _buildTag(
      backgroundColor: backgroundColor,
      textColor: textColor,
      text: '$confidence%',
      icon: Icons.visibility,
      isSmall: true,
    );
  }

  Widget _buildVerifiedTag() {
    return _buildTag(
      backgroundColor: Colors.green.shade100,
      textColor: Colors.green.shade800,
      text: 'Verificado',
      icon: Icons.check_circle,
      isSmall: true,
    );
  }

  Widget _buildTag({
    required Color backgroundColor,
    required Color textColor,
    required String text,
    required IconData icon,
    bool isSmall = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6.0 : 8.0,
        vertical: isSmall ? 2.0 : 4.0,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(isSmall ? 8.0 : 12.0),
        border: Border.all(
          color: textColor.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isSmall ? 10.0 : 12.0,
            color: textColor,
          ),
          SizedBox(width: isSmall ? 2.0 : 4.0),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: isSmall ? 10.0 : 11.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Widget específico para mostrar solo la confianza OCR como un círculo
class OcrConfidenceIndicator extends StatelessWidget {
  final String? ocrConfidence;
  final double size;

  const OcrConfidenceIndicator({
    super.key,
    this.ocrConfidence,
    this.size = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final confidence = int.tryParse(ocrConfidence ?? '0') ?? 0;
    
    if (confidence == 0) {
      return const SizedBox.shrink();
    }

    Color color;
    if (confidence >= 80) {
      color = Colors.green;
    } else if (confidence >= 60) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2.0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$confidence',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
