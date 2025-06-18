import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'response_item_model.dart';
export 'response_item_model.dart';

class ResponseItemWidget extends StatefulWidget {
  const ResponseItemWidget({
    super.key,
    required this.messageItem,
  });

  final dynamic messageItem;

  @override
  State<ResponseItemWidget> createState() => _ResponseItemWidgetState();
}

class _ResponseItemWidgetState extends State<ResponseItemWidget> {
  late ResponseItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ResponseItemModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16.0, 8.0, 16.0, 8.0),
      child: Container(
        width: MediaQuery.sizeOf(context).width * 1.0,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            valueOrDefault<String>(
              widget.messageItem?.toString(),
              '-',
            ).maybeHandleOverflow(
              maxChars: 50,
            ),
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  font: GoogleFonts.inter(
                    fontWeight:
                        FlutterFlowTheme.of(context).bodySmall.fontWeight,
                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                ),
          ),
        ),
      ),
    );
  }
}
