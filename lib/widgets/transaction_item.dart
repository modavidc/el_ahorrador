import 'package:flutter/material.dart';
import '../models/transaction.dart';
import 'transaction_tags.dart';

class TransactionItem extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionItem({super.key, required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            // Icono de la categoría (amarillo como en la imagen)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getCategoryColor().withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getCategoryIcon(),
                color: _getCategoryColor(),
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            // Información principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Descripción principal (Maria E. Tacuche C.)
                  Text(
                    transaction.description,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 2),
                  // Categoría con icono y texto
                  Row(
                    children: [
                      Icon(
                        _getCategoryIcon(),
                        size: 14,
                        color: _getCategoryColor(),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Categoría: ${transaction.categoryDisplayName}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 2),

                  if (transaction.subcategory.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.label_outline,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Subcategoría: ${transaction.subcategory}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 2),

                  // Cuenta (Interbank Soles)
                  Text(
                    transaction.account,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Vendor y teléfono (más pequeño) - solo si hay información adicional
                  _buildVendorInfo(),

                  const SizedBox(height: 4),

                  // Etiquetas de transacción (Yape, OCR, etc.)
                  _buildTransactionTags(),
                ],
              ),
            ),

            const SizedBox(width: 12),

            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Monto, anunciado con su tipo y valor.
                  Semantics(
                    label:
                        '${transaction.type.name}, ${transaction.formattedAmount}',
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        transaction.formattedAmount,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _getAmountColor(),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 2),

                  // Hora
                  Text(
                    _formatTime(transaction.date),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),

                  const SizedBox(height: 4),

                  // Icono para ver captura OCR
                  _buildOcrIcon(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorInfo() {
    // Extraer información del vendor de las notas si es de Yape
    final text = '${transaction.description} ${transaction.notes ?? ''}'
        .toLowerCase();

    if (text.contains('yape') || text.contains('¡yapeaste!')) {
      // Buscar patrones de vendor en las notas
      final vendorMatch = RegExp(
        r'Vendor: ([^,]+)',
      ).firstMatch(transaction.notes ?? '');
      final phoneMatch = RegExp(
        r'Teléfono: (\d+)',
      ).firstMatch(transaction.notes ?? '');

      if (vendorMatch != null || phoneMatch != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vendorMatch != null)
              Text(
                vendorMatch.group(1) ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            if (phoneMatch != null)
              Text(
                phoneMatch.group(1) ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
          ],
        );
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildOcrIcon() {
    final text = '${transaction.description} ${transaction.notes ?? ''}'
        .toLowerCase();

    if (text.contains('yape') || text.contains('ocr')) {
      return Semantics(
        button: true,
        label: 'Ver captura OCR',
        child: GestureDetector(
          onTap: () {
            // TODO: Navegar a pantalla de captura OCR
          },
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.visibility, size: 16, color: Colors.grey[400]),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Color _getCategoryColor() {
    // Usar el color del modelo Transaction
    return transaction.color;
  }

  IconData _getCategoryIcon() {
    // Usar el icono del modelo Transaction
    return transaction.icon;
  }

  Color _getAmountColor() {
    // Usar colores basados en el tipo de transacción
    switch (transaction.type) {
      case TransactionType.expense:
        return Colors.red;
      case TransactionType.income:
        return Colors.green;
      case TransactionType.transfer:
        return Colors.orange;
    }
  }

  String _formatTime(DateTime date) {
    // Mostrar hora en formato HH:MM
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildTransactionTags() {
    // Determinar el tipo de fuente basado en la descripción y notas
    String? sourceApp;
    String? sourceType;
    String? ocrConfidence;
    bool isVerified = false;

    final text = '${transaction.description} ${transaction.notes ?? ''}'
        .toLowerCase();

    // Detectar si es de Yape
    if (text.contains('yape') || text.contains('¡yapeaste!')) {
      sourceApp = 'Yape';
      sourceType = 'OCR';
      // Extraer confianza OCR de las notas
      final confidenceMatch = RegExp(
        r'\[OCR Confianza: (\d+)%\]',
      ).firstMatch(text);
      ocrConfidence = confidenceMatch?.group(1) ?? '85';
    }
    // Detectar si es de Binance
    else if (text.contains('binance')) {
      sourceApp = 'Binance';
      sourceType = 'OCR';
      ocrConfidence = '90';
    }
    // Detectar si es manual
    else if (text.contains('manual') || text.contains('editado')) {
      sourceApp = 'Manual';
      sourceType = 'MANUAL';
      isVerified = true;
    }
    // Detectar si es transferencia bancaria
    else if (text.contains('transferencia') ||
        text.contains('bcp') ||
        text.contains('interbank')) {
      sourceApp = 'Banco';
      sourceType = 'OCR';
      ocrConfidence = '75';
    }

    // Solo mostrar tags si hay información relevante
    if (sourceApp != null) {
      return TransactionTags(
        sourceApp: sourceApp,
        sourceType: sourceType,
        ocrConfidence: ocrConfidence,
        isVerified: isVerified,
      );
    }

    return const SizedBox.shrink();
  }
}
