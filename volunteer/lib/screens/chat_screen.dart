import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/message.dart';
import '../providers/data_provider.dart';
import '../utils/format.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DataProvider>().fetchChatUsers();
    });
  }

  Future<void> _refresh() async {
    await context.read<DataProvider>().fetchChatUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Повідомлення')),
      body: Consumer<DataProvider>(
        builder: (context, data, _) {
          final users = data.chatUsers;
          if (users.isEmpty) {
            if (data.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Немає доступних чатів',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: users.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) => _ChatTile(preview: users[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatPreview preview;
  const _ChatTile({required this.preview});

  String get _roleLabel {
    switch (preview.role) {
      case 'organiser':
        return 'Організатор';
      case 'admin':
        return 'Адміністратор';
      default:
        return 'Волонтер';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.primary,
        child: Text(preview.initials),
      ),
      title: Text(
        preview.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        preview.lastContent != null
            ? (preview.lastFromMe ? 'Ви: ${preview.lastContent}' : preview.lastContent!)
            : _roleLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey.shade700),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (preview.lastAt != null)
            Text(
              relativeTime(preview.lastAt!),
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          if (preview.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${preview.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
        ],
      ),
      onTap: () async {
        await Navigator.pushNamed(
          context,
          '/chat-thread',
          arguments: ChatThreadArgs(
            username: preview.username,
            displayName: preview.name,
          ),
        );
        if (context.mounted) {
          context.read<DataProvider>().fetchChatUsers();
        }
      },
    );
  }
}
