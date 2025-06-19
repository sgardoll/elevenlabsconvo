import '/flutter_flow/flutter_flow_util.dart';
import 'demo_widget.dart' show DemoWidget;
import 'package:flutter/material.dart';

class DemoModel extends FlutterFlowModel<DemoWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for Key widget.
  FocusNode? keyFocusNode;
  TextEditingController? keyTextController;
  late bool keyVisibility;
  String? Function(BuildContext, String?)? keyTextControllerValidator;
  // State field(s) for AgentID widget.
  FocusNode? agentIDFocusNode;
  TextEditingController? agentIDTextController;
  String? Function(BuildContext, String?)? agentIDTextControllerValidator;
  // Stores action output result for [Custom Action - initializeWebSocket] action in Button widget.
  String? initElevenlabsWsTestScreen;

  @override
  void initState(BuildContext context) {
    keyVisibility = false;
  }

  @override
  void dispose() {
    keyFocusNode?.dispose();
    keyTextController?.dispose();

    agentIDFocusNode?.dispose();
    agentIDTextController?.dispose();
  }
}
