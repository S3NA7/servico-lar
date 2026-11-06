import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final dayMonth = DateFormat("d 'de' MMMM", 'pt_BR');
  static final fullDate = DateFormat("EEEE, d 'de' MMMM 'de' y", 'pt_BR');
  static final shortDate = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final time = DateFormat('HH:mm', 'pt_BR');
  static final dateTime = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR');

  static String price(num value) => currency.format(value);

  static String duration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  /// Ex.: "seg, 09/11 · 08:00 – 09:00"
  static String slot(DateTime start, DateTime end) {
    final day = DateFormat('EEE, dd/MM', 'pt_BR').format(start);
    return '$day · ${time.format(start)} – ${time.format(end)}';
  }
}
