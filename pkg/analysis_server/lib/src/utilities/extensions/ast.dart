// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/src/utilities/extensions/element.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/source.dart';

extension AnnotatedNodeExtensions on AnnotatedNode {
  /// Return the first token in this node that is not a comment.
  Token get firstNonCommentToken {
    final metadata = this.metadata;
    if (metadata.isEmpty) {
      return firstTokenAfterCommentAndMetadata;
    }
    return metadata.beginToken!;
  }
}

extension AstNodeExtensions on AstNode {
  /// Returns [ExtensionElement] declared by an enclosing node.
  ExtensionElement? get enclosingExtensionElement {
    for (final node in withParents) {
      if (node is ExtensionDeclaration) {
        return node.declaredElement2;
      }
    }
    return null;
  }

  /// Return the [IfStatement] associated with `this`.
  IfStatement? get enclosingIfStatement {
    for (var node in withParents) {
      if (node is IfStatement) {
        return node;
      } else if (node is! Expression) {
        return null;
      }
    }
    return null;
  }

  /// Returns [InterfaceElement] declared by an enclosing node.
  InterfaceElement? get enclosingInterfaceElement {
    for (final node in withParents) {
      if (node is ClassDeclaration) {
        return node.declaredElement2;
      } else if (node is MixinDeclaration) {
        return node.declaredElement2;
      }
    }
    return null;
  }

  /// Return `true` if this node has an `override` annotation.
  bool get hasOverride {
    var node = this;
    if (node is AnnotatedNode) {
      for (var annotation in node.metadata) {
        if (annotation.name.name == 'override' &&
            annotation.arguments == null) {
          return true;
        }
      }
    }
    return false;
  }

  bool get inAsyncMethodOrFunction {
    var body = thisOrAncestorOfType<FunctionBody>();
    return body != null && body.isAsynchronous && body.star == null;
  }

  bool get inAsyncStarOrSyncStarMethodOrFunction {
    var body = thisOrAncestorOfType<FunctionBody>();
    return body != null && body.keyword != null && body.star != null;
  }

  bool get inCatchClause => thisOrAncestorOfType<CatchClause>() != null;

  bool get inClassMemberBody {
    var node = this;
    while (true) {
      var body = node.thisOrAncestorOfType<FunctionBody>();
      if (body == null) {
        return false;
      }
      var parent = body.parent;
      if (parent is ConstructorDeclaration || parent is MethodDeclaration) {
        return true;
      } else if (parent == null) {
        return false;
      }
      node = parent;
    }
  }

  bool get inDoLoop => thisOrAncestorOfType<DoStatement>() != null;

  bool get inForLoop =>
      thisOrAncestorMatching((p) => p is ForStatement) != null;

  bool get inLoop => inDoLoop || inForLoop || inWhileLoop;

  bool get inSwitch => thisOrAncestorOfType<SwitchStatement>() != null;

  bool get inWhileLoop => thisOrAncestorOfType<WhileStatement>() != null;

  /// Return this node and all its parents.
  Iterable<AstNode> get withParents sync* {
    var current = this;
    while (true) {
      yield current;
      var parent = current.parent;
      if (parent == null) {
        break;
      }
      current = parent;
    }
  }
}

extension CompilationUnitExtension on CompilationUnit {
  /// Is `true` if library being analyzed is non-nullable by default.
  ///
  /// Will return false if the AST structure has not been resolved.
  bool get isNonNullableByDefault =>
      declaredElement?.library.isNonNullableByDefault ?? false;
}

extension DirectiveExtensions on Directive {
  /// If the target imports or exports a [LibraryElement], returns it.
  LibraryElement? get referencedLibrary {
    final element = element2;
    if (element is LibraryExportElement) {
      return element.exportedLibrary;
    } else if (element is LibraryImportElement) {
      return element.importedLibrary;
    }
    return null;
  }

  /// If [referencedUri] is a [DirectiveUriWithSource], returns the [Source]
  /// from it.
  Source? get referencedSource {
    final uri = referencedUri;
    if (uri is DirectiveUriWithSource) {
      return uri.source;
    }
    return null;
  }

  /// Returns the [DirectiveUri] from the element.
  DirectiveUri? get referencedUri {
    final self = this;
    if (self is AugmentationImportDirective) {
      return self.element2?.uri;
    } else if (self is ExportDirective) {
      return self.element2?.uri;
    } else if (self is ImportDirective) {
      return self.element2?.uri;
    } else if (self is PartDirective) {
      return self.element2?.uri;
    }
    return null;
  }
}

extension ExpressionExtensions on Expression {
  /// Return `true` if this expression is an invocation of the method `cast`
  /// from either Iterable`, `List`, `Map`, or `Set`.
  bool get isCastMethodInvocation {
    if (this is MethodInvocation) {
      var element = (this as MethodInvocation).methodName.staticElement;
      return element is MethodElement && element.isCastMethod;
    }
    return false;
  }

  /// Return `true` if this expression is an invocation of the method `toList`
  /// from either `Iterable` or `List`.
  bool get isToListMethodInvocation {
    if (this is MethodInvocation) {
      var element = (this as MethodInvocation).methodName.staticElement;
      return element is MethodElement && element.isToListMethod;
    }
    return false;
  }
}

extension FunctionBodyExtensions on FunctionBody {
  bool get isEmpty =>
      this is EmptyFunctionBody ||
      (this is BlockFunctionBody && beginToken.isSynthetic);
}

extension MethodDeclarationExtension on MethodDeclaration {
  Token? get propertyKeywordGet {
    final propertyKeyword = this.propertyKeyword;
    return propertyKeyword != null && propertyKeyword.keyword == Keyword.GET
        ? propertyKeyword
        : null;
  }
}

extension VariableDeclarationListExtension on VariableDeclarationList {
  Token? get finalKeyword {
    final keyword = this.keyword;
    return keyword != null && keyword.keyword == Keyword.FINAL ? keyword : null;
  }
}
