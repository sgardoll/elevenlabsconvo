import '/components/response_item/response_item_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'response_list_widget.dart' show ResponseListWidget;
import 'package:flutter/material.dart';

class ResponseListModel extends FlutterFlowModel<ResponseListWidget> {
  ///  State fields for stateful widgets in this component.

  // Models for ResponseItem dynamic component.
  late FlutterFlowDynamicModels<ResponseItemModel> responseItemModels;

  @override
  void initState(BuildContext context) {
    responseItemModels = FlutterFlowDynamicModels(() => ResponseItemModel());
  }

  @override
  void dispose() {
    responseItemModels.dispose();
  }
}
