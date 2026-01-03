String formatPostDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final sameDay = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (sameDay) {
      return '${two(dt.hour)}:${two(dt.minute)}';
    }
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final md = '${months[dt.month - 1]} ${dt.day}';
    return '$md, ${two(dt.hour)}:${two(dt.minute)}';
  } catch (_) {
    return iso;
  }
}
