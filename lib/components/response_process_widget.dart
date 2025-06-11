import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'response_process_model.dart';
export 'response_process_model.dart';

class ResponseProcessWidget extends StatefulWidget {
  const ResponseProcessWidget({
    super.key,
    this.parameter1,
  });

  final dynamic parameter1;

  @override
  State<ResponseProcessWidget> createState() => _ResponseProcessWidgetState();
}

class _ResponseProcessWidgetState extends State<ResponseProcessWidget> {
  late ResponseProcessModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ResponseProcessModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(16.0, 8.0, 16.0, 8.0),
          child: Container(
            width: 100.0,
            height: 30.0,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
            ),
            child: Text(
              widget.parameter1!.toString(),
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.inter(
                      fontWeight:
                          FlutterFlowTheme.of(context).bodySmall.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).bodySmall.fontWeight,
                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                  ),
            ),
          ),
        ),
        Container(
          width: 1.0,
          height: 1.0,
          child: custom_widgets.AutoPlayAudioResponse(
            width: 1.0,
            height: 1.0,
            base64Audio: getJsonField(
              widget.parameter1,
              r'''$.audio_event.audio_base_64''',
            ).toString(),
          ),
        ),
      ],
    );
  }
}
