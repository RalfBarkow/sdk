// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/src/services/correction/dart/abstract_producer.dart';
import 'package:analysis_server/src/services/correction/fix.dart';
import 'package:analysis_server/src/services/correction/util.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

class RemoveUnusedLocalVariable extends CorrectionProducer {
  @override
  // Not predictably the correct action.
  bool get canBeAppliedInBulk => false;

  @override
  // Not predictably the correct action.
  bool get canBeAppliedToFile => false;

  @override
  FixKind get fixKind => DartFixKind.REMOVE_UNUSED_LOCAL_VARIABLE;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final declaration = node.parent;
    if (!(declaration is VariableDeclaration && declaration.name2 == token)) {
      return;
    }

    var element = declaration.declaredElement2;
    if (element is! LocalVariableElement) {
      return;
    }

    final sourceRanges = <SourceRange>[];

    final functionBody = declaration.thisOrAncestorOfType<FunctionBody>();
    if (functionBody == null) {
      return;
    }

    final references = findLocalElementReferences(functionBody, element);
    for (var reference in references) {
      final node = reference.thisOrAncestorMatching((node) =>
          node is VariableDeclaration || node is AssignmentExpression);

      SourceRange? sourceRange;
      if (node is AssignmentExpression) {
        sourceRange = _forAssignmentExpression(node);
      } else if (node is VariableDeclaration) {
        sourceRange = _forVariableDeclaration(node);
      }

      if (sourceRange == null) {
        return;
      }

      var isCovered = false;
      for (var other in sourceRanges) {
        if (other.covers(sourceRange)) {
          isCovered = true;
        } else if (other.intersects(sourceRange)) {
          return;
        }
      }

      if (isCovered) {
        continue;
      }

      sourceRanges.add(sourceRange);
    }

    await builder.addDartFileEdit(file, (builder) {
      for (var sourceRange in sourceRanges) {
        builder.addDeletion(sourceRange);
      }
    });
  }

  SourceRange _forAssignmentExpression(AssignmentExpression node) {
    // todo (pq): consider node.parent is! ExpressionStatement to handle
    // assignments in parens, etc.
    var parent = node.parent!;
    if (parent is ArgumentList) {
      return range.startStart(node, node.operator.next!);
    } else {
      return utils.getLinesRange(range.node(parent));
    }
  }

  SourceRange? _forVariableDeclaration(VariableDeclaration node) {
    var declarationList = node.parent as VariableDeclarationList;

    var declarationListParent = declarationList.parent;
    if (declarationListParent is VariableDeclarationStatement) {
      if (declarationList.variables.length == 1) {
        return utils.getLinesRange(range.node(declarationListParent));
      } else {
        return range.nodeInList(declarationList.variables, node);
      }
    } else {
      return null;
    }
  }
}
