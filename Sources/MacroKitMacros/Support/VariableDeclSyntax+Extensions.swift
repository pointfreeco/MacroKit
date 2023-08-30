extension VariableDeclSyntax {
  public var isComputed: Bool {
    return bindings.contains(where: { $0.accessorBlock?.is(CodeBlockSyntax.self) == true })
  }
  public var isStored: Bool {
    return !isComputed
  }
  public var isStatic: Bool {
    return modifiers.lazy.contains(where: { $0.name.tokenKind == .keyword(.static) }) == true
  }
  public var identifier: TokenSyntax {
    return bindings.lazy.compactMap({ $0.pattern.as(IdentifierPatternSyntax.self) }).first!
      .identifier
  }

  public var type: TypeAnnotationSyntax? {
    return bindings.lazy.compactMap(\.typeAnnotation).first
  }

  public var initializerValue: ExprSyntax? {
    return bindings.lazy.compactMap(\.initializer).first?.value
  }

  public var effectSpecifiers: AccessorEffectSpecifiersSyntax? {
    return bindings
      .lazy
      .compactMap(\.accessorBlock?.accessors)
      .compactMap({ accessor in
        switch accessor {
        case .accessors(let syntax):
          return syntax.lazy.compactMap(\.effectSpecifiers).first
        case .getter:
          return nil
        }
      })
      .first
  }
  public var isThrowing: Bool {
    return
      bindings
      .compactMap(\.accessorBlock?.accessors)
      .contains(where: { accessor in
        switch accessor {
        case .accessors(let syntax):
          return syntax.contains(where: { $0.effectSpecifiers?.throwsSpecifier != nil })
        case .getter:
          return false
        }
      })
  }
  public var isAsync: Bool {
    return
      bindings
      .compactMap(\.accessorBlock?.accessors)
      .contains(where: { accessor in
        switch accessor {
        case .accessors(let syntax):
          return syntax.lazy.contains(where: { $0.effectSpecifiers?.asyncSpecifier != nil })
        case .getter:
          return false
        }
      })
  }

  public var getter: AccessorDeclSyntax? {
    get {
      return bindings
        .lazy
        .compactMap(\.accessorBlock?.accessors)
        .compactMap { accessor in
          switch accessor {
          case .getter(let body):
            var getter = AccessorDeclSyntax(
              accessorSpecifier: .keyword(.get), body: CodeBlockSyntax(body))
            getter.modifier = DeclModifierSyntax(
              name: TokenSyntax(stringLiteral: accessLevel.rawValue))
            return getter

          case .accessors(let block):
            return block.lazy.first(where: { $0.accessorSpecifier.tokenKind == .keyword(.get) })?
              .trimmed
          }
        }
        .first
    }
    set {
      guard let newValue else { fatalError("Removing getters is not supported") }

      for (x, var binding) in bindings.enumerated() {
        guard var accessor = binding.accessorBlock?.accessors else { continue }

        switch accessor {
        case .getter:
          accessor = .accessors(.init([newValue]))
          binding.accessorBlock?.accessors = accessor
          bindings[bindings.index(bindings.startIndex, offsetBy: x)] = binding
          return

        case .accessors(var block):
          var update = Array(block.lazy)
          for (index, accessor) in block.lazy.enumerated() {
            if accessor.accessorSpecifier.tokenKind == .keyword(.get) {
              update[index] = newValue
              //                            update = update.replacing(childAt: index, with: newValue)
            } else {
              update[index] = accessor.trimmed
              //                            update = update.replacing(childAt: index, with: accessor.trimmed)
            }
          }

          block = .init(update)
          accessor = .accessors(block)
          binding.accessorBlock?.accessors = accessor
          bindings[bindings.index(bindings.startIndex, offsetBy: x)] = binding
          return
        }
      }

      bindings[bindings.startIndex].accessorBlock?.accessors = .accessors([newValue])
    }
  }
  public var setter: AccessorDeclSyntax? {
    get {
      return bindings
        .lazy
        .compactMap(\.accessorBlock?.accessors)
        .compactMap { accessor in
          switch accessor {
          case .getter:
            return nil

          case .accessors(let block):
            return block.lazy.first(where: { $0.accessorSpecifier.tokenKind == .keyword(.set) })?
              .trimmed
          }
        }
        .first
    }
    set {
      for (x, var binding) in bindings.enumerated() {
        guard var accessor = binding.accessorBlock?.accessors else { continue }

        switch accessor {
        case .getter(let body):
          guard let newValue else { return }

          accessor = .accessors(
            .init([
              AccessorDeclSyntax(accessorSpecifier: .keyword(.get), body: .init(statements: body)),
              newValue,
            ]))
          binding.accessorBlock?.accessors = accessor
          bindings[bindings.index(bindings.startIndex, offsetBy: x)] = binding
          return

        case .accessors(var block):
          var update = Array(block.lazy)
          for (index, accessor) in block.lazy.enumerated() {
            if accessor.accessorSpecifier.tokenKind == .keyword(.set) {
              if let newValue {
                update[index] = newValue
                //                                update = update.replacing(childAt: index, with: newValue)
              } else {
                update.remove(at: index)
                //                                update = update.removing(childAt: index)
              }
            } else {
              update[index] = accessor.trimmed
              //                            update = update.replacing(childAt: index, with: accessor.trimmed)
            }
          }

          if update.count == 1, let newValue {
            update = update + [newValue]
          }

          block = .init(update)
          accessor = .accessors(block)
          binding.accessorBlock?.accessors = accessor
          bindings[bindings.index(bindings.startIndex, offsetBy: x)] = binding
          return
        }
      }
    }
  }
}
