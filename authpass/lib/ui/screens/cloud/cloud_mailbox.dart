import 'package:authpass/bloc/authpass_cloud_bloc.dart';
import 'package:authpass/ui/screens/cloud/cloud_mail_read.dart';
import 'package:authpass/ui/widgets/async/retry_future_builder.dart';
import 'package:authpass/utils/format_utils.dart';
import 'package:authpass_cloud_shared/authpass_cloud_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

class CloudMailboxScreen extends StatelessWidget {
  static MaterialPageRoute<void> route() => MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/cloud_mailbox/'),
        builder: (_) => CloudMailboxScreen(),
      );

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<AuthPassCloudBloc>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mailboxes'),
      ),
      body: CloudMailboxList(bloc: bloc),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Create'),
        onPressed: () async {
          await bloc.createMailbox();
        },
      ),
    );
  }
}

class CloudMailboxTabScreen extends StatefulWidget {
  static MaterialPageRoute<void> route() => MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/cloud_mailbox_tab/'),
        builder: (_) => CloudMailboxTabScreen(),
      );

  @override
  _CloudMailboxTabScreenState createState() => _CloudMailboxTabScreenState();
}

class _CloudMailboxTabScreenState extends State<CloudMailboxTabScreen>
    with SingleTickerProviderStateMixin {
  TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_tabChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _tabChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<AuthPassCloudBloc>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AuthPass Mail'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Mailbox',
              icon: Icon(FontAwesomeIcons.boxOpen),
            ),
            Tab(
              text: 'Mail',
              icon: Icon(FontAwesomeIcons.mailBulk),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CloudMailboxList(bloc: bloc),
          CloudMailList(bloc: bloc),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                await bloc.createMailbox();
              },
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            )
          : null,
    );
  }
}

class CloudMailboxList extends StatelessWidget {
  const CloudMailboxList({Key key, @required this.bloc}) : super(key: key);

  final AuthPassCloudBloc bloc;

  @override
  Widget build(BuildContext context) {
    final formatUtil = context.watch<FormatUtils>();
    return RetryFutureBuilder<List<Mailbox>>(
        produceFuture: (context) => bloc.loadMailboxList(),
        builder: (context, data) {
          if (data.isEmpty) {
            return const Center(
              child: Text('You do not have any mailboxes yet.'),
            );
          }
          return ListView.builder(
            itemBuilder: (context, idx) {
              final mailbox = data[idx];
              return ListTile(
                title: Text(mailbox.address),
                subtitle: Text('Created at '
                    '${formatUtil.formatDateFull(mailbox.createdAt)}'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: mailbox.address));
                  Scaffold.of(context)
                    ..hideCurrentSnackBar(reason: SnackBarClosedReason.hide)
                    ..showSnackBar(
                      SnackBar(
                        content: Text('Copied mailbox address to clipboard: '
                            '${mailbox.address}'),
                      ),
                    );
                },
              );
            },
            itemCount: data.length,
          );
        });
  }
}

class CloudMailList extends StatelessWidget {
  const CloudMailList({Key key, @required this.bloc}) : super(key: key);

  final AuthPassCloudBloc bloc;

  @override
  Widget build(BuildContext context) {
    final formatUtil = context.watch<FormatUtils>();
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () async {
        await bloc.loadMessageListMore(reload: true);
      },
      child: RetryStreamBuilder<EmailMessageList>(
          stream: (context) => bloc.messageList,
          retry: () => bloc.loadMessageListMore(),
          builder: (context, data) {
            if (data.messages.isEmpty) {
              if (data.hasMore) {
                bloc.loadMessageListMore();
                return const Center(child: CircularProgressIndicator());
              }
              return const Center(
                child: Text('You do not have any mails yet.'),
              );
            }
            return ListView.builder(
              itemCount: data.messages.length,
              itemBuilder: (context, idx) {
                if (idx + 1 == data.messages.length) {
                  bloc.loadMessageListMore();
                }
                final message = data.messages[idx];
                return ListTile(
                  leading: message.isRead
                      ? const Icon(FontAwesomeIcons.envelopeOpen)
                      : Icon(
                          FontAwesomeIcons.envelope,
                          color: theme.primaryColor,
                        ),
                  title: Text(message.subject),
                  subtitle: Text('${message.sender}\n'
                      '${formatUtil.formatDateFull(message.createdAt)}'),
                  isThreeLine: true,
                  onTap: () async {
                    await Navigator.of(context)
                        .push(EmailReadScreen.route(bloc, message));
                  },
                );
              },
            );
          }),
    );
  }
}
