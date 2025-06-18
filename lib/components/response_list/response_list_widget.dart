import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/conversation_service.dart';
import '/custom_code/websocket_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'response_list_model.dart';
export 'response_list_model.dart';

class ResponseListWidget extends StatefulWidget {
  const ResponseListWidget({super.key});

  @override
  State<ResponseListWidget> createState() => _ResponseListWidgetState();
}

class _ResponseListWidgetState extends State<ResponseListWidget> {
  late ResponseListModel _model;
  final _conversationService = ConversationService.instance;

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
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppState>(
      stream: _conversationService.stateStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final state = snapshot.data!;
        final messages = state.chatHistory;

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
                const SizedBox(height: 16),
                Text(
                  'Start a conversation',
                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                    fontFamily: GoogleFonts.interTight().fontFamily,
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Press and hold the button to speak',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: GoogleFonts.interTight().fontFamily,
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          itemCount: messages.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final message = messages[index];
            final isSystem = message.metadata?['type'] == 'system';
            
            if (isSystem) {
              return _buildSystemMessage(message);
            }
            
            return _buildChatMessage(message);
          },
        );
      },
    );
  }

  Widget _buildSystemMessage(ChatMessage message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).accent4,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: FlutterFlowTheme.of(context).secondaryText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.text,
              style: FlutterFlowTheme.of(context).bodySmall.override(
                fontFamily: GoogleFonts.interTight().fontFamily,
                color: FlutterFlowTheme.of(context).secondaryText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessage(ChatMessage message) {
    final isUser = message.isUser;
    
    return Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isUser) ...[
          CircleAvatar(
            radius: 16,
            backgroundColor: FlutterFlowTheme.of(context).primary,
            child: Icon(
              Icons.smart_toy,
              size: 18,
              color: FlutterFlowTheme.of(context).primaryBackground,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: isUser 
                ? FlutterFlowTheme.of(context).primary
                : FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isUser ? const Radius.circular(4) : null,
                bottomLeft: !isUser ? const Radius.circular(4) : null,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: GoogleFonts.interTight().fontFamily,
                    color: isUser 
                      ? FlutterFlowTheme.of(context).primaryBackground
                      : FlutterFlowTheme.of(context).primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(message.timestamp),
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                    fontFamily: GoogleFonts.interTight().fontFamily,
                    color: isUser 
                      ? FlutterFlowTheme.of(context).primaryBackground.withOpacity(0.7)
                      : FlutterFlowTheme.of(context).secondaryText,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isUser) ...[
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: FlutterFlowTheme.of(context).secondary,
            child: Icon(
              Icons.person,
              size: 18,
              color: FlutterFlowTheme.of(context).primaryBackground,
            ),
          ),
        ],
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}
