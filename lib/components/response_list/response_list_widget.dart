import '/components/response_item/response_item_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'response_list_model.dart';
export 'response_list_model.dart';

class ResponseListWidget extends StatefulWidget {
  const ResponseListWidget({super.key});

  @override
  State<ResponseListWidget> createState() => _ResponseListWidgetState();
}

class _ResponseListWidgetState extends State<ResponseListWidget> {
  late ResponseListModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ResponseListModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Align(
      alignment: AlignmentDirectional(0.0, -1.0),
      child: Builder(
        builder: (context) {
          final conversationMessages =
              FFAppState().conversationMessages.toList();

          return ListView.builder(
            padding: EdgeInsets.zero,
            reverse: true,
            shrinkWrap: true,
            scrollDirection: Axis.vertical,
            itemCount: conversationMessages.length,
            itemBuilder: (context, conversationMessagesIndex) {
              final conversationMessagesItem =
                  conversationMessages[conversationMessagesIndex];
              return wrapWithModel(
                model: _model.responseItemModels.getModel(
                  conversationMessagesIndex.toString(),
                  conversationMessagesIndex,
                ),
                updateCallback: () => safeSetState(() {}),
                child: ResponseItemWidget(
                  key: Key(
                    'Keyn3v_${conversationMessagesIndex.toString()}',
                  ),
                  messageItem: conversationMessagesItem,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
