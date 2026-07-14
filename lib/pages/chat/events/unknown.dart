// В _buildMemberEvent или отдельный метод для RoomCreate

if (event.type == EventTypes.RoomCreate) {
  final sender = event.senderId ?? 'Пользователь';
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.blue.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: .min,
      children: [
        Icon(Icons.create_outlined, size: 14, color: Colors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$sender создал(а) комнату',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}